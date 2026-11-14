const assert=require('node:assert/strict');
const {loadEts}=require('./ets-loader.cjs');
let options;let destroyed=0;let fail=false;
const http={RequestMethod:{GET:'GET',POST:'POST'},HttpDataType:{STRING:0,ARRAY_BUFFER:1},createHttp(){return{async request(url,o){options=o;if(fail)throw new Error('offline');return{responseCode:200,result:'ok',header:{'Set-Cookie':'sid=a; Path=/private; Secure'}};},destroy(){destroyed++;}};}};
const {HttpClient}=loadEts('entry/src/main/ets/network/http/HttpClient.ets',{'@ohos.net.http':{default:http}});
(async()=>{const client=new HttpClient('https://a.test');await client.get('/private/login');await client.get('/private/next');assert.equal(options.header.Cookie,'sid=a');await client.get('/public');assert.equal(options.header.Cookie,undefined);await client.get('http://a.test/private');assert.equal(options.header.Cookie,undefined);fail=true;await assert.rejects(client.get('/private'));assert.equal(destroyed,5);await assert.rejects(client.get('ftp://a.test/private'));console.log('network HttpClient scope and cleanup checks passed');})().catch(e=>{console.error(e);process.exitCode=1;});
