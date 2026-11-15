import { useEffect } from 'react';

import { navigate } from '../core/router';

const STEPS: [string, string, string][] = [
  ['①', '长按桌面空白处', '进入桌面编辑态'],
  ['②', '点左上角「服务卡片」', '或长按应用图标选卡片'],
  ['③', '找到「福小外」', '选 2×4 今日课程卡片'],
  ['④', '拖到桌面', '自动显示今天的课']
];

/** 桌面小组件说明（对齐鸿蒙 WidgetGuide.ets） */
export default function WidgetGuide() {
  useEffect(() => {
    document.title = '桌面小组件 · 福小外';
  }, []);

  return (
    <div className="page px-widget">
      <div className="nav">
        <button className="nav-back" onClick={() => navigate('/home')} aria-label="返回">
          ‹
        </button>
        <div className="nav-title">桌面小组件</div>
        <div className="nav-right" />
      </div>

      <div className="pxw-scroll no-scrollbar">
        <div className="pxw-preview">
          <div className="pxw-head">
            <span className="pxw-day">今天 · 周一</span>
            <span className="pxw-week">第11周</span>
          </div>

          <div className="pxw-line">
            <span className="pxw-time">08:25</span>
            <div className="pxw-block" style={{ background: '#EDEBFD' }}>
              <div className="pxw-name">高级数据库技术</div>
              <div className="pxw-meta">教4203 · 梁艳</div>
            </div>
          </div>

          <div className="pxw-line pxw-line-sm">
            <span className="pxw-time">10:15</span>
            <div className="pxw-block" style={{ background: '#FDF0E3' }}>
              <div className="pxw-name">高性能系统架构</div>
            </div>
          </div>
        </div>

        <div className="pxw-caption">卡片效果预览</div>

        <div className="pxw-steps">
          {STEPS.map(([num, title, sub], i) => (
            <div key={num} className="pxw-step-wrap">
              <div className="pxw-step">
                <span className="pxw-num">{num}</span>
                <div className="pxw-step-main">
                  <div className="pxw-step-title">{title}</div>
                  <div className="pxw-step-sub">{sub}</div>
                </div>
              </div>
              {i < STEPS.length - 1 && <div className="pxw-divider" />}
            </div>
          ))}
        </div>

        <div className="pxw-note">
          卡片数据来自本机课表，每 30 分钟自动刷新一次，每天 06:10 另外更新一次；当天没有课时会显示「今天没有课」。
        </div>
      </div>
    </div>
  );
}