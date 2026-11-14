const {test}=require('node:test');const assert=require('node:assert/strict');const {loadEts}=require('./ets-loader.cjs');
const jw='jw.fzfu.edu.cn';const portal='portal.fzfu.edu.cn';
function setup(queue){const cache=new Map();const {AccountScope}=loadEts('entry/src/main/ets/common/util/AccountScope.ets',{},cache);const {CookieJar}=loadEts('entry/src/main/ets/network/http/CookieJar.ets',{},cache);const client={jar:new CookieJar()};const calls=[];
 const raw={hostOf:url=>{const u=new URL(url);if(u.protocol!=='http:'||u.port)throw Error('unsupported');return u.hostname;},pathOf:url=>{const u=new URL(url);return u.pathname+u.search;},get:async(host,path,cookie)=>{calls.push({host,path,cookie});const v=queue.shift();if(!v)throw Error('unexpected request');return typeof v==='function'?v():v;}};
 const {CasTicket}=loadEts('entry/src/main/ets/data/remote/auth/CasTicket.ets',{'@ohos.hilog':{default:{info(){},warn(){},error(){}}},'../../../network/http/RawHttp':{RawHttp:raw}},cache);return{client,CasTicket,calls,AccountScope};}
const res=(status,body='',location='',setCookie='')=>({status,body,location,setCookie});
test('old provisional JSESSIONID cannot turn portal login HTML into mint success',async()=>{
 const h=setup([res(200,'<form id="fm1"></form>'),res(200,'<form id="fm1"></form>')]);h.client.jar.absorb('JSESSIONID=synthetic; Path=/jwglxt',jw);
 assert.equal(await h.CasTicket.mint(h.client,'test'),false);assert.equal(h.calls.length,2);
});
test('mint succeeds only after landing on authenticated-looking JW business page',async()=>{
 const h=setup([res(302,'','http://'+jw+'/jwglxt/kbcx/index.html?ticket=synthetic'),res(200,'<html>course page</html>','','JSESSIONID=synthetic; Path=/jwglxt')]);
 assert.equal(await h.CasTicket.mint(h.client,'test'),true);assert.equal(h.calls.length,2);
});
test('follow resolves relative hops from actual previous path and scopes cookies',async()=>{
 const h=setup([res(302,'','next.html','FLOW=synthetic'),res(200,'course page')]);
 const landing=await h.CasTicket.follow(h.client,res(302,'','../kbcx/first.html'),'test',jw,'/jwglxt/xtgl/login_cas.html');
 assert.equal(h.calls[0].host,jw);assert.equal(h.calls[0].path,'/jwglxt/kbcx/first.html');assert.equal(h.calls[1].path,'/jwglxt/kbcx/next.html');assert.equal(landing.host,jw);
 assert.match(h.calls[1].cookie,/FLOW=/);assert.equal(h.client.jar.header(jw,'/outside'),'');
});

test('account change during mint first response cancels before cookies or redirect follow',async()=>{
 let h;h=setup([()=>{h.AccountScope.invalidate();return res(302,'','http://'+jw+'/jwglxt/kbcx/index.html','CAS=synthetic; Path=/');}]);
 h.AccountScope.begin('synthetic');await assert.rejects(h.CasTicket.mint(h.client,'test'),/账号|状态/);
 assert.equal(h.calls.length,1);assert.equal(h.client.jar.header(portal,'/cas/login'),'');
});
