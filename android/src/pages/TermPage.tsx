import { accountToken, isCurrent, schoolTask } from '../core/accountScope';
import { commitTimetable } from '../core/timetableSync';
import { useEffect, useState } from 'react';

import { useApp } from '../core/appState';
import { back, navigate } from '../core/router';
import { TOTAL_WEEKS, TERM_LABEL, currentWeek, weekRangeLabel } from '../core/semester';
import {
  currentSemester,
  ensureJwSession,
  fetchTimetable,
  login,
  persistJwSession
} from '../core/zhengfang';

export default function TermPage() {
  const app = useApp();
  const [busy, setBusy] = useState(false);
  const [syncLabel, setSyncLabel] = useState('');
  const [needCaptcha, setNeedCaptcha] = useState(false);

  useEffect(() => {
    document.title = '切换学期 · 福小外';
  }, []);

  const now = currentWeek(TOTAL_WEEKS);

  async function sync(): Promise<void> {
    if (busy) return;
    const cred = app.credential;
    if (!cred || !cred.user) {
      setSyncLabel('还没有保存的账号，先去登录一次');
      return;
    }
    const token=accountToken(), table=app.activeTableId;
    setBusy(true);
    setSyncLabel('');
    setNeedCaptcha(false);
    await schoolTask(token, async () => {
    try {
      // 门户/扫码登录只留下会话，没有可用的纯 HTTP 登录链路：有会话就直接拉
      if (!ensureJwSession(cred.user)) {
        if (!cred.pwd) {
          setSyncLabel('登录状态已过期，请回「导入课表」重新登录');
          return;
        }
        const res = await login(cred.user, cred.pwd);
        if (res.captcha) {
          // 教务这一轮要人机验证：会话捏在导入页那边，去那边输一次就能接着同步
          setNeedCaptcha(true);
          setSyncLabel('教务要求验证码，请到「导入课表」页完成验证');
          return;
        }
        if (!res.ok) {
          setSyncLabel(`同步失败：${res.message}`);
          return;
        }
        persistJwSession(cred.user);
      }
      const tt = await fetchTimetable(cred.user, currentSemester());
      if (!isCurrent(token,cred.user)) return;
      if (tt.student.XH && tt.student.XH.trim()!==cred.user) throw new Error('教务返回账号不一致，已停止同步');
      commitTimetable(tt.courses,{...cred,lastSyncAt:Date.now()},table,token);
      app.reload();
      setSyncLabel(`同步完成：已导入 ${tt.courses.length} 条课程`);
    } catch (e) {
      setSyncLabel(`同步异常：${e instanceof Error ? e.message : String(e)}`);
    } finally {
      setBusy(false);
    }
    }).catch(() => setBusy(false));
  }

  return (
    <div className="pxs-page">
      <div className="pxs-head">
        <button type="button" className="pxs-back" onClick={back} aria-label="返回">
          ‹
        </button>
        <div className="pxs-title">切换学期</div>
      </div>

      <div className="pxs-term-card">
        <div className="pxs-term-main">
          <div className="pxs-term-kicker">当前学期</div>
          <div className="pxs-term-name">{TERM_LABEL}</div>
          <div className="pxs-term-meta">
            第 {now} 周 · 共 {TOTAL_WEEKS} 周 · 本周 {weekRangeLabel(now)}
          </div>
        </div>
        <span className="pxs-badge">使用中</span>
      </div>

      <div className="pxs-term-card pxs-card-gap">
        <div className="pxs-sync-main">
          <div className="pxs-srow-title">重新同步本学期</div>
          <div className="pxs-srow-sub">用已保存的账号再拉一次课表，课程变动时用</div>
        </div>
        <button
          type="button"
          className="pxs-sync-btn"
          disabled={busy}
          onClick={() => {
            void sync();
          }}
        >
          {busy ? '同步中…' : '同步'}
        </button>
      </div>

      {syncLabel ? <div className="pxs-sync-label">{syncLabel}</div> : null}

      {needCaptcha ? (
        <button
          type="button"
          className="pxs-sync-btn pxs-captcha-go"
          onClick={() => navigate('/login')}
        >
          去导入课表完成验证
        </button>
      ) : null}

      <div className="pxs-term-note">
        教务系统一学期只开放当前学期的课表，历史学期需在教务端查询；下学期开放后这里会自动出现。
      </div>
    </div>
  );
}