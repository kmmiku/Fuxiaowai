'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
exports.createUserMetrics=({ROOT,json,checkAuth,needAuth,readBody})=>{
 const dir=path.join(ROOT,'user-metrics');fs.mkdirSync(dir,{recursive:true,mode:0o700});
 const keyFile=path.join(dir,'.hmac-key');
 try{fs.writeFileSync(keyFile,crypto.randomBytes(32),{flag:'wx',mode:0o600});}catch(e){if(e.code!=='EEXIST')throw e;}
 const key=fs.readFileSync(keyFile);if(key.length!==32)throw new Error('Invalid metrics key');
 const file=path.join(dir,'users.json');
 let users=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):[];
 if(!Array.isArray(users)||users.some(u=>!/^\w{64}$/.test(u.digest)||!/^\d{4}-\d{2}-\d{2}$/.test(u.day)))throw new Error('Invalid metrics store');
 const known=new Set(users.map(u=>u.digest));let queue=Promise.resolve();
 return {async handle(req,res,url){
  if(url.pathname==='/api/user-metrics/login'&&req.method==='POST'){
   let payload;try{payload=JSON.parse(await readBody(req,512));}catch{json(req,res,400,{ok:false,msg:'Invalid request'});return true;}
   if(!payload||typeof payload.studentId!=='string'||!/^\d{6,20}$/.test(payload.studentId)){json(req,res,400,{ok:false,msg:'Invalid request'});return true;}
   const digest=crypto.createHmac('sha256',key).update('fzfu:'+payload.studentId).digest('hex');
   payload.studentId='';payload=null;
   const work=queue.then(async()=>{
    if(known.has(digest))return;
    const registeredAt=Date.now();const day=new Date(registeredAt+8*3600000).toISOString().slice(0,10);
    const next=users.concat({digest,day,registeredAt,userId:users.length+1});const tmp=file+'.tmp';
    try{await fs.promises.writeFile(tmp,JSON.stringify(next),{mode:0o600});await fs.promises.rename(tmp,file);}finally{await fs.promises.unlink(tmp).catch(()=>{});}
    users=next;known.add(digest);
   });queue=work.catch(()=>{});
   try{await work;json(req,res,200,{ok:true});}catch{json(req,res,503,{ok:false,msg:'Metrics unavailable'});}return true;
  }
  if(url.pathname==='/api/admin/users'&&req.method==='GET'){
   if(!checkAuth(req)){needAuth(req,res);return true;}
   res.setHeader('Cache-Control','no-store');
   const counts=new Map();for(const u of users)counts.set(u.day,(counts.get(u.day)||0)+1);
   const daily=[];const now=new Date(Date.now()+8*3600000);for(let n=6;n>=0;n--){const day=new Date(now.getTime()-n*86400000).toISOString().slice(0,10);daily.push({day,count:counts.get(day)||0});}
   const offset=Math.max(0,Math.min(users.length,Number(url.searchParams.get('offset'))||0));
   const rows=users.map((u,i)=>({userId:String(u.userId||i+1).padStart(2,'0'),registeredAt:u.registeredAt?new Date(u.registeredAt+8*3600000).toISOString().slice(0,16).replace('T','-'):u.day})).reverse().slice(offset,offset+50);
   json(req,res,200,{ok:true,total:users.length,daily,offset,users:rows});return true;
  }return false;
 }};
};
