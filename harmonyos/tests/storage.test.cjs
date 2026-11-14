const { test } = require('node:test');
const assert = require('node:assert/strict');
const { DatabaseSync } = require('node:sqlite');
const { loadEts } = require('./ets-loader.cjs');
const base = 'entry/src/main/ets/';
const log = { info(){}, warn(){}, error(){} };
function harness(options={}) {
 const sql = new DatabaseSync(':memory:'); let fail = false;let backups=0;let removedBackups=[];
 if(options.legacy){sql.exec("CREATE TABLE course(id TEXT PRIMARY KEY,table_id TEXT NOT NULL,name TEXT NOT NULL,teacher TEXT,room TEXT,campus TEXT,weekday INTEGER NOT NULL,start_period INTEGER NOT NULL,end_period INTEGER NOT NULL,weeks TEXT NOT NULL,color_index INTEGER NOT NULL);CREATE TABLE timetable(id TEXT PRIMARY KEY,name TEXT NOT NULL,is_active INTEGER DEFAULT 0);INSERT INTO timetable VALUES ('t1','default',1),('old_custom','legacy',0);INSERT INTO course VALUES ('legacy_id','t1','legacy course','','','',1,1,2,'1,2',0)");}
 const result=rows=>{let at=-1;return{rowCount:rows.length,goToNextRow:()=>++at<rows.length,getColumnIndex:k=>k,getString:k=>String(rows[at][k]??''),getLong:k=>Number(rows[at][k]),close(){}};};
 class Pred { constructor(table){this.table=table;this.where=[];this.args=[];} equalTo(k,v){this.where.push(k+'=?');this.args.push(v);return this;} orderByAsc(){return this;} }
 const where=p=>p.where.length?' WHERE '+p.where.join(' AND '):'';
 const store={
  executeSql:async(s,args=[])=>{if(options.failMigration&&s.startsWith('ALTER TABLE timetable'))throw Error('migration fault');return sql.prepare(s).run(...args);},
  querySql:async(s,args=[])=>result(sql.prepare(s).all(...args)),
  update:async(b,p)=>{const keys=Object.keys(b);return sql.prepare('UPDATE '+p.table+' SET '+keys.map(k=>k+'=?').join(',')+where(p)).run(...Object.values(b),...p.args).changes;},
  beginTransaction:()=>sql.exec('BEGIN'),commit:()=>sql.exec('COMMIT'),rollBack:()=>sql.exec('ROLLBACK'),
  backup:async()=>{backups++;},
  delete:async p=>sql.prepare('DELETE FROM '+p.table+where(p)).run(...p.args).changes,
  insert:async(t,b)=>{if(fail)throw Error('disk fault');const k=Object.keys(b);return sql.prepare('INSERT INTO '+t+' ('+k.join(',')+') VALUES ('+k.map(()=>'?').join(',')+')').run(...Object.values(b)).changes;},
  batchInsert:async(t,bs)=>{for(const b of bs)await store.insert(t,b);return bs.length;},
  query:async(p,cols)=>{const rows=sql.prepare('SELECT '+cols.join(',')+' FROM '+p.table+where(p)).all(...p.args);let at=-1;return {rowCount:rows.length,goToNextRow:()=>++at<rows.length,getColumnIndex:k=>k,getString:k=>String(rows[at][k]??''),getLong:k=>Number(rows[at][k]),close(){}};}
 };
 const mocks={'@ohos.data.relationalStore':{default:{getRdbStore:async()=>store,deleteRdbStore:async(ctx,name)=>{removedBackups.push(name);},SecurityLevel:{S1:1},RdbPredicates:Pred}},'@ohos.hilog':{default:log}};
 const cache=new Map(); const {Db}=loadEts(base+'data/local/Db.ets',mocks,cache);
 const {CourseRepositoryImpl}=loadEts(base+'data/repository/CourseRepositoryImpl.ets',mocks,cache);
 return {sql,Db,repo:new CourseRepositoryImpl(),fault:()=>fail=true,backups:()=>backups,removedBackups:()=>removedBackups};
}
const course={id:'school1',name:'课程',teacher:'教师',room:'教室',campus:'校区',weekday:1,startPeriod:1,endPeriod:2,weeks:[1,2],colorIndex:0};
test('failed replacement retains previous timetable',async()=>{const h=harness();await h.Db.open({});await h.repo.replaceAll('t1',[course]);h.fault();await assert.rejects(h.repo.replaceAll('t1',[{...course,name:'new'}]));assert.equal((await h.repo.listAll('t1'))[0].name,'课程');});
test('same source course in two tables remains independently removable',async()=>{const h=harness();await h.Db.open({});await h.repo.replaceAll('t1',[course]);await h.repo.replaceAll('t2',[course]);const first=(await h.repo.listAll('t1'))[0];await h.repo.remove(first.id);assert.equal((await h.repo.listAll('t2')).length,1);assert.equal((await h.repo.listAll('t1')).length,0);});
test('invalid replacement cannot erase valid timetable',async()=>{const h=harness();await h.Db.open({});await h.repo.replaceAll('t1',[course]);await assert.rejects(h.repo.replaceAll('t1',[{...course,weekday:8}]));assert.equal((await h.repo.listAll('t1')).length,1);});
test('overlapping replacements serialize into one complete snapshot',async()=>{const h=harness();await h.Db.open({});await Promise.all([h.repo.replaceAll('t1',[course]),h.repo.replaceAll('t1',[{...course,name:'last'}])]);const rows=await h.repo.listAll('t1');assert.equal(rows.length,1);assert.equal(rows[0].name,'last');});

