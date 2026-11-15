import { useEffect, useState } from 'react';

import { useApp } from '../core/appState';
import { buildWeeks, describeRange } from '../core/courseFormat';
import { back, param, useRoute } from '../core/router';
import { TOTAL_WEEKS, weekdayText } from '../core/semester';
import { COURSE_PALETTE } from '../core/courseAppearance';
import { toast } from '../ui/toast';
import WheelPicker from '../ui/WheelPicker';

const PARITY = ['全部周', '单周', '双周'];
const WEEKDAYS = [1, 2, 3, 4, 5, 6, 7];
const CAMPUSES = ['长乐校区', '滨海校区'];

/** 数字加减器：− 数字 ＋，胶囊按钮 */
function StepSpin(props: {
  value: number;
  min: number;
  max: number;
  name: string;
  onChange: (v: number) => void;
}) {
  const { value, min, max, name, onChange } = props;
  return (
    <div className="pxs-spin">
      <button
        type="button"
        className="pxs-spin-btn"
        disabled={value <= min}
        onClick={() => onChange(value - 1)}
        aria-label={`减少${name}`}
      >
        −
      </button>
      <div className="pxs-spin-val">{value}</div>
      <button
        type="button"
        className="pxs-spin-btn pxs-spin-plus"
        disabled={value >= max}
        onClick={() => onChange(value + 1)}
        aria-label={`增加${name}`}
      >
        ＋
      </button>
    </div>
  );
}

