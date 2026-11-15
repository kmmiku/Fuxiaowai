'use strict';
// Additional management routes. Public share/feedback contracts and ticket files stay untouched.
const fs=require('node:fs');
const fsp=fs.promises;
const path=require('node:path');
const os=require('node:os');
const crypto=require('node:crypto');
const http=require('node:http');
const https=require('node:https');
const {monitorEventLoopDelay}=require('node:perf_hooks');

function createAdminConsole(options){
 const {ROOT,TICKET_DIR,TTL_MS,PORT,BIND,json,checkAuth,needAuth}=options;
 const dir=path.join(ROOT,'admin');fs.mkdirSync(dir,{recursive:true,mode:0o700});
 const retention=30*86400000;
 const blocked=new Set();let storageError=null,writeError=null,dirty=false,timer=null,writing=Promise.resolve(),closed=false;
 const storageMessage=()=>blocked.size?'历史记录读取失败，已禁止覆盖受影响文件；请从备份恢复 '+[...blocked].join('/')+'.json':writeError;
 const load=name=>{try{const rows=JSON.parse(fs.readFileSync(path.join(dir,name+'.json'),'utf8'));if(!Array.isArray(rows))throw new Error('Invalid history');return rows.filter(r=>r&&Number(r.time)>Date.now()-retention).slice(-2000);}catch(e){if(e.code!=='ENOENT'){blocked.add(name);storageError=storageMessage();}return [];}};
 let audit=load('audit'),events=load('alerts'),active=new Map();
 // A process restart interrupts observation; never present old active rows as freshly observed.
 for(const event of events){if(event.state==='active'){event.state='interrupted';event.endedAt=Date.now();dirty=true;}}
 let recentErrors=[],authFailures=[],cpuPrevious=os.cpus(),netPrevious=null,latest=null,probing=null,lastExternal=0,external={state:'pending',checkedAt:null};
 const streak=new Map();
 const delay=monitorEventLoopDelay({resolution:20});delay.enable();
 const fingerprint=value=>crypto.createHash('sha256').update(String(value)).digest('hex').slice(0,12);
 function schedule(wait=100){dirty=true;if(!timer&&!closed){timer=setTimeout(()=>{timer=null;flush().catch(()=>{});},wait);timer.unref();}}
 if(dirty)schedule();
 function record(action,target='',status=200){
  audit.push({id:crypto.randomBytes(8).toString('hex'),time:Date.now(),actor:'管理员',action,target:target?fingerprint(target):'',status});
  audit=audit.filter(r=>r.time>Date.now()-retention).slice(-2000);schedule();
 }
 async function flush(){
  if(timer){clearTimeout(timer);timer=null;}
  const job=writing.catch(()=>{}).then(async()=>{
   if(!dirty)return;dirty=false;
   try{
    for(const [name,rows] of [['audit',audit],['alerts',events]]){
     if(blocked.has(name))continue;
     const file=path.join(dir,name+'.json'),tmp=file+'.'+crypto.randomBytes(6).toString('hex')+'.tmp';
     try{await fsp.writeFile(tmp,JSON.stringify(rows),{mode:0o600,flag:'wx'});await fsp.rename(tmp,file);}finally{await fsp.unlink(tmp).catch(()=>{});}
    }
    writeError=null;storageError=storageMessage();
   }catch(e){writeError='操作记录或告警持久化失败，请检查磁盘和权限';storageError=storageMessage();console.error('[admin-console] persistence failure',e.code||'IO');schedule(options.retryMs||5000);}
  });writing=job;await job;
 }
 function signal(key,abnormal,title,detail,level='warning',now=Date.now()){
  const prev=active.get(key);
  if(abnormal){
   if(prev){prev.lastSeen=now;prev.detail=detail;return;}
   const item={id:crypto.randomBytes(8).toString('hex'),time:now,lastSeen:now,key,title,detail,level,state:'active'};
   active.set(key,item);events.push(item);schedule();
  }else if(prev){prev.state='resolved';prev.resolvedAt=now;active.delete(key);schedule();}
  events=events.filter(r=>r.time>now-retention).slice(-2000);
 }
 function evaluate(metrics,now=Date.now()){
  for(const [key,title,threshold] of [['cpu','CPU 持续高负载',90],['mem','主机内存使用率偏高',90],['disk','磁盘空间不足',90]]){
   const n=metrics[key];if(!Number.isFinite(n))continue;
   const count=n>=threshold?(streak.get(key)||0)+1:0;streak.set(key,count);
   signal(key,count>=3,title,`当前 ${n.toFixed(1)}%，阈值 ${threshold}%；连续三次采样触发`,key==='disk'?'danger':'warning',now);
  }
  signal('errors',recentErrors.filter(t=>t>now-60000).length>=3,'接口连续异常','最近一分钟至少三次服务端错误，请检查服务日志','danger',now);
  signal('auth',authFailures.filter(t=>t>now-300000).length>=10,'后台认证失败较多','最近五分钟至少十次认证失败，请核对访问来源','warning',now);
 }
 function observe(req,res,url){
  res.once('finish',()=>{
   if(res.statusCode>=500){recentErrors.push(Date.now());recentErrors=recentErrors.filter(t=>t>Date.now()-60000).slice(-500);}
   if(res.statusCode===401&&req.headers.authorization&&(url.pathname.startsWith('/api/admin/')||url.pathname.startsWith('/admin'))){authFailures.push(Date.now());authFailures=authFailures.filter(t=>t>Date.now()-300000).slice(-500);}
   if(!checkAuth(req))return;
   const p=url.pathname;
   let action=null,target='';
   if(req.method==='DELETE'&&/^\/api\/admin\/tickets\/[a-f0-9]{32}$/i.test(p)){action='ticket.delete';target=p.split('/').pop().toLowerCase();}
   if(req.method==='DELETE'&&/^\/api\/admin\/feedback\/[a-f0-9]{16}$/.test(p)){action='feedback.delete';target=p.split('/').pop();}
   if(req.method==='POST'&&p==='/api/admin/feedback/read')action='feedback.read';
   if(req.method==='POST'&&p==='/api/admin/inspect'){action='ticket.inspect';target=req.adminAuditTarget||'';}
   if(action)record(action,target,res.statusCode);
  });
 }
 async function readJson(req){
  let total=0;const chunks=[];
  for await(const chunk of req){total+=chunk.length;if(total>16384){const error=new Error('body too large');error.status=413;throw error;}chunks.push(chunk);}
  try{return JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{const error=new Error('bad JSON');error.status=400;throw error;}
 }
 function sameOrigin(req){
  if(req.headers['sec-fetch-site']==='cross-site')return false;
  const origin=req.headers.origin;if(!origin)return true;
  try{const u=new URL(origin),publicOrigin=new URL(options.publicOrigin||process.env.FXW_ADMIN_ORIGIN||'https://fuxiaowai.xyz');
   const expected=String(req.headers.host)===publicOrigin.host?publicOrigin.origin:(req.socket?.encrypted?'https://':'http://')+req.headers.host;
   return u.origin===expected;
  }catch{return false;}
 }
 function courseChecks(data){
  const courses=Array.isArray(data.courses)?data.courses:[];
  const int=(n,min,max)=>Number.isInteger(n)&&n>=min&&n<=max;
  const time=s=>typeof s==='string'&&/^([01]\d|2[0-3]):[0-5]\d$/.test(s);
  const text=(v,max)=>typeof v==='string'&&v.length<=max;
  const ids=new Set();
  const checks=[{name:'快照基础字段',ok:text(data.code,64)&&text(data.term,200)&&int(data.week,0,60)},
   {name:'课程列表',ok:courses.length>0&&courses.length<=800},
   {name:'课程字段与唯一标识',ok:courses.length>0&&courses.every(c=>{
    if(!c||!text(c.id,300)||ids.has(c.id)||!text(c.name,300)||!c.name.trim()||!text(c.room,300)||!int(c.weekday,1,7)||!int(c.startPeriod,1,48)||!int(c.endPeriod,c.startPeriod,48)||!Array.isArray(c.weeks)||!c.weeks.length||c.weeks.length>60||!c.weeks.every(w=>int(w,1,60)))return false;
    if(c.teacher!==undefined&&!text(c.teacher,300)||c.campus!==undefined&&!text(c.campus,300)||c.colorIndex!==undefined&&!int(c.colorIndex,0,255))return false;
    ids.add(c.id);return true;
   })}];
  const periods=data.periods;
  {const seen=new Set();checks.push({name:'节次时间表',ok:Array.isArray(periods)&&periods.length<=48&&periods.every(p=>{if(!p||!int(p.index,1,48)||seen.has(p.index)||!time(p.start)||!time(p.end)||p.end<=p.start)return false;seen.add(p.index);return true;})});}
  return {checks,warnings:!Array.isArray(periods)||!periods.length?['未附带节次时间表，客户端可能使用本地默认时间']:[]};
 }
 async function inspect(code){
  const file=path.join(TICKET_DIR,code+'.json');let data;
  try{const st=await fsp.stat(file);if(st.size>1048576)return {status:'invalid',message:'快照超过检测大小上限'};data=JSON.parse(await fsp.readFile(file,'utf8'));}
  catch(e){if(e.code==='ENOENT')return {status:'missing',message:'口令不存在；已清理的过期记录无法追溯'};if(e instanceof SyntaxError)return {status:'invalid',message:'快照 JSON 损坏'};throw e;}
  if(!data||typeof data!=='object'||!Number.isFinite(data.createdAt)||data.createdAt<=0)return {status:'invalid',message:'创建时间或快照结构异常'};
   const detail=courseChecks({...data,code:data.code===undefined?code:data.code}),expiresAt=data.createdAt+TTL_MS;
  return {status:expiresAt<Date.now()?'expired':detail.checks.every(c=>c.ok)?'valid':'invalid',createdAt:data.createdAt,expiresAt,term:typeof data.term==='string'?data.term:'',week:data.week,count:Array.isArray(data.courses)?data.courses.length:0,...detail};
 }
 let ticketCache=null,ticketLoading=null;
 async function ticketRows(){
  if(ticketCache&&ticketCache.until>Date.now())return ticketCache.rows;
  if(ticketLoading)return ticketLoading;
  ticketLoading=(async()=>{
   const files=(await fsp.readdir(TICKET_DIR)).filter(f=>/^[a-f0-9]{32}\.json$/.test(f)),rows=[];
   for(const file of files){
    try{const full=path.join(TICKET_DIR,file),st=await fsp.stat(full);let data=null;
     if(st.size<=1048576){try{data=JSON.parse(await fsp.readFile(full,'utf8'));}catch{}}
     const createdAt=Number.isFinite(data?.createdAt)?data.createdAt:st.mtimeMs;
     rows.push({code:file.slice(0,-5),createdAt,expiresAt:data?.createdAt?data.createdAt+TTL_MS:null,term:typeof data?.term==='string'?data.term:'',week:data?.week||0,count:Array.isArray(data?.courses)?data.courses.length:0,size:st.size,status:!data?'invalid':createdAt+TTL_MS<Date.now()?'expired':'unchecked'});
    }catch(e){if(e.code!=='ENOENT')throw e;}
   }
   rows.sort((a,b)=>b.createdAt-a.createdAt);ticketCache={until:Date.now()+10000,rows};return rows;
  })();try{return await ticketLoading;}finally{ticketLoading=null;}
 }
 function localHealth(){return new Promise(resolve=>{
  if(!PORT){resolve({state:'unknown',message:'未配置健康检查端口',checkedAt:Date.now()});return;}
  const started=Date.now(),host=BIND==='0.0.0.0'||BIND==='::'?'127.0.0.1':BIND;
  const req=http.get({host,port:PORT,path:'/healthz',timeout:2500},res=>{let body='';res.on('data',b=>{if(body.length<64)body+=b;});res.on('end',()=>resolve({state:res.statusCode===200&&body.trim()==='ok'?'healthy':'error',status:res.statusCode,latencyMs:Date.now()-started,checkedAt:Date.now()}));});
  req.on('timeout',()=>req.destroy());req.on('error',()=>resolve({state:'error',message:'本机应用健康检查失败',checkedAt:Date.now()}));
 });}
 function externalHealth(){return new Promise(resolve=>{
  // A resumed TLS session may return an empty certificate object. Use a fresh
  // one-off connection for this once-per-minute certificate/HTTPS probe.
  const started=Date.now();const req=https.get('https://fuxiaowai.xyz/healthz',{timeout:4000,agent:false},res=>{
   const cert=res.socket.getPeerCertificate();let body='';res.on('data',b=>{if(body.length<64)body+=b;});
   res.on('end',()=>resolve({state:res.statusCode===200&&body.trim()==='ok'?'healthy':'error',status:res.statusCode,latencyMs:Date.now()-started,checkedAt:Date.now(),certificateExpiresAt:cert.valid_to?Date.parse(cert.valid_to):null}));
  });req.on('timeout',()=>req.destroy());req.on('error',()=>resolve({state:'error',message:'公网 HTTPS 健康检查失败（含证书校验）',checkedAt:Date.now()}));
 });}
 async function sample(){
  if(probing)return probing;
  probing=(async()=>{
   const now=Date.now(),cpus=os.cpus();let total=0,idle=0;
   const retained=audit.filter(r=>r.time>now-retention);if(retained.length!==audit.length){audit=retained;schedule();}
   cpus.forEach((c,i)=>{const prev=cpuPrevious[i];if(prev){for(const k of Object.keys(c.times))total+=c.times[k]-prev.times[k];idle+=c.times.idle-prev.times.idle;}});cpuPrevious=cpus;
   let disk={state:'unknown'};
   try{const st=await fsp.statfs(ROOT);disk={state:'healthy',total:st.blocks*st.bsize,used:(st.blocks-st.bfree)*st.bsize,avail:st.bavail*st.bsize,percent:st.blocks?(st.blocks-st.bfree)/st.blocks*100:0};}catch{disk={state:'error'};}
   let net={state:'unknown'};
   try{const raw=await fsp.readFile('/proc/net/dev','utf8');let rx=0,tx=0;raw.split('\n').forEach(line=>{if(!line.includes(':'))return;const [name,values]=line.split(':');if(name.trim()==='lo')return;const fields=values.trim().split(/\s+/).map(Number);rx+=fields[0]||0;tx+=fields[8]||0;});if(netPrevious){const seconds=(now-netPrevious.time)/1000;net={state:'healthy',rxBps:Math.max(0,(rx-netPrevious.rx)/seconds),txBps:Math.max(0,(tx-netPrevious.tx)/seconds)};}netPrevious={time:now,rx,tx};}catch{}
   const mem={total:os.totalmem(),free:os.freemem(),used:os.totalmem()-os.freemem(),percent:(1-os.freemem()/os.totalmem())*100};
   const health=await localHealth();
   if(options.externalProbe!==false&&now-lastExternal>=60000){lastExternal=now;external=await externalHealth();}
   const lag=Number.isFinite(delay.mean)?delay.mean/1e6:0;delay.reset();
   const cpu=total>0?Math.max(0,Math.min(100,(1-idle/total)*100)):0;
   evaluate({cpu,mem:mem.percent,disk:disk.percent},now);
   signal('disk-probe',disk.state==='error','磁盘探针失败','无法读取数据目录所在磁盘的统计信息','danger',now);
   signal('health',health.state==='error','应用健康检查异常','本机 /healthz 检查失败','danger',now);
   if(options.externalProbe!==false){signal('https',external.state==='error','公网 HTTPS 链路异常','域名健康检查失败，请检查证书、反向代理或网络','danger',now);if(external.certificateExpiresAt)signal('certificate',external.certificateExpiresAt-now<14*86400000,'HTTPS 证书即将到期','证书有效期不足14天，请检查自动续期','warning',now);}
   const lagCount=lag>200?(streak.get('lag')||0)+1:0;streak.set('lag',lagCount);signal('lag',lagCount>=3,'应用事件循环延迟较高','连续三次采样的平均延迟超过200ms','warning',now);
   signal('sampling',false,'系统采样失败','','danger',now);
   latest={ok:true,sampledAt:Date.now(),uptimeSec:Math.round(process.uptime()),host:{hostname:os.hostname(),cores:cpus.length,load:os.loadavg()},metrics:{cpu:{percent:cpu},mem,disk,net,proc:{rss:process.memoryUsage().rss,heap:process.memoryUsage().heapUsed,eventLoopMs:lag}},health,external,storageError};return latest;
  })();try{return await probing;}finally{probing=null;}
 }
 function alertPayload(){return {ok:true,time:Date.now(),sampledAt:latest?.sampledAt||null,storageError,active:[...active.values()],rows:[...events].reverse().slice(0,200),thresholds:{cpu:90,mem:90,disk:90,consecutiveSamples:3,certificateDays:14}};}
 async function handle(req,res,url){
  const p=url.pathname;

  if(p==='/api/admin/app-version'){
   if(!checkAuth(req)){needAuth(req,res);return true;}
   if(!['GET','PUT'].includes(req.method)){json(req,res,405,{ok:false,msg:'请求方法不支持'});return true;}
   if(req.method==='PUT'&&!sameOrigin(req)){json(req,res,403,{ok:false,msg:'拒绝跨站管理操作'});return true;}
   const platform=url.searchParams.get('platform');
   if(!['android','harmony'].includes(platform)){json(req,res,400,{ok:false,msg:'平台无效'});return true;}
   const file=path.join(dir,'app-version-'+platform+'.json');
   try{
    if(req.method==='GET'){
     let version=null;try{version=JSON.parse(await fsp.readFile(file,'utf8'));}catch(e){if(e.code!=='ENOENT')throw e;}
     json(req,res,200,{ok:true,version});return true;
    }
    const b=await readJson(req);
    if(!b||!Number.isSafeInteger(b.versionCode)||b.versionCode<1||b.versionCode>2147483647||typeof b.versionName!=='string'||!/^\d+(?:\.\d+){1,3}$/.test(b.versionName)||b.versionName.length>40){json(req,res,400,{ok:false,msg:'软件版本无效'});return true;}
    if(b.content!==undefined&&(typeof b.content!=='string'||b.content.length>2500)){json(req,res,400,{ok:false,msg:'版本说明最多2500字'});return true;}
    let updateUrl='';
    if(platform==='android'&&b.updateUrl){try{const u=new URL(b.updateUrl);if(u.protocol!=='https:'||u.username||u.password)throw Error();updateUrl=u.href;}catch{json(req,res,400,{ok:false,msg:'安卓更新地址必须为HTTPS'});return true;}}
    const version={platform,content:typeof b.content==='string'?b.content.trim():'',versionCode:b.versionCode,versionName:b.versionName,updateUrl,publishedAt:Date.now()};
    const tmp=file+'.'+crypto.randomBytes(8).toString('hex')+'.tmp';
    try{await fsp.writeFile(tmp,JSON.stringify(version),{mode:0o600,flag:'wx'});await fsp.rename(tmp,file);}finally{await fsp.unlink(tmp).catch(()=>{});}
    record('version.save',platform+':'+b.versionCode);json(req,res,200,{ok:true,version});return true;
   }catch(e){json(req,res,e.status||500,{ok:false,msg:'软件版本读取或保存失败'});return true;}
  }
  if(p==='/api/app-update'||p==='/api/admin/app-update'){
   const publicRead=p==='/api/app-update',platform=url.searchParams.get('platform')||'harmony'; if(!['android','harmony'].includes(platform)){json(req,res,400,{ok:false,msg:'平台无效'});return true;} const file=path.join(dir,platform==='harmony'?'app-update.json':'app-update-android.json');
   res.setHeader('Cache-Control','no-store');
   if(!publicRead&&!checkAuth(req)){needAuth(req,res);return true;}
   if(!publicRead&&!['GET','HEAD'].includes(req.method)&&!sameOrigin(req)){json(req,res,403,{ok:false,msg:'拒绝跨站管理操作'});return true;}
   try{
    if(req.method==='GET'){
     let release=null;try{release=JSON.parse(await fsp.readFile(file,'utf8'));}catch(e){if(e.code!=='ENOENT')throw e;}
     json(req,res,200,{ok:true,release});return true;
    }
    if(!publicRead&&req.method==='PUT'){
     const b=await readJson(req); if(!b||typeof b!=='object'||Array.isArray(b)){json(req,res,400,{ok:false,msg:'公告格式无效'});return true;}
     if(!Number.isSafeInteger(b.versionCode)||b.versionCode<1||b.versionCode>2147483647||typeof b.versionName!=='string'||!/^\d+(?:\.\d+){1,3}$/.test(b.versionName)||b.versionName.length>40||typeof b.content!=='string'||!b.content.trim()||b.content.length>2500){json(req,res,400,{ok:false,msg:'版本号或更新内容无效（内容最多2500字）'});return true;}
     let updateUrl=''; if(platform==='android'){try{const u=new URL(b.updateUrl);if(u.protocol!=='https:'||u.username||u.password)throw Error();updateUrl=u.href;}catch{json(req,res,400,{ok:false,msg:'安卓更新地址必须为HTTPS'});return true;}} const release={platform,updateUrl,versionCode:b.versionCode,versionName:b.versionName,content:b.content.trim(),publishedAt:Date.now()};
     const tmp=file+'.'+crypto.randomBytes(8).toString('hex')+'.tmp';
     try{await fsp.writeFile(tmp,JSON.stringify(release),{mode:0o600,flag:'wx'});await fsp.rename(tmp,file);}finally{await fsp.unlink(tmp).catch(()=>{});}
     record('update.publish',platform+':'+String(b.versionCode));json(req,res,200,{ok:true,release});return true;
    }
    if(!publicRead&&req.method==='DELETE'){await fsp.unlink(file).catch(e=>{if(e.code!=='ENOENT')throw e;});record('update.withdraw',platform);json(req,res,200,{ok:true});return true;}
    json(req,res,405,{ok:false,msg:'请求方法不支持'});return true;
   }catch(e){json(req,res,e.status||500,{ok:false,msg:'版本公告读取或保存失败'});return true;}
  }


  const asset=p==='/admin/admin.js'||p==='/admin/admin.css';
  const endpoint=['/api/admin/inspect','/api/admin/ticket-search','/api/admin/probes','/api/admin/alerts','/api/admin/audit'].includes(p);
  const adminWrite=p.startsWith('/api/admin/')&&!['GET','HEAD','OPTIONS'].includes(req.method);
  if(!asset&&!endpoint&&!adminWrite)return false;
  if(!checkAuth(req)){needAuth(req,res);return true;}
  if(adminWrite&&!sameOrigin(req)){json(req,res,403,{ok:false,msg:'拒绝跨站管理操作'});return true;}
  if(req.method==='DELETE'&&p.startsWith('/api/admin/tickets/'))ticketCache=null;
  if(!asset&&!endpoint)return false;
  const method=p==='/api/admin/inspect'?'POST':'GET';
  if(req.method!==method){res.setHeader('Allow',method);json(req,res,405,{ok:false,msg:'请求方法不支持'});return true;}
  try{
   if(asset){const body=await fsp.readFile(path.join(__dirname,p.endsWith('.js')?'admin.js':'admin.css'));res.writeHead(200,{'content-type':p.endsWith('.js')?'text/javascript; charset=utf-8':'text/css; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff'});res.end(body);return true;}
   if(p==='/api/admin/inspect'){
    const body=await readJson(req),code=typeof body?.code==='string'?body.code.trim().toLowerCase():'';
    if(!/^[a-f0-9]{32}$/.test(code)){json(req,res,400,{ok:false,msg:'请输入32位十六进制口令'});return true;}req.adminAuditTarget=code;
    json(req,res,200,{ok:true,code,...await inspect(code)});return true;
   }
   if(p==='/api/admin/ticket-search'){
    const q=(url.searchParams.get('q')||'').trim().toLowerCase().slice(0,200),status=url.searchParams.get('status')||'';
    const offset=Math.max(0,Math.floor(Number(url.searchParams.get('offset'))||0)),limit=Math.min(100,Math.max(1,Math.floor(Number(url.searchParams.get('limit'))||20)));
    const all=await ticketRows(),filtered=all.filter(r=>(!q||r.code.includes(q)||r.term.toLowerCase().includes(q))&&(!status||r.status===status));
    json(req,res,200,{ok:true,total:filtered.length,allTotal:all.length,offset,limit,rows:filtered.slice(offset,offset+limit)});return true;
   }
   if(p==='/api/admin/probes'){json(req,res,200,latest&&latest.sampledAt>Date.now()-15000?latest:await sample());return true;}
   if(p==='/api/admin/alerts'){if(!latest)await sample();json(req,res,200,alertPayload());return true;}
   if(p==='/api/admin/audit'){json(req,res,200,{ok:true,time:Date.now(),storageError,retentionDays:30,rows:[...audit].reverse().slice(0,200)});return true;}
  }catch(e){json(req,res,e.status||500,{ok:false,msg:e.status===400?'JSON 格式错误':e.status===413?'请求内容过大':'管理数据读取失败，请检查服务日志'});}
  return true;
 }
 const interval=setInterval(()=>sample().catch(()=>{signal('sampling',true,'系统采样失败','探针无法完成采样，请检查服务日志','danger');}),15000);interval.unref();
 return {handle,observe,record,flush,evaluate,async close(){closed=true;clearInterval(interval);delay.disable();if(probing)await probing;await flush();}};
}
module.exports={createAdminConsole};
