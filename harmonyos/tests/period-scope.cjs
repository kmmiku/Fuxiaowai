const {test}=require('node:test');const assert=require('node:assert/strict');const {loadEts}=require('./ets-loader.cjs');
test('old import cannot overwrite school periods after identity changes during preference open',async()=>{
 let raw='';let release;const wait=new Promise(r=>release=r);let first=true;
 const prefs={get:async(k,d)=>raw||d,put:async(k,v)=>raw=v,flush:async()=>{}};
 const cache=new Map();const {AccountScope}=loadEts('entry/src/main/ets/common/util/AccountScope.ets',{},cache);
 const {PeriodStore}=loadEts('entry/src/main/ets/data/local/PeriodStore.ets',{
  '@ohos.data.preferences':{default:{getPreferences:async()=>{if(first){first=false;await wait;}return prefs;}}}
 },cache);
 PeriodStore.init({});AccountScope.begin('');const old=PeriodStore.save([{index:1,start:'01:00',end:'02:00'}],AccountScope.token());
 await new Promise(r=>setTimeout(r,5));AccountScope.begin('A');
 const school=PeriodStore.save([{index:1,start:'08:25',end:'09:10'}],AccountScope.token());
 release();assert.equal(await old,false);assert.equal(await school,true);assert.equal(JSON.parse(raw)[0].start,'08:25');
});
