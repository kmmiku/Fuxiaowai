import { Fragment, useEffect, useState } from 'react';

import { navigate } from '../core/router';
import LineIcon, { type IconName } from '../ui/LineIcons';

/** 「更多」：隐私与个人信息相关的五个入口 */

interface Row {
  key: string;
  title: string;
  desc: string;
  icon: IconName;
}

const ROWS: Row[] = [
  { key: 'collect', title: '个人信息收集清单', desc: '收集了什么、用在哪里', icon: 'grid' },
  { key: 'share', title: '第三方信息共享清单', desc: '与谁交换了数据', icon: 'wifi' },
  { key: 'export', title: '个人信息导出', desc: '把数据复制成 JSON', icon: 'info' },
  { key: 'permission', title: '权限中心', desc: '申请了哪些系统权限', icon: 'lock' },
  { key: 'revoke', title: '隐私协议撤回', desc: '清除本机全部个人数据', icon: 'trash' }
];

export default function MorePage() {
  const [press, setPress] = useState('');

  useEffect(() => {
    document.title = '更多 · 福小外';
  }, []);

  return (
    <div className="pm-page">
      <div className="pm-head">
        <button className="pm-back" onClick={() => navigate('/profile')} aria-label="返回">
          ←
        </button>
        <div className="pm-title">更多</div>
      </div>

      <div className="pm-body">
        <div className="pm-card">
          {ROWS.map((r, i) => (
            <Fragment key={r.key}>
              <button
                className="pm-row"
                data-press={press === r.key}
                onPointerDown={() => setPress(r.key)}
                onPointerUp={() => setPress('')}
                onPointerCancel={() => setPress('')}
                onPointerLeave={() => setPress('')}
                onClick={() => navigate(`/privacy/${r.key}`)}
              >
                <div className="pm-glyph pm-glyph--quiet">
                  <LineIcon name={r.icon} size={17} />
                </div>
                <div className="pm-row-main">
                  <div className="pm-row-title">{r.title}</div>
                  <div className="pm-row-desc">{r.desc}</div>
                </div>
                <div className="pm-row-arrow">›</div>
              </button>
              {i === ROWS.length - 1 ? null : <div className="pm-divider" />}
            </Fragment>
          ))}
        </div>

        <div className="pm-note">这些内容只描述本机数据的处理方式，不涉及任何云端账号。</div>
      </div>
    </div>
  );
}