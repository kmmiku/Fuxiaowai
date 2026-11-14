const {test}=require('node:test');const assert=require('node:assert/strict');const {loadEts}=require('./ets-loader.cjs');
const root='entry/src/main/ets/';const jw='jw.fzfu.edu.cn';const portal='portal.fzfu.edu.cn';
const response=(status,body='',location='',setCookie='')=>({status,body,location,setCookie});
const data=JSON.stringify({kbList:[{kcmc:'synthetic'}]});
function harness(queue,mintResult=true){
 const cache=new Map();const {CookieJar}=loadEts(root+'network/http/CookieJar.ets',{},cache);
 const calls=[];let mints=0;let systemGets=0;
 class HttpClient{constructor(){this.jar=new CookieJar();}static encodeForm(fields){return fields.map(f=>f.key+'='+encodeURIComponent(f.value)).join('&');}async get(){systemGets++;throw Error('must not reload menu');}}
 const raw={hostOf:url=>{const u=new URL(url);if(u.protocol!=='http:'||u.port)throw Error('unsupported');return u.hostname;},pathOf:url=>{const u=new URL(url);return u.pathname+u.search;},
  postForm:async(host,path,cookie,body)=>{calls.push({method:'POST',host,path,body});const next=queue.shift();if(!next)throw Error('unexpected request');return typeof next==='function'?next():next;},
  get:async(host,path)=>{calls.push({method:'GET',host,path});const next=queue.shift();if(!next)throw Error('unexpected request');return next;}};
 const mocks={'@ohos.hilog':{default:{info(){},warn(){},error(){}}},'../../../network/http/HttpClient':{HttpClient},'../../../network/http/RawHttp':{RawHttp:raw},'./RsaPublicKey':{},'./CasAuth':{},'./WecomQrLogin':{},
 './CasTicket':{JW_HOST:jw,CAS_PORTAL_HOST:portal,CasTicket:{mint:async()=>{mints++;return mintResult;}}}};
 const {AccountScope}=loadEts(root+'common/util/AccountScope.ets',{},cache);AccountScope.begin('synthetic');
 const ticket=loadEts(root+'data/remote/auth/CasTicket.ets',mocks,cache);
 class TestTicket extends ticket.CasTicket{static async mint(){mints++;return mintResult;}}
 mocks['./CasTicket']={JW_HOST:jw,CAS_PORTAL_HOST:portal,CasTicket:TestTicket};
 const {ZhengfangAuth}=loadEts(root+'data/remote/auth/ZhengfangAuth.ets',mocks,cache);
 return{auth:new ZhengfangAuth(),calls,mints:()=>mints,systemGets:()=>systemGets,AccountScope};
}
const semester={xnm:2026,xqm:3};
test('302 to login remints once and retries without reloading menu',async()=>{
 const h=harness([response(302,'','http://'+portal+'/cas/login?service=synthetic'),response(200,data)]);
 assert.equal(await h.auth.fetchTimetable('synthetic',semester),data);assert.equal(h.mints(),1);assert.equal(h.calls.length,2);assert.equal(h.systemGets(),0);
});
test('200 login HTML is recovered once; continuous 302 stops with useful error',async()=>{
 const h=harness([response(200,'<form id="fm1"></form>'),response(302,'','/jwglxt/xtgl/login_slogin.html')]);
 await assert.rejects(h.auth.fetchTimetable('synthetic',semester),/会话|重新登录/);assert.equal(h.mints(),1);assert.equal(h.calls.length,2);
});
test('failed session recovery does not resend timetable',async()=>{
 const h=harness([response(302,'','/jwglxt/xtgl/login_cas.html')],false);
 await assert.rejects(h.auth.fetchTimetable('synthetic',semester),/会话|重新登录/);assert.equal(h.mints(),1);assert.equal(h.calls.length,1);
});
test('foreign redirect is refused before following or session recovery',async()=>{
 const h=harness([response(302,'','http://untrusted.test/collect')]);
 await assert.rejects(h.auth.fetchTimetable('synthetic',semester),/不受信任|拒绝/);assert.equal(h.calls.length,1);assert.equal(h.mints(),0);
});
test('307 timetable relocation preserves POST and form body',async()=>{
 const h=harness([response(307,'','./new-query.html'),response(200,data)]);
 assert.equal(await h.auth.fetchTimetable('synthetic',semester),data);assert.equal(h.calls[1].method,'POST');assert.equal(h.calls[0].body,h.calls[1].body);assert.match(h.calls[1].path,/\/jwglxt\/kbcx\/new-query.html/);
});
test('fake kbList text and permission HTML never become a successful timetable',async()=>{
 const h=harness([response(200,'<html>"kbList"<p class="error_title">无功能权限</p></html>')]);
 await assert.rejects(h.auth.fetchTimetable('synthetic',semester),/权限/);assert.equal(h.mints(),0);
});
test('identity change after response prevents session recovery and retry',async()=>{
 let h;h=harness([()=>{h.AccountScope.invalidate();return response(302,'','/jwglxt/xtgl/login_cas.html');}]);
 await assert.rejects(h.auth.fetchTimetable('synthetic',semester),/账号|状态/);assert.equal(h.mints(),0);assert.equal(h.calls.length,1);
});
