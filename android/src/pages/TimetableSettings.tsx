import { useState } from 'react';

import { useApp } from '../core/appState';
import { back } from '../core/router';
import { CELL_MAX, CELL_MIN } from '../core/store';
import TimetableGrid from '../components/TimetableGrid';

export default function TimetableSettings() {
  const app = useApp();
  const s = app.settings;
  const [dragging, setDragging] = useState(false);
  // 拖动过程中用本地值渲染，松手才落盘
  const [liveCell, setLiveCell] = useState(s.cellHeight);

  function commitCell(v: number): void {
    setLiveCell(v);
    setDragging(true);
  }

  function save(): void {
    setDragging(false);
    app.updateSettings({ cellHeight: liveCell });
  }

  return (
    <div className="pxs-page pxs-page-preview">
      {/* 背景课表：拖动时透出来，和首页排版一致 */}
      <div className="pxs-preview" style={{ opacity: dragging ? 1 : 0.5 }}>
        <TimetableGrid
          courses={app.courses}
          week={app.week}
          periods={app.periods}
          showWeekend
          showGhost={s.showGhost}
          cellHeight={liveCell}
        />
      </div>

      <div className="pxs-sheet" style={{ opacity: dragging ? 0.45 : 1 }}>
        <div className="pxs-head">
          <button type="button" className="pxs-back" onClick={back} aria-label="返回">
            ‹
          </button>
          <div className="pxs-title">课表设置</div>
          {dragging && <div className="pxs-live">实时预览</div>}
        </div>

        <div className="pxs-card-flat">
          <div className="pxs-srow">
            <div className="pxs-srow-main">
              <div className="pxs-srow-title">显示非本周课表</div>
              <div className="pxs-srow-sub">其他周有课、本周不上，浅色显示</div>
            </div>
            <button
              type="button"
              className={`switch${s.showGhost ? ' on' : ''}`}
              data-on={s.showGhost}
              onClick={() => app.updateSettings({ showGhost: !s.showGhost })}
              aria-label="显示非本周课表"
            />
          </div>
        </div>

        <div className="pxs-card-flat pxs-card-gap">
          <div className="pxs-block-head">
            <div className="pxs-srow-title">格子高度</div>
            <div className="pxs-srow-value">{liveCell} vp</div>
          </div>
          <input
            className="pxs-range"
            type="range"
            min={CELL_MIN}
            max={CELL_MAX}
            step={1}
            value={liveCell}
            onChange={(e) => commitCell(Number(e.target.value))}
            onPointerUp={save}
            onKeyUp={save}
          />
        </div>

        <div className="pxs-tip">拖动滑块时，背后的课表会实时变化；松手自动保存</div>
      </div>
    </div>
  );
}