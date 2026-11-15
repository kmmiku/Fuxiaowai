import { checkAppUpdate } from '../core/appUpdate';
import TimetableIcon from '../ui/TimetableIcon';
import { atomic } from '../core/persistence';
import { saveCourses, savePeriods, loadCourses } from '../core/store';
import { saveTerm } from '../core/termStore';
import { accountToken, isCurrent, schoolTask } from '../core/accountScope';
import { commitTimetable } from '../core/timetableSync';
import { loadActiveTable } from '../core/store';
/**
 * 首页：周课表 / 日视图（Y 轴翻面）+ 周次侧滑 + 三点菜单、px 过冲回弹。 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { useApp } from '../core/appState';
import { navigate } from '../core/router';
import {
  TERM_LABEL,
  TOTAL_WEEKS,
  currentWeek,
  weekDates,
  weekRangeLabel
} from '../core/semester';
import { isInWeek, type Course, type TableOption } from '../core/types';
import { fmtTime, loadCredential } from '../core/store';
import {
  currentSemester,
  ensureJwSession,
  fetchTimetable,
  login,
  persistJwSession
} from '../core/zhengfang';
import { silentPortalLogin } from '../core/portal';
import { resetSession } from '../core/session';
import { nextClassLabel, nextClassOf } from '../core/nextClass';
import { extractShareCode, fetchShare, toLocalCourses, uploadShare, type ShareSnapshot } from '../core/share';
import { buildWeekText } from '../core/shareText';
import { buildEvents, exportCourses, DEFAULT_REMIND } from '../core/calendar';
import { toast } from '../ui/toast';
import WheelPicker from '../ui/WheelPicker';

/** 自定义提醒可选分钟（滚轮 5–90） */
const WHEEL_MINUTES: number[] = Array.from({ length: 86 }, (_, i) => i + 5);

/** 不是 0 / 10 / 15 就算自定义 */
const isCustomRemind = (m: number): boolean => m !== 0 && m !== 10 && m !== 15;

import WeekBar from '../components/WeekBar';
import TimetableGrid from '../components/TimetableGrid';
import DayList from '../components/DayList';
import MenuSheet from '../components/MenuSheet';
import TableSwitcher from '../components/TableSwitcher';
import CourseDetailSheet from '../components/CourseDetailSheet';

/* 与鸿蒙版一致的密度高度 */
/** 与鸿蒙 Index.ets 的 menuHeight 一致：448（面板顶落在 57% 屏高） */
const MENU_H = 448;
const FLIP_MS = 190;
/** 翻周动画时长，与鸿蒙 Swiper.duration 一致 */
const WEEK_MS = 200;

