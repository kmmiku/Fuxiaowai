const {test}=require('node:test');const assert=require('node:assert/strict');const {load,storage}=require('./load.cjs');
test('native password migration verifies ciphertext before deleting plaintext',()=>{
 const s=storage();s.setItem('fxw_credential',JSON.stringify({user:'A',pwd:'old-test',remember:true}));
 const cap={Capacitor:{isNativePlatform:()=>true}};
 const window={prompt:(_msg,raw)=>{const p=JSON.parse(raw);return JSON.stringify({ok:true,value:p.action==='seal'?'cipher':'WRONG'})}};
 const {exports:db}=load('src/core/store.ts',{globals:{localStorage:s,window},mocks:{'@capacitor/core':cap}});
 assert.equal(db.loadCredential().pwd,'old-test');assert.equal(JSON.parse(s.getItem('fxw_credential')).pwd,'old-test');
});

test('unavailable decryption key preserves account and ciphertext without blocking cached data',()=>{
 const s=storage();s.setItem('fxw_credential',JSON.stringify({user:'A',pwd_enc_v1:'unavailable',remember:true}));
 const cap={Capacitor:{isNativePlatform:()=>true}};
 const {exports:db}=load('src/core/store.ts',{globals:{localStorage:s,window:{prompt:()=>JSON.stringify({ok:false})}},mocks:{'@capacitor/core':cap}});
 const c=db.loadCredential();assert.equal(c.user,'A');assert.equal(c.pwd,'');db.saveCredential({...c,lastSyncAt:10});assert.equal(JSON.parse(s.getItem('fxw_credential')).pwd_enc_v1,'unavailable');
});
