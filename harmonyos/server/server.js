'use strict';
/**
 * 福小外 · 课表口令服务
 * - POST /api/share            存一份课表快照，返回 32 位口令
 * - GET  /api/share/:code      凭口令取回快照
 * - GET  /admin                可视化仪表盘（Basic Auth）
 * - GET  /api/admin/stats      实时指标（CPU / 内存 / 磁盘 / 网络 / 口令）
 * - GET  /api/admin/tickets    口令列表
 * - DEL  /api/admin/tickets/:c 删除口令
 * - GET  /healthz
 *
 * 单文件、零依赖，为 2Mbps 带宽做了：全量 gzip、请求体 64KB 上限、
 * 分层限流、异步持久化、统计 TTL 缓存；部署说明见 OPERATIONS.md。
 */
const http = require('http');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const crypto = require('crypto');
const os = require('os');

const PORT = Number(process.env.FXW_PORT || 8080);
const BIND = process.env.FXW_BIND || '127.0.0.1';
const ROOT = path.resolve(process.env.FXW_ROOT || '/var/lib/fxw');
const fsp=fs.promises;
const TICKET_DIR = path.join(ROOT, 'tickets');
const FB_DIR = path.join(ROOT, 'feedback');
const FB_IMG_DIR = path.join(FB_DIR, 'img');




const ADMIN_USER = process.env.FXW_ADMIN_USER;
const ADMIN_PASS = process.env.FXW_ADMIN_PASS;
if (!ADMIN_USER || !ADMIN_PASS) throw new Error('FXW_ADMIN_USER and FXW_ADMIN_PASS required');
const MAX_BODY = 64 * 1024;
const MAX_FB_BODY = 4 * 1024 * 1024;   // 反馈带图：3 张压过的 JPEG + 文字，4MB 足够
const MAX_FB_TEXT = 2000;
const MAX_FB_IMAGES = 3;
const TTL_MS = 30 * 24 * 3600 * 1000;
const RATE_LIMIT = 1200;
const RATE_WINDOW = 60 * 1000;
const MAX_COURSES = 800;
// Each feedback reader can retain 4 MiB plus decoded JSON/image copies.
// Admission is shared by every body-bearing route, before the first await.
const MAX_ACTIVE_WRITES = Math.min(32, Math.max(1, Math.floor(Number(process.env.FXW_MAX_ACTIVE_WRITES) || 8)));
let activeWrites = 0;

function admitWrite(req,res) {
  if(activeWrites >= MAX_ACTIVE_WRITES) {
    req.resume();
    res.setHeader('Retry-After','5');
    json(req,res,503,{ok:false,msg:'服务繁忙，请稍后再试',retryAfter:5});
    return null;
  }
  activeWrites++;
  let released=false;
  const release=()=>{if(!released){released=true;activeWrites--;}};
  return release;
}

function validShare(d) {
  const obj=o=>o && typeof o==='object' && !Array.isArray(o);
  const num=(n,a,b)=>Number.isInteger(n)&&n>=a&&n<=b;
  const str=(v,n)=>v===undefined || (typeof v==='string' && v.length<=n);
  if(!obj(d)||!Array.isArray(d.courses)||!d.courses.length||d.courses.length>800||!str(d.term,200)||(d.week!==undefined&&!num(d.week,0,60)))return false;
  if(!d.courses.every(c=>obj(c)&&typeof c.name==='string'&&c.name.length>0&&c.name.length<=300&&['id','teacher','room','campus'].every(k=>str(c[k],300))&&num(c.weekday,1,7)&&num(c.startPeriod,1,48)&&num(c.endPeriod,c.startPeriod,48)&&Array.isArray(c.weeks)&&c.weeks.length<=60&&c.weeks.every(w=>num(w,1,60))&&(c.colorIndex===undefined||num(c.colorIndex,0,255))))return false;
  return d.periods===undefined || (Array.isArray(d.periods)&&d.periods.length<=48&&d.periods.every(p=>obj(p)&&num(p.index,1,48)&&typeof p.start==='string'&&typeof p.end==='string'&&/^([01]\d|2[0-3]):[0-5]\d$/.test(p.start)&&/^([01]\d|2[0-3]):[0-5]\d$/.test(p.end)));
}
async function atomicWrite(file,data) {
  const tmp=file+'.'+crypto.randomBytes(8).toString('hex')+'.tmp';
  try {await fsp.writeFile(tmp,data,{mode:0o600,flag:'wx'});await fsp.rename(tmp,file);} finally {await fsp.unlink(tmp).catch(()=>{});}
}
function pipeFile(file,res,options) {
  const stream=fs.createReadStream(file,options);
  stream.on('error',()=>res.destroy());res.on('close',()=>stream.destroy());stream.pipe(res);
}
// One in-flight refresh per cache; polling does not rescan every request.
const caches=new Map();
function cached(key,fn,ttl=30000){
  const now=Date.now();let c=caches.get(key);
  if(!c||now>c.until){c={until:now+ttl,promise:Promise.resolve().then(fn)};caches.set(key,c);c.promise.catch(()=>caches.delete(key));}
  return c.promise;
}
function invalidate(){caches.delete('ticket-list');caches.delete('feedback-list');}
const writeLimits=new Map();
function quota(key,max){const now=Date.now();let q=writeLimits.get(key);if(!q||now>q.until){q={n:0,until:now+60000};writeLimits.set(key,q);}if(writeLimits.size>20000)writeLimits.delete(writeLimits.keys().next().value);return ++q.n>max;}
async function storageAvailable(kind){
  const disk=await cached('disk',diskUsage,5000);
  if(disk.avail<Number(process.env.FXW_MIN_FREE_BYTES||536870912))return false;
  const t=await cached('tickets',ticketStats);
  const f=await cached('feedback',fbStats);
  return kind==='share'?t.count<Number(process.env.FXW_MAX_TICKETS||100000):f.total<Number(process.env.FXW_MAX_FEEDBACK||20000);
}
const feedbackRequests=new Map();