test('accounts isolate default courses and custom tables while preserving both histories',async()=>{const h=harness();await h.Db.open({});await h.sql.exec("INSERT INTO timetable(id,name,account_id) VALUES('t1','default','')");await h.Db.claimLegacyAccount('A');h.Db.selectAccount('A');await h.repo.replaceAll('t1',[course]);const custom=await h.repo.createTable('A only');await h.repo.replaceAll(custom.id,[{...course,name:'A custom'}]);const a=(await h.repo.listAll('t1'))[0];h.Db.selectAccount('B');assert.equal((await h.repo.listAll('t1')).length,0);assert.equal((await h.repo.tables()).map(t=>t.id).join(','),'t1');await h.repo.replaceAll('t1',[{...course,name:'B course'}]);await h.repo.remove(a.id);assert.equal((await h.repo.listAll('t1')).length,1);h.Db.selectAccount('A');assert.equal((await h.repo.listAll('t1'))[0].name,'课程');assert.equal((await h.repo.listAll(custom.id))[0].name,'A custom');await h.Db.eraseAllAccountData();assert.equal(h.sql.prepare('SELECT count(*) n FROM course').get().n,0);assert.equal((await h.repo.tables()).map(t=>t.id).join(','),'t1');});
test('legacy schema migration backs up once, keeps opaque IDs and claims exactly one account',async()=>{const h=harness({legacy:true});await h.Db.open({});assert.equal(h.backups(),1);await h.Db.claimLegacyAccount('A');h.Db.selectAccount('A');assert.equal((await h.repo.listAll('t1'))[0].id,'legacy_id');assert.ok((await h.repo.tables()).some(t=>t.id==='old_custom'));await h.Db.claimLegacyAccount('B');h.Db.selectAccount('B');assert.equal((await h.repo.listAll('t1')).length,0);assert.ok(!(await h.repo.tables()).some(t=>t.id==='old_custom'));h.Db.selectAccount('A');assert.equal((await h.repo.listAll('t1')).length,1);await h.Db.open({});assert.equal(h.backups(),1);assert.equal(h.removedBackups().length,0);await h.Db.clearMigrationBackup({});assert.equal(h.removedBackups()[0],'fuxiaowai_pre_account_v1.db');});
test('failed schema migration rolls back every ALTER and leaves all historical data',async()=>{const h=harness({legacy:true,failMigration:true});await assert.rejects(h.Db.open({}),/migration fault/);assert.equal(h.sql.prepare('PRAGMA table_info(course)').all().some(c=>c.name==='account_id'),false);assert.equal(h.sql.prepare('SELECT id FROM course').get().id,'legacy_id');assert.equal(h.backups(),1);});
test('queued write cannot publish into a switched account',async()=>{const h=harness();await h.Db.open({});h.Db.selectAccount('A');const pending=h.repo.replaceAll('t1',[course]);h.Db.selectAccount('B');await assert.rejects(pending,/账号/);assert.equal((await h.repo.listAll('t1')).length,0);});

test('successful school replacement removes guest tables and courses atomically',async()=>{
 const h=harness();await h.Db.open({});await h.repo.replaceAll('t1',[course]);
 const guest=await h.repo.createTable('guest');await h.repo.replaceAll(guest.id,[course]);
 h.Db.selectAccount('A');await h.repo.replaceAll('t1',[{...course,name:'school'}],true);
 assert.equal((await h.repo.listAll('t1'))[0].name,'school');
 h.Db.selectAccount('');assert.equal((await h.repo.listAll('t1')).length,0);
 assert.equal(h.sql.prepare("SELECT count(*) n FROM timetable WHERE account_id='' AND id<>'t1'").get().n,0);
});

test('failed school replacement retains guest data and prior account timetable',async()=>{
 const h=harness();await h.Db.open({});await h.repo.replaceAll('t1',[course]);
 h.Db.selectAccount('A');await h.repo.replaceAll('t1',[{...course,name:'previous'}]);h.fault();
 await assert.rejects(h.repo.replaceAll('t1',[{...course,name:'school'}],true));
 assert.equal((await h.repo.listAll('t1'))[0].name,'previous');
 h.Db.selectAccount('');assert.equal((await h.repo.listAll('t1'))[0].name,'课程');
});

test('closing an import while its database write is queued prevents replacement',async()=>{
 const h=harness();await h.Db.open({});await h.repo.replaceAll('t1',[course]);
 let release;const wait=new Promise(r=>release=r);const blocker=h.Db.write(async()=>wait);
 let open=true;const pending=h.repo.replaceAll('t1',[{...course,name:'cancelled'}],false,undefined,()=>open);
 open=false;release();await blocker;await assert.rejects(pending,/取消|账号|操作/);
 assert.equal((await h.repo.listAll('t1'))[0].name,'课程');
});
