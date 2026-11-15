/**
 * 校历页：自绘月历（1:1 还原鸿蒙版 pages/AcademicCalendar.ets）。
 *
 * 数据来自 core/schoolCalendar.ts（人工解析自 2026-2027 学年校历图），
 * 逐月渲染，今天用红色圆环圈出来，放假/考试日下方有一个彩色圆点，卡片底部列出当月安排。
 */

import { useEffect, useRef, useState } from 'react';

import { toast } from '../ui/toast';
import {
  CAL_TERMS,
  eventOfDay,
  eventsOfMonth,
  isToday,
  kindColor,
  monthRows,
  termIndexOfToday,
  weekOfTerm
} from '../core/schoolCalendar';
import type { CalMonth, CalTerm } from '../core/schoolCalendar';

const WEEK_HEAD = ['日', '一', '二', '三', '四', '五', '六'];
/** 教务处原文（鸿蒙版用 startAbility 打开，这里换 window.open） */
const SOURCE_URL = 'https://www.fzfu.com/jwc/info/1084/5556.htm';

/** 一天的格子：日期圆圈 + 下方 4×4 事件圆点；day 为 0 表示空位 */
function DayCell({ year, month, day, term }: { year: number; month: number; day: number; term: CalTerm }) {
  if (day === 0) return <div className="px-cal-cell" />;

  const today = isToday(year, month, day);
  const wd = new Date(year, month - 1, day).getDay();
  const e = eventOfDay(term, month, day);
  const cls = `px-cal-day${today ? ' today' : wd === 0 || wd === 6 ? ' weekend' : ''}`;

  return (
    <div className="px-cal-cell">
      <span className={cls}>{day}</span>
      <span className="px-cal-dot" style={{ background: e ? kindColor(e.kind) : 'transparent' }} />
    </div>
  );
}

/** 一张月卡：标题（本月胶囊）+ 星期头 + 日期网格 + 当月事件 */
function MonthCard({ term, cm }: { term: CalTerm; cm: CalMonth }) {
  const rows = monthRows(cm.year, cm.month);
  const events = eventsOfMonth(term, cm.year, cm.month);

  return (
    <div className="px-cal-month" data-cal-month={`${cm.year}-${cm.month}`}>
      <div className="px-cal-month-head">
        <div className="px-cal-month-title">{`${cm.year} 年 ${cm.month} 月`}</div>
      </div>

      <div className="px-cal-weekhead">
        {WEEK_HEAD.map((w, i) => (
          <div className="px-cal-weekday" key={w} data-weekend={i === 0 || i === 6}>
            {w}
          </div>
        ))}
      </div>

      {rows.map((row, ri) => (
        <div className="px-cal-row" key={`${cm.year}-${cm.month}-${ri}`}>
          {row.map((d, ci) => (
            <DayCell
              key={`${cm.month}-${ri}-${ci}-${d}`}
              year={cm.year}
              month={cm.month}
              day={d}
              term={term}
            />
          ))}
        </div>
      ))}

      {events.length > 0 && (
        <>
          <div className="px-cal-line" />
          <div className="px-cal-events">
            {events.map((e) => (
              <div className="px-cal-event" key={`${e.month}-${e.day}-${e.title}`}>
                <span className="px-cal-event-dot" style={{ background: kindColor(e.kind) }} />
                <span className="px-cal-event-date">{`${e.month} 月 ${e.day} 日`}</span>
                <span className="px-cal-event-title">{e.title}</span>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

export default function AcademicCalendar() {
  /** 0 = 第一学期，1 = 第二学期；进来先定位到今天所在学期（对应 aboutToAppear） */
  const [tab, setTab] = useState(() => {
    const i = termIndexOfToday();
    return i >= 0 ? i : 0;
  });

  const scrollRef = useRef<HTMLDivElement>(null);


  // 进页面后从顶部平滑滑到当前月份并居中（先快后慢）
  useEffect(() => {
    const box = scrollRef.current;
    if (!box) return;
    const now = new Date();
    const target = box.querySelector<HTMLElement>(
      `[data-cal-month="${now.getFullYear()}-${now.getMonth() + 1}"]`
    );
    if (!target) return;
    const boxRect = box.getBoundingClientRect();
    const tRect = target.getBoundingClientRect();
    const dest = Math.max(
      0,
      box.scrollTop + (tRect.top - boxRect.top) + tRect.height / 2 - boxRect.height / 2
    );
    const timer = window.setTimeout(() => {
      const start = box.scrollTop;
      const dist = dest - start;
      if (Math.abs(dist) < 4) return;
      const dur = 900;
      const t0 = performance.now();
      const ease = (p: number): number => 1 - Math.pow(1 - p, 3);
      const step = (t: number): void => {
        const p = Math.min(1, (t - t0) / dur);
        box.scrollTop = start + dist * ease(p);
        if (p < 1) window.requestAnimationFrame(step);
      };
      window.requestAnimationFrame(step);
    }, 260);
    return () => window.clearTimeout(timer);
  }, [tab]);

  useEffect(() => {
    document.title = '校历 · 福小外';
  }, []);

  const cur: CalTerm = CAL_TERMS[tab];
  const weekNow = weekOfTerm(cur, new Date());

  function openSource() {
    const w = window.open(SOURCE_URL, '_blank');
    if (w) {
      w.opener = null;
      return;
    }
    toast('没有可用的浏览器');
  }

  return (
    <div className="page px-cal">
      {/* ---------- 标题 ---------- */}
      <div className="px-cal-head no-select">
        <div className="px-cal-title">校历</div>
        <button className="px-cal-link" onClick={openSource}>
          原文
        </button>
      </div>

      {/* ---------- 学期滑块 ---------- */}
      <div className="px-cal-seg no-select" data-tab={tab}>
        <div className="px-cal-thumb" />
        <div className="px-cal-seg-items">
          {CAL_TERMS.map((t, i) => (
            <button
              key={t.key}
              className="px-cal-seg-item"
              data-on={tab === i}
              onClick={() => setTab(i)}
            >
              {t.label}
            </button>
          ))}
        </div>
      </div>

      {/* ---------- 第 N 周 ---------- */}
      <div className="px-cal-week no-select">
        <span className="px-cal-week-now">{weekNow > 0 ? `第 ${weekNow} 周` : '不在学期内'}</span>
        <span className="px-cal-week-total">{`· 共 ${cur.weeks} 周`}</span>
        <span className="px-cal-week-legend">红圈 = 今天</span>
      </div>

      {/* ---------- 月卡列表 + 学期安排 ---------- */}
      <div className="px-cal-scroll no-scrollbar" ref={scrollRef}>
        {cur.months.map((cm) => (
          <MonthCard key={`${cm.year}-${cm.month}`} term={cur} cm={cm} />
        ))}

        <div className="px-cal-summary">
          <div className="px-cal-summary-title">学期安排</div>
          {cur.summary.map((line) => (
            <div className="px-cal-summary-line" key={line}>
              {line}
            </div>
          ))}
        </div>
      </div>

      {/* ---------- 来源 ---------- */}
      <div className="px-cal-source">来源：福州外语外贸学院教务处 · 2026-2027 学年校历</div>

    </div>
  );
}
