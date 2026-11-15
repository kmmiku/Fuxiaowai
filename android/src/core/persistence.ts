/** Synchronous localStorage transactions. A durable undo journal brackets multi-key writes. */
const JOURNAL = 'fxw_storage_transaction_v1';
let pending: Map<string, string | null> | null = null;
export function getRaw(key: string): string | null {
  return pending?.has(key) ? pending.get(key)! : localStorage.getItem(key);
}
export function setRaw(key: string, value: string): void {
  if (pending) pending.set(key, value); else localStorage.setItem(key, value);
}
export function removeRaw(key: string): void {
  if (pending) pending.set(key, null); else localStorage.removeItem(key);
}
export function recoverStorage(): void {
  const raw = localStorage.getItem(JOURNAL);
  if (!raw) return;
  const entries: [string, string | null][] = JSON.parse(raw);
  if (!Array.isArray(entries) || entries.some(e => !Array.isArray(e) || e.length !== 2 ||
    typeof e[0] !== 'string' || !e[0].startsWith('fxw_') || e[0] === JOURNAL ||
    (e[1] !== null && typeof e[1] !== 'string'))) throw new Error('本地恢复记录损坏，请保留数据后重试');
  for (const [key, before] of entries) {
    if (before === null) localStorage.removeItem(key); else localStorage.setItem(key, before);
  }
  localStorage.removeItem(JOURNAL);
}
export function atomic<T>(action: () => T): T {
  if (pending) return action();
  recoverStorage();
  const writes = new Map<string, string | null>();
  pending = writes;
  let value: T;
  try { value = action(); } finally { pending = null; }
  if (!writes.size) return value;
  const before = [...writes.keys()].map(key => [key, localStorage.getItem(key)]);
  // If the journal cannot be saved, nothing has changed.
  localStorage.setItem(JOURNAL, JSON.stringify(before));
  try {
    for (const [key, after] of writes) {
      if (after === null) localStorage.removeItem(key); else localStorage.setItem(key, after);
    }
    localStorage.removeItem(JOURNAL);
  } catch (error) {
    try { recoverStorage(); } catch { /* Keep the durable journal for next startup. */ }
    throw error;
  }
  return value;
}