export default function HomePage() {
  const app = useApp();
  const { week, setWeek, settings, periods, courses, tables, activeTableId } = app;

  const [isDay, setIsDay] = useState(false);
  const [flip, setFlip] = useState(0);

  /* 课程详情弹层 */
  const [detail, setDetail] = useState<Course | null>(null);
  const [detailAllWeeks, setDetailAllWeeks] = useState(false);

  const [menuOpen, setMenuOpen] = useState(false);
  const [menuOffset, setMenuOffset] = useState(MENU_H + 60);
  const [menuMask, setMenuMask] = useState(0);
  const [menuTrans, setMenuTrans] = useState('none');

  /* 课表管理弹层：新建 / 重命名 / 删除确认 */
  const [tableSheet, setTableSheet] = useState<{ mode: 'create' | 'rename'; id?: string } | null>(null);
  const [tableName, setTableName] = useState('');
  const [confirmDel, setConfirmDel] = useState<TableOption | null>(null);

  /* 已导入过课表时，再点导入先确认是否重新导入（与鸿蒙一致） */
  const [reloginAsk, setReloginAsk] = useState<{ when: string; count: number } | null>(null);

  /* 转发面板：分享口令 / 从口令导入 */
  const [forwardOpen, setForwardOpen] = useState(false);
  const [codeCard, setCodeCard] = useState<{ text: string; online: boolean } | null>(null);
  const [codeBusy, setCodeBusy] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const [importCode, setImportCode] = useState('');
  const [importBusy, setImportBusy] = useState(false);
  const [importPreview, setImportPreview] = useState<ShareSnapshot | null>(null);
  const importRequest = useRef(0);
  const importScope = useRef<{token: number; table: string} | null>(null);
  useEffect(() => {
    importRequest.current++;
    importScope.current = null;
    setImportPreview(null);
    setImportBusy(false);
  }, [activeTableId, app.credential?.user, importOpen]);

  /* 导出到日程确认 */
  const [exportAsk, setExportAsk] = useState<{ total: number; names: number; reminder: number } | null>(
    null
  );

  /* 自定义提醒：滚轮 + 3 秒提示 */
  const [wheelOpen, setWheelOpen] = useState(false);
  const [wheelIdx, setWheelIdx] = useState(25); // 30 分钟
  const [remindTip, setRemindTip] = useState('');

  useEffect(() => {
    if (!remindTip) return undefined;
    const t = window.setTimeout(() => setRemindTip(''), 3000);
    return () => window.clearTimeout(t);
  }, [remindTip]);

  const cellHeight = settings.cellHeight;
  const wd = useMemo(() => weekDates(week), [week, activeTableId, courses]);
  const todayW = currentWeek(TOTAL_WEEKS);

  const nextHint = useMemo(() => {
    const n = nextClassOf(courses, periods, week);
    if (n) return nextClassLabel(n);
    const cnt = courses.filter((c) => isInWeek(c, week)).length;
    return cnt > 0 ? `第${week}周共 ${cnt} 节课` : `第${week}周没有课`;
  }, [courses, periods, week]);

  /* ---------- 导入课表：已导入过就先确认，避免覆盖手动加的课。 ---------- */

  const openImport = useCallback(() => {
    const cred = loadCredential();
    if (!cred || !cred.user || courses.length === 0) {
      navigate('/login');
      return;
    }
    setReloginAsk({
      when: cred.lastSyncAt ? fmtTime(cred.lastSyncAt) : '从未同步',
      count: courses.length
    });
  }, [courses.length]);

  /* ---------- 翻面 ---------- */

  const toggleView = useCallback(() => {
    if (flip !== 0) return;
    setFlip(90);
    window.setTimeout(() => {
      setIsDay((d) => !d);
      setFlip(-90);
      window.setTimeout(() => setFlip(0), 24);
    }, FLIP_MS);
  }, [flip]);

  /* ---------- 翻周：三页横排，跟手拖动时实时露出邻周（对齐鸿蒙 Swiper） ---------- */

  const gridRef = useRef<HTMLDivElement>(null);
  const trackRef = useRef<HTMLDivElement>(null);
  const gridW = useRef(0);
  const xRef = useRef(0);
  const drag = useRef({ x: 0, y: 0, active: false, locked: false });

  /**
   * 三页横排（上一周 / 本周 / 下一周），轨道宽 300%。
   * 「居中页」轨道整体左移三分之一，让第 2 页落在视口里。
   * 拖动时在这个基线上叠加像素位移，邻周实时露出来（预加载）。
   */
  const TRACK_CENTER = 'translate3d(-33.333333%, 0, 0)';
  const atX = (dx: number) => `translate3d(calc(-33.333333% + ${dx}px), 0, 0)`;

  /** 直接改 DOM transform：跟手拖动不触发 React 渲染，60fps 不掉帧 */
  const setX = (v: number) => {
    xRef.current = v;
    const el = trackRef.current;
    if (el) el.style.transform = atX(v);
  };

  const animateTo = (v: number, ms: number, curve: string, done?: () => void) => {
    const el = trackRef.current;
    if (!el) return;
    el.style.transition = `transform ${ms}ms ${curve}`;
    el.style.transform = atX(v);
    xRef.current = v;
    if (done) window.setTimeout(done, ms);
  };

  useEffect(() => {
    const el = gridRef.current;
    if (!el) return;
    const w = el.getBoundingClientRect().width;
    if (w > 0) gridW.current = w;
    const ro = new ResizeObserver(() => {
      const nw = el.getBoundingClientRect().width;
      if (nw > 0) gridW.current = nw;
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, [isDay]);

  // 换周（含键盘/子页返回）后归位到「本周居中」，避免残留位移
  useEffect(() => {
    const el = trackRef.current;
    if (el) {
      el.style.transition = 'none';
      el.style.transform = TRACK_CENTER;
    }
    xRef.current = 0;
  }, [week, isDay]);

  const onWeekTouchStart = (e: React.TouchEvent) => {
    if (flip !== 0) return;
    const t = e.touches[0];
    drag.current = { x: t.clientX, y: t.clientY, active: true, locked: false };
    const el = trackRef.current;
    if (el) el.style.transition = 'none';
  };

  const onWeekTouchMove = (e: React.TouchEvent) => {
    const d = drag.current;
    if (!d.active) return;
    const t = e.touches[0];
    const dx = t.clientX - d.x;
    const dy = t.clientY - d.y;
    if (!d.locked) {
      if (Math.abs(dx) < 6 && Math.abs(dy) < 6) return;
      if (Math.abs(dy) > Math.abs(dx)) {
        d.active = false;
        return;
      }
      d.locked = true;
    }
    const w = gridW.current || 360;
    let v = Math.max(-w, Math.min(w, dx));
    // 首尾周阻尼，拖不出空白。
    if (week <= 1 && v > 0) v *= 0.25;
    if (week >= TOTAL_WEEKS && v < 0) v *= 0.25;
    setX(v);
  };

  const onWeekTouchEnd = () => {
    const d = drag.current;
    if (!d.active) return;
    d.active = false;
    const w = gridW.current || 360;
    const dx = xRef.current;
    if (Math.abs(dx) > w * 0.22) {
      const dir = dx < 0 ? 1 : -1;
      if ((dir > 0 && week >= TOTAL_WEEKS) || (dir < 0 && week <= 1)) {
        animateTo(0, WEEK_MS, 'ease-out');
        toast(dir > 0 ? '已经是最后一周' : '已经是第一周');
        return;
      }
      // 先滑到邻页（邻页早已渲染好，滑过去就是完整内容）。
      // 落地后同一个回调里把位移归零并换周：React 批处理成一次提交，不跳变。
      animateTo(-dir * w, WEEK_MS, 'cubic-bezier(.22,.61,.36,1)', () => {
        const el = trackRef.current;
        if (el) {
          el.style.transition = 'none';
          el.style.transform = TRACK_CENTER;
        }
        xRef.current = 0;
        setWeek(week + dir);
      });
    } else {
      animateTo(0, WEEK_MS, 'ease-out');
    }
  };

  /* ---------- 菜单 ---------- */

  const openMenu = useCallback(() => {
    setMenuTrans('none');
    setMenuOffset(MENU_H + 60);
    setMenuMask(0);
    setMenuOpen(true);
    window.setTimeout(() => {
      setMenuTrans('transform 300ms cubic-bezier(.16,.84,.44,1), opacity 240ms ease-out');
      setMenuOffset(-8);
      setMenuMask(0.45);
      window.setTimeout(() => {
        setMenuTrans('transform 130ms ease-in-out');
        setMenuOffset(3);
        window.setTimeout(() => {
          setMenuTrans('transform 170ms ease-out');
          setMenuOffset(0);
        }, 130);
      }, 300);
    }, 16);
  }, []);

  const closeMenu = useCallback(() => {
    setMenuTrans('transform 230ms ease-in, opacity 200ms ease-in');
    setMenuOffset(MENU_H + 60);
    setMenuMask(0);
    window.setTimeout(() => setMenuOpen(false), 250);
  }, []);

  useEffect(() => {
    if (!menuOpen) return;
    const onBack = (e: PopStateEvent) => {
      e.preventDefault();
      closeMenu();
    };
    window.addEventListener('popstate', onBack);
    return () => window.removeEventListener('popstate', onBack);
  }, [menuOpen, closeMenu]);

  /* ---------- 交互 ---------- */

  /** 点课程块 → 弹出详情（对齐鸿蒙 openDetail） */
  const openDetail = (c: Course) => {
    setDetail(c);
    // 点的是「非本周」幽灵块时本周本来没这门课，作用域默认落到「所有周」。
    setDetailAllWeeks(!isInWeek(c, week));
  };

  const onCourseClick = (c: Course) => openDetail(c);

  /** 删除课程：按作用域决定只摘掉本周还是整条删除 */
  const doDeleteCourse = () => {
    const c = detail;
    if (!c) return;
    if (detailAllWeeks) {
      app.deleteCourse(c.id);
      toast(`已删除「${c.name}」`);
    } else {
      const left = c.weeks.filter((w) => w !== week);
      if (left.length === 0) {
        app.deleteCourse(c.id);
        toast(`已删除「${c.name}」`);
      } else {
        app.updateCourse({ ...c, weeks: left });
        toast(`已从第 ${week} 周移除「${c.name}」`);
      }
    }
    setDetail(null);
  };

  const onMenuAction = (key: string) => {
    if (key === 'dark') { app.updateSettings({ dark: !settings.dark }); return; }
    closeMenu();
    if (key === 'update') { void checkAppUpdate(); return; }
    if (key === 'refresh') {
      window.setTimeout(() => {
        void quickRefresh();
      }, 180);
      return;
    }
    const map: Record<string, string> = {
      table: '/timetable-settings',
      remind: '/remind',
      widget: '/widget',
      contact: '/about',
      import: '/login',
      term: '/term',
      period: '/periods',
      appearance: '/appearance',
      account: '/account',
      about: '/about'
    };
    const p = map[key];
    if (p) window.setTimeout(() => navigate(p), 180);
  };

  /* ---------- 课表管理 ---------- */

  const openCreate = () => {
    setTableName('');
    setTableSheet({ mode: 'create' });
  };

  const openRename = (t: TableOption) => {
    setTableName(t.name);
    setTableSheet({ mode: 'rename', id: t.id });
  };

  const saveTableName = () => {
    const name = tableName.trim();
    if (!name) {
      toast('课表名称不能为空');
      return;
    }
    if (tableSheet?.mode === 'create') {
      app.createTable(name);
      toast(`已新建「${name}」`);
    } else if (tableSheet?.id) {
      app.renameTable(tableSheet.id, name);
      toast('已重命名');
    }
    setTableSheet(null);
  };

  const doDeleteTable = () => {
    if (!confirmDel) return;
    if (app.tables.length <= 1) {
      toast('至少保留一个课表');
      setConfirmDel(null);
      return;
    }
    app.deleteTable(confirmDel.id);
    toast(`已删除「${confirmDel.name}」`);
    setConfirmDel(null);
  };

  /** 菜单里的「刷新课表」：用已保存的凭据就地重拉，不跳登录页 */
  const quickRefresh = async (): Promise<void> => {
    const cred = loadCredential();
    if (!cred || !cred.user) {
      navigate('/login');
      return;
    }
    const token=accountToken(), table=activeTableId;
    toast('正在刷新课表…');
    await schoolTask(token, async () => {
    try {
      // 门户/扫码登录只留下会话，没有可用的纯 HTTP 登录链路：有会话就直接刷
      if (!ensureJwSession(cred.user)) {
        if (!cred.pwd) {
          toast('登录状态已过期，请重新导入课表');
          return;
        }
        const res = await login(cred.user, cred.pwd);
        if (res.captcha) {
          toast('教务要求验证码，请到导入课表页完成验证');
          return;
        }
        if (!res.ok) {
          // 纯 HTTP 登录被门户挡下：改走静默网页登录，再接着刷新
          const viaWeb = await silentPortalLogin(cred.user, cred.pwd);
          if (!viaWeb.ok) {
            toast(`刷新失败：${viaWeb.message}`);
            return;
          }
        } else {
          persistJwSession(cred.user);
        }
      }
      if (!isCurrent(token,cred.user)) return;
      const tt = await fetchTimetable(cred.user, currentSemester());
      if (!isCurrent(token,cred.user) || loadActiveTable()!==table) return;
      // 会话必须还是这个账号：拿到了别人的课表就停手，绝不存在自己名下。
      const xh = (tt.student.XH ?? '').trim();
      if (xh && xh !== cred.user) {
        await resetSession();
        toast(`教务返回的账号是 ${xh}，与当前登录的 ${cred.user} 不一致，请重新登录`);
        return;
      }
      commitTimetable(tt.courses,{...cred,lastSyncAt:Date.now()},table,token);
      app.reload();
      toast(`已更新 ${tt.courses.length} 条课程`);
    } catch (e) {
      if (isCurrent(token,cred.user)) toast(`刷新异常：${e instanceof Error ? e.message : String(e)}`);
    }
    }).catch(() => undefined);
  };

  const onFunctionTap = (key: string) => {
    const map: Record<string, string> = {
      period: '/periods',
      table: '/timetable-settings',
      remind: '/remind',
      widget: '/widget'
    };
    const p = map[key];
    if (p) navigate(p);
  };

  /* ---------- 导出到系统日历 ---------- */
  const confirmExportCalendar = () => {
    if (courses.length === 0) {
      toast('课表还是空的，先导入课表');
      return;
    }
    const events = buildEvents(courses, periods, DEFAULT_REMIND);
    if (events.length === 0) {
      toast('这些课都没有设置周次');
      return;
    }
    const names = new Set(events.map((e) => e.title)).size;
    setExportAsk({
      total: events.length,
      names,
      reminder: app.settings.calendarRemind ? DEFAULT_REMIND : 0
    });
  };

  const doExportCalendar = async () => {
    const reminder = exportAsk?.reminder ?? DEFAULT_REMIND;
    setExportAsk(null);
    try {
      const r = await exportCourses(courses, periods, reminder);
      toast(r.failed > 0 ? `已写进 ${r.inserted} 条日程，${r.failed} 条失败` : `已写进 ${r.inserted} 条日程`);
    } catch (e) {
      toast('导出失败：' + (e instanceof Error ? e.message : String(e)));
    }
  };

  /* ---------- 转发：分享口令 / 从口令导入 ---------- */
  const makeShareCode = async () => {
    setForwardOpen(false);
    if (codeBusy) return;
    if (courses.length === 0) {
      toast('课表还是空的，先导入课表');
      return;
    }
    setCodeBusy(true);
    try {
      const code = await uploadShare(courses, periods, TERM_LABEL, week);
      const online = true;
      const text =
        '这是来自「福小外」的课表分享，口令 30 天内有效。\n' +
        '复制这条消息后打开福小外，点首页右上角「↗」→「从口令导入」，即可一比一复用这份课表' +
        `（${courses.length} 门课 · 共 ${TOTAL_WEEKS} 周）。\n` +
        `分享口令：${code}`;
      setCodeCard({ text, online });
    } catch (e) {
      toast('生成口令失败：' + (e instanceof Error ? e.message : String(e)));
    } finally {
      setCodeBusy(false);
    }
  };

  const queryImport = async (raw?: string) => {
    const code = extractShareCode(raw ?? importCode);
    if (!code) {
      toast('未识别到唯一有效口令，请粘贴完整分享消息或32位口令');
      return;
    }
    if (importBusy) return;
    const request = ++importRequest.current;
    const scope = { token: accountToken(), table: activeTableId };
    setImportBusy(true);
    setImportPreview(null);
    try {
      const snap = await fetchShare(code);
      if (request !== importRequest.current || !isCurrent(scope.token) || loadActiveTable() !== scope.table) return;
      if (!snap) {
        toast('口令不存在或已过期');
        return;
      }
      setImportPreview(snap);
      importScope.current = scope;
    } catch (e) {
      if (request !== importRequest.current) return;
      toast('查询失败：' + (e instanceof Error ? e.message : String(e)));
    } finally {
      if (request === importRequest.current) setImportBusy(false);
    }
  };

  const applyImport = () => {
    if (!importPreview) return;
    const scope = importScope.current;
    if (!scope || !isCurrent(scope.token) || loadActiveTable() !== scope.table) {
      setImportPreview(null);
      toast('账号或课表已切换，请重新查询口令');
      return;
    }
    const list = toLocalCourses(importPreview.courses);
    try {
      atomic(()=>{
        saveCourses(activeTableId,list);
        if(importPreview.periods?.length)savePeriods(importPreview.periods);
        if(importPreview.termMetadata)saveTerm(activeTableId,importPreview.termMetadata);
        if (JSON.stringify(loadCourses(activeTableId)) !== JSON.stringify(list)) throw new Error('课表保存核对失败');
      });
      app.reload();
    } catch(e) {toast(`导入失败：${e instanceof Error?e.message:String(e)}`);return;}
    setImportOpen(false);
    setImportPreview(null);
    setImportCode('');
    toast(`已导入 ${list.length} 门课`);
  };

  const onShare = async () => {
    closeMenu();
    const text = buildWeekText(week, app.courses, periods);
    try {
      await navigator.clipboard.writeText(text);
      toast('本周课表已复制到剪贴板');
    } catch {
      toast('复制失败，请检查剪贴板权限');
    }
  };

  return (
    <div className="page home">
      {/* ---------- 头部 ---------- */}
      <div className="home-header no-select">
        <div className="hh-left">
          <span className="hh-week">
            第{week}周
            {week !== todayW && <span className="hh-offweek">（非本周）</span>}
          </span>
          <span className="hh-range">{weekRangeLabel(week)}</span>
        </div>
        <div className="hh-right">
          <button className="hh-btn hh-toggle" onClick={toggleView}>
            {isDay ? '周' : '日'}
          </button>
          <button className="hh-btn" aria-label="新增课表" onClick={() => navigate('/add-course')}>
            <TimetableIcon name="add" />
          </button>
          <button className="hh-btn" aria-label="导入课表" onClick={openImport}>
            <TimetableIcon name="import" />          </button>
          <button
            aria-label="分享课表"
            className={`hh-btn${forwardOpen ? ' hh-btn-on' : ''}`}
            onClick={() => setForwardOpen((v) => !v)}
          >
            <TimetableIcon name="share" />
          </button>
          <button className="hh-btn" onClick={openMenu}>
            ⋯
          </button>
        </div>
      </div>

      {/* ---------- 翻转容器：标题+周条+内容整体翻 ---------- */}
      <div
        className="home-flip"
        style={{
          transform: `perspective(1600px) rotateY(${flip}deg)`,
          transition: `transform ${FLIP_MS}ms ease-in-out`
        }}
      >
        <WeekBar
          dates={wd.dates}
          month={wd.month}
          todayIndex={wd.todayIndex}
          showWeekend
        />

        <div className="nextbar-spacer" aria-hidden="true" />

        <div className="home-body no-scrollbar">
          {isDay ? (
            <DayList courses={courses} week={week} periods={periods} onCourseClick={onCourseClick} />
          ) : (
            <div
              className="grid-card week-swiper"
              ref={gridRef}
              onTouchStart={onWeekTouchStart}
              onTouchMove={onWeekTouchMove}
              onTouchEnd={onWeekTouchEnd}
            >
              <div className="week-track" ref={trackRef}>
                <div className="week-page">
                  {week > 1 && (
                    <TimetableGrid
                      courses={courses}
                      week={week - 1}
                      periods={periods}
                      showWeekend
                      showGhost={settings.showGhost}
                      cellHeight={cellHeight}
                      onCourseClick={onCourseClick}
                      onCellClick={() => navigate('/add-course')}
                    />
                  )}
                </div>
                <div className="week-page">
                  <TimetableGrid
                    courses={courses}
                    week={week}
                    periods={periods}
                    showWeekend
                    showGhost={settings.showGhost}
                    cellHeight={cellHeight}
                    onCourseClick={onCourseClick}
                    onCellClick={() => navigate('/add-course')}
                  />
                </div>
                <div className="week-page">
                  {week < TOTAL_WEEKS && (
                    <TimetableGrid
                      courses={courses}
                      week={week + 1}
                      periods={periods}
                      showWeekend
                      showGhost={settings.showGhost}
                      cellHeight={cellHeight}
                      onCourseClick={onCourseClick}
                      onCellClick={() => navigate('/add-course')}
                    />
                  )}
                </div>
              </div>
            </div>
          )}

          {isDay && <div className="daylist-tip">点右上角「周」翻回周课表</div>}
        </div>
      </div>

      {/* ---------- 课程详情 ---------- */}
      {detail && (
        <CourseDetailSheet
          course={detail}
          periods={periods}
          scopeAll={detailAllWeeks}
          onScope={setDetailAllWeeks}
          onEdit={() => {
            const id = detail.id;
            setDetail(null);
            navigate('/add-course', { id });
          }}
          onCopy={() => toast('复制到其他时段（P1）')}
          onDelete={doDeleteCourse}
          onClose={() => setDetail(null)}
        />
      )}

      {/* ---------- 底部 Tab ---------- */}


      {/* ---------- 菜单 ---------- */}
      {menuOpen && (
        <>
          <div
            className="sheet-mask"
            style={{ opacity: menuMask, transition: 'opacity 240ms ease-out' }}
            onClick={closeMenu}
          />
          <MenuSheet
            tables={<TableSwitcher
                tables={tables}
                activeId={activeTableId}
                onSwitch={(id) => app.switchTable(id)}
                onCreate={() => { closeMenu(); openCreate(); }}
                onDelete={(t) => { closeMenu(); setConfirmDel(t); }}
                onRename={(t) => { closeMenu(); openRename(t); }}
              />}
            dark={settings.dark}
            offset={menuOffset}
            week={week}
            totalWeeks={TOTAL_WEEKS}
            weekRange={weekRangeLabel(week, true)}
            onWeekChange={(w) => setWeek(w)}
            onShare={onShare}
            onItem={onMenuAction}
          />
        </>
      )}

      {/* 菜单过渡：inline style 控制，这里把 transition 注入 */}
      <style>
        {menuOpen ? `.menu-sheet{transition:${menuTrans};}` : ''}
      </style>

      {/* 新建 / 重命名课表 */}
      {tableSheet && (
        <div className="mask" onClick={() => setTableSheet(null)}>
          <div className="sheet-inline" onClick={(e) => e.stopPropagation()}>
            <div className="sheet-head">
              <div className="sheet-title">{tableSheet.mode === 'create' ? '新建课表' : '重命名课表'}</div>
              <button className="sheet-save" onClick={saveTableName}>
                保存
              </button>
            </div>
            <input
              className="field-input sheet-input"
              value={tableName}
              onChange={(e) => setTableName(e.target.value)}
              placeholder=""
              autoFocus
            />
          </div>
        </div>
      )}

      {/* 重新导入确认（与鸿蒙同一套文案） */}
      {reloginAsk && (
        <div className="mask" onClick={() => setReloginAsk(null)}>
          <div className="dialog" onClick={(e) => e.stopPropagation()}>
            <div className="dialog-title">课表已是最新</div>
            <div className="dialog-body">
              当前课表于 {reloginAsk.when} 同步，已有 {reloginAsk.count} 门课。
              <br />
              继续导入会重新登录教务系统并整体替换本机课表，手动添加的课程会被覆盖。是否继续导入？
            </div>
            <div className="dialog-actions">
              <button className="dialog-btn" onClick={() => setReloginAsk(null)}>
                取消
              </button>
              <button
                className="dialog-btn primary"
                onClick={() => {
                  setReloginAsk(null);
                  navigate('/login');
                }}
              >
                继续导入
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 删除课表确认 */}
      {confirmDel && (
        <div className="mask" onClick={() => setConfirmDel(null)}>
          <div className="dialog" onClick={(e) => e.stopPropagation()}>
            <div className="dialog-title">删除「{confirmDel.name}」？</div>
            <div className="dialog-body">这个课表里的全部课程会一起删除，且无法恢复。</div>
            <div className="dialog-actions">
              <button className="dialog-btn" onClick={() => setConfirmDel(null)}>
                取消
              </button>
              <button className="dialog-btn danger" onClick={doDeleteTable}>
                删除
              </button>
            </div>
          </div>
        </div>
      )}
    {/* 导出到日程确认 */}
      {exportAsk && (
        <div className="mask" onClick={() => setExportAsk(null)}>
          <div className="dialog" onClick={(e) => e.stopPropagation()}>
            <div className="dialog-title">导出到系统日历？</div>
            <div className="dialog-body">
              {exportAsk.names} 门课按周次展开后共 <b>{exportAsk.total}</b> 条日程，会写进系统日历，
              之后可在日历里单独管理。
            </div>
            <div className="remind-label">提前提醒</div>
            <div className="remind-chips">
              {[0, 10, 15, -1].map((m) => {
                const active = m === -1 ? isCustomRemind(exportAsk.reminder) : exportAsk.reminder === m;
                const label =
                  m === -1
                    ? isCustomRemind(exportAsk.reminder)
                      ? `${exportAsk.reminder} 分钟`
                      : '自定义'
                    : m === 0
                      ? '不提醒'
                      : `${m} 分钟`;
                return (
                  <button
                    key={m}
                    className="remind-chip"
                    data-on={active}
                    onClick={() => {
                      if (m === -1) {
                        const base = isCustomRemind(exportAsk.reminder) ? exportAsk.reminder : 30;
                        setWheelIdx(Math.max(0, Math.min(WHEEL_MINUTES.length - 1, base - 5)));
                        setWheelOpen(true);
                        return;
                      }
                      setExportAsk({ ...exportAsk, reminder: m });
                    }}
                  >
                    {label}
                  </button>
                );
              })}
            </div>
            <div className="dialog-actions">
              <button className="dialog-btn" onClick={() => setExportAsk(null)}>
                取消
              </button>
              <button className="dialog-btn primary" onClick={doExportCalendar}>
                导出
              </button>
            </div>
          </div>
        </div>
      )}

    {/* 自定义提醒滚轮（5–90 分钟） */}
      {wheelOpen && exportAsk && (
        <div className="mask" onClick={() => setWheelOpen(false)}>
          <div className="dialog wheel-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="wheel-head">
              <div className="dialog-title">提前多久提醒</div>
              <div className="wheel-hint">{WHEEL_MINUTES[wheelIdx]} 分钟</div>
            </div>
            <WheelPicker
              items={WHEEL_MINUTES.map((m) => `${m} 分钟`)}
              index={wheelIdx}
              onPick={setWheelIdx}
            />
            <div className="dialog-actions">
              <button className="dialog-btn" onClick={() => setWheelOpen(false)}>
                取消
              </button>
              <button
                className="dialog-btn primary"
                onClick={() => {
                  const m = WHEEL_MINUTES[wheelIdx];
                  setWheelOpen(false);
                  setExportAsk((prev) => (prev ? { ...prev, reminder: m } : prev));
                  setRemindTip(`已设为提前 ${m} 分钟提醒`);
                }}
              >
                确定
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 3 秒后自动消失的「已创建提醒」 */}
      {remindTip && (
        <div className="remind-toast no-select">
          <div className="remind-toast-icon">✓</div>
          <div className="remind-toast-title">已创建提醒</div>
          <div className="remind-toast-sub">{remindTip}</div>
        </div>
      )}

    {/* 转发面板：分享课表 / 从口令导入 */}
      {forwardOpen && (
        <>
          <div className="forward-mask" onClick={() => setForwardOpen(false)} />
          <div className="forward-pop">
            <button
              className="forward-item"
              onClick={() => {
                setForwardOpen(false);
                makeShareCode();
              }}
            >
              <span className="forward-glyph"><TimetableIcon name="send" /></span>
              <span className="forward-texts">
                <span className="forward-title">分享课表</span>
                <span className="forward-sub">生成口令，发给同学复用</span>
              </span>
            </button>
            <button
              className="forward-item"
              onClick={() => {
                setForwardOpen(false);
                confirmExportCalendar();
              }}
            >
              <span className="forward-glyph"><TimetableIcon name="calendar" /></span>
              <span className="forward-texts">
                <span className="forward-title">导出到日程</span>
                <span className="forward-sub">写进系统日历，可设提醒</span>
              </span>
            </button>
            <button
              className="forward-item"
              onClick={() => {
                setForwardOpen(false);
                setImportCode('');
                setImportPreview(null);
                setImportOpen(true);
              }}
            >
              <span className="forward-glyph"><TimetableIcon name="key" /></span>
              <span className="forward-texts">
                <span className="forward-title">从口令导入</span>
                <span className="forward-sub">粘贴同学发来的口令</span>
              </span>
            </button>
          </div>
        </>
      )}

      {/* 生成口令卡片 */}
      {codeCard && (
        <div className="mask" onClick={() => setCodeCard(null)}>
          <div className="dialog code-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="dialog-title">生成口令</div>
            <pre className="code-text">{codeCard.text}</pre>
            <div className={`code-state${codeCard.online ? '' : ' off'}`}>
              {codeCard.online
                ? '已上传服务器 · 同学输入口令即可一比一导入'
                : '离线口令 · 没连上服务器，别人暂时导入不进来'}
            </div>
            <div className="dialog-actions">
              <button
                className="dialog-btn"
                onClick={async () => {
                  try {
                    await navigator.clipboard.writeText(codeCard.text);
                    toast('口令已复制，发给同学即可');
                  } catch {
                    toast('复制失败，请长按选中文字');
                  }
                  setCodeCard(null);
                }}
              >
                复制
              </button>
              <button className="dialog-btn" onClick={() => setCodeCard(null)}>
                取消
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 从口令导入 */}
      {importOpen && (
        <div className="mask" onClick={() => setImportOpen(false)}>
          <div className="dialog" onClick={(e) => e.stopPropagation()}>
            <div className="sheet-head">
              <div className="dialog-title">从口令导入</div>
              <button
                className="sheet-save"
                onClick={() => (importPreview ? applyImport() : queryImport())}
              >
                {importBusy ? '查询中' : importPreview ? '覆盖导入' : '查询'}
              </button>
            </div>
            <div className="dialog-body">可直接粘贴整条分享消息或32位口令，查询后整份覆盖当前课表。</div>
            <input
              className="field-input"
              value={importCode}
              onChange={(e) => {
                const v = e.target.value;
                importRequest.current++;
                importScope.current = null;
                setImportBusy(false);
                const code = extractShareCode(v);
                setImportCode(code ?? v);
                setImportPreview(null);
              }}
              placeholder=""
              autoFocus
            />
            {importPreview && (
              <div className="import-preview">
                <div className="import-preview-main">
                  {importPreview.courses.length} 门课 · {importPreview.term} · 第{importPreview.week}周
                </div>
                <div className="import-preview-warn">导入会覆盖当前课表，原有课程不保留</div>
              </div>
            )}
            <div className="dialog-actions">
              <button className="dialog-btn" onClick={() => setImportOpen(false)}>
                取消
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