fs.mkdirSync(TICKET_DIR, { recursive: true });
fs.mkdirSync(FB_IMG_DIR, { recursive: true });

// ---------- 静态页 ----------
const DASH_PATH = path.join(__dirname, 'dashboard.html');
let dashRaw = Buffer.from('<!doctype html><meta charset=utf-8><h1>dashboard.html 缺失</h1>');
let dashGzip = null;
try {
  dashRaw = fs.readFileSync(DASH_PATH);
  dashGzip = zlib.gzipSync(dashRaw, { level: 9 });
} catch (e) {
  console.error('dashboard.html 读取失败:', e.message);
}

// ---------- 发布页与下载 ----------
const REL_DIR = path.join(ROOT, 'release');
const REL_SHOT_DIR = path.join(REL_DIR, 'shot');
const REL_META = path.join(REL_DIR, 'release.json');
const REL_TPL = path.join(__dirname, 'release.html');
fs.mkdirSync(REL_SHOT_DIR, { recursive: true });

let relTplRaw = '';
try {
  relTplRaw = fs.readFileSync(REL_TPL, 'utf8');
} catch (e) {
  console.error('release.html 读取失败:', e.message);
  relTplRaw = '<!doctype html><meta charset=utf-8><h1>release.html 缺失</h1>';
}

function esc(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

async function relMeta() {
  try {
    const o = JSON.parse(await fsp.readFile(REL_META, 'utf8'));
    if (!o || typeof o.apk !== 'string' || !/^[A-Za-z0-9._-]+$/.test(o.apk)) return null;
    return o;
  } catch (e) {
    return null;
  }
}

function humanSize(n) {
  if (!n) return '—';
  if (n >= 1048576) return (n / 1048576).toFixed(1) + ' MB';
  return Math.round(n / 1024) + ' KB';
}

async function releasePage(req, res) {
  const meta = await relMeta();
  let apkSize = 0;
  if (meta) {
    try { apkSize = (await fsp.stat(path.join(REL_DIR, meta.apk))).size; } catch (e) { apkSize = 0; }
  }
  const html = relTplRaw
    .replace(/\{\{VERSION\}\}/g, esc(meta && meta.version ? meta.version : '0.1.0'))
    .replace(/\{\{APK\}\}/g, meta ? meta.apk : 'app-release.apk')
    .replace(/\{\{SIZE\}\}/g, humanSize(apkSize))
    .replace(/\{\{DATE\}\}/g, esc(meta && meta.date ? meta.date : ''));
  const buf = Buffer.from(html);
  const accept = String(req.headers['accept-encoding'] || '');
  const headers = { 'Cache-Control': 'public, max-age=60' };
  if (accept.includes('gzip')) {
    res.writeHead(200, Object.assign({}, headers, {
      'Content-Type': 'text/html; charset=utf-8',
      'Content-Encoding': 'gzip',
      'Content-Length': zlib.gzipSync(buf, { level: 9 }).length
    }));
    res.end(zlib.gzipSync(buf, { level: 9 }));
    return;
  }
  res.writeHead(200, Object.assign({}, headers, {
    'Content-Type': 'text/html; charset=utf-8',
    'Content-Length': buf.length
  }));
  res.end(buf);
}

// 支持 Range（手机断点续传 / 多线程下载器）
async function serveStatic(req, res, file, type, asDownload) {
  let st;
  try { st = await fsp.stat(file); } catch (e) { send(req, res, 404, 'Not Found', 'text/plain; charset=utf-8'); return; }
  if (!st.isFile()) { send(req, res, 404, 'Not Found', 'text/plain; charset=utf-8'); return; }
  const total = st.size;
  const base = {
    'Content-Type': type,
    'Accept-Ranges': 'bytes',
    'Cache-Control': 'public, max-age=3600'
  };
  if (asDownload) base['Content-Disposition'] = 'attachment; filename="' + path.basename(file) + '"';
  const range = req.headers.range;
  if (range && /^bytes=\d*-\d*$/.test(range)) {
    const parts = range.slice(6).split('-');
    let start = parts[0] === '' ? total - Number(parts[1]) : Number(parts[0]);
    let end = (parts[0] === '' || parts[1] === '') ? total - 1 : Number(parts[1]);
    if (!Number.isFinite(start) || start < 0) start = 0;
    if (!Number.isFinite(end) || end >= total) end = total - 1;
    if (start > end) {
      res.writeHead(416, { 'Content-Range': 'bytes */' + total });
      res.end();
      return;
    }
    res.writeHead(206, Object.assign({}, base, {
      'Content-Range': 'bytes ' + start + '-' + end + '/' + total,
      'Content-Length': end - start + 1
    }));
    pipeFile(file,res,{start,end});
    return;
  }
  res.writeHead(200, Object.assign({}, base, { 'Content-Length': total }));
  pipeFile(file,res);
}

const APK_TYPE = 'application/vnd.android.package-archive';

async function dlFile(req, res, name) {
  const safe = decodeURIComponent(name);
  if (!/^[A-Za-z0-9._-]+$/.test(safe)) { send(req, res, 400, 'bad name', 'text/plain; charset=utf-8'); return; }
  await serveStatic(req, res, path.join(REL_DIR, safe), safe.endsWith('.apk') ? APK_TYPE : 'application/octet-stream', true);
}

async function shotFile(req, res, name) {
  const safe = decodeURIComponent(name);
  if (!/^[A-Za-z0-9._-]+$/.test(safe)) { send(req, res, 400, 'bad name', 'text/plain; charset=utf-8'); return; }
  const ext = path.extname(safe).toLowerCase();
  const type = ext === '.png' ? 'image/png' : ext === '.webp' ? 'image/webp' : 'image/jpeg';
  await serveStatic(req, res, path.join(REL_SHOT_DIR, safe), type, false);
}

// ---------- 站点：只展示软件信息，不提供任何安装包下载 ----------
// 目录结构：site/index.html  site/privacy.html  site/terms.html  site/style.css  site/screens/*.jpg
const SITE_DIR = path.join(__dirname, 'site');
const SITE_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon'
};
const siteCache = new Map();

