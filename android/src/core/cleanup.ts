import { Capacitor } from '@capacitor/core';
import { invalidateAccount, accountUser } from './accountScope';
import { resetSession } from './session';
import { clearReminders } from './remind';
import { clearOwnedCalendar } from './calendar';
import { clearWidget } from './widget';
import { atomic } from './persistence';
import * as DB from './store';
const KEY='fxw_cleanup_pending_v1';
interface Cleanup {owner:string;all:boolean;scope?:'account'|'all'|'timetables';remaining:string[];feedbackIds?:string[]}
function clearLocal(job:Cleanup):void {
  if(job.all){DB.wipeAll();return;}
  atomic(()=>{
    if(job.scope==='timetables'){DB.clearTimetables(job.owner);return;}
    DB.clearAccountData(job.owner);
    const selected=accountUser()===job.owner;
    const ids=new Set(job.feedbackIds??(selected?DB.loadFeedback().map(f=>f.id):[]));
    DB.saveFeedback(DB.loadFeedback().filter(f=>!ids.has(f.id)));
    if(selected)DB.clearCredential();
  });
}
async function run(job:Cleanup, notify?:()=>void):Promise<void> {
  const failures:string[]=[];
  const steps:Record<string,()=>void|Promise<void>>={
    local:()=>{clearLocal(job);notify?.();},
    session:resetSession,
    reminders:async()=>{if(Capacitor.isNativePlatform())await clearReminders();},
    calendar:async()=>{if(Capacitor.isNativePlatform())await clearOwnedCalendar(job.all?undefined:job.owner);},
    widget:async()=>{if(!accountUser()||accountUser()===job.owner)await clearWidget();}
  };
  for(const step of job.remaining)try{if(!steps[step])throw new Error('Invalid cleanup step');await steps[step]();}catch{failures.push(step);}
  if(failures.length){
    try{localStorage.setItem(KEY,JSON.stringify({...job,remaining:failures}));}catch{/* Continue reporting failure even when retry metadata cannot be persisted. */}
    throw new Error('部分本机数据或系统日程未能清除，请检查权限与存储后重试；云端数据未删除');
  }
  localStorage.removeItem(KEY);
}
async function begin(scope:'account'|'all'|'timetables',notify?:()=>void):Promise<void>{
  invalidateAccount();
  const job:Cleanup={owner:accountUser(),all:scope==='all',scope,feedbackIds:DB.loadFeedback().map(f=>f.id),
    remaining:scope==='timetables'?['local','reminders','calendar','widget']:['local','session','reminders','calendar','widget']};
  // A failed journal write must not block independent deletion/cancellation.
  try{localStorage.setItem(KEY,JSON.stringify(job));}catch{/* Local deletion may free enough space for retry metadata. */}
  await run(job,notify);
}
export function clearPersonalData(all:boolean,notify?:()=>void):Promise<void>{return begin(all?'all':'account',notify);}
export function clearTimetableData(notify?:()=>void):Promise<void>{return begin('timetables',notify);}
export async function retryExternalCleanup():Promise<boolean>{
  const raw=localStorage.getItem(KEY);if(!raw)return false;
  const job:Cleanup=JSON.parse(raw);
  if(!job||typeof job.owner!=='string'||!Array.isArray(job.remaining))throw new Error('清理记录损坏，请保留数据后重试');
  invalidateAccount();await run(job);return true;
}
