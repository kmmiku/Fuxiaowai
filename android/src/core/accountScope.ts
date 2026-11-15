import { getRaw } from './persistence';
/** A lifecycle revision, independent of whether the cookie is authenticated. */
let revision = 0;
export function invalidateAccount(): void { revision++; }
export function accountToken(): number { return revision; }
export function accountUser(): string {
  try { return JSON.parse(getRaw('fxw_credential') || 'null')?.user || ''; }
  catch { return ''; }
}
export function isCurrent(token: number, user?: string): boolean {
  return token === revision && (user === undefined || accountUser() === user);
}
export function accountKey(user: string): string {
  // Keep existing alphanumeric account keys, encode everything else without collisions.
  return user ? encodeURIComponent(user).replace(/_/g, '%5F') : 'anon';
}
let tail: Promise<unknown> = Promise.resolve();
let runningToken: number | undefined;
export function schoolRequestToken(): number { return runningToken ?? accountToken(); }
export function schoolTask<T>(token: number, action: () => Promise<T>): Promise<T> {
  const next = tail.then(async () => {
    if (!isCurrent(token)) throw new Error('账号状态已改变，请重试');
    runningToken=token;
    try { return await action(); } finally { runningToken=undefined; }
  });
  tail = next.catch(() => undefined);
  return next;
}
