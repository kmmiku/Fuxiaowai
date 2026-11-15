import { useEffect, useState } from 'react';

import { useApp } from '../core/appState';
import { back } from '../core/router';
import { DEFAULT_PERIODS, type Period } from '../core/types';
import { toast } from '../ui/toast';

/** "HH:mm" → 分钟数；非法值返回 -1 */
function toMinutes(t: string): number {
  const m = /^(\d{1,2}):(\d{2})$/.exec(t);
  if (!m) return -1;
  return Number(m[1]) * 60 + Number(m[2]);
}

/** 分钟数 → "HH:mm"（跨天回绕） */
function toTime(n: number): string {
  const v = ((n % 1440) + 1440) % 1440;
  const h = Math.floor(v / 60);
  const mm = v % 60;
  return `${String(h).padStart(2, '0')}:${String(mm).padStart(2, '0')}`;
}

function clone(list: Period[]): Period[] {
  return list.map((p) => ({ ...p }));
}

export default function PeriodSettings() {
  const app = useApp();
  const [list, setList] = useState<Period[]>(() => clone(app.periods));
  const [dirty, setDirty] = useState(false);

  useEffect(() => {
    document.title = '上课时间 · 福小外';
  }, []);

  function patchStart(i: number, value: string): void {
    setList((prev) => {
      const next = clone(prev);
      next[i].start = value;
      const s = toMinutes(value);
      const e = toMinutes(next[i].end);
      if (s >= 0 && (e < 0 || e <= s)) {
        next[i].end = toTime(s + 45);
      }
      return next;
    });
    setDirty(true);
  }

  function patchEnd(i: number, value: string): void {
    setList((prev) => {
      const next = clone(prev);
      next[i].end = value;
      return next;
    });
    setDirty(true);
  }

  function addPeriod(): void {
    setList((prev) => {
      const next = clone(prev);
      const last = next[next.length - 1];
      const start = last && toMinutes(last.end) >= 0 ? toMinutes(last.end) + 10 : 18 * 60 + 30;
      next.push({ index: next.length + 1, start: toTime(start), end: toTime(start + 45) });
      return next;
    });
    setDirty(true);
  }

  function removePeriod(i: number): void {
    if (list.length <= 1) return;
    setList((prev) =>
      clone(prev)
        .filter((_, k) => k !== i)
        .map((p, k) => ({ ...p, index: k + 1 }))
    );
    setDirty(true);
    toast('已删除，记得保存');
  }

  function restore(): void {
    setList(clone(DEFAULT_PERIODS));
    setDirty(true);
    toast('已恢复默认，记得保存');
  }

  function save(): void {
    for (const p of list) {
      const s = toMinutes(p.start);
      const e = toMinutes(p.end);
      if (s < 0 || e < 0 || e <= s) {
        toast('结束时间要晚于开始时间');
        return;
      }
    }
    app.setPeriods(list.map((p, i) => ({ ...p, index: i + 1 })));
    setDirty(false);
    try {
      toast('已保存，课表同步更新');
      window.setTimeout(back, 500);
    } catch {
      toast('保存失败');
    }
  }

  function goBack(): void {
    if (dirty) toast('有未保存的修改，点『保存』后生效');
    back();
  }

  return (
    <div className="pxs-page">
      <div className="pxs-head">
        <button type="button" className="pxs-back" onClick={goBack} aria-label="返回">
          ‹
        </button>
        <div className="pxs-title">上课时间</div>
        <button type="button" className="pxs-add" onClick={addPeriod}>
          ＋ 添加
        </button>
      </div>

      <div className="pxs-sub">共 {list.length} 节 · 点任意一节用滚轮改时间</div>

      <div className="pxs-list">
        {list.map((p, i) => (
          <div className="pxs-item" key={i}>
            <span className="pxs-item-index">{p.index}</span>
            <span className="pxs-item-title">第 {p.index} 节</span>
            <span className="pxs-tl">开始</span>
            <input
              type="time"
              className="pxs-timeinput"
              value={p.start}
              onChange={(e) => patchStart(i, e.target.value)}
              aria-label={`第 ${p.index} 节开始时间`}
            />
            <span className="pxs-dash">–</span>
            <span className="pxs-tl">结束</span>
            <input
              type="time"
              className="pxs-timeinput"
              value={p.end}
              onChange={(e) => patchEnd(i, e.target.value)}
              aria-label={`第 ${p.index} 节结束时间`}
            />
            <button
              type="button"
              className="pxs-del"
              disabled={list.length <= 1}
              onClick={() => removePeriod(i)}
              aria-label="删除本节"
            >
              ×
            </button>
          </div>
        ))}
      </div>

      <div className="pxs-foot">
        <button type="button" className="pxs-btn pxs-btn-ghost" onClick={restore}>
          恢复默认
        </button>
        <button type="button" className="pxs-btn pxs-btn-primary" onClick={save}>
          保存
        </button>
      </div>
    </div>
  );
}