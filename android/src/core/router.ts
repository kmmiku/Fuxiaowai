/**
 * 极简 hash 路由
 * 路径形如 #/home、#/add-course；页面参数放内存 Map（不进 URL，避免中文与敏感值外泄）
 */

import { useEffect, useState } from 'react';

export type RouteParams = Record<string, unknown>;

const paramCache = new Map<string, RouteParams>();

function readPath(): string {
  const h = window.location.hash.replace(/^#/, '');
  return h.length > 0 ? h : '/home';
}

export function navigate(path: string, params?: RouteParams): void {
  if (params) paramCache.set(path, params);
  if (readPath() === path) {
    // 同一路径重复进入时强制刷新一次，让页面拿到新参数
    window.dispatchEvent(new HashChangeEvent('hashchange'));
    return;
  }
  window.location.hash = path;
}

export function replace(path: string, params?: RouteParams): void {
  if (params) paramCache.set(path, params);
  const url = `${window.location.pathname}${window.location.search}#${path}`;
  history.replaceState(null, '', url);
  window.dispatchEvent(new HashChangeEvent('hashchange'));
}

export function back(): void {
  if (history.length > 1) history.back();
  else window.location.hash = '/home';
}

export interface RouteState {
  path: string;
  params: RouteParams;
  query: URLSearchParams;
}

export function useRoute(): RouteState {
  const [path, setPath] = useState<string>(readPath);

  useEffect(() => {
    const onChange = () => setPath(readPath());
    window.addEventListener('hashchange', onChange);
    return () => window.removeEventListener('hashchange', onChange);
  }, []);

  const [base, search] = path.split('?');
  return {
    path: base,
    params: paramCache.get(base) ?? {},
    query: new URLSearchParams(search ?? '')
  };
}

/** 取参数并给默认值 */
export function param<T>(params: RouteParams, key: string, fallback: T): T {
  const v = params[key];
  return (v === undefined || v === null ? fallback : v) as T;
}