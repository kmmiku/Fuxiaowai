import socket from '@ohos.net.socket';
import util from '@ohos.util';
import zlib from '@ohos.zlib';

export interface RawResponse {
  status: number;
  location: string;
  setCookie: string;
  body: string;
}
interface ParsedResponse {
  response: RawResponse;
  complete: boolean;
  bytes?: Uint8Array;
  encoding?: string;
}

/** One HTTP hop over port 80. HTTPS is deliberately rejected rather than downgraded. */
export class RawHttp {
  private static readonly MAX_BYTES: number = 8 * 1024 * 1024;
  static async get(host: string, path: string, cookie: string, timeoutMs: number = 15000): Promise<RawResponse> {
    return RawHttp.send('GET', host, path, cookie, '', timeoutMs);
  }
  static async postForm(host: string, path: string, cookie: string, form: string,
    timeoutMs: number = 15000): Promise<RawResponse> {
    return RawHttp.send('POST', host, path, cookie, form, timeoutMs);
  }

  private static async send(method: string, host: string, path: string, cookie: string,
    form: string, timeoutMs: number): Promise<RawResponse> {
    if (!/^[a-zA-Z0-9.-]+$/.test(host) || !path.startsWith('/') || /[\r\n ]/.test(path) ||
      /[\r\n]/.test(cookie) || !Number.isFinite(timeoutMs) || timeoutMs <= 0) {
      throw new Error('Invalid raw HTTP request');
    }
    const tcp: socket.TCPSocket = socket.constructTCPSocketInstance();
    return new Promise<RawResponse>((resolve, reject) => {
      let bytes: Uint8Array = new Uint8Array(0);
      let settled: boolean = false;
      let readingDone: boolean = false;
      let released: boolean = false;
      const deadline: number = Date.now() + timeoutMs;
      let timer: number = -1;
      const cleanup = (stopTimer: boolean = true): void => {
        if (stopTimer) { clearTimeout(timer); }
        if (released) { return; }
        released = true;
        tcp.off('message'); tcp.off('close'); tcp.off('error');
        try { tcp.close().catch(() => {}); } catch (_) {}
      };
      const fail = (error: Error): void => {
        if (settled) { return; }
        settled = true; cleanup(); reject(error);
      };
      const inspect = (closed: boolean): void => {
        if (settled || readingDone) { return; }
        try {
          const parsed: ParsedResponse = RawHttp.parse(bytes, closed);
          if (parsed.complete) {
            readingDone = true;
            cleanup(false);
            RawHttp.decode(parsed, deadline).then((response: RawResponse) => {
              if (!settled) { settled = true; cleanup(); resolve(response); }
            }).catch(() => { fail(new Error('HTTP response decompression failed')); });
          }
          else if (closed) { fail(new Error('Incomplete HTTP response')); }
        } catch (_) { fail(new Error('Invalid or unsupported HTTP response')); }
      };
      tcp.on('message', (info: socket.SocketMessageInfo) => {
        if (settled) { return; }
        const next: Uint8Array = new Uint8Array(info.message);
        if (bytes.length + next.length > RawHttp.MAX_BYTES) { fail(new Error('HTTP response too large')); return; }
        const joined: Uint8Array = new Uint8Array(bytes.length + next.length);
        joined.set(bytes); joined.set(next, bytes.length); bytes = joined;
        inspect(false);
      });
      tcp.on('close', () => { inspect(true); });
      tcp.on('error', () => { fail(new Error('HTTP socket error')); });
      timer = setTimeout(() => { fail(new Error('HTTP request timed out')); }, timeoutMs);
      const encoder: util.TextEncoder = new util.TextEncoder();
      const length: number = form.length > 0 ? encoder.encodeInto(form).length : 0;
      let request: string = `${method} ${path} HTTP/1.1\r\nHost: ${host}\r\n`;
      request += 'User-Agent: Mozilla/5.0 (Linux; HarmonyOS 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36\r\n';
      request += 'Accept: text/html,application/json,*/*;q=0.8\r\nAccept-Language: zh-CN,zh;q=0.9\r\nAccept-Encoding: gzip, deflate\r\n';
      if (method === 'POST') { request += 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8\r\n'; }
      request += `Content-Length: ${length}\r\n`;
      if (cookie.length > 0) { request += `Cookie: ${cookie}\r\n`; }
      request += 'Connection: close\r\n\r\n' + form;
      tcp.connect({ address: { address: host, port: 80 }, timeout: timeoutMs }).then(() => {
        if (!settled) { return tcp.send({ data: request }); }
        return Promise.resolve();
      }).catch(() => { fail(new Error('HTTP connection or send failed')); });
    });
  }

  static pathOf(url: string): string {
    if (url.indexOf('://') < 0) { return url.startsWith('/') ? url.split('#')[0] : '/' + url.split('#')[0]; }
    RawHttp.hostOf(url);
    const remainder: string = url.substring(url.indexOf('://') + 3);
    const start: number = remainder.search(/[/?#]/);
    if (start < 0 || remainder.charAt(start) === '#') { return '/'; }
    const path: string = remainder.substring(start).split('#')[0];
    return path.startsWith('?') ? '/' + path : path;
  }
  static hostOf(url: string): string {
    let value: string = url;
    const scheme: number = url.indexOf('://');
    if (scheme >= 0) {
      if (url.substring(0, scheme).toLowerCase() !== 'http') { throw new Error('Raw HTTP supports only http'); }
      value = url.substring(scheme + 3);
    }
    const authority: string = value.split(/[/?#]/)[0];
    const host: string = authority.replace(/:80$/, '');
    if (!/^[a-zA-Z0-9.-]+$/.test(host)) { throw new Error('Unsupported HTTP authority'); }
    return host;
  }
  static sleep(ms: number): Promise<void> { return new Promise<void>((resolve) => { setTimeout(resolve, ms); }); }

  private static ascii(bytes: Uint8Array, start: number, end: number): string {
    let out: string = '';
    for (let i = start; i < end; i++) { out += String.fromCharCode(bytes[i]); }
    return out;
  }
  private static find(bytes: Uint8Array, start: number, marker: string): number {
    for (let i = start; i <= bytes.length - marker.length; i++) {
      let match: boolean = true;
      for (let j = 0; j < marker.length; j++) { if (bytes[i + j] !== marker.charCodeAt(j)) { match = false; break; } }
      if (match) { return i; }
    }
    return -1;
  }
  private static parse(bytes: Uint8Array, closed: boolean): ParsedResponse {
    const response: RawResponse = { status: 0, location: '', setCookie: '', body: '' };
    const pending: ParsedResponse = { response: response, complete: false };
    const end: number = RawHttp.find(bytes, 0, '\r\n\r\n');
    if (end < 0) { if (bytes.length > 65536) { throw new Error('Headers too large'); } return pending; }
    if (end > 65536) { throw new Error('Headers too large'); }
    const lines: string[] = RawHttp.ascii(bytes, 0, end).split('\r\n');
    if (!/^HTTP\/1\.[01] [1-5][0-9]{2}( |$)/.test(lines[0])) { throw new Error('Bad status'); }
    response.status = Number(lines[0].split(' ')[1]);
    const headers: Record<string, string> = {};
    const cookies: string[] = [];
    for (let i = 1; i < lines.length; i++) {
      const colon: number = lines[i].indexOf(':');
      if (colon <= 0) { throw new Error('Bad header'); }
      const name: string = lines[i].substring(0, colon).toLowerCase();
      const value: string = lines[i].substring(colon + 1).trim();
      if (name === 'set-cookie') { cookies.push(value); }
      if (headers[name] !== undefined && (name === 'content-length' || name === 'transfer-encoding')) {
        throw new Error('Duplicate framing');
      }
      headers[name] = value;
    }
    const start: number = end + 4;
    if (response.status >= 100 && response.status < 200) {
      if (response.status === 101) { throw new Error('Upgrade unsupported'); }
      return RawHttp.parse(bytes.slice(start), closed);
    }
    response.location = headers['location'] ?? '';
    response.setCookie = cookies.join('\n');
    if (response.status === 204 || response.status === 304) { return { response: response, complete: true }; }
    const coding: string = (headers['content-encoding'] ?? 'identity').toLowerCase();
    if (coding !== 'identity' && coding !== 'gzip' && coding !== 'deflate') { throw new Error('Unsupported content encoding'); }
    let body: Uint8Array = new Uint8Array(0);
    const transfer: string = (headers['transfer-encoding'] ?? '').toLowerCase();
    const lengthText: string = headers['content-length'];
    if (transfer.length > 0) {
      if (transfer !== 'chunked' || lengthText !== undefined) { throw new Error('Unsupported framing'); }
      const chunks: Uint8Array[] = [];
      let pos: number = start;
      let total: number = 0;
      while (true) {
        const lineEnd: number = RawHttp.find(bytes, pos, '\r\n');
        if (lineEnd < 0) { return pending; }
        const sizeText: string = RawHttp.ascii(bytes, pos, lineEnd).split(';')[0];
        if (!/^[0-9a-fA-F]+$/.test(sizeText)) { throw new Error('Bad chunk'); }
        const size: number = parseInt(sizeText, 16);
        if (!Number.isSafeInteger(size) || size > RawHttp.MAX_BYTES) { throw new Error('Chunk too large'); }
        pos = lineEnd + 2;
        if (size === 0) {
          if (bytes.length < pos + 2) { return pending; }
          if (RawHttp.ascii(bytes, pos, pos + 2) !== '\r\n' && RawHttp.find(bytes, pos, '\r\n\r\n') < 0) { return pending; }
          break;
        }
        if (bytes.length < pos + size + 2) { return pending; }
        if (RawHttp.ascii(bytes, pos + size, pos + size + 2) !== '\r\n') { throw new Error('Bad chunk delimiter'); }
        chunks.push(bytes.slice(pos, pos + size)); total += size; pos += size + 2;
      }
      body = new Uint8Array(total);
      let offset: number = 0;
      chunks.forEach((chunk: Uint8Array) => { body.set(chunk, offset); offset += chunk.length; });
    } else if (lengthText !== undefined) {
      if (!/^\d+$/.test(lengthText)) { throw new Error('Bad length'); }
      const length: number = Number(lengthText);
      if (!Number.isSafeInteger(length) || length > RawHttp.MAX_BYTES) { throw new Error('Body too large'); }
      if (bytes.length - start < length) { return pending; }
      body = bytes.slice(start, start + length);
    } else {
      if (!closed) { return pending; }
      body = bytes.slice(start);
    }
    return { response: response, complete: true, bytes: body, encoding: coding };
  }
  private static async decode(parsed: ParsedResponse, deadline: number): Promise<RawResponse> {
    if (parsed.bytes === undefined) { return parsed.response; }
    let body: Uint8Array = parsed.bytes;
    if (parsed.encoding === 'gzip' || parsed.encoding === 'deflate') {
      body = await RawHttp.inflate(body, parsed.encoding === 'gzip' ? 31 : 15, deadline);
    }
    if (Date.now() >= deadline) { throw new Error('HTTP request timed out'); }
    parsed.response.body = util.TextDecoder.create('utf-8').decodeToString(body);
    return parsed.response;
  }

  private static async inflate(input: Uint8Array, windowBits: number, deadline: number): Promise<Uint8Array> {
    const zip: zlib.Zip = zlib.createZipSync();
    let stream: zlib.ZStream = {};
    let initialized: boolean = false;
    const chunks: Uint8Array[] = [];
    let total: number = 0;
    try {
      if (await zip.inflateInit2(stream, windowBits) !== zlib.ReturnStatus.OK) { throw new Error('Inflater init failed'); }
      initialized = true;
      stream.nextIn = input.buffer as ArrayBuffer;
      stream.availableIn = input.length;
      while (true) {
        if (Date.now() >= deadline) { throw new Error('HTTP request timed out'); }
        const before: number = stream.availableIn ?? 0;
        const output: ArrayBuffer = new ArrayBuffer(65536);
        stream.nextOut = output;
        stream.availableOut = output.byteLength;
        const status: zlib.ReturnStatus = await zip.inflate(stream, zlib.CompressFlushMode.NO_FLUSH);
        stream = await zip.getZStream();
        const remainingOut: number = stream.availableOut ?? -1;
        const remainingIn: number = stream.availableIn ?? -1;
        if (remainingOut < 0 || remainingOut > output.byteLength || remainingIn < 0 || remainingIn > before) {
          throw new Error('Invalid inflater state');
        }
        const produced: number = output.byteLength - remainingOut;
        total += produced;
        if (total > RawHttp.MAX_BYTES) { throw new Error('Decoded HTTP response too large'); }
        if (produced > 0) { chunks.push(new Uint8Array(output.slice(0, produced))); }
        if (status === zlib.ReturnStatus.STREAM_END) {
          if (remainingIn !== 0) { throw new Error('Trailing compressed data'); }
          break;
        }
        if (status !== zlib.ReturnStatus.OK || (produced === 0 && remainingIn === before)) {
          throw new Error('Incomplete compressed response');
        }
      }
      const body: Uint8Array = new Uint8Array(total);
      let offset: number = 0;
      chunks.forEach((chunk: Uint8Array) => { body.set(chunk, offset); offset += chunk.length; });
      return body;
    } finally {
      if (initialized) { await zip.inflateEnd(stream).catch(() => {}); }
    }
  }

}
