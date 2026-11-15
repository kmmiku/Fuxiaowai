import { accountToken, invalidateAccount, isCurrent, schoolTask } from '../core/accountScope';
import { useEffect, useRef, useState } from 'react';

import { Capacitor, registerPlugin } from '@capacitor/core';

import { useApp } from '../core/appState';
import { navigate, param, useRoute } from '../core/router';
import { loadCredential, todayKey } from '../core/store';
import { clearReminders } from '../core/remind';
import { resetSession } from '../core/session';
import {
  completePortalLogin,
  currentSemester,
  fetchTimetable,
  importWebviewCookies,
  login,
  persistJwSession,
  portalLoginEntryUrl,
  qrLogin,
  qrPoll,
  qrStart,
  refreshCasCaptcha,
  setLoginMode,
  type LoginMode,
  type LoginResult
} from '../core/zhengfang';
import { toast } from '../ui/toast';
import { syncGrades } from '../core/gradeStore';

/** 原生侧的门户网页登录窗口（PortalLoginPlugin） */
interface FxwPortalPlugin {
  login(options: { url: string; user: string; pwd: string; silent?: boolean }): Promise<{
    jw: string;
    portal: string;
  }>;
}
const Portal = registerPlugin<FxwPortalPlugin>('FxwPortal');

const GRADE_FROM_ID = (sid: string): string => {
  const m = /^(\d{2})/.exec(sid);
  if (!m) return '';
  const yy = parseInt(m[1], 10);
  return String(yy >= 50 ? 1900 + yy : 2000 + yy);
};

