const {test}=require('node:test');const assert=require('node:assert/strict');const {load,storage}=require('./load.cjs');
test('successful feedback cleanup drops images but 429 remains pending until Retry-After',async()=>{
 const s=storage();s.setItem('fxw_feedback',JSON.stringify([{id:'fb_test_1',text:'test',contact:'',images:[],createdAt:1,sent:false}]));
 const {exports:f}=load('src/core/feedbackDelivery.ts',{globals:{localStorage:s},mocks:{'./feedback':{postFeedback:async()=>{const e=Error('slow');e.status=429;e.retryAfter=90;throw e},deviceLabel:()=>''}}});
 await assert.rejects(()=>f.deliverFeedback('fb_test_1'));const item=JSON.parse(s.getItem('fxw_feedback'))[0];assert.equal(item.sent,false);assert.ok(item.retryAt>=Date.now()+89000);
});
