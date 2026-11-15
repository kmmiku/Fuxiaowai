import { accountToken, isCurrent, schoolTask } from '../core/accountScope';
import { useCallback, useEffect, useRef, useState } from 'react';

import { useApp } from '../core/appState';
import { daysUntil } from '../core/exam';
import { navigate } from '../core/router';
import type { ExamRecord } from '../core/types';
import {
  currentSemester,
  ensureJwSession,
  fetchExams,
  login,
  persistJwSession
} from '../core/zhengfang';
import { silentPortalLogin } from '../core/portal';
import '../styles/px-grade.css';

export default function ExamPage() {
  const app = useApp();
  const request=useRef(0);

  const [loading, setLoading] = useState(true);
  const [needLogin, setNeedLogin] = useState(false);
  const [expired, setExpired] = useState(false);
  const [errMsg, setErrMsg] = useState('');
  const [exams, setExams] = useState<ExamRecord[]>([]);
  const [now, setNow] = useState<number>(() => Date.now());

  useEffect(() => {
    document.title = '考试安排 · 福小外';
  }, []);

  /** 登录 → 拉本学期考试 → 解析；没有数据就显示「近期没有考试」 */
  const load = useCallback(async () => {
    const mine=++request.current, token=accountToken();
    setLoading(true);
    setNeedLogin(false);
    setErrMsg('');
    setExpired(false);
    const at = Date.now();
    setNow(at);
    const cred = app.credential;
    if (!cred || cred.user.length === 0) {
      setLoading(false);
      setNeedLogin(true);
      return;
    }
    let parsed: ExamRecord[] = [];
    let failed = '';
    await schoolTask(token, async () => {
    try {
      // 门户/扫码登录可能没留下密码：有会话就直接查，没会话才走账号密码（与鸿蒙一致）
      if (!ensureJwSession(cred.user)) {
        if (cred.pwd.length === 0) {
          setLoading(false);
          setExpired(true);
          return;
        }
        const r = await login(cred.user, cred.pwd);
        if (!r.ok) {
          // 纯 HTTP 登录被门户挡下时，改用静默网页登录（与「教学综合平台入口」同一条链路）
          const viaWeb = await silentPortalLogin(cred.user, cred.pwd);
          if (viaWeb.ok) {
            persistJwSession(cred.user);
          } else {
            failed = viaWeb.message;
          }
        } else {
          persistJwSession(cred.user);
        }
      }
      if (failed.length === 0) {
        // 考试一般排在学期末，先查本学期
        const cur = currentSemester(new Date());
        try {
          parsed = await fetchExams(cur.xnm, cur.xqm);
        } catch (e) {
          // 单学期失败不致命，但过期要报出来，别伪装成「没有考试」
          const msg = e instanceof Error ? e.message : String(e);
          failed = msg;
        }
      }
    } catch {
      failed = '无法连接教务系统，请检查校园网';
    }
    });
    if (mine!==request.current || !isCurrent(token,cred.user)) return;
    setLoading(false);
    if (parsed.length > 0) {
      setExams(parsed);
      setErrMsg('');
      return;
    }
    setExams([]);
    setErrMsg(failed.length > 0 ? failed : '教务还没有发布本学期考试安排');
  }, [app.credential]);

  useEffect(() => { setExams([]); void load().catch(() => setLoading(false)); return () => {request.current++;}; }, [load]);

  function refresh(): void {
    if (!loading) void load();
  }

  /** 下一场未结束的考试；没有则返回 null */
  function nextExam(): ExamRecord | null {
    for (const e of exams) {
      if (e.startAt >= now) return e;
    }
    return null;
  }

  function passed(e: ExamRecord): boolean {
    return e.startAt > 0 && e.startAt < now;
  }

  function nextLabel(): string {
    const n = nextExam();
    if (n === null) return '已全部结束';
    const d = daysUntil(n.startAt, now);
    if (d <= 0) return '就在今天';
    return `${d} 天后`;
  }

  function summaryLine(): string {
    const n = nextExam();
    if (n === null) {
      return '本学期的考试都过去了，成绩出来后在「我的成绩」里能看到。';
    }
    const room = n.room.length > 0 ? ` · ${n.room}` : '';
    // 数据层会把缺失时刻填成「时间待定」，这里按空处理，避免重复出现
    const when = [n.dateLabel, n.clockLabel]
      .filter((s) => s.length > 0 && s !== '时间待定')
      .join(' ');
    const prefix = when.length > 0 ? `最近一场 ${when}` : '最近一场';
    return `${prefix} ${n.course}${room}`;
  }

  function tagOf(e: ExamRecord): string {
    if (passed(e)) return '已结束';
    if (e.startAt <= 0) return '待定';
    const d = daysUntil(e.startAt, now);
    if (d === 0) return '今天';
    if (d === 1) return '明天';
    return `${d} 天后`;
  }

  function openWeb(): void {
    navigate('/exam-web');
  }

  return (
    <div className="pxg-page">
      <div className="pxg-head pxg-head-exam">
        <button className="pxg-back" onClick={() => navigate('/grades')} aria-label="返回">
          ‹        </button>
        <div className="pxg-head-title">考试安排</div>
        <div className="pxg-head-spacer" />
        <button
          className="pxg-icon-btn"
          onClick={refresh}
          disabled={loading}
          aria-label="重新读取"
        >
          ‹        </button>
      </div>

      {needLogin ? (
        <div className="pxg-center">
          <div className="pxg-center-title">还没有保存教务账号</div>
          <div className="pxg-center-desc">先在首页用 ⇩ 登录一次，之后就能直接看考试安排</div>
          <button className="pxg-btn" onClick={() => navigate('/login')}>
            去登录
          </button>
        </div>
      ) : expired ? (
        <div className="pxg-center">
          <div className="pxg-center-title">登录状态已过期</div>
          <div className="pxg-center-desc">
            这次是扫码登录，本机没有存密码；回首页用企业微信扫码登录一次，会话恢复后就能直接看考试安排
          </div>
          <button className="pxg-btn" onClick={() => navigate('/login')}>
            回首页扫码登录
          </button>
        </div>
      ) : loading ? (
        <div className="pxg-center">
          <div className="pxg-spinner" aria-hidden="true" />
          <div className="pxg-loading-text">正在读取考试安排…</div>
        </div>
      ) : exams.length === 0 ? (
        <div className="pxg-exam-empty">
          <div className="pxg-exam-empty-body">
            <div className="pxg-exam-empty-title">近期没有考试</div>
            <div className="pxg-exam-empty-sub">{errMsg}</div>
            <div className="pxg-exam-empty-tip">
              期末考试一般提前两三周才排定，到时候点右上角 ↻ 重新读取。</div>
            <button className="pxg-btn pxg-btn-tight" onClick={refresh}>
              重新读取
            </button>
          </div>
          <button className="pxg-link" onClick={openWeb}>
            用网页查看教务原始页面 ›
          </button>
        </div>
      ) : (
        <div className="pxg-scroll">
          <div className="pxg-exam-hero">
            <div className="pxg-hero-row">
              <div className="pxg-hero-main">
                <div className="pxg-hero-label">共安排</div>
                <div className="pxg-hero-value">{exams.length}</div>
              </div>
              <div className="pxg-hero-next">
                <div className="pxg-hero-label">下一场</div>
                <div className="pxg-exam-next">{nextLabel()}</div>
              </div>
            </div>
            <div className="pxg-exam-sum">{summaryLine()}</div>
          </div>

          {exams.map((e) => {
            const isPassed = passed(e);
            const d = new Date(e.startAt > 0 ? e.startAt : now);
            const clock = e.clockLabel === '时间待定' ? '' : e.clockLabel;
            return (
              <div className="pxg-exam-card" key={e.id}>
                <div className="pxg-date" data-passed={isPassed} data-tall={clock.length > 0}>
                  <div className="pxg-date-day">{d.getDate()}</div>
                  <div className="pxg-date-mon">{d.getMonth() + 1}月</div>
                </div>
                <div className="pxg-exam-main">
                  <div className="pxg-exam-title-row">
                    <div className="pxg-exam-name" data-passed={isPassed}>
                      {e.course}
                    </div>
                    <div className="pxg-tag" data-passed={isPassed}>
                      {tagOf(e)}
                    </div>
                  </div>
                  <div className="pxg-exam-line">
                    <span>{e.dateLabel}</span>
                    {clock.length > 0 ? (
                      <>
                        <span className="pxg-exam-dot pxg-dot-5">·</span>
                        <span>{clock}</span>
                      </>
                    ) : null}
                  </div>
                  <div className="pxg-exam-line">
                    {e.room.length > 0 ? (
                      <>
                        <span className="pxg-exam-label">考场</span>
                        <span>{e.room}</span>
                      </>
                    ) : null}
                    {e.seat.length > 0 ? (
                      <>
                        <span className="pxg-exam-dot pxg-dot-6">·</span>
                        <span>{e.seat} 号</span>
                      </>
                    ) : null}
                    {e.method.length > 0 ? (
                      <>
                        <span className="pxg-exam-dot pxg-dot-6">·</span>
                        <span>{e.method}</span>
                      </>
                    ) : null}
                  </div>
                </div>
              </div>
            );
          })}

          <div className="pxg-exam-tail">
            <button className="pxg-link" onClick={openWeb}>
              用网页查看教务原始页面 ›
            </button>
            <div className="pxg-exam-source">数据来源：正方教务系统 · 点右上角 ↻ 重新读取</div>
          </div>
        </div>
      )}
    </div>
  );
}