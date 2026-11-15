const {test}=require('node:test');const assert=require('node:assert/strict');const {spawn}=require('node:child_process');const fs=require('node:fs/promises');const os=require('node:os');const path=require('node:path');
test('share completeness, stable cross-IP feedback dedup, conflict and concurrent capacity',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'fxw-extra-'));const child=spawn(process.execPath,[path.resolve('server/server.js')],{env:{...process.env,FXW_PORT:'18896',FXW_ROOT:root,FXW_ADMIN_USER:'test',FXW_ADMIN_PASS:'test-password',FXW_TRUST_PROXY:'1',FXW_MAX_TICKETS:'2'},stdio:['ignore','pipe','pipe']});t.after(async()=>{child.kill();await new Promise(r=>child.once('exit',r));await fs.rm(root,{recursive:true,force:true})});
 await new Promise((resolve,reject)=>{child.stdout.on('data',b=>{if(b.toString().includes('listening'))resolve()});child.once('exit',()=>reject(Error('exit')));setTimeout(()=>reject(Error('startup timeout')),5000).unref()});
 const send=(route,data,ip='192.0.2.1',id)=>fetch('http://127.0.0.1:18896'+route,{method:'POST',headers:{'Content-Type':'application/json','X-FXW-Client-IP':ip,...(id?{'X-FXW-Request-ID':id}:{})},body:JSON.stringify(data)});
 const c={id:'same',name:'测试',weekday:1,startPeriod:1,endPeriod:2,weeks:[1]};
 assert.equal((await send('/api/share',{courses:[{...c,weeks:[]}]})).status,400);
 const a=await(await send('/api/feedback',{text:'test'},'192.0.2.1','fb_stable_001')).json();const b=await(await send('/api/feedback',{text:'test'},'192.0.2.2','fb_stable_001')).json();assert.equal(a.id,b.id);
 assert.equal((await send('/api/feedback',{text:'different'},'192.0.2.1','fb_stable_001')).status,409);
 const responses=await Promise.all(Array.from({length:5},()=>send('/api/share',{courses:[c]})));assert.equal(responses.filter(r=>r.status===200).length,2);
 const auth='Basic '+Buffer.from('test:test-password').toString('base64');const admin=await fetch('http://127.0.0.1:18896/admin',{headers:{Authorization:auth}});assert.match(admin.headers.get('content-security-policy')||'',/script-src 'self'/);
 assert.equal((await fetch('http://127.0.0.1:18896/healthz')).status,200);
});
