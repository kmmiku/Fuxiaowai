import { Capacitor } from '@capacitor/core';
import { getRaw, setRaw, removeRaw } from './persistence';
const ephemeral = new Map<string, string>();
const unavailable = new Set<string>();
function transform(action: 'seal' | 'open', value: string, context: string): string {
  if (!Capacitor.isNativePlatform()) {
    if (action === 'open') {
      if (!ephemeral.has(value)) throw new Error('预览环境不持久保存凭据，请重新登录');
      return ephemeral.get(value)!;
    }
    const token = `memory:${crypto.randomUUID()}`;
    ephemeral.set(token, value); return token;
  }
  // onJsPrompt provides the invoking frame URL; native accepts only the packaged app origin.
  const raw = window.prompt('fxw-secret-v1', JSON.stringify({action,value,context}));
  const result = raw ? JSON.parse(raw) : null;
  if (!result?.ok || typeof result.value !== 'string') throw new Error('安全存储暂不可用，原数据已保留，请重试');
  return result.value;
}
export function readSecretRecord(key: string, field: string): Record<string, unknown> | null {
  const raw = getRaw(key);
  if (!raw) return null;
  let record;
  try {record=JSON.parse(raw);} catch {return null;}
  if (!record || typeof record !== 'object' || typeof record.user !== 'string') return null;
  const encryptedField = `${field}_enc_v1`;
  if (typeof record[encryptedField] === 'string') {
    try {
      record[field] = transform('open', record[encryptedField], `${key}:${record.user}`);
      unavailable.delete(key);
    } catch {
      // Keep the ciphertext intact after restore/key loss; cached timetable and account metadata remain readable.
      unavailable.add(key); record[field]=''; record.autoUpdate=false;
    }
    return record;
  }
  if (typeof record[field] === 'string' && record[field]) {
    try {writeSecretRecord(key, field, record);} catch { /* Existing plaintext is retained for retry, never newly written. */ }
  }
  return record;
}
export function writeSecretRecord(key: string, field: string, record: Record<string, unknown>): void {
  const value = record[field];
  if (typeof value !== 'string' || typeof record.user !== 'string') throw new Error('凭据格式不正确');
  const next = {...record};
  if (!value && unavailable.has(key)) {
    const prior=JSON.parse(getRaw(key)||'null');
    if (prior?.user===record.user && record.remember!==false && prior[`${field}_enc_v1`]) {
      delete next[field]; next[`${field}_enc_v1`]=prior[`${field}_enc_v1`];
      setRaw(key,JSON.stringify(next)); return;
    }
  }
  if (value) {
    const context = `${key}:${record.user}`;
    const cipher = transform('seal', value, context);
    if (transform('open', cipher, context) !== value) throw new Error('安全存储解密校验失败，原数据已保留');
    // The copy is written and read back while the old plaintext remains recoverable.
    const stagedKey = `${key}_migration_v1`;
    const staged = {...next, [field]: undefined, [`${field}_enc_v1`]: cipher};
    setRaw(stagedKey, JSON.stringify(staged));
    const checked = JSON.parse(getRaw(stagedKey)!);
    if (transform('open', checked[`${field}_enc_v1`], context) !== value) throw new Error('安全存储写入校验失败');
    setRaw(key, JSON.stringify(staged));
    // Leaving a verified encrypted staging copy after a crash is harmless; never keep plaintext here.
    if (getRaw(key) !== JSON.stringify(staged)) throw new Error('安全存储写入失败');
    removeRaw(stagedKey);
  } else {
    delete next[`${field}_enc_v1`];
    setRaw(key, JSON.stringify(next));
  }
}