async function siteFile(req, res, rel) {
  if (!/^[A-Za-z0-9._/-]+$/.test(rel) || rel.includes('..')) {
    send(req, res, 404, 'Not Found', 'text/plain; charset=utf-8');
    return;
  }
  const file = path.join(SITE_DIR, rel);
  const type = SITE_TYPES[path.extname(file).toLowerCase()] || 'application/octet-stream';
  let hit = siteCache.get(file);
  if (!hit) {
    let raw;
    try {
      raw = await fsp.readFile(file);
    } catch (e) {
      send(req, res, 404, 'Not Found', 'text/plain; charset=utf-8');
      return;
    }
    hit = { raw, gzip: zlib.gzipSync(raw, { level: 9 }) };
    siteCache.set(file, hit);
  }
  const compressible = /^text\//.test(type) || /^application\/(javascript|json)/.test(type) || type === 'image/svg+xml';
  const accept = String(req.headers['accept-encoding'] || '');
  if (compressible && accept.includes('gzip')) {
    res.writeHead(200, {
      'Content-Type': type,
      'Content-Encoding': 'gzip',
      'Content-Length': hit.gzip.length,
      'Cache-Control': 'public, max-age=300',
      'Vary': 'Accept-Encoding'
    });
    res.end(hit.gzip);
    return;
  }
  res.writeHead(200, {
    'Content-Type': type,
    'Content-Length': hit.raw.length,
    'Cache-Control': 'public, max-age=300'
  });
  res.end(hit.raw);
}

// ---------- 系统指标 ----------
let prevCpu = readCpu();
let prevNet = {rx:0,tx:0,at:Date.now()};

function readCpu() { const cpus=os.cpus();return {idle:cpus.reduce((n,c)=>n+c.times.idle,0),total:cpus.reduce((n,c)=>n+Object.values(c.times).reduce((a,b)=>a+b,0),0)}; }
async function readNet(){const out={rx:0,tx:0,at:Date.now()};try{const text=await fsp.readFile('/proc/net/dev','utf8');for(const line of text.split('\n')){const m=line.match(/^\s*([^:]+):\s*(.+)$/);if(!m||m[1].trim()==='lo')continue;const f=m[2].trim().split(/\s+/).map(Number);out.rx+=f[0]||0;out.tx+=f[8]||0;}}catch{}return out;}

function sampleCpu() {
  const cur = readCpu();
  const dTotal = cur.total - prevCpu.total;
  const dIdle = cur.idle - prevCpu.idle;
  prevCpu = cur;
  if (dTotal <= 0) return 0;
  const pct = (1 - dIdle / dTotal) * 100;
  return Math.max(0, Math.min(100, Math.round(pct * 10) / 10));
}

async function sampleNet() {
  const cur = await readNet();
  const dt = Math.max(1, cur.at - prevNet.at) / 1000;
  const rx = Math.max(0, (cur.rx - prevNet.rx) / dt);
  const tx = Math.max(0, (cur.tx - prevNet.tx) / dt);
  prevNet = cur;
  return { rxBps: Math.round(rx), txBps: Math.round(tx) };
}

async function diskUsage() {
  const s = await fsp.statfs(ROOT);
  const total = s.blocks * s.bsize;
  const avail = s.bavail * s.bsize;
  const used = total - s.bfree * s.bsize;
  return {
    total, used, avail,
    percent: total > 0 ? Math.round((used / total) * 1000) / 10 : 0
  };
}

