const {test}=require('node:test');const assert=require('node:assert/strict');
const {loadEts}=require('./ets-loader.cjs');
test('share uses direct IP while feedback keeps HTTPS and rejects unusable upload codes',async()=>{
 const calls=[];let code='ab12'.repeat(8);
 const http={RequestMethod:{GET:'GET',POST:'POST'},HttpDataType:{STRING:0},createHttp:()=>({
  request:async(url)=>{calls.push(url);return {responseCode:200,result:JSON.stringify({ok:true,code,id:'feedback'})};},destroy(){}
 })};
 class OhosTextEncoder { encodeInto(value){return new TextEncoder().encode(value);} }
 const api=loadEts('entry/src/main/ets/data/remote/ShareApi.ets',{'@ohos.net.http':{default:http},'@ohos.util':{default:{TextEncoder:OhosTextEncoder}}});
 await api.uploadShare([],[],'term',1);
 assert.equal(calls[0],'http://113.45.242.182/api/share');
 await api.uploadFeedback({text:'test',contact:'',images:[],app:'test',version:'0',device:'test'});
 assert.equal(calls[1],'https://fuxiaowai.xyz/api/feedback');
 code='not-a-valid-ticket';await assert.rejects(api.uploadShare([],[],'term',1));
});
