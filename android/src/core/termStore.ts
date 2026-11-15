import { accountKey, accountUser } from './accountScope';
import { getRaw, setRaw } from './persistence';
export interface TermMetadata {
  year:number; term:number; startMonday:string; totalWeeks:number; label:string; source:string; syncedAt:number;
}
// Exact legacy configuration, retained for historical tables. It is not a newly verified school calendar.
export const LEGACY_TERM: TermMetadata = {year:2026,term:3,startMonday:'2026-08-31',totalWeeks:20,
  label:'2026-2027学年 第1学期',source:'legacy-config-2026-08-31',syncedAt:0};
function prefix(): string { return `fxw_a_${accountKey(accountUser())}_`; }
export function activeTable(): string { return JSON.parse(getRaw(`${prefix()}active_table`) || '"t1"'); }
export function loadTerm(tableId=activeTable()): TermMetadata {
  const raw=getRaw(`${prefix()}term_${tableId}`);
  if(!raw)return {...LEGACY_TERM};
  return validateTermMetadata(JSON.parse(raw));
}
export function validateTermMetadata(value:unknown):TermMetadata {
  const term=value as TermMetadata;
  if(!term || typeof term!=='object')throw new Error('课表学期配置不正确');
  const date=new Date(`${term.startMonday}T00:00:00`);
  if(!Number.isInteger(term.year)||term.year<1990||term.year>2200||![3,12,16].includes(term.term)||!/^\d{4}-\d{2}-\d{2}$/.test(term.startMonday)||
    !Number.isFinite(date.getTime())||date.getFullYear()!==Number(term.startMonday.slice(0,4))||date.getMonth()+1!==Number(term.startMonday.slice(5,7))||date.getDate()!==Number(term.startMonday.slice(8,10))||date.getDay()!==1||!Number.isInteger(term.totalWeeks)||term.totalWeeks<1||term.totalWeeks>60||
    typeof term.label!=='string'||term.label.length>200||typeof term.source!=='string'||term.source.length>200||!Number.isFinite(term.syncedAt))throw new Error('课表学期配置不正确，请保留数据后重试');
  return term;
}
export function saveTerm(tableId:string,term:TermMetadata): void {
  const key=`${prefix()}term_${tableId}`;
  setRaw(key,JSON.stringify(validateTermMetadata(term)));
}
export function initializeTerm(tableId=activeTable()): void {
  const key=`${prefix()}term_${tableId}`;
  if(getRaw(key)===null)setRaw(key,JSON.stringify(LEGACY_TERM));
}
