import { useEffect, useMemo, useState } from 'react';

import { useApp } from '../core/appState';
import { COURSE_COLORS } from '../components/CourseBlock';
import { courseBrief, weeksLabel } from '../core/courseFormat';
import { navigate } from '../core/router';

/** 已添加课程：列出当前课表全部课程，可按课名/教师/教室搜索（对齐鸿蒙 CourseListPage.ets） */
export default function CourseListPage() {
  const app = useApp();
  const [keyword, setKeyword] = useState('');

  useEffect(() => {
    document.title = '已添加课程 · 福小外';
  }, []);

  const all = useMemo(
    () =>
      [...app.courses].sort(
        (a, b) => a.weekday - b.weekday || a.startPeriod - b.startPeriod
      ),
    [app.courses]
  );

  const list = useMemo(() => {
    const k = keyword.trim();
    if (!k) return all;
    return all.filter((c) => c.name.includes(k) || c.teacher.includes(k) || c.room.includes(k));
  }, [all, keyword]);

  const tableName = app.tables.find((t) => t.id === app.activeTableId)?.name ?? '我的课表';

  return (
    <div className="page px-courselist">
      <div className="nav pxcl-nav">
        <button className="nav-back" onClick={() => navigate('/home')} aria-label="返回">
          ‹
        </button>
        <div className="pxcl-head">
          <div className="nav-title">已添加课程</div>
          <div className="pxcl-sub">
            {tableName} · 共 {all.length} 门
          </div>
        </div>
      </div>

      <div className="pxcl-search">
        <span className="pxcl-icon">⌕</span>
        <input
          className="pxcl-input"
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
          aria-label="搜索课程"
        />
      </div>

      {list.length === 0 ? (
        <div className="pxcl-empty">
          <div className="pxcl-empty-title">{all.length === 0 ? '还没有课程' : '没有匹配的课程'}</div>
          <div className="pxcl-empty-sub">
            {all.length === 0 ? '点首页 ⇩ 用教务账号导入' : '换个关键词试试'}
          </div>
        </div>
      ) : (
        <div className="pxcl-list no-scrollbar">
          {list.map((c) => {
            const [, fg] = COURSE_COLORS[c.colorIndex % COURSE_COLORS.length];
            return (
              <div className="pxcl-item" key={c.id}>
                <div className="pxcl-bar" style={{ background: fg }} />
                <div className="pxcl-main">
                  <div className="pxcl-name">{c.name}</div>
                  <div className="pxcl-brief">{courseBrief(c)}</div>
                  <div className="pxcl-weeks">{weeksLabel(c.weeks)}</div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}