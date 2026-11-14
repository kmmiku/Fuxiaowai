const {test}=require('node:test');const assert=require('node:assert/strict');const {loadEts}=require('./ets-loader.cjs');
test('online share code replaces its local placeholder and is not queued for upload again',async()=>{
 let raw='[]';const prefs={get:async()=>raw,put:async(k,v)=>raw=v,flush:async()=>{}};
 const {createTicket,markUploaded,listTickets,pendingUpload}=loadEts('entry/src/main/ets/data/local/ShareCodeStore.ets',{'@kit.ArkData':{preferences:{getPreferences:async()=>prefs}}});
 const ticket=await createTicket({},[],[],'term',1);await markUploaded({},ticket.code,'b'.repeat(32));const result=await listTickets({});assert.equal(result[0].code,'b'.repeat(32));assert.equal((await pendingUpload({})).length,0);
});

test('share code accepts full messages and rejects ambiguous or embedded tokens',()=>{
 const {extractShareCode}=loadEts('entry/src/main/ets/data/local/ShareCodeStore.ets',{'@kit.ArkData':{preferences:{}}});
 const code='ab12'.repeat(8);
 assert.equal(extractShareCode(code.toUpperCase()).code,code);
 assert.equal(extractShareCode('分享口令：'+code).code,code);
 assert.equal(extractShareCode('这是课表分享。\n分享口令:\n'+code+'\n有效期30天').code,code);
 assert.equal(extractShareCode(code+'\n'+code).code,code);
 assert.equal(extractShareCode(code+' '+ 'cd34'.repeat(8)).code,'');
 assert.equal(extractShareCode('x'+code+'y').code,'');
 assert.equal(extractShareCode('a'.repeat(33)).code,'');
 assert.equal(extractShareCode('g'.repeat(32)).code,'');
});
