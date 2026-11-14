'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs/promises');
const path=require('node:path');
const os=require('node:os');
const http=require('node:http');

test('admin extension protects routes, inspects without changing tickets and persists redacted operations',async t=>{
 const {createAdminConsole}=require('../server/admin-console');
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'fxw-console-'));
 const tickets=path.join(root,'tickets'); await fs.mkdir(tickets);
 const code='a'.repeat(32),expired='b'.repeat(32),bad='c'.repeat(32);
 const payload={code,createdAt:Date.now(),term:'<script>bad</script>',week:2,courses:[{id:'course-1',room:'',name:'数学',weekday:1,startPeriod:1,endPeriod:2,weeks:[1,2]}],periods:[]};
 await fs.writeFile(path.join(tickets,code+'.json'),JSON.stringify(payload));
 await fs.writeFile(path.join(tickets,expired+'.json'),JSON.stringify({...payload,createdAt:1}));
 await fs.writeFile(path.join(tickets,bad+'.json'),'{broken');
 const before=await Promise.all([code,expired,bad].map(c=>fs.readFile(path.join(tickets,c+'.json'),'utf8')));
 const json=(req,res,status,data)=>{res.writeHead(status,{'content-type':'application/json'});res.end(JSON.stringify(data));};
 const checkAuth=req=>req.headers.authorization==='Basic dGVzdDp0ZXN0';
 const admin=createAdminConsole({ROOT:root,TICKET_DIR:tickets,TTL_MS:30*86400000,PORT:0,BIND:'127.0.0.1',json,checkAuth,needAuth:(req,res)=>json(req,res,401,{ok:false}),externalProbe:false});
 const server=http.createServer(async(req,res)=>{const url=new URL(req.url,'http://localhost');admin.observe(req,res,url);if(await admin.handle(req,res,url))return;json(req,res,200,{ok:true});});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const base='http://127.0.0.1:'+server.address().port;
 t.after(async()=>{await new Promise(r=>server.close(r));await admin.close();await fs.rm(root,{recursive:true,force:true});});
 const headers={authorization:'Basic dGVzdDp0ZXN0','content-type':'application/json'};
 const req=(route,body)=>fetch(base+route,{method:body===undefined?'GET':'POST',headers,body:body===undefined?undefined:JSON.stringify(body)});
 for(const route of ['/api/admin/audit','/api/admin/alerts','/api/admin/probes','/api/admin/ticket-search','/admin/admin.js'])assert.equal((await fetch(base+route)).status,401);
 assert.equal((await fetch(base+'/api/admin/inspect',{method:'POST',headers:{...headers,origin:'https://evil.example'},body:JSON.stringify({code})})).status,403);
 assert.equal((await fetch(base+'/api/admin/inspect',{method:'POST',headers:{...headers,host:'fuxiaowai.xyz',origin:'http://fuxiaowai.xyz'},body:JSON.stringify({code})})).status,403);
 let schemeStatus;await admin.handle({method:'POST',headers:{host:'fuxiaowai.xyz',origin:'http://fuxiaowai.xyz',authorization:headers.authorization}}, {writeHead(status){schemeStatus=status;},end(){}},new URL('http://localhost/api/admin/inspect'));assert.equal(schemeStatus,403);
 assert.equal((await req('/api/admin/inspect',{code:'../bad'})).status,400);
 for(const [c,status] of [[code,'valid'],[expired,'expired'],[bad,'invalid'],['d'.repeat(32),'missing']]){
  const response=await req('/api/admin/inspect',{code:c});assert.equal(response.status,200);assert.equal((await response.json()).status,status);
 }
 assert.deepEqual(await Promise.all([code,expired,bad].map(c=>fs.readFile(path.join(tickets,c+'.json'),'utf8'))),before);
 for(const courses of [[{...payload.courses[0],id:undefined}], [payload.courses[0],payload.courses[0]], [{...payload.courses[0],room:undefined}]]){
  await fs.writeFile(path.join(tickets,code+'.json'),JSON.stringify({...payload,courses}));
  assert.equal((await(await req('/api/admin/inspect',{code})).json()).status,'invalid');
 }
 await fs.writeFile(path.join(tickets,code+'.json'),before[0]);
 const list=await(await req('/api/admin/ticket-search?q='+code+'&limit=1')).json();assert.equal(list.total,1);assert.equal(list.rows[0].code,code);
 const probes=await(await req('/api/admin/probes')).json();assert.equal(probes.ok,true);assert.ok(probes.sampledAt);assert.equal(typeof probes.metrics.mem.percent,'number');
 admin.evaluate({cpu:98,mem:20,disk:20},Date.now());admin.evaluate({cpu:98,mem:20,disk:20},Date.now());admin.evaluate({cpu:98,mem:20,disk:20},Date.now());
 assert.ok((await(await req('/api/admin/alerts')).json()).active.some(a=>a.key==='cpu'));
 admin.evaluate({cpu:5,mem:20,disk:20},Date.now());
 assert.ok(!(await(await req('/api/admin/alerts')).json()).active.some(a=>a.key==='cpu'));
 await fetch(base+'/api/admin/tickets/'+code.toUpperCase(),{method:'DELETE',headers});
 await admin.flush();
 const audit=await(await req('/api/admin/audit')).json();assert.ok(audit.rows.some(r=>r.action==='ticket.delete'));
 const stored=await fs.readFile(path.join(root,'admin','audit.json'),'utf8');assert.ok(!stored.includes(code));assert.ok(!stored.includes('Basic'));assert.ok(!stored.includes(payload.term));
 assert.ok((await fs.stat(path.join(root,'admin','audit.json'))).size>0);
 assert.equal((await req('/api/admin/alerts')).status,200);
});

