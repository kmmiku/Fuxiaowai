import { clearPersonalData } from '../core/cleanup';
import { useEffect, useRef, useState } from 'react';
import type { ChangeEvent } from 'react';

import { useApp } from '../core/appState';
import { back } from '../core/router';
import { clearReminders } from '../core/remind';
import { resetSession } from '../core/session';
import { toast } from '../ui/toast';
import AvatarCropper from '../ui/AvatarCropper';

/**
 * 个人资料 —— 1:1 对照 entry/src/main/ets/pages/PersonalInfoPage.ets
 * 80 圆头像（右下角换图徽标）+ 五行只读信息 + 退出登录确认弹层
 * 换头像：选图 → 框选裁剪 → 确认
 */

/** 先把原图读成 dataURL 交给裁剪层，最终尺寸由裁剪层决定 */
function readRaw(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error('读取图片失败'));
    reader.onload = () => resolve(String(reader.result));
    reader.readAsDataURL(file);
  });
}

export default function PersonalInfoPage() {
  const app = useApp();
  const p = app.profile;
  const avatar = app.avatar;
  const fileRef = useRef<HTMLInputElement | null>(null);
  const [picking, setPicking] = useState(false);
  const [cropping, setCropping] = useState('');
  const [confirmClear, setConfirmClear] = useState(false);

  useEffect(() => {
    document.title = '个人资料 · 福小外';
  }, []);

  const rows = [
    { label: '姓名', value: p.name.length > 0 ? p.name : '—' },
    { label: '学号', value: p.studentId.length > 0 ? p.studentId : '—' },
    { label: '专业', value: p.major.length > 0 ? p.major : '—' },
    { label: '班级', value: p.clazz.length > 0 ? p.clazz : '—' },
    { label: '年级', value: p.grade.length > 0 ? `${p.grade}级` : '—' }
  ];

  const initial = p.name.length === 0 ? '—' : p.name.slice(-1);

  async function onPick(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file || picking) return;
    setPicking(true);
    try {
      const raw = await readRaw(file);
      setCropping(raw);
    } catch {
      toast('当前设备没有可用图库，真机上可正常选图');
    } finally {
      setPicking(false);
    }
  }

  async function logout() {
    setConfirmClear(false);
    try {
      await clearPersonalData(false, app.reload);
      toast('已退出登录');
      window.setTimeout(() => back(), 600);
    } catch(e) {toast(e instanceof Error?e.message:'清理未完成，请重试');}
  }

  return (
    <div className="pm-page">
      <div className="pm-head pm-head--sub">
        <button className="pm-back" onClick={() => back()} aria-label="返回">
          ‹
        </button>
        <div className="pm-title">个人资料</div>
      </div>

      <div className="pm-body pm-body--sub">
        <div className="pm-avatar-hero">
          <button className="pm-avatar80" onClick={() => fileRef.current?.click()} aria-label="更换头像">
            <div className="pm-avatar80-face">
              {avatar ? <img src={avatar} alt="" /> : <span>{initial}</span>}
            </div>
            <div className="pm-avatar-badge">
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <rect
                  x="2.6"
                  y="4.6"
                  width="18.8"
                  height="14.8"
                  rx="3.4"
                  fill="none"
                  stroke="#FFFFFF"
                  strokeWidth="2"
                />
                <circle cx="8.4" cy="9.9" r="1.7" fill="#FFFFFF" />
                <path
                  d="M3.8 17.6 L9.6 11.6 L13.6 15.8 L16.4 13.2 L20.2 17.2"
                  fill="none"
                  stroke="#FFFFFF"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </div>
          </button>
          <div className="pm-avatar-name">{p.name.length > 0 ? p.name : '未登录'}</div>
          <div className="pm-avatar-clazz">
            {p.clazz.length > 0 ? p.clazz : '登录教务后自动同步'}
          </div>
        </div>

        <div className="pm-avatar-tip">
          {avatar.length > 0 ? '点击头像可重新选择' : '点击头像从相册选择'}
        </div>

        <div className="pm-card">
          {rows.map((r, i) => (
            <div key={r.label}>
              <div className="pm-kv-row">
                <div className="pm-kv-label">{r.label}</div>
                <div className="pm-kv-value">{r.value}</div>
              </div>
              {i < rows.length - 1 ? <div className="pm-divider pm-divider--16" /> : null}
            </div>
          ))}
        </div>

        <div className="pm-note">资料来自教务系统，在首页点 ⇩ 重新同步课表时会一并更新</div>

        <button className="pm-danger-row" onClick={() => setConfirmClear(true)}>
          退出登录
        </button>
      </div>

      <input ref={fileRef} type="file" accept="image/*" hidden onChange={onPick} />

      {cropping ? (
        <AvatarCropper
          src={cropping}
          onCancel={() => setCropping('')}
          onDone={(dataUrl) => {
            app.setAvatar(dataUrl);
            setCropping('');
            toast('头像已更新');
          }}
        />
      ) : null}

      {confirmClear ? (
        <>
          <div className="pm-mask" onClick={() => setConfirmClear(false)} />
          <div className="pm-sheet pm-sheet--logout">
            <div className="pm-sheet-inner">
              <div className="pm-sheet-title">退出登录？</div>
              <div className="pm-sheet-text">
                会清除本机保存的学号密码和课表，重新登录后自动恢复
              </div>
              <div className="pm-sheet-actions">
                <button className="pm-sheet-btn pm-sheet-btn--ghost" onClick={() => setConfirmClear(false)}>
                  取消
                </button>
                <button className="pm-sheet-btn pm-sheet-btn--danger" onClick={logout}>
                  退出
                </button>
              </div>
            </div>
          </div>
        </>
      ) : null}
    </div>
  );
}