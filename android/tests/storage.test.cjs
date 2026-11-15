const { test } = require('node:test');
const assert = require('node:assert/strict');
const { load, storage } = require('./load.cjs');
const cred = user => ({user,pwd:'test-only',remember:true,lastSyncAt:0,autoUpdate:false,autoDay:''});
const course = id => ({id,name:'测试课',teacher:'',room:'A1',campus:'',weekday:1,startPeriod:1,endPeriod:2,weeks:[1,2],colorIndex:0});
function setup() { const localStorage = storage(); const app = load('src/core/store.ts',{globals:{localStorage}}); app.exports.saveCredential(cred('A')); return {...app,localStorage}; }

test('guest imported courses survive reload and remain isolated from signed-in accounts',()=>{
 const s=storage();let db=load('src/core/store.ts',{globals:{localStorage:s}}).exports;
 db.saveCourses('t1',[course('guest')]);assert.equal(db.loadCourses('t1')[0]?.id,'guest');
 db=load('src/core/store.ts',{globals:{localStorage:s}}).exports;
 db.ensureSeeded();db.migrateCleanDemo();assert.equal(db.loadCourses('t1')[0]?.id,'guest');
 db.saveCredential(cred('A'));assert.equal(db.loadCourses('t1').length,0);db.saveCourses('t1',[course('account-a')]);
 db.clearCredential();assert.equal(db.loadCourses('t1')[0]?.id,'guest');
 db.saveCredential(cred('B'));assert.equal(db.loadCourses('t1').length,0);
});
test('write failure is reported and old timetable remains intact', () => {
  const {exports:db,localStorage:s} = setup(); db.saveCourses('t1',[course('old')]);
  const set = s.setItem; s.setItem = (k,v) => { if(k.endsWith('courses_t1')) throw Error('disk full'); set(k,v); };
  assert.throws(() => db.saveCourses('t1',[course('new')]), /存储|disk/);
  assert.equal(db.loadCourses('t1')[0].id,'old');
});
test('invalid course batch never overwrites valid timetable', () => {
  const {exports:db} = setup(); db.saveCourses('t1',[course('old')]);
  assert.throws(() => db.saveCourses('t1',[course('new'),{...course('bad'),weekday:9}]));
  assert.equal(db.loadCourses('t1')[0].id,'old');
});
test('courses with same public id remain scoped to table', () => {
 const {exports:db}=setup(); db.saveCourses('t1',[course('same')]); db.saveCourses('t2',[{...course('same'),name:'第二表'}]); db.removeCourses('t1'); assert.equal(db.loadCourses('t2')[0].name,'第二表');
});
test('failed legacy scope migration is retryable', () => {
 const s=storage(); s.setItem('fxw_credential',JSON.stringify(cred('A'))); s.setItem('fxw_tables',JSON.stringify([{id:'t1',name:'old'}])); s.setItem('fxw_courses_t1',JSON.stringify([course('old')]));
 const {exports:db}=load('src/core/store.ts',{globals:{localStorage:s}}); const set=s.setItem;
 s.setItem=(k,v)=>{if(k==='fxw_a_A_courses_t1')throw Error('full');set(k,v)};
 assert.throws(()=>db.migrateAccountScope()); assert.notEqual(s.getItem('fxw_scope_v1'),'true'); s.setItem=set; db.migrateAccountScope(); assert.equal(db.loadCourses('t1')[0].id,'old');
});
test('account namespace cannot collide after removing punctuation', () => {
 const {exports:db}=setup(); db.saveCredential(cred('A-B')); db.saveCourses('t1',[course('dash')]); db.saveCredential(cred('AB')); assert.equal(db.loadCourses('t1').length,0);
});
test('last successful timetable snapshot restores courses with term and periods',()=>{const {exports:db}=setup();db.saveCourses('t1',[course('old')]);db.saveCourses('t1',[course('new')]);db.restoreLastTimetable('t1');assert.equal(db.loadCourses('t1')[0].id,'old')});
test('clearing current account preserves other account and application settings',()=>{const {exports:db}=setup();db.saveSettings({...db.DEFAULT_SETTINGS,dark:true});db.saveCourses('t1',[course('A')]);db.saveCredential(cred('B'));db.saveCourses('t1',[course('B')]);db.clearAccountData('A');db.saveCredential(cred('A'));assert.equal(db.loadCourses('t1').length,0);db.saveCredential(cred('B'));assert.equal(db.loadCourses('t1')[0].id,'B');assert.equal(db.loadSettings().dark,true)});

test('automatic course colors survive load, update, account isolation and restart without reassignment',()=>{
 const {exports:db,localStorage:s}=setup();
 db.saveCourses('t1',[course('first'),{...course('second'),startPeriod:3,endPeriod:4,weeks:[2]}]);
 const before=db.loadCourses('t1').map(c=>c.autoColorIndex);
 assert.ok(before.every(Number.isInteger));
 db.saveCourses('t1',[course('first'),{...course('second'),startPeriod:3,endPeriod:4,weeks:[2]}]);
 assert.deepEqual(db.loadCourses('t1').map(c=>c.autoColorIndex),before);
 const reopened=load('src/core/store.ts',{globals:{localStorage:s}}).exports;
 assert.deepEqual(Array.from(reopened.loadCourses('t1'),c=>c.autoColorIndex),Array.from(before));
 reopened.saveCredential(cred('B'));assert.equal(reopened.loadCourses('t1').length,0);
 reopened.saveCredential(cred('A'));assert.deepEqual(Array.from(reopened.loadCourses('t1'),c=>c.autoColorIndex),Array.from(before));
});
test('legacy courses receive one persisted color assignment before initial rendering',()=>{
 const {exports:db,localStorage:s}=setup();db.saveCourses('t1',[course('legacy')]);
 const rawKey=Array.from({length:s.length},(_,i)=>s.key(i)).find(k=>k.endsWith('courses_t1'));
 const old=JSON.parse(s.getItem(rawKey));old.forEach(c=>delete c.autoColorIndex);s.setItem(rawKey,JSON.stringify(old));
 const first=db.loadCourses('t1')[0].autoColorIndex;
 assert.equal(JSON.parse(s.getItem(rawKey))[0].autoColorIndex,first);
 assert.equal(db.loadCourses('t1')[0].autoColorIndex,first);
});
