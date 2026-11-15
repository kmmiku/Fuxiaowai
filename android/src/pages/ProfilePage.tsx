import { checkAppUpdate } from '../core/appUpdate';
import { clearTemporaryCache } from '../core/store';
import { Fragment, useEffect, useState } from 'react';

import { useApp } from '../core/appState';
import { navigate } from '../core/router';
import LineIcon, { type IconName } from '../ui/LineIcons';
import { toast } from '../ui/toast';

/**
 * 「我的」首页
 * 头像卡（72 圆头像 / 姓名 / 摘要）→ 六项主菜单 → 五个次级入口 → 页脚
 * 左侧图标统一用极简线条 SVG（LineIcons）
 */

interface MenuRow {
  key: string;
  title: string;
  desc: string;
  icon: IconName;
}

const ROWS: MenuRow[] = [
  { key: 'info', title: '个人资料', desc: '学号、专业、班级', icon: 'user' },
  { key: 'feedback', title: '反馈问题', desc: '说说哪里不好用', icon: 'help' },
  { key: 'timetable', title: '课表设置', desc: '周末、行高、上课时间', icon: 'calendar' },
  { key: 'remind', title: '上课提醒', desc: '提前几分钟提醒', icon: 'bell' },
  { key: 'appearance', title: '外观', desc: '深色 / 主题', icon: 'shirt' },
  { key: 'account', title: '账号与安全', desc: '凭据、清除数据', icon: 'lock' }
];

const SUB_ROWS: MenuRow[] = [
  { key: 'faq', title: '常见问题', desc: '登录、课表、提醒的答案', icon: 'help' },
  { key: 'about', title: '关于福小外', desc: '版本、开发者与反馈邮箱', icon: 'info' },
  { key: 'cache', title: '清除缓存', desc: '清掉临时文件，不动课表', icon: 'trash' },
  { key: 'network', title: '网络检测', desc: '看看教务和服务器通不通', icon: 'wifi' },
  { key: 'update', title: '检测更新', desc: '查看新版本与更新公告', icon: 'download' },
  { key: 'more', title: '更多', desc: '隐私与个人信息相关的入口', icon: 'grid' }
];

/** 与 ProfileStore.subtitle 一致：专业 · 年级级（空项不入串） */
function subtitle(p: { major: string; grade: string }): string {
  const parts: string[] = [];
  if (p.major.length > 0) parts.push(p.major);
  if (p.grade.length > 0) parts.push(`${p.grade}级`);
  return parts.join(' · ');
}

export default function ProfilePage() {
  const app = useApp();
  const p = app.profile;
  const avatar = app.avatar;
  const loggedIn = p.name.length > 0;
  const [press, setPress] = useState('');

  useEffect(() => {
    document.title = '我的 · 福小外';
  }, []);

  function open(key: string) {
    if (key === 'update') { void checkAppUpdate(); return; }
    if (key === 'info') return navigate('/personal');
    if (key === 'feedback') return navigate('/feedback');
    if (key === 'timetable') return navigate('/timetable-settings');
    if (key === 'remind') return navigate('/remind');
    if (key === 'appearance') return navigate('/appearance');
    if (key === 'account') return navigate('/account');
    if (key === 'faq') return navigate('/faq');
    if (key === 'about') return navigate('/about');
    if (key === 'cache') return clearCache();
    if (key === 'network') return checkNetwork();
    if (key === 'more') return navigate('/more');
    navigate(`/privacy/${key}`);
  }

  /** 清除缓存：只清临时键，不动设置 / 凭据 / 课表 */
  function clearCache() {
    const {count,bytes} = clearTemporaryCache();
    if (!count) { toast('没有可清理的缓存'); return; }
    toast(`已清理 ${count} 项临时数据（约 ${Math.max(1, Math.round(bytes / 1024))} KB）`);
  }

  /** 网络检测：并发探教务与后台服务器 */
  async function checkNetwork() {
    toast('正在检测网络…');
    const probe = async (url: string, ms = 6000): Promise<boolean> => {
      const ctrl = new AbortController();
      const t = window.setTimeout(() => ctrl.abort(), ms);
      try {
        await fetch(url, { method: 'GET', mode: 'no-cors', signal: ctrl.signal, cache: 'no-store' });
        return true;
      } catch {
        return false;
      } finally {
        window.clearTimeout(t);
      }
    };
    const [jw, api] = await Promise.all([
      probe('http://jw.fzfu.edu.cn/jwglxt/xtgl/login_slogin.html'),
      probe('https://fuxiaowai.xyz/healthz')
    ]);
    const lines = [
      `教务系统（jw.fzfu.edu.cn）：${jw ? '可访问' : '连不上'}`,
      `福小外后台（fuxiaowai.xyz）：${api ? '可访问' : '连不上'}`
    ];
    if (!jw) lines.push('校外访问教务需先连学校 VPN。');
    if (!api) lines.push('后台连不上时，分享口令与反馈会先存本机。');
    window.alert(lines.join('\n'));
  }

  const sub = loggedIn
    ? subtitle(p).length > 0
      ? subtitle(p)
      : p.clazz
    : '选择学校 / 年级 ›';

  function renderRow(r: MenuRow, quiet: boolean, last: boolean) {
    return (
      <Fragment key={r.key}>
        <button
          className="pm-row"
          data-press={press === r.key}
          onPointerDown={() => setPress(r.key)}
          onPointerUp={() => setPress('')}
          onPointerCancel={() => setPress('')}
          onPointerLeave={() => setPress('')}
          onClick={() => open(r.key)}
        >
          <div className={quiet ? 'pm-glyph pm-glyph--quiet' : 'pm-glyph'}>
            <LineIcon name={r.icon} size={quiet ? 17 : 19} />
          </div>
          <div className="pm-row-main">
            <div className="pm-row-title">{r.title}</div>
            <div className="pm-row-desc">{r.desc}</div>
          </div>
          <div className="pm-row-arrow">›</div>
        </button>
        {last ? null : <div className="pm-divider" />}
      </Fragment>
    );
  }

  return (
    <div className="pm-page">
      <div className="pm-head pm-head--profile">
        <div className="pm-title">我的</div>
      </div>

      <div className="pm-body pm-body--profile">
        {/* 头像卡：未登录去登录页，已登录去个人资料 */}
        <button
          className="pm-account"
          onClick={() => (loggedIn ? navigate('/personal') : navigate('/login'))}
        >
          {loggedIn ? (
            <div className="pm-avatar">
              {avatar ? <img src={avatar} alt="" /> : <span>{p.name.slice(-1)}</span>}
            </div>
          ) : (
            <div className="pm-avatar pm-avatar--empty">
              <LineIcon name="user" size={30} />
            </div>
          )}

          <div className="pm-account-main">
            <div className={loggedIn ? 'pm-account-name' : 'pm-account-name pm-account-name--guest'}>
              {loggedIn ? p.name : '立即登录'}
            </div>
            <div className="pm-account-sub">{sub}</div>
          </div>

          {loggedIn ? null : <div className="pm-account-chev">›</div>}
        </button>

        <div className="pm-card pm-menu">
          {ROWS.map((r, i) => renderRow(r, false, i === ROWS.length - 1))}
        </div>

        <div className="pm-card pm-card--sub">
          {SUB_ROWS.map((r, i) => renderRow(r, true, i === SUB_ROWS.length - 1))}
        </div>

        <div className="pm-footer">福小外 v0.1.1 · 福州外语外贸学院</div>
      </div>
    </div>
  );
}