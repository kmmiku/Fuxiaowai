const assert=require('node:assert/strict');
const {loadEts}=require('./ets-loader.cjs');
const {TextEncoder}=require('node:util');
let response={responseCode:429,result:JSON.stringify({retryAfter:37}),header:{}};let options;let destroys=0;
const platform={RequestMethod:{GET:'GET',POST:'POST'},HttpDataType:{STRING:0},createHttp(){return{async request(url,o){options=o;return response;},destroy(){destroys++;}};}};
const api=loadEts('entry/src/main/ets/data/remote/ShareApi.ets',{'@ohos.net.http':{default:platform},'@ohos.util':{default:{TextEncoder:class{encodeInto(s){return new TextEncoder().encode(s);}}}}});
const payload={text:'problem',contact:'email',images:[],app:'harmony',version:'1',device:'os',requestId:'fb_stable'};
const snapshot=()=>({code:'a'.repeat(32),createdAt:1,term:'学期',week:1,courses:[{id:'c',name:'课程',room:'教室',weekday:1,startPeriod:1,endPeriod:2,weeks:[1,2]}],periods:[{index:1,start:'08:00',end:'08:45'}]});
(async()=>{
 await assert.rejects(api.uploadFeedback(payload),/TOO_FREQUENT:37/);assert.equal(options.header['X-FXW-Request-ID'],'fb_stable');
 response.header={'Retry-After':'59'};await assert.rejects(api.uploadFeedback(payload),/TOO_FREQUENT:59/);
 response={responseCode:200,result:JSON.stringify({ok:true,id:'server-id'}),header:{}};assert.equal(await api.uploadFeedback(payload),'server-id');
 const old=snapshot();assert.equal(api.validateSnapshot(old),true);assert.equal(old.courses[0].teacher,'');assert.equal(old.courses[0].campus,'');assert.equal(typeof old.courses[0].colorIndex,'number');
 for(const mutate of [s=>s.courses[0].weekday=8,s=>s.courses[0].weeks=[0],s=>s.courses[0].endPeriod=0,s=>s.periods[0].start='99:00',s=>s.periods.push(s.periods[0]),s=>s.courses=null,s=>s.week='1']){const snap=snapshot();mutate(snap);assert.equal(api.validateSnapshot(snap),false);response.result=JSON.stringify(snap);await assert.rejects(api.fetchShare('a'.repeat(32)),/格式/);}
 await assert.rejects(api.uploadFeedback({...payload,text:'中'.repeat(1500000)}),/过大/);
 assert.equal(destroys,11);console.log('feedback API retries, payload bounds and snapshot validation passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