async function ticketStats() {
  let files = [];
  try { files = (await fsp.readdir(TICKET_DIR)).filter((f) => /^[a-f0-9]{32}\.json$/.test(f)); } catch (e) { files = []; }
  let bytes = 0;
  let today = 0;
  let oldest = 0;
  let newest = 0;
  const now = Date.now();
  const todayStart = new Date(); todayStart.setHours(0, 0, 0, 0);
  for (const f of files) {
    try {
      const st = await fsp.stat(path.join(TICKET_DIR, f));
      bytes += st.size;
      if (st.mtimeMs >= todayStart.getTime()) today++;
      if (!oldest || st.mtimeMs < oldest) oldest = st.mtimeMs;
      if (st.mtimeMs > newest) newest = st.mtimeMs;
    } catch (e) { /* 忽略并发删除 */ }
  }
  return { count: files.length, bytes, today, oldest, newest, now };
}

// ---------- 限流 ----------
const hits = new Map();
function rateLimited(ip) {
  const now = Date.now();
  let e = hits.get(ip);
  if (!e || now > e.reset) { e = { count: 0, reset: now + RATE_WINDOW }; hits.set(ip, e); }
  e.count++;
  if(hits.size>10000)hits.delete(hits.keys().next().value);
  if (hits.size > 5000) {
    for (const [k, v] of hits) if (now > v.reset) hits.delete(k);
  }
  return e.count > RATE_LIMIT;
}

// ---------- 响应工具 ----------
function clientIp(req) {
  const peer=(req.socket.remoteAddress || '').replace('::ffff:','');
  const xf=req.headers['x-fxw-client-ip'];
  return process.env.FXW_TRUST_PROXY==='1' && ['127.0.0.1','::1'].includes(peer) && typeof xf==='string' && require('net').isIP(xf) ? xf : peer;
}

function send(req, res, status, body, type, extraHeaders) {
  const buf = Buffer.isBuffer(body) ? body : Buffer.from(String(body), 'utf8');
  const headers = Object.assign({
    'Content-Type': type || 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff'
  }, extraHeaders || {});
  const accept = String(req.headers['accept-encoding'] || '');
  if (buf.length > 256 && accept.includes('gzip')) {
    const gz = zlib.gzipSync(buf, { level: 6 });
    headers['Content-Encoding'] = 'gzip';
    headers['Content-Length'] = gz.length;
    res.writeHead(status, headers);
    res.end(gz);
    return;
  }
  headers['Content-Length'] = buf.length;
  res.writeHead(status, headers);
  res.end(buf);
}

function json(req, res, status, obj) {
  send(req, res, status, JSON.stringify(obj), 'application/json; charset=utf-8');
}