export default function AddCoursePage() {
  const app = useApp();
  const { params } = useRoute();
  const editId = param<string>(params, 'id', '');
  const editing = editId ? app.courses.find((c) => c.id === editId) : undefined;

  const [name, setName] = useState(editing?.name ?? '');
  const [teacher, setTeacher] = useState(editing?.teacher ?? '');
  const [room, setRoom] = useState(editing?.room ?? '');
  const [campus, setCampus] = useState(editing?.campus ?? '长乐校区');
  const [campusOpen, setCampusOpen] = useState(false);
  const [campusDraft, setCampusDraft] = useState(0);
  const [weekday, setWeekday] = useState(editing?.weekday ?? 1);
  const [startPeriod, setStartPeriod] = useState(editing?.startPeriod ?? 1);
  const [endPeriod, setEndPeriod] = useState(editing?.endPeriod ?? 2);
  const [weekStart, setWeekStart] = useState(() => (editing ? describeRange(editing.weeks).from : 1));
  const [weekEnd, setWeekEnd] = useState(() => (editing ? describeRange(editing.weeks).to : 16));
  const [parity, setParity] = useState(() => (editing ? describeRange(editing.weeks).parity : 0));
  const [colorIndex, setColorIndex] = useState((editing?.colorOverride ? editing.colorIndex : (editing?.autoColorIndex ?? editing?.colorIndex ?? 0)) % COURSE_PALETTE.length);
  const [colorOverride, setColorOverride] = useState(editing?.colorOverride === true);
  const [err, setErr] = useState('');

  useEffect(() => {
    document.title = editing ? '编辑课程 · 福小外' : '添加课程 · 福小外';
  }, [editing]);

  const periods = app.periods;
  const periodMax = Math.max(1, periods.length);
  const weeks = buildWeeks(weekStart, weekEnd, parity);

  const weeksHint = (() => {
    if (weeks.length === 0) return '没有符合条件的周次';
    if (weeks.length === 1) return `第 ${weeks[0]} 周`;
    const parityText = parity === 1 ? '（单周）' : parity === 2 ? '（双周）' : '';
    return `${weekStart}–${weekEnd} 周${parityText} · 共 ${weeks.length} 周`;
  })();

  const timeLabel = (() => {
    if (periods.length === 0) return '';
    const s = periods[Math.min(startPeriod, periods.length) - 1];
    const e = periods[Math.min(endPeriod, periods.length) - 1];
    return `${s.start} – ${e.end}`;
  })();

  function save(): void {
    const nm = name.trim();
    if (nm.length === 0) {
      setErr('课程名不能为空');
      return;
    }
    if (startPeriod > endPeriod) {
      setErr('结束节次不能早于开始节次');
      return;
    }
    if (weekStart > weekEnd) {
      setErr('结束周不能早于开始周');
      return;
    }
    if (weeks.length === 0) {
      setErr('周次为空，检查一下单双周设置');
      return;
    }
    setErr('');
    const payload = {
      name: nm,
      teacher: teacher.trim(),
      room: room.trim(),
      campus: campus.trim(),
      weekday,
      startPeriod,
      endPeriod,
      weeks,
      colorIndex,
      ...(colorOverride ? {colorOverride:true} : {})
    };
    if (editing) {
      app.updateCourse({ ...editing, ...payload });
      toast('已保存修改');
    } else {
      app.addCourse(payload);
      toast('已添加');
    }
    back();
  }

  return (
    <div className="pxs-page">
      <div className="pxs-head pxs-head-52">
        <button type="button" className="pxs-back" onClick={back} aria-label="返回">
          ‹
        </button>
        <div className="pxs-title">{editing ? '编辑课程' : '添加课程'}</div>
        <button type="button" className="pxs-save" onClick={save}>
          保存
        </button>
      </div>

      <div className="pxs-scroll">
        {err ? <div className="pxs-err">{err}</div> : null}

        <div className="pxs-card">
          <label className="pxs-field">
            <span className="pxs-field-label">课程名 *</span>
            <input className="pxs-input" value={name} onChange={(e) => setName(e.target.value)} />
          </label>
          <label className="pxs-field">
            <span className="pxs-field-label">教师</span>
            <input className="pxs-input" value={teacher} onChange={(e) => setTeacher(e.target.value)} />
          </label>
          <div className="pxs-field-row">
            <label className="pxs-field">
              <span className="pxs-field-label">教室</span>
              <input className="pxs-input" value={room} onChange={(e) => setRoom(e.target.value)} />
            </label>
            <div className="pxs-field">
              <span className="pxs-field-label">校区</span>
              <span className="pxs-campus">
                <button type="button" className="pxs-input pxs-campus-trigger" aria-label="校区" aria-haspopup="dialog" aria-expanded={campusOpen} onClick={() => {
                  setCampusDraft(Math.max(0, CAMPUSES.indexOf(campus)));
                  setCampusOpen(true);
                }}>{campus}</button>
                <span className="pxs-campus-arrow" aria-hidden="true" />
              </span>
            </div>
          </div>
        </div>

        <div className="pxs-card">
          <div className="pxs-sec">
            <span className="pxs-sec-title">星期</span>
          </div>
          <div className="pxs-days">
            {WEEKDAYS.map((d) => (
              <button
                key={d}
                type="button"
                className="pxs-day"
                data-on={weekday === d}
                onClick={() => setWeekday(d)}
              >
                {weekdayText(d)}
              </button>
            ))}
          </div>
        </div>

        <div className="pxs-card">
          <div className="pxs-sec">
            <span className="pxs-sec-title">节次</span>
            <span className="pxs-sec-hint">共 {periods.length} 节</span>
          </div>
          <div className="pxs-row">
            <span className="pxs-spin-label pxs-spin-label-w40">开始</span>
            <StepSpin
              value={startPeriod}
              min={1}
              max={periodMax}
              name="开始节次"
              onChange={(v) => {
                setStartPeriod(v);
                if (endPeriod < v) setEndPeriod(v);
              }}
            />
            <span className="pxs-spin-gap" />
            <span className="pxs-spin-label pxs-spin-label-w40">结束</span>
            <StepSpin
              value={endPeriod}
              min={startPeriod}
              max={periodMax}
              name="结束节次"
              onChange={setEndPeriod}
            />
          </div>
          <div className="pxs-time">{timeLabel}</div>
        </div>

        <div className="pxs-card">
          <div className="pxs-sec">
            <span className="pxs-sec-title">周次</span>
            <span className="pxs-sec-hint">{weeksHint}</span>
          </div>
          <div className="pxs-row">
            <span className="pxs-spin-label pxs-spin-label-w28">从</span>
            <StepSpin
              value={weekStart}
              min={1}
              max={weekEnd}
              name="开始周"
              onChange={setWeekStart}
            />
            <span className="pxs-spin-gap" />
            <span className="pxs-spin-label pxs-spin-label-w28">到</span>
            <StepSpin
              value={weekEnd}
              min={weekStart}
              max={TOTAL_WEEKS}
              name="结束周"
              onChange={setWeekEnd}
            />
          </div>
          <div className="pxs-mini-row">
            {PARITY.map((label, i) => (
              <button
                key={label}
                type="button"
                className="pxs-chip"
                data-on={parity === i}
                onClick={() => setParity(i)}
              >
                {label}
              </button>
            ))}
            <span className="pxs-spin-gap" />
            <button
              type="button"
              className="pxs-chip"
              data-on={weekStart === 1 && weekEnd === TOTAL_WEEKS}
              onClick={() => {
                setWeekStart(1);
                setWeekEnd(TOTAL_WEEKS);
                setParity(0);
              }}
            >
              整学期
            </button>
          </div>
        </div>

        <div className="pxs-card">
          <div className="pxs-sec">
            <span className="pxs-sec-title">颜色</span>
          </div>
          <div className="pxs-colors">
            {COURSE_PALETTE.map((color, i) => (
              <button
                key={color}
                type="button"
                className="pxs-color"
                onClick={() => { setColorIndex(i); setColorOverride(true); }}
                aria-label={`颜色 ${i + 1}`}
              >
                {colorIndex === i ? (
                  <span className="pxs-color-ring" style={{ borderColor: color }} />
                ) : null}
                <span
                  className="pxs-color-dot"
                  style={{ background: color, borderColor: color }}
                />
              </button>
            ))}
          </div>
        </div>

        {err ? <div className="pxs-err-bottom">{err}</div> : null}

        <div className="pxs-note">
          手动添加的课程保存在本课表；从教务重新同步会整表替换，手加课会被覆盖
        </div>
      </div>
      {campusOpen && (
        <div className="wheel-mask" onClick={() => setCampusOpen(false)}>
          <div className="wheel-sheet" role="dialog" aria-modal="true" aria-label="选择校区" onClick={(e) => e.stopPropagation()} onKeyDown={(e) => { if (e.key === 'Escape') setCampusOpen(false); }}>
            <div className="wheel-head">
              <span className="wheel-title">选择校区</span>
              <button type="button" className="wheel-done" onClick={(e) => {
                const scroll = e.currentTarget.closest('.wheel-sheet')?.querySelector('.wheel-scroll');
                const index = scroll ? Math.max(0, Math.min(CAMPUSES.length - 1, Math.round(scroll.scrollTop / 44))) : campusDraft;
                setCampus(CAMPUSES[index]);
                setCampusOpen(false);
              }}>完成</button>
            </div>
            <WheelPicker items={CAMPUSES} index={campusDraft} onPick={setCampusDraft} />
          </div>
        </div>
      )}
    </div>
  );
}

