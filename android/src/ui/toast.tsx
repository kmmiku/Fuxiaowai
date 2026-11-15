/** 全局轻提示：任何模块 import { toast } 直接调用 */

import { useEffect, useState } from 'react';

let handler: ((msg: string) => void) | null = null;

export function toast(msg: string): void {
  if (handler) handler(msg);
  else console.log('[toast]', msg);
}

export function ToastHost() {
  const [msg, setMsg] = useState('');

  useEffect(() => {
    handler = setMsg;
    return () => {
      handler = null;
    };
  }, []);

  useEffect(() => {
    if (!msg) return;
    const t = window.setTimeout(() => setMsg(''), 1900);
    return () => window.clearTimeout(t);
  }, [msg]);

  if (!msg) return null;
  return <div className="toast">{msg}</div>;
}