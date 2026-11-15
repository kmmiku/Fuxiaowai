import { useEffect } from 'react';

import { useApp } from '../core/appState';
import { navigate } from '../core/router';
import { toast } from '../ui/toast';

/** 主题名先固定默认，后续接入配色方案时只改这里 */
const THEME_LABEL = '默认';

/** 外观设置：深色模式 / 主题（对齐鸿蒙 AppearancePage.ets） */
export default function AppearancePage() {
  const app = useApp();
  const s = app.settings;

  useEffect(() => {
    document.title = '外观设置 · 福小外';
  }, []);

  return (
    <div className="page px-appearance">
      <div className="nav">
        <button className="nav-back" onClick={() => navigate('/home')} aria-label="返回">
          ‹
        </button>
        <div className="nav-title">外观设置</div>
        <div className="nav-right" />
      </div>

      <div className="pxa-scroll no-scrollbar">
        <div className="pxa-card">
          <div className="pxa-row">
            <div className="pxa-main">
              <div className="pxa-title">深色模式</div>
              <div className="pxa-sub">夜间看课表不刺眼</div>
            </div>
            <button
              className={`switch${s.dark ? ' on' : ''}`}
              onClick={() => {
                const next = !s.dark;
                app.updateSettings({ dark: next });
                toast(next ? '已切到夜间模式' : '已切回浅色');
              }}
              aria-label="深色模式"
            >
              <i />
            </button>
          </div>

          <div className="pxa-divider" />

          <button className="pxa-row pxa-tap" onClick={() => toast('主题功能即将上线')}>
            <div className="pxa-main">
              <div className="pxa-title">主题</div>
              <div className="pxa-sub">课程表配色与卡片风格</div>
            </div>
            <div className="pxa-value">{THEME_LABEL}</div>
            <div className="pxa-arrow">›</div>
          </button>
        </div>

        <div className="pxa-note">设置即时生效，回到课表即可看到。</div>
      </div>
    </div>
  );
}