interface StoredCookie {
  name: string;
  value: string;
  domain: string;
  hostOnly: boolean;
  path: string;
  secure: boolean;
  expires: number;
}

/** Cookie scope is checked on both receipt and transmission. */
export class CookieJar {
  private cookies: StoredCookie[] = [];

  absorb(setCookie: string, host: string, requestPath: string = '/'): void {
    const origin: string = host.toLowerCase();
    setCookie.split(/\r?\n/).forEach((line: string) => {
      if (line.indexOf('\t') >= 0) {
        this.absorbNetscape(line, origin);
        return;
      }
      const parts: string[] = line.split(';');
      const eq: number = parts[0].indexOf('=');
      if (eq <= 0) { return; }
      const slash: number = requestPath.split('?')[0].lastIndexOf('/');
      const item: StoredCookie = { name: parts[0].substring(0, eq).trim(),
        value: parts[0].substring(eq + 1).trim(), domain: origin, hostOnly: true,
        path: slash > 0 ? requestPath.substring(0, slash) : '/', secure: false, expires: 0 };
      let maxAge: string = '';
      parts.slice(1).forEach((part: string) => {
        const pos: number = part.indexOf('=');
        const key: string = (pos < 0 ? part : part.substring(0, pos)).trim().toLowerCase();
        const value: string = pos < 0 ? '' : part.substring(pos + 1).trim();
        if (key === 'domain') { item.domain = value.toLowerCase().replace(/^\./, ''); item.hostOnly = false; }
        if (key === 'path' && value.startsWith('/')) { item.path = value; }
        if (key === 'secure') { item.secure = true; }
        if (key === 'expires') { const date: number = Date.parse(value); if (!isNaN(date)) { item.expires = date <= 0 ? 1 : date; } }
        if (key === 'max-age' && /^-?\d+$/.test(value)) { maxAge = value; }
      });
      if (maxAge.length > 0) { item.expires = Number(maxAge) <= 0 ? 1 : Date.now() + Number(maxAge) * 1000; }
      if (CookieJar.domainMatches(origin, item.domain)) { this.store(item); }
    });
  }

  absorbHeader(header: string, host: string): void {
    header.split(';').forEach((part: string) => { this.absorb(part + '; Path=/', host); });
  }

  private absorbNetscape(line: string, host: string): void {
    const cols: string[] = line.replace(/^#HttpOnly_/, '').split('\t');
    if (cols.length < 7) { return; }
    const domain: string = cols[0].toLowerCase().replace(/^\./, '');
    if (!CookieJar.domainMatches(host, domain)) { return; }
    const seconds: number = Number(cols[4]);
    if (!Number.isFinite(seconds)) { return; }
    this.store({ name: cols[5], value: cols[6], domain: domain, hostOnly: cols[1].toUpperCase() !== 'TRUE',
      path: cols[2].startsWith('/') ? cols[2] : '/', secure: cols[3].toUpperCase() === 'TRUE',
      expires: seconds === 0 ? 0 : seconds * 1000 });
  }

  private static domainMatches(host: string, domain: string): boolean {
    return domain.length > 0 && (host === domain || host.endsWith('.' + domain));
  }

  private store(item: StoredCookie): void {
    this.cookies = this.cookies.filter((old: StoredCookie) =>
      !(old.name === item.name && old.domain === item.domain && old.path === item.path));
    if (item.name.length > 0 && !/[\s;\r\n]/.test(item.name) && !/[\r\n]/.test(item.value) &&
      (item.expires === 0 || item.expires > Date.now())) { this.cookies.push(item); }
  }

  header(host: string, path: string = '/', secure: boolean = false): string {
    const target: string = path.split('?')[0];
    this.cookies = this.cookies.filter((item: StoredCookie) => item.expires === 0 || item.expires > Date.now());
    return this.cookies.filter((item: StoredCookie) =>
      (item.hostOnly ? host.toLowerCase() === item.domain : CookieJar.domainMatches(host.toLowerCase(), item.domain)) &&
      (!item.secure || secure) && (target === item.path ||
      (target.startsWith(item.path) && (item.path.endsWith('/') || target.charAt(item.path.length) === '/'))))
      .sort((a: StoredCookie, b: StoredCookie) => b.path.length - a.path.length)
      .map((item: StoredCookie) => `${item.name}=${item.value}`).join('; ');
  }

  has(key: string, host: string): boolean {
    return this.cookies.some((item: StoredCookie) => item.name === key &&
      (item.hostOnly ? item.domain === host.toLowerCase() : CookieJar.domainMatches(host.toLowerCase(), item.domain)) &&
      (item.expires === 0 || item.expires > Date.now()));
  }

  hosts(): string[] { return Array.from(new Set<string>(this.cookies.map((item: StoredCookie) => item.domain))); }
  clear(): void { this.cookies = []; }
}