/** 教务登录页：学号 + 密码 → 同步课表（对齐鸿蒙 LoginPage.ets，含企业微信扫码与图片验证码） */
export default function LoginPage() {
  const app = useApp();
  const route = useRoute();
  /** 登录成功后回到哪一页：从成绩页点「身份验证」进来时是 /grades */
  const nextPath = param(route.params, 'next', '/home');
  const saved = loadCredential();
  const [user, setUser] = useState(saved?.user ?? '');
  const [pwd, setPwd] = useState(saved?.pwd ?? '');
  const [remember, setRemember] = useState(saved?.remember ?? true);
  const [autoUpdate, setAutoUpdate] = useState(saved?.autoUpdate ?? true);
  /** 登录入口：教务直登 / 教学综合平台（互斥，只能选一个） */
  const [mode, setMode] = useState<LoginMode>('jw');
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState('');
  const [statusOk, setStatusOk] = useState(false);

  /* 图片验证码层 */
  const [captchaOpen, setCaptchaOpen] = useState(false);
  const [captchaMsg, setCaptchaMsg] = useState('');
  const [captchaCode, setCaptchaCode] = useState('');
  const [captchaImage, setCaptchaImage] = useState('');
  const [captchaBusy, setCaptchaBusy] = useState(false);

  /* 企业微信扫码层 */
  const [qrOpen, setQrOpen] = useState(false);
  const [qrImage, setQrImage] = useState('');
  const [qrMsg, setQrMsg] = useState('');
  const [qrBusy, setQrBusy] = useState(false);
  const [qrScanned, setQrScanned] = useState(false);
  const [qrLoading, setQrLoading] = useState(false);

  /** 每次开新码 +1，旧轮询看到变化就退出 */
  const qrToken = useRef(0);
  const alive = useRef(true);
  const attempt=useRef(accountToken());
  const committed=useRef(false);
  const beginAttempt=()=>{ invalidateAccount(); attempt.current=accountToken(); committed.current=false; };
  const validAttempt=()=>alive.current && isCurrent(attempt.current);

  useEffect(() => {
    document.title = '导入课表 · 福小外';
    alive.current = true;
    return () => {
      alive.current = false;
      qrToken.current += 1;
      if (!committed.current && isCurrent(attempt.current)) invalidateAccount();
    };
  }, []);

  /* ---------- 登录成功后的落库 ---------- */
  async function finishLogin(res: LoginResult, opts: { user: string; pwd: string; qr: boolean }) {
    const mine=attempt.current;
    if (!validAttempt()) return;
    const semester = res.semester ?? currentSemester();
    const probe = opts.qr ? '' : opts.user;
    let tt = await fetchTimetable(probe, semester);
    if (!validAttempt() || mine!==attempt.current) return;
    const xh = (tt.student.XH ?? '').trim();
    if (tt.courses.length === 0 && xh && xh !== probe) {
      const again = await fetchTimetable(xh, semester);
      if (!validAttempt() || mine!==attempt.current) return;
      if (again.courses.length > 0) tt = again;
    }

    // 关键校验：教务返回的学号必须就是这次要登录的账号。
    // 以前不加这一步，「换账号登录」会沿用旧会话，把上一个人的课表当成本人导入。
    const sid = (xh || tt.student.XH || probe).trim();
    if (probe && sid && sid !== probe) {
      await resetSession();
      setStatus(`教务返回的账号是 ${sid}，与输入的 ${probe} 不一致，已停止导入；请重新登录`);
      setStatusOk(false);
      return;
    }

    if (tt.courses.length === 0) {
      setStatus(`导入失败：${semester.label} 没有读到课程，可能学期未开始或课表未发布`);
      setStatusOk(false);
      return;
    }


    // 扫码登录拿不到密码：同账号沿用旧密码，换账号就清掉并关自动同步
    const sameUser = (saved?.user ?? '') === sid;
    const keepPwd = sameUser ? (saved?.pwd ?? '') : '';
    const credential = {
      user: sid,
      pwd: opts.qr ? keepPwd : opts.pwd,
      remember: opts.qr ? sameUser && (saved?.remember ?? false) : remember,
      lastSyncAt: Date.now(),
      autoUpdate: opts.qr ? false : autoUpdate,
      autoDay: todayKey()
    };
    const profile = {
      name: (tt.student.XM ?? '').trim(),
      studentId: sid,
      clazz: (tt.student.BJMC ?? '').trim(),
      major: (tt.student.ZYMC ?? '').trim(),
      grade: GRADE_FROM_ID(sid)
    };

    // 一个动作完成「换账号 + 只写这个账号的课表」，避免中间态串号
    if (!validAttempt() || mine!==attempt.current || !sid) return;
    app.signIn(credential, profile, tt.courses);
    committed.current=true;
    attempt.current=accountToken();
    // 会话落盘：成绩/考试页冷启动后不必再登一次
    persistJwSession(sid);
    // 扫码/密码登录都只换来一段有效期的校验权限：当场在后台把成绩抓下来存好，
    // 这样即使权限过期或没网，也能打开成绩页看上次的结果（离线缓存按学号分开存）
    void syncGrades({ user: sid, pwd: credential.pwd });
    // 新账号的提醒要重排，旧账号排过的提醒先清掉
    await clearReminders();

    setStatusOk(true);
    setStatus(`已导入 ${tt.courses.length} 门课程`);
    toast(`已导入 ${tt.courses.length} 门课程`);
    const completedToken=accountToken();
    window.setTimeout(() => {if(alive.current && isCurrent(completedToken,sid)) navigate(nextPath, { replace: true });}, 900);
  }

  /* ---------- 教学综合平台：网页登录窗 ---------- */
  async function portalLogin() {
    if (busy) return;
    if (!user.trim() || !pwd) {
      setStatus('请填写学号和密码');
      setStatusOk(false);
      return;
    }
    beginAttempt();
    setBusy(true);
    setLoginMode('portal');
    setStatus('正在后台登录教学综合平台…');
    setStatusOk(false);
    await schoolTask(attempt.current, async () => {
    try {
      const cookies = await Portal.login({
        url: portalLoginEntryUrl(),
        user: user.trim(),
        pwd,
        silent: true
      });
      if (!validAttempt()) return;
      const live = importWebviewCookies({ jw: cookies.jw, portal: cookies.portal });
      if (!live) {
        setStatus('登录窗口没有拿到教务会话，请重试');
        return;
      }
      setStatus('正在后台提取课表…');
      const done = await completePortalLogin();
      if (!done.ok) {
        setStatus(`导入失败：${done.message}`);
        return;
      }
      await finishLogin(done, { user: user.trim(), pwd, qr: false });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setStatus(msg.indexOf('取消') >= 0 ? '已取消登录' : `导入失败：${msg}`);
    } finally {
      setBusy(false);
    }
    }).catch(() => { setBusy(false); setCaptchaBusy(false); setQrBusy(false); });
  }

  /* ---------- 密码登录 ---------- */
  async function doLogin() {
    if (busy) return;
    if (mode === 'portal' && Capacitor.isNativePlatform()) {
      await portalLogin();
      return;
    }
    if (!user.trim() || !pwd) {
      setStatus('请填写学号和密码');
      setStatusOk(false);
      return;
    }
    beginAttempt();
    setBusy(true);
    setLoginMode(mode);
    setStatus(mode === 'portal' ? '正在连接教学综合平台…' : '正在连接教务系统…');
    setStatusOk(false);
    await schoolTask(attempt.current, async () => {
    try {
      const res = await login(user.trim(), pwd);
      if (!validAttempt()) return;
      if (res.captcha) {
        setCaptchaMsg(res.message);
        setCaptchaImage(res.captcha);
        setCaptchaCode('');
        setCaptchaOpen(true);
        setStatus(res.message);
        return;
      }
      if (!res.ok) {
        setStatus(`导入失败：${res.message}`);
        return;
      }
      await finishLogin(res, { user: user.trim(), pwd, qr: false });
    } catch (e) {
      setStatus('导入异常：' + (e instanceof Error ? e.message : String(e)));
    } finally {
      setBusy(false);
    }
    }).catch(() => { setBusy(false); setCaptchaBusy(false); setQrBusy(false); });
  }

  /* ---------- 验证码 ---------- */
  async function refreshCaptcha() {
    setCaptchaBusy(true);
    try {
      const img = await refreshCasCaptcha();
      setCaptchaImage(img);
      setCaptchaCode('');
      setCaptchaMsg(img ? '已换一张，请重新输入' : '验证码图片获取失败，请重试');
    } finally {
      setCaptchaBusy(false);
    }
  }

  async function submitCaptcha() {
    if (captchaBusy) return;
    if (!captchaCode.trim()) {
      setCaptchaMsg('请输入图片中的字符');
      return;
    }
    setCaptchaBusy(true);
    setCaptchaMsg('提交中…');
    await schoolTask(attempt.current, async () => {
    try {
      const res = await login(user.trim(), pwd, captchaCode.trim());
      if (res.captcha) {
        setCaptchaImage(res.captcha);
        setCaptchaCode('');
        setCaptchaMsg(res.message);
        return;
      }
      if (!res.ok) {
        setCaptchaMsg(`验证失败：${res.message}`);
        return;
      }
      setCaptchaOpen(false);
      setStatus('验证通过，正在导入课表…');
      await finishLogin(res, { user: user.trim(), pwd, qr: false });
    } catch (e) {
      setCaptchaMsg('验证异常：' + (e instanceof Error ? e.message : String(e)));
    } finally {
      setCaptchaBusy(false);
    }
    }).catch(() => { setBusy(false); setCaptchaBusy(false); setQrBusy(false); });
  }

  /* ---------- 企业微信扫码 ---------- */
  async function fetchQr(): Promise<string> {
    const t = await qrStart();
    setQrImage(t.image);
    return t.key;
  }

  async function openQr() {
    beginAttempt();
    qrToken.current += 1;
    setQrOpen(true);
    setQrMsg('正在获取二维码…');
    setQrBusy(true);
    setQrScanned(false);
    setQrLoading(true);
    try {
      const key = await fetchQr();
      setQrMsg('请用企业微信扫一扫，在手机上确认登录');
      await watchQr(key);
    } catch (e) {
      setQrMsg('二维码获取失败：' + (e instanceof Error ? e.message : String(e)));
    } finally {
      setQrLoading(false);
    }
  }

  function closeQr() {
    if (!committed.current) { invalidateAccount(); attempt.current=accountToken(); }
    qrToken.current += 1;
    setQrOpen(false);
    setQrBusy(false);
    setQrImage('');
  }

  async function refreshQr() {
    if (qrLoading) return;
    beginAttempt();
    const mine = ++qrToken.current;
    setQrMsg('正在获取二维码…');
    setQrLoading(true);
    setQrScanned(false);
    try {
      const key = await fetchQr();
      if (mine !== qrToken.current) return;
      await watchQr(key);
    } catch (e) {
      setQrMsg('二维码获取失败：' + (e instanceof Error ? e.message : String(e)));
    } finally {
      setQrLoading(false);
    }
  }

  /** 轮询：企业微信一次最多挂 20s，回来就接着问 */
  async function watchQr(key: string) {
    const mine = qrToken.current;
    let scanned = false;
    for (;;) {
      if (!alive.current || mine !== qrToken.current) return;
      const t0 = Date.now();
      let poll;
      try {
        poll = await qrPoll(key);
      } catch {
        if (mine !== qrToken.current) return;
        setQrMsg('状态获取失败，正在重试…');
        await new Promise((r) => window.setTimeout(r, 1200));
        continue;
      }
      if (mine !== qrToken.current) return;

      if (poll.state === 'done') {
        setQrBusy(true);
        setQrMsg('扫码成功，正在导入课表…');
        await finishQr(poll.code);
        return;
      }
      if (poll.state === 'cancel') {
        setQrMsg('已取消扫码，可刷新二维码重试');
        setQrBusy(false);
        return;
      }
      if (poll.state === 'expired') {
        setQrMsg('二维码已失效，正在换新码…');
        try {
          const next = await fetchQr();
          if (mine !== qrToken.current) return;
          await watchQr(next);
        } catch {
          setQrMsg('二维码已失效，请点刷新重试');
        }
        return;
      }
      if (poll.state === 'scanned') {
        if (!scanned) {
          scanned = true;
          setQrScanned(true);
          setQrMsg('已扫码，请在手机上确认登录');
        }
      } else if (!scanned) {
        setQrMsg('请用企业微信扫一扫，在手机上确认登录');
      }

      // 秒回说明服务端没挂住，稍等一下再问
      const spent = Date.now() - t0;
      await new Promise((r) => window.setTimeout(r, spent < 1500 ? 900 : 0));
    }
  }

  async function finishQr(code: string) {
    await schoolTask(attempt.current, async () => {
    try {
      const res = await qrLogin(code);
      if (!validAttempt()) return;
      if (!res.ok) {
        setQrMsg(res.message.includes('验证码') ? '扫码后仍需人机验证，请改用密码登录' : `导入失败：${res.message}`);
        setQrBusy(false);
        return;
      }
      await finishLogin(res, { user: '', pwd: '', qr: true });
      setQrOpen(false);
    } catch (e) {
      setQrMsg('导入失败，请重新扫码：' + (e instanceof Error ? e.message : String(e)));
      setQrBusy(false);
    }
    }).catch(() => { setBusy(false); setCaptchaBusy(false); setQrBusy(false); });
  }

  return (
    <div className="page px-login">
      <div className="pxl-nav no-select">
        <button className="pxl-back" onClick={() => navigate('/home')} aria-label="返回">
          ←
        </button>
        <span className="pxl-nav-title">导入课表</span>
      </div>

      <div className="pxl-scroll no-scrollbar">
        <div className="pxl-brand">
          <div className="pxl-name">福小外</div>
          <div className="pxl-sub">福州外语外贸学院 · 课表同步</div>
        </div>

        <div className="pxl-card">
          <div className="pxl-card-title">登录教务系统</div>

          <input
            className="pxl-input"
            inputMode="numeric"
            placeholder="学号"
            value={user}
            onChange={(e) => setUser(e.target.value)}
            autoComplete="username"
          />
          <input
            className="pxl-input"
            type="password"
            placeholder="教务密码"
            value={pwd}
            onChange={(e) => setPwd(e.target.value)}
            autoComplete="current-password"
          />

          {/* 两个登录入口：圆形单选，只能选一个，选中即填充 */}
          <div className="pxl-radios" role="radiogroup" aria-label="登录入口">
            <button
              type="button"
              className="pxl-radio"
              role="radio"
              aria-checked={mode === 'jw'}
              data-on={mode === 'jw'}
              onClick={() => setMode('jw')}
            >
              <span className="pxl-dot" />
              <span className="pxl-radio-text">教务登录入口</span>
            </button>
            <button
              type="button"
              className="pxl-radio"
              role="radio"
              aria-checked={mode === 'portal'}
              data-on={mode === 'portal'}
              onClick={() => setMode('portal')}
            >
              <span className="pxl-dot" />
              <span className="pxl-radio-text">教学综合平台入口</span>
            </button>
          </div>

          <label className="pxl-check">
            <input type="checkbox" checked={remember} onChange={(e) => setRemember(e.target.checked)} />
            <span className="pxl-check-text">记住密码（用于定期更新课表）</span>
          </label>

          <label className="pxl-check">
            <input type="checkbox" checked={autoUpdate} onChange={(e) => setAutoUpdate(e.target.checked)} />
            <span className="pxl-check-col">
              <span className="pxl-check-text">每天自动更新课表</span>
              <span className="pxl-check-hint">勾选后每天首次打开 App 同步一次，同一天不会重复同步</span>
            </span>
          </label>

          <button className="pxl-btn" disabled={busy} onClick={doLogin}>
            {busy ? '正在登录…' : '登录并导入课表'}
          </button>

          <button className="pxl-link" type="button" onClick={openQr}>
            企业微信扫码登录
          </button>

          {status && <div className={`pxl-status${statusOk ? ' ok' : ''}`}>{status}</div>}
        </div>

        <div className="pxl-note">账号密码只用于登录教务系统取课表，不发送到第三方服务器。</div>
      </div>

      {/* 企业微信扫码 */}
      {qrOpen && (
        <div className="pxl-mask" onClick={closeQr}>
          <div className="pxl-sheet pxl-sheet--qr" onClick={(e) => e.stopPropagation()}>
            <div className="pxl-sheet-title">企业微信扫码登录</div>

            <div className="pxl-qr-box">
              {qrImage ? (
                <img className="pxl-qr-img" src={qrImage} alt="企业微信登录二维码" />
              ) : (
                <div className="pxl-qr-empty">正在获取二维码…</div>
              )}
              {qrScanned && qrImage ? <div className="pxl-qr-veil">已扫码</div> : null}
            </div>

            <div className="pxl-sheet-msg">{qrMsg}</div>

            <div className="pxl-sheet-actions">
              <button className="pxl-ghost" type="button" onClick={closeQr}>
                关闭
              </button>
              <button className="pxl-ghost pxl-ghost--main" type="button" disabled={qrBusy} onClick={refreshQr}>
                刷新二维码
              </button>
            </div>

            <div className="pxl-sheet-tip">扫码后仍需在手机上确认；导入失败可改用账号密码登录。</div>
          </div>
        </div>
      )}

      {/* 图片验证码 */}
      {captchaOpen && (
        <div className="pxl-mask" onClick={() => setCaptchaOpen(false)}>
          <div className="pxl-sheet" onClick={(e) => e.stopPropagation()}>
            <div className="pxl-sheet-title">安全验证</div>
            <div className="pxl-sheet-msg">{captchaMsg || '教务系统要求输入验证码'}</div>

            <button className="pxl-captcha" type="button" onClick={refreshCaptcha} disabled={captchaBusy}>
              {captchaImage ? (
                <img src={captchaImage} alt="验证码" />
              ) : (
                <span>{captchaBusy ? '验证码加载中…' : '点这里加载验证码'}</span>
              )}
            </button>

            <input
              className="pxl-input"
              placeholder="请输入图片中的字符（点图片可换一张）"
              value={captchaCode}
              onChange={(e) => setCaptchaCode(e.target.value)}
              autoCapitalize="characters"
              autoComplete="off"
            />

            <div className="pxl-sheet-actions">
              <button className="pxl-ghost" type="button" onClick={() => setCaptchaOpen(false)}>
                取消
              </button>
              <button className="pxl-ghost pxl-ghost--main" type="button" disabled={captchaBusy} onClick={submitCaptcha}>
                {captchaBusy ? '提交中…' : '确定'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}