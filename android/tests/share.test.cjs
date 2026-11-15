const {test}=require('node:test');const assert=require('node:assert/strict');const {load}=require('./load.cjs');
test('extract share code accepts full messages and rejects ambiguous or malformed codes',()=>{
 const {exports:s}=load('src/core/share.ts');const code='a1'.repeat(16);
 assert.equal(s.extractShareCode(code.toUpperCase()),code);
 assert.equal(s.extractShareCode(`来自福小外的分享\n分享口令：${code}\n已上传服务器`),code);
 assert.equal(s.extractShareCode(`分享口令：${code} 已上传` .replace(/\n/g,'')),code);
 assert.equal(s.extractShareCode('b'+code),null);
 assert.equal(s.extractShareCode('z'.repeat(32)),null);
 assert.equal(s.extractShareCode(`${code} ${'b2'.repeat(16)}`),null);
});
test('share upload and lookup use the user-authorized temporary IP endpoint',async()=>{
 const urls=[];const {exports:s}=load('src/core/share.ts',{mocks:{'@capacitor/core':{CapacitorHttp:{request:async o=>{urls.push(o.url);return {status:o.method==='POST'?200:404,data:{ok:true,code:'a'.repeat(32)}}}}}}});
 await s.uploadShare([],[],'测试学期',1);await s.fetchShare('a'.repeat(32));
 assert.deepEqual(urls,['http://113.45.242.182/api/share','http://113.45.242.182/api/share/'+'a'.repeat(32)]);
});
test('share connection reset reports service connectivity failure without exposing native details',async()=>{
 const {exports:s}=load('src/core/share.ts',{mocks:{'@capacitor/core':{CapacitorHttp:{request:async()=>{throw new Error('connection closed')}}}}});
 await assert.rejects(()=>s.uploadShare([],[],'测试学期',1),/分享服务连接中断，请稍后重试/);
});
test('share download rejects malformed courses before import',async()=>{const {exports:s}=load('src/core/share.ts',{mocks:{'@capacitor/core':{CapacitorHttp:{request:async()=>({status:200,data:{ok:true,courses:[null]}})}}}});await assert.rejects(()=>s.fetchShare('a'.repeat(32)))});
test('share code cannot inject a URL path',async()=>{let called=false;const {exports:s}=load('src/core/share.ts',{mocks:{'@capacitor/core':{CapacitorHttp:{request:async()=>{called=true;return {status:404}}}}}});await assert.rejects(()=>s.fetchShare('../admin'));assert.equal(called,false)});
