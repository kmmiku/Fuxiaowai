import { useEffect, useState } from 'react';

import { useApp } from '../core/appState';
import { clearReminders, planWeekReminders } from '../core/remind';
import { back } from '../core/router';
import { toast } from '../ui/toast';

const MINUTES = [5, 10, 15, 30];

/** 上课提醒：手动按本周生成（对齐鸿蒙 RemindPage） */
export default function RemindPage() {
  const app = useApp();
  const before = app.settings.remindBefore;
  const on = before > 0;
  const calendarRemind = app.settings.calendarRemind;
  const week = app.week;
  const [busy, setBusy] = useState(false);
  const [hint, setHint] = useState('');

  useEffect(() => {
    document.title = '上课提醒 · 福小外';
  }, []);

  /* 关掉开关时清空已排的提醒；打开不自动排，等用户点按钮 */
  useEffect(() => {
    if (before <= 0) {
      void clearReminders().catch(e=>setHint('清除提醒失败：'+(e instanceof Error?e.message:String(e))));
      setHint('');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [before]);

  async function generate() {
    if (busy) return;
    if (!on) {
      toast('先开启上课提醒');
      return;
    }
    setBusy(true);
    setHint('正在排提醒…');
    try {
      const r = await planWeekReminders(app.courses, app.periods, before, week);
      if (r.denied) {
        setHint('系统通知权限未授予，请在系统设置中允许通知后重试');
        toast('系统通知权限被拒绝，提醒发不出来');
        return;
      }
      if (r.scheduled === 0) {
        setHint('本周剩余时间没有可提醒的课');
        return;
      }
      const tail = r.skipped > 0 ? `，超出系统上限的 ${r.skipped} 条已略过` : '';
      setHint(`已排 ${r.scheduled} 条提醒（第 ${week} 周剩余课程）${tail}`);
      toast(`已排 ${r.scheduled} 条提醒`);
    } catch (e) {
      setHint('排提醒失败：' + (e instanceof Error ? e.message : String(e)));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="pxs-page">
      <div className="pxs-head">
        <button type="button" className="pxs-back" onClick={back} aria-label="返回">
          ‹
        </button>
        <div className="pxs-title">上课提醒</div>
      </div>

      <div className="pxs-rem-card">
        <div className="pxs-srow">
          <div className="pxs-srow-main">
            <div className="pxs-srow-title">开启上课提醒</div>
            <div className="pxs-srow-sub">每节课开始前提醒一次</div>
          </div>
          <button
            type="button"
            className={`switch${on ? ' on' : ''}`}
            data-on={on}
            onClick={() => app.updateSettings({ remindBefore: on ? 0 : 15 })}
            aria-label="开启上课提醒"
          />
        </div>
        <div className="pxs-line" />
        <div className="pxs-rem-row" data-off={!on}>
          <div className="pxs-srow-title">提前</div>
          <div className="pxs-rem-chips">
            {MINUTES.map((m) => (
              <button
                key={m}
                type="button"
                className="pxs-rem-chip"
                data-on={before === m}
                onClick={() => app.updateSettings({ remindBefore: m })}
              >
                {m} 分钟
              </button>
            ))}
          </div>
        </div>
        <div className="pxs-line" />
        <button type="button" className="pxs-rem-gen" disabled={busy || !on} onClick={generate}>
          {busy ? '正在排提醒…' : '按本周课表生成提醒'}
        </button>
      </div>

      <div className="pxs-rem-card">
        <div className="pxs-srow">
          <div className="pxs-srow-main">
            <div className="pxs-srow-title">日程提醒</div>
            <div className="pxs-srow-sub">导出到系统日历时，也带上提前提醒</div>
          </div>
          <button
            type="button"
            className={`switch${calendarRemind ? ' on' : ''}`}
            data-on={calendarRemind}
            onClick={() => app.updateSettings({ calendarRemind: !calendarRemind })}
            aria-label="日程提醒"
          />
        </div>
      </div>

      {hint ? <div className="pxs-rem-hint">{hint}</div> : null}

      <div className="pxs-rem-note">
        提醒由系统代理发布，应用退到后台也能触发；换周或改上课时间后建议重新生成一次。
        日程提醒只影响「导出到系统日历」里那些日程自带的提醒。
      </div>
    </div>
  );
}