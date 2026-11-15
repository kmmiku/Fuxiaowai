const {test}=require('node:test');const assert=require('node:assert/strict');const {load,storage}=require('./load.cjs');
function network(request){return load('src/core/zhengfang.ts',{mocks:{'@capacitor/core':{Capacitor:{isNativePlatform:()=>true},CapacitorHttp:{request},CapacitorCookies:{clearAllCookies:async()=>{},setCookie:async()=>{}}}}}).exports}

for(const mode of ['portal','qr'])test(`${mode} login resolves the CAS bridge against the actual absolute request URL`,async()=>{
 const paths=[];
 const z=network(async o=>{
   const u=new URL(o.url);paths.push(u.hostname+u.pathname);
   if(u.hostname==='portal.fzfu.edu.cn'&&u.searchParams.has('code'))return {status:302,headers:{'Set-Cookie':'PORTAL=test-only; Path=/'},data:''};
   if(u.pathname==='/jwglxt/xtgl/login_cas.html')return {status:302,headers:{Location:'http://portal.fzfu.edu.cn/cas/bridge'},data:''};
   if(u.pathname==='/cas/bridge')return {status:302,headers:{Location:'../cas/complete'},data:''};
   if(u.pathname==='/cas/complete')return {status:302,headers:{Location:'http://jw.fzfu.edu.cn/jwglxt/xtgl/index_initMenu.html'},data:''};
   if(u.pathname==='/jwglxt/xtgl/index_initMenu.html')return {status:200,headers:{'Set-Cookie':'JSESSIONID=test-only; Path=/'},data:'<html>学生个人中心</html>'};
   throw new Error('Unexpected synthetic route');
 });
 const result=await (mode==='portal'?z.completePortalLogin():z.qrLogin('test-only-code'));
 assert.equal(result.ok,true,result.message);
 assert.ok(paths.includes('portal.fzfu.edu.cn/cas/complete'));
 assert.ok(z.hasSession());
});
test('relative redirects resolve against current path',()=>{const z=network();assert.equal(z.absoluteUrl('../login?x=1','http://portal.fzfu.edu.cn/cas/path/page'),'http://portal.fzfu.edu.cn/cas/login?x=1')});
test('grades follows school pagination until complete',async()=>{const pages=[];const z=network(async o=>{const p=Number(new URLSearchParams(o.data).get('queryModel.currentPage'));pages.push(p);return {status:200,headers:{},data:JSON.stringify({items:Array.from({length:p===1?100:1},(_,i)=>({kch:String((p-1)*100+i),kcmc:'测试',cj:'80'})),total:2,records:101,currentPage:p})}});const all=await z.fetchGrades(2026,3);assert.equal(all.length,101);assert.equal(pages.join(','),'1,2')});
test('repeated school pages are rejected instead of publishing truncated results',async()=>{const z=network(async()=>({status:200,headers:{},data:JSON.stringify({items:Array.from({length:100},(_,i)=>({kch:String(i),kcmc:'test'})),total:2,records:200,currentPage:1})}));await assert.rejects(()=>z.fetchGrades(2026,3))});
test('foreign Domain and expired cookies are never replayed to school',async()=>{const seen=[];const z=network(async o=>{seen.push(o.headers.Cookie||'');return {status:200,headers:{'Set-Cookie':['bad=x; Domain=evil.test; Path=/','gone=x; Max-Age=0; Path=/','secure=x; Secure; Path=/']},data:JSON.stringify({items:[]})}});await z.fetchGrades(2026,3);await z.fetchGrades(2026,3);assert.equal(seen[1],'')});
test('in-flight native cookie writes cannot recreate cookies after clear',async()=>{let release,started;const gate=new Promise(r=>release=r),entered=new Promise(r=>started=r);const cookies=new Map();const {exports:z}=load('src/core/zhengfang.ts',{mocks:{'@capacitor/core':{Capacitor:{isNativePlatform:()=>true},CapacitorHttp:{},CapacitorCookies:{setCookie:async o=>{started();await gate;cookies.set(o.key,o.value)},clearAllCookies:async()=>cookies.clear()}}}});const task=z.syncCookiesToWebView('JSESSIONID=test-only');await entered;// clearSessionCookies is the public synchronous reset; its native clear must be ordered after writes.
z.clearSessionCookies();release();await task.catch(()=>{});await new Promise(r=>setTimeout(r,0));assert.equal(cookies.size,0)});
test('advertised last page cannot hide missing grade records',async()=>{const z=network(async o=>{const p=Number(new URLSearchParams(o.data).get('queryModel.currentPage'));return {status:200,headers:{},data:JSON.stringify({items:p===1?Array.from({length:100},(_,i)=>({kch:String(i),kcmc:'test'})):[],total:2,records:101,currentPage:p})}});await assert.rejects(()=>z.fetchGrades(2026,3))});
