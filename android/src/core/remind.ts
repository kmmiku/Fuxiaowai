import { accountToken, accountUser, isCurrent } from './accountScope';
import { activeTable } from './termStore';
﻿/**
 * 上课提醒：真正走系统通知（LocalNotifications → AlarmManager + NotificationChannel）。
 *
 * 为什么不做 App 内弹窗：App 在后台/被划掉时没有任何办法弹，只有系统通知才可靠。
 *
 * 策略：按「本周」排一次（和鸿蒙版一致），换周或改上课时间后用户再点一次「按本周课表生成提醒」。
 */

import { LocalNotifications } from '@capacitor/local-notifications';

import { dateOf } from './semester';
import type { Course, Period } from './types';

/** 通知渠道（Android 8+ 必须建） */
const CHANNEL_ID = 'fxw-class';
const CHANNEL_NAME = '上课提醒';

function atClock(day: Date, clock: string): Date {
  const m = /^(\d{1,2}):(\d{2})$/.exec(clock.trim());
  const d = new Date(day.getTime());
  if (!m) {
    d.setHours(8, 25, 0, 0);
    return d;
  }
  d.setHours(Number(m[1]), Number(m[2]), 0, 0);
  return d;
}

function clockOf(periods: Period[], index: number, fallback: string): string {
  const p = periods.find((x) => x.index === index);
  return p ? p.start : fallback;
}

async function ensureChannel(): Promise<void> {
  try {
    await LocalNotifications.createChannel({
      id: CHANNEL_ID,
      name: CHANNEL_NAME,
      description: '每节课开始前提醒',
      importance: 4,
      visibility: 1,
      vibration: true
    });
  } catch {
    // 渠道已存在或平台不支持，忽略
  }
}

async function ensurePermission(): Promise<boolean> {
  const cur = await LocalNotifications.checkPermissions();
  if (cur.display === 'granted') return true;
  const ask = await LocalNotifications.requestPermissions();
  return ask.display === 'granted';
}

/** 清掉本模块排过的通知（只清 fxw 前缀的，不动其它） */
const OWNED='fxw_reminder_owned_v1';
let reminderTail: Promise<unknown>=Promise.resolve();
function serialized<T>(work:()=>Promise<T>):Promise<T> { const result=reminderTail.then(work); reminderTail=result.catch(()=>undefined);return result; }
async function clearOwned(): Promise<void> {
  const registered: number[]=JSON.parse(localStorage.getItem(OWNED)||'[]');
  const pending=await LocalNotifications.getPending();
  const mine=new Set<number>(registered);
  for(const item of pending.notifications)if(item.extra?.fxw===true || (item.id>=1000 && item.id<1060 && / · \d+ 分钟后上课$/.test(item.title ?? '') && /^地点[：未]/.test(item.body ?? '')))mine.add(item.id);
  if(mine.size)await LocalNotifications.cancel({notifications:[...mine].map(id=>({id}))});
  localStorage.removeItem(OWNED);
}
export function clearReminders():Promise<void> { return serialized(clearOwned); }

export interface RemindPlan {
  /** 实际排上的条数 */
  scheduled: number;
  /** 超过系统上限、这次没排上的条数 */
  skipped: number;
  /** 用户拒绝了通知权限 */
  denied: boolean;
}

/**
 * 按「某一周」的课表排提醒（对齐鸿蒙 RemindPage：手动点一次生成，换周后再点一次）。
 * beforeMinutes=0 表示用户关掉了上课提醒 → 只清不排。
 */
async function planWeekRemindersInternal(
  courses: Course[],
  periods: Period[],
  beforeMinutes: number,
  week: number
): Promise<RemindPlan> {
  const token=accountToken();
  await clearOwned();
  if (!isCurrent(token)) throw new Error('账号状态已改变');
  if (beforeMinutes <= 0 || courses.length === 0) {
    return { scheduled: 0, skipped: 0, denied: false };
  }
  if (!(await ensurePermission())) {
    return { scheduled: 0, skipped: 0, denied: true };
  }
  await ensureChannel();

  const other=await LocalNotifications.getPending();
  const occupied=new Set(other.notifications.map(n=>n.id));
  let nextId=1000000;
  const now = Date.now();
  const items: {
    id: number;
    title: string;
    body: string;
    at: Date;
  }[] = [];

  for (const c of courses) {
    if (!c.weeks || !c.weeks.includes(week)) continue;
    const day = dateOf(week, c.weekday);
    const start = atClock(day, clockOf(periods, c.startPeriod, '08:25')).getTime();
    const at = start - beforeMinutes * 60000;
    // 已经过了的时刻排不上，本周剩余时间里没有课就什么都不排
    if (at <= now) continue;
    const room = [c.campus, c.room].filter((s) => s && s.length > 0).join(' ');
    while(occupied.has(nextId))nextId++;
    items.push({
      id: nextId++,
      title: `${c.name} · ${beforeMinutes} 分钟后上课`,
      body: [room ? `地点：${room}` : '地点未填写', c.teacher ? `教师：${c.teacher}` : '']
        .filter((s) => s.length > 0)
        .join('  ·  '),
      at: new Date(at)
    });
  }

  if (items.length === 0) {
    return { scheduled: 0, skipped: 0, denied: false };
  }

  const sorted = items.sort((a, b) => a.at.getTime() - b.at.getTime());
  const batch = sorted;
  if (!isCurrent(token)) throw new Error('账号状态已改变');
  // Register before scheduling: after a partial platform failure the next attempt can cancel every owned ID.
  localStorage.setItem(OWNED,JSON.stringify(batch.map(x=>x.id)));
  await LocalNotifications.schedule({
    notifications: batch.map((x) => ({
      id: x.id,
      title: x.title,
      body: x.body,
      channelId: CHANNEL_ID,
      extra: {fxw:true,account:accountUser(),table:activeTable()},
      schedule: { at: x.at, allowWhileIdle: true }
    }))
  });

  return { scheduled: batch.length, skipped: sorted.length - batch.length, denied: false };
}
export function planWeekReminders(courses:Course[],periods:Period[],beforeMinutes:number,week:number):Promise<RemindPlan> {
  const token=accountToken();
  return serialized(async()=>{
    if(!isCurrent(token))throw new Error('账号状态已改变');
    const result=await planWeekRemindersInternal(courses,periods,beforeMinutes,week);
    if(!isCurrent(token)){await clearOwned();throw new Error('账号状态已改变');}
    return result;
  });
}
