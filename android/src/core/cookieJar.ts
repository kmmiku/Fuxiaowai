interface Cookie {name:string;value:string;domain:string;path:string;hostOnly:boolean;secure:boolean;expires:number}
const asUrl = (value: string) => new URL(value.includes('://') ? value : `http://${value}/`);
export class Jar {
  private cookies = new Map<string, Cookie>();
  clear(): void { this.cookies.clear(); }
  absorb(headers: Record<string, unknown> | undefined, address: string): void {
    const raw = Object.entries(headers ?? {}).find(([k]) => k.toLowerCase() === 'set-cookie')?.[1];
    if (!raw) return;
    const url = asUrl(address);
    for (const line of Array.isArray(raw) ? raw : [String(raw)]) {
      for (const piece of String(line).split(/,(?=\s*[^;,=\s]+\s*=)/)) {
        const parts = piece.split(';').map(p => p.trim());
        const eq = parts[0].indexOf('='); if (eq <= 0) continue;
        const cookie: Cookie = {name:parts[0].slice(0,eq),value:parts[0].slice(eq+1),domain:url.hostname,
          path:url.pathname.slice(0,url.pathname.lastIndexOf('/')+1) || '/',hostOnly:true,secure:false,expires:Infinity};
        let maxAge: number | undefined;
        for (const part of parts.slice(1)) {
          const pos = part.indexOf('='), name = (pos < 0 ? part : part.slice(0,pos)).toLowerCase();
          const value = pos < 0 ? '' : part.slice(pos+1);
          if (name === 'domain') { cookie.domain=value.replace(/^\./,'').toLowerCase(); cookie.hostOnly=false; }
          if (name === 'path' && value.startsWith('/')) cookie.path=value;
          if (name === 'secure') cookie.secure=true;
          if (name === 'expires' && Number.isFinite(Date.parse(value))) cookie.expires=Date.parse(value);
          if (name === 'max-age' && /^-?\d+$/.test(value)) maxAge=Number(value);
        }
        // School hosts are fixed; broad parent-domain cookies are unnecessary and unsafe.
        if (cookie.domain !== url.hostname) continue;
        if (maxAge !== undefined) cookie.expires=Date.now()+maxAge*1000;
        const key=JSON.stringify([cookie.domain,cookie.path,cookie.name]);
        if (cookie.expires <= Date.now()) this.cookies.delete(key); else this.cookies.set(key,cookie);
      }
    }
  }
  importHeader(header:string, host:string): void {
    for (const piece of header.split(';')) {
      const eq=piece.indexOf('='); if(eq<1)continue;
      this.absorb({'set-cookie':`${piece.trim()}; Path=/`},host);
    }
  }
  header(address:string): string {
    const url=asUrl(address), allPaths=!address.includes('://');
    const out: Cookie[]=[];
    for (const [key,c] of this.cookies) {
      if(c.expires<=Date.now()){this.cookies.delete(key);continue;}
      const domain=c.hostOnly ? url.hostname===c.domain : url.hostname===c.domain||url.hostname.endsWith(`.${c.domain}`);
      const path=url.pathname===c.path||url.pathname.startsWith(c.path.endsWith('/')?c.path:`${c.path}/`);
      if(domain&&(allPaths||path)&&(!c.secure||url.protocol==='https:'))out.push(c);
    }
    return out.sort((a,b)=>b.path.length-a.path.length).map(c=>`${c.name}=${c.value}`).join('; ');
  }
  get(name:string,host:string): string {
    return this.header(host).split('; ').find(p=>p.startsWith(`${name}=`))?.slice(name.length+1)??'';
  }
  expiry(host:string): number {
    return Math.min(Date.now()+24*60*60*1000,...[...this.cookies.values()].filter(c=>c.domain===host).map(c=>c.expires));
  }
}