function checkAuth(req) {
  const h = req.headers.authorization || '';
  if (!h.startsWith('Basic ')) return false;
  let dec = '';
  try { dec = Buffer.from(h.slice(6), 'base64').toString('utf8'); } catch (e) { return false; }
  const i = dec.indexOf(':');
  if (i < 0) return false;
  const u = dec.slice(0, i);
  const p = dec.slice(i + 1);
  const a = Buffer.from(u + ':' + p);
  const b = Buffer.from(ADMIN_USER + ':' + ADMIN_PASS);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function needAuth(req, res) {
  res.writeHead(401, {
    'WWW-Authenticate': 'Basic realm="Fuxiaowai Admin", charset="UTF-8"',
    'Content-Type': 'text/plain; charset=utf-8'
  });
  res.end('Authentication required');
}

function readBody(req, limit) {
  const cap = limit || MAX_BODY;
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    let tooLarge = false;
    req.on('data', (c) => {
      if(tooLarge)return;
      size += c.length;
      if (size > cap) {
        tooLarge = true;
        chunks.length = 0;
        reject(new Error('body too large'));
        req.resume();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject); req.on('aborted',()=>reject(Error('aborted')));
  });
}

// ---------- 反馈 ----------
function fbPath(id) { return path.join(FB_DIR, id + '.json'); }
function validId(id) { return /^[0-9a-f]{16}$/.test(id); }

/** 把 data:image/xxx;base64,... 落盘，返回文件名；不合法的返回 null */
async function saveFeedbackImage(dataUrl, id, idx) {
  if (typeof dataUrl !== 'string') return null;
  const m = dataUrl.match(/^data:image\/(jpeg|jpg|png|webp);base64,([A-Za-z0-9+/=]+)$/);
  if (!m) return null;
  const ext = m[1] === 'jpg' ? 'jpeg' : m[1];
  let buf;
  try { buf = Buffer.from(m[2], 'base64'); } catch (e) { return null; }
  if (buf.length === 0 || buf.length > 1.5 * 1024 * 1024) return null;
  const name = `${id}_${idx}.${ext}`;
  try {
    await atomicWrite(path.join(FB_IMG_DIR, name), buf);
  } catch (e) { return null; }
  return name;
}

async function fbStats() {
  let files = [];
  try { files = (await fsp.readdir(FB_DIR)).filter((f) => /^[a-f0-9]{16}\.json$/.test(f)); } catch (e) { files = []; }
  let today = 0;
  let unread = 0;
  let newest = 0;
  const todayStart = new Date(); todayStart.setHours(0, 0, 0, 0);
  for (const f of files) {
    try {
      const st = await fsp.stat(path.join(FB_DIR, f));
      if (st.mtimeMs >= todayStart.getTime()) today++;
      if (st.mtimeMs > newest) newest = st.mtimeMs;
      const obj = JSON.parse(await fsp.readFile(path.join(FB_DIR, f), 'utf8'));
      if (!obj.read) unread++;
    } catch (e) { /* 忽略并发删除 */ }
  }
  return { total: files.length, today, unread, newest };
}

/** 读出全部反馈，按时间倒序 */
async function listFeedback() {
  let files = [];
  try { files = (await fsp.readdir(FB_DIR)).filter((f) => /^[a-f0-9]{16}\.json$/.test(f)); } catch (e) { files = []; }
  const items = [];
  for (const f of files) {
    try {
      const obj = JSON.parse(await fsp.readFile(path.join(FB_DIR, f), 'utf8'));
      items.push(obj);
    } catch (e) { /* 忽略损坏文件 */ }
  }
  items.sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
  return items;
}

function ticketPath(code) { return path.join(TICKET_DIR, code + '.json'); }
function validCode(c) { return /^[0-9a-f]{32}$/.test(c); }

// ---------- 路由 ----------
const adminConsole = require('./admin-console').createAdminConsole({ ROOT, TICKET_DIR, TTL_MS, PORT, BIND, json, checkAuth, needAuth });
const server = http.createServer(async (req, res) => {
let releaseWrite = null;
try {
  const ip = clientIp(req);
  let url;
  try { url = new URL(req.url, 'http://localhost'); }
  catch { json(req,res,400,{ok:false,msg:'URL 格式错误'});return; }
  const p = url.pathname;
  adminConsole.observe(req, res, url);
  if (await adminConsole.handle(req, res, url)) return;
  try{decodeURIComponent(p);}catch{json(req,res,400,{ok:false,msg:'URL 格式错误'});return;}

  if (p === '/favicon.ico') { res.writeHead(204); res.end(); return; }

  if (p === '/healthz') { send(req, res, 200, 'ok', 'text/plain; charset=utf-8'); return; }

  // 站点与静态资源：放在限流之前，避免图片被 429
  if (p === '/' || p === '/index.html') { await siteFile(req, res, 'index.html'); return; }
  if (p === '/privacy.html' || p === '/terms.html' || p === '/style.css') { await siteFile(req, res, p.slice(1)); return; }
  if (p.startsWith('/screens/')) { await siteFile(req, res, p.slice(1)); return; }
  if (p.startsWith('/img/')) { await siteFile(req, res, p.slice(1)); return; }
  if (p.startsWith('/shot/')) { await shotFile(req, res, p.slice('/shot/'.length)); return; }
  // 安装包下载已关闭：本站只展示软件信息，应用通过应用市场分发
  if (p.startsWith('/download/')) { send(req, res, 404, 'Not Found', 'text/plain; charset=utf-8'); return; }

  if (rateLimited(ip)) { json(req, res, 429, { ok: false, msg: '请求过于频繁，请稍后再试' }); return; }

  if(req.method==='POST' && ['/api/share','/api/feedback','/api/admin/feedback/read'].includes(p)) {
    releaseWrite=admitWrite(req,res);
    if(!releaseWrite)return;
  }

  // --- 公开：创建口令 ---
  if (p === '/api/share' && req.method === 'POST') {
    let raw;
    try { raw = await readBody(req); } catch (e) { json(req, res, 413, { ok: false, msg: '内容过大' }); return; }
    let data;
    try { data = JSON.parse(raw); } catch (e) { json(req, res, 400, { ok: false, msg: '格式错误' }); return; }
    if(!validShare(data)){json(req,res,400,{ok:false,msg:'课表格式错误'});return;}
    const courses = Array.isArray(data.courses) ? data.courses : null;
    if (!courses || courses.length === 0) { json(req, res, 400, { ok: false, msg: '课表为空' }); return; }
    if (courses.length > MAX_COURSES) { json(req, res, 400, { ok: false, msg: '课程数量超过上限' }); return; }
    if(quota('share:'+ip,120)||quota('share:global',600)){json(req,res,429,{ok:false,msg:'请求过于频繁，请稍后再试'});return;}
    if(!await storageAvailable('share')){json(req,res,503,{ok:false,msg:'存储空间暂不可用'});return;}
    const code = crypto.randomBytes(16).toString('hex');
    const payload = {
      code,
      createdAt: Date.now(),
      term: String(data.term || ''),
      week: Number(data.week || 0),
      courses,
      periods: Array.isArray(data.periods) ? data.periods : []
    };
    const text = JSON.stringify(payload);
    try {
      await atomicWrite(ticketPath(code), text);invalidate();
    } catch (e) {
      json(req, res, 500, { ok: false, msg: '写入失败' });
      return;
    }
    console.log(`[share] new code=${code} courses=${courses.length} bytes=${text.length} ip=${ip}`);
    json(req, res, 200, { ok: true, code, expiresAt: payload.createdAt + TTL_MS });
    return;
  }

  // --- 公开：提交反馈（文字 + 最多 3 张图） ---
  if (p === '/api/feedback' && req.method === 'POST') {
    const requestId=req.headers['x-fxw-request-id'];
    if(requestId!==undefined && (typeof requestId!=='string'||!/^[A-Za-z0-9_-]{8,128}$/.test(requestId))){json(req,res,400,{ok:false,msg:'请求标识格式错误'});return;}
    const retryKey=requestId?crypto.createHash('sha256').update(ip+'\0'+requestId).digest('hex'):null;
    if(retryKey && feedbackRequests.has(retryKey)){const prior=feedbackRequests.get(retryKey);if(Date.now()-prior.at<86400000){const result=await prior.promise;json(req,res,result.status,result.body);return;}feedbackRequests.delete(retryKey);}
    // Shared campus networks may submit multiple independent feedback reports.

    if(quota('feedback:'+ip,Number(process.env.FXW_FEEDBACK_PER_MIN||20))||quota('feedback:global',100)){
      res.setHeader('Retry-After','60');json(req,res,429,{ok:false,msg:'反馈过于频繁，请稍后再试',retryAfter:60});return;
    }
    if(!await storageAvailable('feedback')){json(req,res,503,{ok:false,msg:'存储空间暂不可用'});return;}
    let raw;
    try { raw = await readBody(req, MAX_FB_BODY); } catch (e) { json(req, res, 413, { ok: false, msg: '内容过大，图片请少放几张' }); return; }
    let data;
    try { data = JSON.parse(raw); } catch (e) { json(req, res, 400, { ok: false, msg: '格式错误' }); return; }
    if(!data || typeof data!=='object' || Array.isArray(data) || ['text','contact','app','version','device'].some(k=>data[k]!==undefined && typeof data[k]!=='string') || (data.images!==undefined && (!Array.isArray(data.images) || data.images.length>3))){json(req,res,400,{ok:false,msg:'反馈格式错误'});return;}
    const text = String(data.text || '').trim();
    if (text.length === 0 && (!Array.isArray(data.images) || data.images.length===0)) { json(req, res, 400, { ok: false, msg: '反馈内容为空' }); return; }
    if (text.length > MAX_FB_TEXT) { json(req, res, 400, { ok: false, msg: '文字太长了' }); return; }
    if(retryKey && feedbackRequests.has(retryKey)){const result=await feedbackRequests.get(retryKey).promise;json(req,res,result.status,result.body);return;}
    let finishRetry;
    if(retryKey){const promise=new Promise(resolve=>{finishRetry=resolve;});feedbackRequests.set(retryKey,{at:Date.now(),promise});if(feedbackRequests.size>10000)feedbackRequests.delete(feedbackRequests.keys().next().value);}
    const id = crypto.randomBytes(8).toString('hex');
    const images = [];
    const rawImages = Array.isArray(data.images) ? data.images.slice(0, MAX_FB_IMAGES) : [];
    for(const [i,u] of rawImages.entries()){
      const name = await saveFeedbackImage(u, id, i);
      if (name) images.push(name);
      else {for(const n of images)await fsp.unlink(path.join(FB_IMG_DIR,n)).catch(()=>{});const body={ok:false,msg:"图片格式错误或无法保存"};if(finishRetry)finishRetry({status:400,body});json(req,res,400,body);return;}
    }
    if(!text && !images.length){const body={ok:false,msg:'反馈内容为空'};if(finishRetry)finishRetry({status:400,body});json(req,res,400,body);return;}
    const payload = {
      id,
      ...(retryKey ? {requestKey:retryKey} : {}),
      createdAt: Date.now(),
      text,
      contact: String(data.contact || '').slice(0, 120),
      images,
      app: String(data.app || '').slice(0, 32),
      version: String(data.version || '').slice(0, 32),
      device: String(data.device || '').slice(0, 120),
      ip,
      read: false
    };
    try {
      await atomicWrite(fbPath(id), JSON.stringify(payload));invalidate();
    } catch (e) {
      if(finishRetry)finishRetry({status:500,body:{ok:false,msg:'写入失败'}});
      for(const name of images)await fsp.unlink(path.join(FB_IMG_DIR,name)).catch(()=>{});
      json(req, res, 500, { ok: false, msg: '写入失败' });
      return;
    }
    console.log(`[feedback] id=${id} len=${text.length} imgs=${images.length} ip=${ip}`);
    if(finishRetry)finishRetry({status:200,body:{ok:true,id}});
    json(req, res, 200, { ok: true, id });
    return;
  }

  // --- 公开：读取口令 ---
  if (p.startsWith('/api/share/') && req.method === 'GET') {
    const code = p.slice('/api/share/'.length).toLowerCase();
    if (!validCode(code)) { json(req, res, 400, { ok: false, msg: '口令格式不正确' }); return; }
    const file = ticketPath(code);
    let text;
    try { text = await fsp.readFile(file, 'utf8'); } catch (e) { json(req, res, 404, { ok: false, msg: '口令不存在或已过期' }); return; }
    let obj;
    try { obj = JSON.parse(text); } catch (e) { json(req, res, 500, { ok: false, msg: '数据损坏' }); return; }
    if (!obj || !Number.isFinite(obj.createdAt)) {json(req,res,500,{ok:false,msg:'数据损坏'});return;}
    if (Date.now() - obj.createdAt > TTL_MS) {
      try { await fsp.unlink(file); } catch (e) { /* ignore */ }
      json(req, res, 404, { ok: false, msg: '口令已过期' });
      return;
    }
    json(req, res, 200, Object.assign({ ok: true }, obj));
    return;
  }

  // --- 管理端 ---
  if (p === '/admin' || p === '/admin/' ) {
    if (!checkAuth(req)) { needAuth(req, res); return; }
    const accept = String(req.headers['accept-encoding'] || '');
    const headers = { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' };
    if (dashGzip && accept.includes('gzip')) {
      headers['Content-Encoding'] = 'gzip';
      headers['Content-Length'] = dashGzip.length;
      res.writeHead(200, headers);
      res.end(dashGzip);
    } else {
      headers['Content-Length'] = dashRaw.length;
      res.writeHead(200, headers);
      res.end(dashRaw);
    }
    return;
  }

  if (p.startsWith('/api/admin/')) {
    if (!checkAuth(req)) { needAuth(req, res); return; }

    if (p === '/api/admin/stats') {
      const cpu = sampleCpu();
      const net = await sampleNet();
      const disk = await cached('disk',diskUsage,5000);
      const t = await cached('tickets',ticketStats);
      const load = os.loadavg();
      json(req, res, 200, {
        ok: true,
        time: Date.now(),
        uptimeSec: Math.round(process.uptime()),
        host: {
          hostname: os.hostname(),
          cores: os.cpus().length,
          load1: Math.round(load[0] * 100) / 100,
          load5: Math.round(load[1] * 100) / 100,
          load15: Math.round(load[2] * 100) / 100
        },
        cpu: { percent: cpu },
        mem: {
          total: os.totalmem(),
          free: os.freemem(),
          used: os.totalmem() - os.freemem(),
          percent: Math.round(((os.totalmem() - os.freemem()) / os.totalmem()) * 1000) / 10
        },
        disk,
        net,
        proc: {
          rss: process.memoryUsage().rss,
          heap: process.memoryUsage().heapUsed
        },
        tickets: t,
        feedback: await cached('feedback',fbStats),
        limits: { ratePerMin: RATE_LIMIT, maxBody: MAX_BODY, ttlDays: Math.round(TTL_MS / 86400000), maxCourses: MAX_COURSES }
      });
      return;
    }

    if (p === '/api/admin/tickets' && req.method === 'GET') {
      const limit = Math.min(200, Math.max(1, (Number(url.searchParams.get('limit')) || 50)));
      const rows = await cached('ticket-list',async()=>{
      let files = [];
      try { files = (await fsp.readdir(TICKET_DIR)).filter((f) => /^[a-f0-9]{32}\.json$/.test(f)); } catch (e) { files = []; }
      const rows = [];
      for (const f of files) {
        const full = path.join(TICKET_DIR, f);
        try {
          const st = await fsp.stat(full);
          let meta = {};
          try {
            const txt = await fsp.readFile(full, 'utf8');
            const o = JSON.parse(txt);
            meta = { term: o.term, week: o.week, count: (o.courses || []).length, createdAt: o.createdAt };
          } catch (e) { meta = {}; }
          rows.push({
            code: f.replace(/\.json$/, ''),
            size: st.size,
            mtime: st.mtimeMs,
            term: meta.term || '',
            week: meta.week || 0,
            count: meta.count || 0,
            createdAt: meta.createdAt || st.mtimeMs
          });
        } catch (e) { /* ignore */ }
      }
      rows.sort((a, b) => b.createdAt - a.createdAt);return rows;});
      json(req, res, 200, { ok: true, total: rows.length, rows: rows.slice(0, limit) });
      return;
    }

    if (p.startsWith('/api/admin/tickets/') && req.method === 'DELETE') {
      const code = p.slice('/api/admin/tickets/'.length).toLowerCase();
      if (!validCode(code)) { json(req, res, 400, { ok: false, msg: '口令格式不正确' }); return; }
      try {
        await fsp.unlink(ticketPath(code));invalidate();
        console.log(`[admin] delete code=${code} ip=${ip}`);
        json(req, res, 200, { ok: true });
      } catch (e) {
        json(req, res, 404, { ok: false, msg: '不存在' });
      }
      return;
    }

    // ---- 反馈 ----
    if (p === '/api/admin/feedback' && req.method === 'GET') {
      const offset = Math.max(0, (Number(url.searchParams.get('offset')) || 0));
      const limit = Math.min(100, Math.max(1, (Number(url.searchParams.get('limit')) || 50)));
      const all = await cached('feedback-list',listFeedback);
      const rows = all.slice(offset, offset + limit).map((o) => ({
        id: o.id,
        createdAt: o.createdAt,
        text: o.text,
        contact: o.contact,
        app: o.app,
        version: o.version,
        device: o.device,
        ip: o.ip,
        read: !!o.read,
        images: (o.images || []).map((n) => `/api/admin/feedback/img/${n}`)
      }));
      json(req, res, 200, { ok: true, total: all.length, offset, limit, rows });
      return;
    }

    if (p.startsWith('/api/admin/feedback/img/') && req.method === 'GET') {
      const name = decodeURIComponent(p.slice('/api/admin/feedback/img/'.length));
      if (!/^[0-9a-f]{16}_[0-9]{1,2}\.(jpeg|png|webp)$/.test(name)) {
        json(req, res, 400, { ok: false, msg: '文件名不合法' });
        return;
      }
      const full = path.join(FB_IMG_DIR, name);
      let buf;
      try { buf = await fsp.readFile(full); } catch (e) { json(req, res, 404, { ok: false, msg: '图片不存在' }); return; }
      const type = name.endsWith('.png') ? 'image/png' : (name.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
      send(req, res, 200, buf, type, { 'Cache-Control': 'private, max-age=3600' });
      return;
    }

    if (p === '/api/admin/feedback/read' && req.method === 'POST') {
      let raw;
      try { raw = await readBody(req); } catch (e) { json(req, res, 413, { ok: false, msg: '内容过大' }); return; }
      let ids = [];
      try {const o=JSON.parse(raw);ids=o && Array.isArray(o.ids)?o.ids.slice(0,100):[]; } catch (e) { ids = []; }
      let n = 0;
      for (const id of ids) {
        if (!validId(String(id))) continue;
        const full = fbPath(String(id));
        try {
          const o = JSON.parse(await fsp.readFile(full, 'utf8'));
          if (!o.read) { o.read = true; await atomicWrite(full,JSON.stringify(o));invalidate(); n++; }
        } catch (e) { /* ignore */ }
      }
      json(req, res, 200, { ok: true, updated: n });
      return;
    }

    if (p.startsWith('/api/admin/feedback/') && req.method === 'DELETE') {
      const id = p.slice('/api/admin/feedback/'.length);
      if (!validId(id)) { json(req, res, 400, { ok: false, msg: 'id 不合法' }); return; }
      let imgs = [];
      try {
        const o = JSON.parse(await fsp.readFile(fbPath(id), 'utf8'));
        imgs = o.images || [];
      } catch (e) { /* 文件可能已删 */ }
      try { await fsp.unlink(fbPath(id));invalidate(); } catch (e) { /* ignore */ }
      for (const n of imgs) { if(typeof n!=='string'||! /^[0-9a-f]{16}_[0-9]{1,2}\.(jpeg|png|webp)$/.test(n))continue;try { await fsp.unlink(path.join(FB_IMG_DIR, n)); } catch (e) { /* ignore */ } }
      console.log(`[admin] delete feedback=${id} ip=${ip}`);
      json(req, res, 200, { ok: true });
      return;
    }
  }

  send(req, res, 404, 'Not Found', 'text/plain; charset=utf-8');
} catch(e) {console.error('request failed',e.code || e.name);if(!res.headersSent && !res.destroyed)json(req,res,500,{ok:false,msg:'服务暂时不可用'});else res.destroy();}
finally {if(releaseWrite)releaseWrite();}
});

server.keepAliveTimeout = 15000;
server.headersTimeout = 20000;
server.requestTimeout = 30000;

async function start(){
 await cleanup();
 for(const o of await listFeedback()){
  if(o && /^[a-f0-9]{64}$/.test(o.requestKey||'') && validId(o.id) && Date.now()-o.createdAt<86400000){
   feedbackRequests.set(o.requestKey,{at:o.createdAt,promise:Promise.resolve({status:200,body:{ok:true,id:o.id}})});
  }
 }
 server.listen(PORT,BIND,()=>{console.log(`fxw share service listening on ${BIND}:${server.address().port}`);});
}
start().catch(e=>{console.error('startup failed:',e.code||e.name);process.exit(1);});

// Startup and hourly retention, including orphaned feedback images.
async function cleanup(){
 const now=Date.now();
 for(const [dir,ttl] of [[TICKET_DIR,TTL_MS],[FB_DIR,365*86400000],[FB_IMG_DIR,365*86400000]]){
  for(const ent of await fsp.readdir(dir,{withFileTypes:true})){
   if(!ent.isFile())continue;const file=path.join(dir,ent.name);
   try{const st=await fsp.stat(file);let timestamp=st.mtimeMs;
    if(ent.name.endsWith('.json')){try{const o=JSON.parse(await fsp.readFile(file,'utf8'));if(Number.isFinite(o.createdAt))timestamp=o.createdAt;}catch{}}
    if(now-timestamp>ttl){await fsp.unlink(file);if(dir===FB_DIR){const prefix=ent.name.replace(/\.json$/,'')+'_';for(const name of await fsp.readdir(FB_IMG_DIR))if(name.startsWith(prefix))await fsp.unlink(path.join(FB_IMG_DIR,name)).catch(()=>{});}}
   }catch{}
  }
 }
 for(const [k,v] of feedbackRequests)if(now-v.at>86400000)feedbackRequests.delete(k);
 for(const [k,v] of writeLimits)if(now>v.until)writeLimits.delete(k);
 invalidate();
}
setInterval(()=>cleanup().catch(e=>console.error('cleanup',e.code)),3600000).unref();

process.on('SIGTERM', () => { server.close(() => process.exit(0)); });
process.on('SIGINT', () => { server.close(() => process.exit(0)); });