test('corrupt audit survives writes, failed persistence retries, and restart ends previous active alerts',async t=>{
 const {createAdminConsole}=require('../server/admin-console');
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'fxw-console-store-'));await fs.mkdir(path.join(root,'admin'));await fs.mkdir(path.join(root,'tickets'));
 const options={ROOT:root,TICKET_DIR:path.join(root,'tickets'),TTL_MS:30*86400000,PORT:0,BIND:'127.0.0.1',json(req,res,status,data){res.end(JSON.stringify(data));},checkAuth(){return true;},needAuth(){},externalProbe:false};
 const corrupt='{keep-this-corrupt-file';await fs.writeFile(path.join(root,'admin','audit.json'),corrupt);
 await fs.writeFile(path.join(root,'admin','alerts.json'),JSON.stringify([{id:'old',time:Date.now()-1000,key:'cpu',state:'active',title:'CPU'}]));
 const admin=createAdminConsole(options);t.after(async()=>{await admin.close();await fs.rm(root,{recursive:true,force:true});});
 admin.record('deploy');await admin.flush();
 assert.equal(await fs.readFile(path.join(root,'admin','audit.json'),'utf8'),corrupt);
 const restored=JSON.parse(await fs.readFile(path.join(root,'admin','alerts.json'),'utf8'));assert.notEqual(restored[0].state,'active');
 const response={writeHead(){},end(text){this.data=JSON.parse(text);}};await admin.handle({method:'GET',headers:{}},response,new URL('http://localhost/api/admin/audit'));assert.ok(response.data.storageError);
 const root2=await fs.mkdtemp(path.join(os.tmpdir(),'fxw-console-retry-'));await fs.mkdir(path.join(root2,'tickets'));
 const retry=createAdminConsole({...options,ROOT:root2,TICKET_DIR:path.join(root2,'tickets'),retryMs:30});
 t.after(async()=>{await retry.close();await fs.rm(root2,{recursive:true,force:true});});
 await fs.mkdir(path.join(root2,'admin','audit.json'));retry.record('deploy');await retry.flush();await fs.rmdir(path.join(root2,'admin','audit.json'));
 await new Promise(r=>setTimeout(r,150));
 assert.ok(JSON.parse(await fs.readFile(path.join(root2,'admin','audit.json'),'utf8')).some(r=>r.action==='deploy'));
});

test('repeated HTTPS probes retain certificate details instead of a resumed-session empty certificate',async t=>{
 const {createAdminConsole}=require('../server/admin-console'),https=require('node:https'),{EventEmitter}=require('node:events');
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'fxw-console-cert-'));await fs.mkdir(path.join(root,'tickets'));
 const original=https.get;
 https.get=(url,options,callback)=>{const request=new EventEmitter();request.destroy=()=>{};setImmediate(()=>{const response=new EventEmitter();response.statusCode=200;response.socket={getPeerCertificate:()=>options.agent===false?{valid_to:'Dec 31 23:59:59 2030 GMT'}:{}};callback(response);response.emit('data','ok');response.emit('end');});return request;};
 const admin=createAdminConsole({ROOT:root,TICKET_DIR:path.join(root,'tickets'),TTL_MS:30*86400000,PORT:0,BIND:'127.0.0.1',json(req,res,status,data){res.data=data;},checkAuth(){return true;},needAuth(){}});
 t.after(async()=>{https.get=original;await admin.close();await fs.rm(root,{recursive:true,force:true});});
 const response={};await admin.handle({method:'GET',headers:{}},response,new URL('http://localhost/api/admin/probes'));
 assert.ok(response.data.external.certificateExpiresAt>Date.now());
});
