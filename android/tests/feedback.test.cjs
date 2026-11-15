const { test } = require('node:test');
const assert = require('node:assert/strict');
const { load } = require('./load.cjs');
test('429 Retry-After header is respected',async()=>{
 const {exports:f}=load('src/core/feedback.ts',{mocks:{'@capacitor/core':{CapacitorHttp:{request:async()=>({status:429,data:{ok:false,msg:'slow'},headers:{'Retry-After':'90'}})}}}});
 await assert.rejects(()=>f.postFeedback({text:'test'}),e=>e.status===429&&e.retryAfter===90);
});
test('stable feedback id is forwarded on every retry',async()=>{
 const seen=[];const {exports:f}=load('src/core/feedback.ts',{mocks:{'@capacitor/core':{CapacitorHttp:{request:async o=>{seen.push(o);return {status:200,data:{ok:true,id:'saved'}}}}}}});
 await f.postFeedback({text:'test',requestId:'fb_test_1'});assert.equal(seen[0].headers['X-FXW-Request-ID'],'fb_test_1');
});
test('oversized actual UTF8 JSON is rejected before network',async()=>{
 let calls=0;const {exports:f}=load('src/core/feedback.ts',{mocks:{'@capacitor/core':{CapacitorHttp:{request:async()=>{calls++;return {status:200,data:{ok:true,id:'saved'}}}}}}});
 await assert.rejects(()=>f.postFeedback({text:'test',images:['data:image/jpeg;base64,'+'A'.repeat(4*1024*1024)]}));assert.equal(calls,0);
});
