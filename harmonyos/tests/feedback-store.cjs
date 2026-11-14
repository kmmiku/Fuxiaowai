const assert=require('node:assert/strict');
const {loadEts}=require('./ets-loader.cjs');
let raw='';const pref={async get(){return raw;},async put(k,v){raw=v;},async flush(){},async clear(){raw='';}};
const {FeedbackStore}=loadEts('entry/src/main/ets/data/local/FeedbackStore.ets',{'@ohos.data.preferences':{default:{async getPreferences(){return pref;}}},'@ohos.app.ability.common':{default:{}}});
const feedback=i=>({id:String(i),text:'problem',contact:'contact',images:[],createdAt:i,sent:false});
(async()=>{await Promise.all([FeedbackStore.push({},feedback(1)),FeedbackStore.push({},feedback(2))]);assert.equal((await FeedbackStore.pending({})).length,2);for(let i=3;i<38;i++){await FeedbackStore.push({},feedback(i));await FeedbackStore.markSent({},String(i));}assert.equal((await FeedbackStore.pending({})).length,2);assert.equal((await FeedbackStore.list({})).filter(f=>f.sent).length,30);raw='malformed';await assert.rejects(FeedbackStore.push({},feedback(99)));assert.equal(raw,'malformed');console.log('feedback store concurrent writes, bounded sent history and corrupt-data preservation passed');})().catch(e=>{console.error(e);process.exitCode=1;});
