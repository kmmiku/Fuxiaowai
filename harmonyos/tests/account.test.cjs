const {test}=require('node:test');const assert=require('node:assert/strict');const {loadEts}=require('./ets-loader.cjs');
test('logout while school fetch is pending prevents database commit',async()=>{
 let release, saved=0;const pending=new Promise(r=>release=r);const cache=new Map();
 const {AccountScope}=loadEts('entry/src/main/ets/common/util/AccountScope.ets',{},cache);
 const {SyncTimetable}=loadEts('entry/src/main/ets/domain/usecase/SyncTimetable.ets',{},cache);
 AccountScope.begin('A');const sync=new SyncTimetable({fetch:async()=>{await pending;return {courses:[{id:'c'}],student:{name:'A',studentId:'A',clazz:'',major:''},semesterLabel:'term',captcha:new ArrayBuffer(0)}}},{replaceAll:async()=>saved++});
 const p=sync.run('A','pwd','t1');AccountScope.invalidate();release();const result=await p;assert.equal(result.ok,false);assert.equal(saved,0);
});
test('school traffic serializes independent login flows and recovers after errors',async()=>{
 const {SchoolTraffic}=loadEts('entry/src/main/ets/common/util/SchoolTraffic.ets');let release;const pending=new Promise(r=>release=r);const order=[];
 const first=SchoolTraffic.run(async()=>{order.push('a');await pending;order.push('b');throw Error('failed');});
 const second=SchoolTraffic.run(async()=>order.push('c'));await new Promise(r=>setTimeout(r,5));assert.equal(order.join(''),'a');release();await assert.rejects(first);await second;assert.equal(order.join(''),'abc');
});
test('authentication completing after logout cannot resurrect account or cookie',async()=>{
 let release, binds=0,saves=0;const pending=new Promise(r=>release=r);const cache=new Map();
 const {AccountScope}=loadEts('entry/src/main/ets/common/util/AccountScope.ets',{},cache);
 class Auth{async login(){await pending;return {ok:true,captcha:new ArrayBuffer(0),semester:{label:'term'}};}async fetchTimetable(){return JSON.stringify({kbList:[{kcmc:'Course',xqj:'1',jcs:'1-2',zcd:'1-2周'}],xsxx:{XH:'A'}});}cookieHeader(){return 'secret';}}
 const mocks={'@ohos.hilog':{default:{info(){},warn(){}}},'./auth/ZhengfangAuth':{ZhengfangAuth:Auth},'../local/SessionStore':{SessionStore:{bindUser:async()=>binds++,saveJw:async()=>saves++}},'../local/TimetableStateStore':{resolveSchoolTerm:()=>({})},'../local/Db':{Db:{selectAccount(){}}}};
 const {FuwaiTimetableSource}=loadEts('entry/src/main/ets/data/remote/FuwaiTimetableSource.ets',mocks,cache);
 AccountScope.begin('A');const work=new FuwaiTimetableSource().fetch('A','pwd');await new Promise(r=>setTimeout(r,5));AccountScope.invalidate();release();await assert.rejects(work);assert.equal(binds,0);assert.equal(saves,0);assert.equal(AccountScope.user(),'');
});
