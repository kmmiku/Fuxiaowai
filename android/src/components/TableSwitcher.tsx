/** 课表切换：方块列表 + 管理态（右上角 × 删除、长按重命名） */

import { useState } from 'react';

import type { TableOption } from '../core/types';

export interface TableSwitcherProps {
  tables: TableOption[];
  activeId: string;
  onSwitch: (id: string) => void;
  onCreate: () => void;
  onDelete: (t: TableOption) => void;
  onRename: (t: TableOption) => void;
}

export default function TableSwitcher({
  tables,
  activeId,
  onSwitch,
  onCreate,
  onDelete,
  onRename
}: TableSwitcherProps) {
  const [managing, setManaging] = useState(false);
  const longPress = useLongPress((t: TableOption) => onRename(t));

  return (
    <div className="tableswitcher no-select">
      <div className="ts-head">
        <span className="ts-title">切换课表</span>
        <button className="ts-manage" onClick={onCreate}>新建课表</button>
        <button className="ts-manage" onClick={() => setManaging((m) => !m)}>
          {managing ? '完成' : '管理课表'}
        </button>
      </div>

      <div className="ts-list">
        {tables.map((t) => {
          const sel = t.id === activeId;
          return (
            <div
              key={t.id}
              className="ts-block"
              data-sel={sel}
              onClick={() => onSwitch(t.id)}
              {...longPress.bind(t)}
            >
              <svg className="ts-check" width="28" height="28" viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12 5 5 9-12" fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="miter" strokeLinecap="butt" /></svg>
              <span className="ts-name">{t.name}</span>
              {managing && tables.length > 1 && (
                <button
                  className="ts-del"
                  onClick={(e) => {
                    e.stopPropagation();
                    onDelete(t);
                  }}
                >
                  ×
                </button>
              )}
            </div>
          );
        })}

        <button className="ts-block ts-add" onClick={onCreate}>
          <span className="ts-addtext">＋ 新建</span>
        </button>
      </div>

      {managing && (
        <div className="ts-hint">点方块右上角 × 删除，长按方块可重命名</div>
      )}
    </div>
  );
}

/** 长按 420ms 触发；返回可直接展开到元素上的事件处理器 */
function useLongPress(onFire: (t: TableOption) => void) {
  let timer: number | undefined;
  let fired = false;

  const start = (t: TableOption) => {
    fired = false;
    timer = window.setTimeout(() => {
      fired = true;
      onFire(t);
    }, 420);
  };
  const clear = () => {
    if (timer) window.clearTimeout(timer);
    timer = undefined;
  };

  return {
    bind: (t: TableOption) => ({
      onPointerDown: () => start(t),
      onPointerUp: clear,
      onPointerLeave: clear,
      onPointerCancel: clear,
      onContextMenu: (e: React.MouseEvent) => {
        e.preventDefault();
        if (!fired) onFire(t);
      }
    })
  };
}
