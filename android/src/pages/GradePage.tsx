import { accountToken, isCurrent } from '../core/accountScope';
import { useCallback, useEffect, useRef, useState } from 'react';

import WheelPicker from '../ui/WheelPicker';
import { useApp } from '../core/appState';
import { navigate } from '../core/router';
import type { GradeRecord } from '../core/types';
import {
  clearPersistedJwSession,
  ensureJwSession,
  markSession
} from '../core/zhengfang';
import {
  loadGradesCache,
  saveGradesCache,
  syncGrades,
  type GradeSummary,
  type GradesSnapshot,
  type TermGrades
} from '../core/gradeStore';
import '../styles/px-grade.css';

const EMPTY_SUMMARY: GradeSummary = {
  count: 0,
  credits: 0,
  weightedScore: 0,
  weightedGpa: 0,
  failed: 0,
  best: 0
};

/** 成绩等级：0=优 1=良 2=中 3=及格 4=不及格 5=非百分制 */
function scoreLevel(score: number, hasScore: boolean): number {
  if (!hasScore) return 5;
  if (score >= 90) return 0;
  if (score >= 80) return 1;
  if (score >= 70) return 2;
  if (score >= 60) return 3;
  return 4;
}

/** 11-13 15:26 */
function fmtStamp(ts: number): string {
  const d = new Date(ts);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

export default function GradePage() {
  const app = useApp();
  const request=useRef(0);

  const [loading, setLoading] = useState(true);
  const [needLogin, setNeedLogin] = useState(false);
  const [stale, setStale] = useState(false);
  const [errMsg, setErrMsg] = useState('');
  const [terms, setTerms] = useState<TermGrades[]>([]);
  const [allItems, setAllItems] = useState<GradeRecord[]>([]);
  const [activeTerm, setActiveTerm] = useState(-1);
  const [sheet, setSheet] = useState(false);
  const [summary, setSummary] = useState<GradeSummary>(EMPTY_SUMMARY);
  /** 这份数据是什么时候抓的（离线时也能说清楚） */
  const [stamp, setStamp] = useState(0);
  /** 本地会话是否还有效（决定「身份验证」那行是绿还是黄） */
  const [sessionOk, setSessionOk] = useState(false);
  /** 断网时只能看缓存，别把「有效/过期」说成定论 */
  const [offline, setOffline] = useState(() => (typeof navigator === 'undefined' ? false : !navigator.onLine));

  useEffect(() => {
    const on = () => setOffline(false);
    const off = () => setOffline(true);
    window.addEventListener('online', on);
    window.addEventListener('offline', off);
    return () => {
      window.removeEventListener('online', on);
      window.removeEventListener('offline', off);
    };
  }, []);

  useEffect(() => {
    document.title = '成绩 · 福小外';
  }, []);

  const applySnapshot = useCallback((snap: GradesSnapshot) => {
    setTerms(snap.terms);
    setAllItems(snap.items);
    setSummary(snap.summary);
    setStamp(snap.at);
  }, []);

  /** 在线拉一次；失败/过期时保留缓存不动 */
  const load = useCallback(async () => {
    const mine=++request.current, token=accountToken();
    setErrMsg('');
    const cred = app.credential;
    if (!cred || cred.user.length === 0) {
      setLoading(false);
      setNeedLogin(true);
      return;
    }

    setNeedLogin(false);
    setTerms([]); setAllItems([]); setSummary(EMPTY_SUMMARY); setStamp(0);
    const cached = loadGradesCache(cred.user);
    if (cached) {
      // 先渲染缓存：断网也能立刻看到上次的成绩
      applySnapshot(cached);
      setLoading(false);
    } else {
      setLoading(true);
    }

    const alive = ensureJwSession(cred.user);
    setSessionOk(false);

    const res = await syncGrades(cred);
    if (mine!==request.current || !isCurrent(token,cred.user)) return;
    if (res.ok && res.snapshot) {
      applySnapshot(res.snapshot);

      setStale(false);
      setSessionOk(true);
      setLoading(false);
      return;
    }

    // 没拿到新数据：缓存还在就继续显示，只把状态标出来
    if (res.expired) {
      clearPersistedJwSession();
      markSession(false);
      setSessionOk(false);
      setStale(true);
    } else {
      setStale(true);
      // 连不上教务：说明是网络问题，不是身份失效，别把用户吓去重登
      if ((res.message ?? '').includes('无法连接')) setOffline(true);
    }
    setErrMsg(res.message ?? '');
    setLoading(false);
  }, [app.credential, applySnapshot]);

  useEffect(() => {
    void load();
    return () => { request.current++; };
  }, [load]);

  /** 后台同步（登录页/首页触发的）写好后，直接把页面换成新数据 */
  useEffect(() => {
    const onUpdated = () => {
      const who = app.credential?.user ?? '';
      if (!who) return;
      const snap = loadGradesCache(who);
      if (!snap) return;
      applySnapshot(snap);
      setStale(false);
      setSessionOk(ensureJwSession(who));
      setLoading(false);
      setErrMsg('');
    };
    window.addEventListener('fxw:grades-updated', onUpdated);
    return () => window.removeEventListener('fxw:grades-updated', onUpdated);
  }, [app.credential, applySnapshot]);

  /** 右上角「身份验证刷新」：先回登录页重新验证，验完自动回到本页 */
  function refreshIdentity(): void {
    navigate('/login', { next: '/grades' });
  }

  function shown(): GradeRecord[] {
    if (activeTerm < 0) return allItems;
    if (activeTerm >= terms.length) return allItems;
    return terms[activeTerm].items;
  }

  function termTitle(): string {
    if (activeTerm < 0) return '全部学期';
    return activeTerm < terms.length ? terms[activeTerm].label : '全部学期';
  }

  const rows = shown();
  const hasData = allItems.length > 0;

  return (
    <div className="pxg-page">
      <div className="pxg-head">
        <div className="pxg-head-title">我的成绩</div>
        <div className="pxg-head-spacer" />
        <button
          className="pxg-id-btn"
          onClick={refreshIdentity}
          aria-label="身份验证刷新"
          title="重新验证身份"
        >
          <span className="pxg-id-icon" aria-hidden="true">
            ↻
          </span>
          <span className="pxg-id-text">身份验证</span>
        </button>
      </div>

      {hasData ? (
        <div className="pxg-meta">
          <span className="pxg-meta-item">
            成绩更新于 {stamp > 0 ? fmtStamp(stamp) : '—'}
            {offline ? '（离线）' : ''}
          </span>
          <span className="pxg-meta-dot">·</span>
          <span className={`pxg-meta-state ${offline ? 'is-warn' : sessionOk && !stale ? 'is-ok' : 'is-warn'}`}>
            {offline ? '离线 · 身份验证未校验' : sessionOk && !stale ? '身份验证有效' : '身份验证已过期'}
          </span>
        </div>
      ) : null}

      {needLogin ? (
        <div className="pxg-center">
          <div className="pxg-center-title">还没有保存教务账号</div>
          <div className="pxg-center-desc">先在首页用 ⇩ 登录一次，之后就能直接看成绩</div>
          <button className="pxg-btn" onClick={() => navigate('/login', { next: '/grades' })}>
            去登录
          </button>
        </div>
      ) : loading ? (
        <div className="pxg-center">
          <div className="pxg-spinner" aria-hidden="true" />
          <div className="pxg-loading-text">正在读取成绩…</div>
        </div>
      ) : !hasData ? (
        <div className="pxg-center">
          <div className="pxg-center-title">{stale ? '登录状态已过期' : '没拿到成绩'}</div>
          <div className="pxg-center-desc">
            {errMsg.length > 0
              ? errMsg
              : '扫码登录的校验权限只有很短一段时间；点右上角「身份验证」重新登录一次即可'}
          </div>
          <button className="pxg-btn" onClick={refreshIdentity}>
            重新验证身份
          </button>
        </div>
      ) : (
        <div className="pxg-scroll">
          <div className="pxg-hero">
            <div className="pxg-hero-row">
              <div className="pxg-hero-col">
                <div className="pxg-hero-label">平均绩点</div>
                <div className="pxg-hero-value">{summary.weightedGpa.toFixed(2)}</div>
              </div>
              <button className="pxg-hero-entry" onClick={() => navigate('/exam')}>
                <span className="pxg-entry-title">考试安排</span>
                <span className="pxg-entry-sub">教务系统 ›</span>
              </button>
            </div>

            <div className="pxg-hero-meta">
              <span>已修 {summary.credits} 学分</span>
              <span className="pxg-hero-dot">·</span>
              <span>{summary.count} 门课</span>
              {summary.failed > 0 ? (
                <>
                  <span className="pxg-hero-dot">·</span>
                  <span className="pxg-hero-warn">{summary.failed} 门不及格</span>
                </>
              ) : null}
            </div>
          </div>

          <div className="pxg-term">
            <button className="pxg-termbar" onClick={() => setSheet(true)}>
              <span className="pxg-termbar-key">学期</span>
              <span className="pxg-termbar-val">{termTitle()}</span>
              <span className="pxg-termbar-arrow">›</span>
            </button>
          </div>

          {rows.map((g, i) => {
            const lv = scoreLevel(g.score, g.score > 0);
            return (
              <div className="pxg-row" key={`${g.id}-${g.term}-${i}`}>
                <div className="pxg-row-main">
                  <div className="pxg-row-name">{g.course}</div>
                  <div className="pxg-row-sub">
                    <span>{g.credit} 学分</span>
                    {g.nature.length > 0 ? (
                      <>
                        <span className="pxg-row-dot">·</span>
                        <span>{g.nature}</span>
                      </>
                    ) : null}
                  </div>
                </div>
                <div className={`pxg-score pxg-lv${lv}`}>
                  <div className="pxg-score-value">{g.score > 0 ? g.score : '—'}</div>
                  <div className="pxg-score-gpa">{g.gpa > 0 ? `绩点 ${g.gpa.toFixed(1)}` : ' '}</div>
                </div>
              </div>
            );
          })}

          <div className="pxg-foot">
            {stale
              ? '离线数据：教务会话已过期，重新验证身份后会自动更新'
              : '数据来源：正方教务系统 · 点右上角「身份验证」可重新校验'}
          </div>
        </div>
      )}

      {sheet ? (
        <div className="wheel-mask" onClick={() => setSheet(false)}>
          <div className="wheel-sheet" onClick={(e) => e.stopPropagation()}>
            <div className="wheel-head">
              <span className="wheel-title">选择学期</span>
              <button className="wheel-done" onClick={() => setSheet(false)}>
                完成
              </button>
            </div>
            <WheelPicker
              items={['全部学期', ...terms.map((t) => t.label)]}
              index={activeTerm + 1}
              onPick={(i) => setActiveTerm(i - 1)}
            />
          </div>
        </div>
      ) : null}
    </div>
  );
}