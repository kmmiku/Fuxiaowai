const assert = require('node:assert/strict');
const { TextEncoder, TextDecoder } = require('node:util');
const { loadEts } = require('./ets-loader.cjs');
const util = { TextEncoder: class { encodeInto(s) { return new TextEncoder().encode(s); } }, TextDecoder: { create() { return { decodeToString(b) { return new TextDecoder().decode(b); } }; } } };
let scenario; let closes=0;
const socket = { constructTCPSocketInstance() {
  const listeners = {};
  return { on(n,f) { listeners[n]=f; }, off(n) { delete listeners[n]; },
    async connect() {}, async send() { scenario(listeners); }, async close() { closes++; } };
} };
const { RawHttp } = loadEts('entry/src/main/ets/network/http/RawHttp.ets', { '@ohos.zlib':{default:{}}, '@ohos.net.socket':{default:socket}, '@ohos.util':{default:util} });
function emit(l, text) { const b=Buffer.from(text); l.message?.({message: b.buffer.slice(b.byteOffset,b.byteOffset+b.length)}); }
(async () => {
  scenario=l=>{ emit(l,'HTTP/1.1 200 OK\r\nContent-Length: 6\r\n\r\n'); const b=Buffer.from('你好'); l.message({message:b.buffer.slice(b.byteOffset,b.byteOffset+2)}); l.message?.({message:b.buffer.slice(b.byteOffset+2,b.byteOffset+6)}); };
  assert.equal((await RawHttp.get('a.test','/','',100)).body,'你好');
  scenario=l=>{ emit(l,'HTTP/1.1 302 Found\r\nTransfer-Encoding: chunked\r\nSet-Cookie: s=secret\r\nLocation: /next\r\n\r\n3\r\nabc\r\n'); emit(l,'0\r\nX-Check: yes\r\n\r\n'); };
  const result=await RawHttp.get('a.test','/','',100); assert.equal(result.body,'abc'); assert.equal(result.location,'/next');
  scenario=l=>{ emit(l,'HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\nabc'); l.close(); };
  await assert.rejects(RawHttp.get('a.test','/','',100), /Incomplete/);
  scenario=l=>emit(l,'HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\nabc');
  await assert.rejects(RawHttp.get('a.test','/','',10), /timed out/);
  scenario=l=>{ emit(l,'HTTP/1.1 200 OK\r\n\r\nabc'); l.error(); };
  await assert.rejects(RawHttp.get('a.test','/','',100), /socket error/);
  scenario=l=>emit(l,'HTTP/1.1 200 OK\r\nContent-Length: 99999999\r\n\r\n');
  await assert.rejects(RawHttp.get('a.test','/','',100));
  scenario=l=>{ emit(l,'HTTP/1.1 200 OK\r\n\r\nabc'); l.close(); };
  assert.equal((await RawHttp.get('a.test','/','',100)).body,'abc');
  assert.throws(()=>RawHttp.hostOf('https://a.test/private'));
  assert.throws(()=>RawHttp.hostOf('http://a.test:443/private'));
  assert.equal(RawHttp.pathOf('http://a.test?x=1#fragment'),'/?x=1');
  assert.equal(closes,7);
  console.log('network raw HTTP checks passed');
})().catch(e=>{ console.error(e); process.exitCode=1; });


