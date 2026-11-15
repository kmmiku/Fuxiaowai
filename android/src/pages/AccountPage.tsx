import { clearPersonalData, clearTimetableData } from '../core/cleanup';
import { useEffect, useState } from 'react';

import { useApp } from '../core/appState';
import * as DB from '../core/store';
import { back, navigate } from '../core/router';
import { clearReminders } from '../core/remind';
import { resetSession } from '../core/session';
import { toast } from '../ui/toast';

/**
 * 账号与安全 —— 1:1 对照 entry/src/main/ets/pages/AccountPage.ets
 * 教务账号卡（掩码账号 / 更新密码）+ 三条信息 + 危险操作按钮组
 */

/** 保留前 4 位，其余打码 */
function maskUser(u: string): string {
  if (u.length <= 4) return u;
  return u.substring(0, 4) + '*'.repeat(u.length - 4);
}

/** 鸿蒙版格式：yyyy-MM-dd HH:mm */
function formatTime(ts: number): string {
  const d = new Date(ts);
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  const hh = String(d.getHours()).padStart(2, '0');
  const mi = String(d.getMinutes()).padStart(2, '0');
  return `${d.getFullYear()}-${mm}-${dd} ${hh}:${mi}`;
}

export default function AccountPage() {
  const app = useApp();
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    document.title = '账号与安全 · 福小外';
  }, []);

  const cred = app.credential;
  const user = cred ? cred.user : '';
  const masked = maskUser(user);
  const remember = cred ? cred.autoUpdate : true;
  const lastSync = cred && cred.lastSyncAt > 0 ? formatTime(cred.lastSyncAt) : '从未同步';

  async function clearCourses() {
    if (busy) return;
    setBusy(true);
    try {
      // 清空所有课表，别只清当前这张
      await clearTimetableData(app.reload);
      toast('本地课表已清空');
    } catch {
      toast('清除失败');
    } finally {
      setBusy(false);
    }
  }

  async function clearAll() {
    if (busy) return;
    setBusy(true);
    try {
      // 退出登录：清掉会话 Cookie 与这个账号的本地数据，换账号不会串
      await clearPersonalData(false, app.reload);
      toast('已退出登录');
      window.setTimeout(() => back(), 800);
    } catch(e) {
      toast(e instanceof Error?e.message:'操作失败');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="pm-page">
      <div className="pm-head pm-head--bar">
        <button className="pm-back" onClick={() => back()} aria-label="返回">
          ‹
        </button>
        <div className="pm-title">账号与安全</div>
        <div className="pm-grow" />
      </div>

      <div className="pm-body pm-body--flush">
        <div className="pm-acct-card">
          <div className="pm-acct-row">
            <div>
              <div className="pm-acct-label">
                {user.length > 0 ? '已绑定教务账号' : '未绑定教务账号'}
              </div>
              <div className="pm-acct-user">{user.length > 0 ? masked : '—'}</div>
            </div>
            <button className="pm-acct-update" onClick={() => navigate('/login')}>
              更新密码
            </button>
          </div>
        </div>

        <div className="pm-acct-info">
          <div className="pm-acct-line">
            <div className="pm-acct-line-label">上次同步</div>
            <div className="pm-acct-line-value">{lastSync}</div>
          </div>
          <div className="pm-divider pm-divider--16 pm-divider--half" />
          <div className="pm-acct-line">
            <div className="pm-acct-line-label">记住密码</div>
            <div className="pm-acct-line-value">{remember ? '已开启（自动刷新用）' : '已关闭'}</div>
          </div>
          <div className="pm-divider pm-divider--16 pm-divider--half" />
          <div className="pm-acct-line">
            <div className="pm-acct-line-label">数据位置</div>
            <div className="pm-acct-line-value">仅本机，不上传服务器</div>
          </div>
        </div>

        <div className="pm-acct-note">
          凭据由 Android Keystore 保护后保存在本机；请勿向他人提供密码或会话。
        </div>

        <div className="pm-acct-actions">
          <button className="pm-acct-btn pm-acct-btn--plain" disabled={busy} onClick={clearCourses}>
            {busy ? '处理中…' : '清除本地课表'}
          </button>
          <button className="pm-acct-btn pm-acct-btn--solid" disabled={busy} onClick={clearAll}>
            退出登录并清除账号
          </button>
        </div>
      </div>
    </div>
  );
}