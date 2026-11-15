import { accountToken, isCurrent } from './accountScope';
/**
 * 桌面小组件（2×4 今日课程卡片）
 *
 * WebView 里的数据在 localStorage，原生 AppWidget 读不到，所以由前端算好一份快照推给原生，
 * 原生存 SharedPreferences 再刷新 RemoteViews。对齐鸿蒙 entry/src/main/ets/widget/。
 */

import { Capacitor, registerPlugin } from '@capacitor/core';

import { todayWeekday, weekdayText } from './semester';
import type { Course, Period } from './types';

export interface WidgetSnapshot {
  /** 顶部一句：今天 3 节课 / 今天没课 */
  headline: string;
  /** 周三 */
  dayLabel: string;
  /** 11月13日 */
  dateLabel: string;
  /** 每条一行：08:25-09:10 高等数学 · A101 */
  lines: string[];
  /** 没有课时的一行说明 */
  empty: string;
  /** 22:10 这类更新时间 */
  updatedAt: string;
}

interface FxwWidgetPlugin {
  sync(options: WidgetSnapshot): Promise<void>;
}

const FxwWidget = registerPlugin<FxwWidgetPlugin>('FxwWidget');

/** 从当前课表摘出「今天」要显示的内容 */
export function buildWidgetSnapshot(courses: Course[], periods: Period[], week: number): WidgetSnapshot {
  const wd = todayWeekday();
  const now = new Date();
  const clock = (index: number, key: 'start' | 'end'): string =>
    periods.find((p) => p.index === index)?.[key] ?? '';

  const todays = courses
    .filter((c) => c.weekday === wd && c.weeks.includes(week))
    .sort((a, b) => a.startPeriod - b.startPeriod);

  const lines = todays.slice(0, 4).map((c) => {
    const span = `${clock(c.startPeriod, 'start')}-${clock(c.endPeriod, 'end')}`;
    const room = c.room.trim().length > 0 ? ` · ${c.room.trim()}` : '';
    return `${span} ${c.name}${room}`;
  });

  return {
    headline: todays.length > 0 ? `今天 ${todays.length} 节课` : '今天没课',
    dayLabel: weekdayText(wd),
    dateLabel: `${now.getMonth() + 1}月${now.getDate()}日`,
    lines,
    empty: '今天没有课，好好休息',
    updatedAt: `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`
  };
}

/** 推给原生；Web 调试环境没有这个插件，静默跳过 */
let tail:Promise<unknown>=Promise.resolve();
export function syncWidget(snapshot:WidgetSnapshot):Promise<void> {
  const token=accountToken();
  const task=tail.then(async()=>{if(Capacitor.isNativePlatform()&&isCurrent(token))await FxwWidget.sync(snapshot);});
  tail=task.catch(()=>undefined);return task.catch(()=>undefined);
}
export function clearWidget():Promise<void> {
  const task=tail.then(async()=>{if(Capacitor.isNativePlatform())await FxwWidget.sync(buildWidgetSnapshot([],[],1));});
  tail=task.catch(()=>undefined);return task;
}
