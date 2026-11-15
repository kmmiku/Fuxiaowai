import type { Course } from './types';
/** Screenshot palette; red/orange/deep-blue use user-specified HSL S/L. */
export const COURSE_PALETTE = ['hsl(346.6667, 88%, 55%)','#F06880','#10C0B0','#3080F8','#A078F8','hsl(33.1034, 90%, 60%)','#2898F0','hsl(210, 80%, 45%)'];
export interface CourseRect { day:number; start:number; end:number; col:number; cols:number; pinnedColor?:number }
const left=(r:CourseRect)=>r.day+r.col/r.cols;
const right=(r:CourseRect)=>r.day+(r.col+1)/r.cols;
const overlapsX=(a:CourseRect,b:CourseRect)=>Math.min(right(a),right(b))-Math.max(left(a),left(b))>0.001;
export function neighboringCourses(rs:CourseRect[],i:number,j:number):boolean{
 const a=rs[i],b=rs[j];
 const beside=Math.abs(right(a)-left(b))<0.001||Math.abs(right(b)-left(a))<0.001;
 if(beside&&Math.max(a.start,b.start)<=Math.min(a.end,b.end))return true;
 if(a.day!==b.day||!overlapsX(a,b))return false;
 const [early,late]=a.end<b.start?[a,b]:b.end<a.start?[b,a]:[null,null];
 if(!early||!late)return false;
 return !rs.some((c,k)=>k!==i&&k!==j&&c.day===a.day&&c.start>early.end&&c.end<late.start&&overlapsX(c,early)&&overlapsX(c,late));
}
/** Randomized graph coloring; stable for the supplied session seed. */
export function assignCourseColors(rs:CourseRect[],seed:number):string[]{
 let state=(seed>>>0)||1;
 const random=()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296;};
 const palette=COURSE_PALETTE.slice();
 for(let i=palette.length-1;i>0;i--){const j=Math.floor(random()*(i+1));[palette[i],palette[j]]=[palette[j],palette[i]];}
 const edges=rs.map((_,i)=>rs.flatMap((_,j)=>i!==j&&neighboringCourses(rs,i,j)?[j]:[]));
 const colors:string[]=rs.map(r=>r.pinnedColor!==undefined&&Number.isInteger(r.pinnedColor)&&r.pinnedColor>=0&&r.pinnedColor<COURSE_PALETTE.length?COURSE_PALETTE[r.pinnedColor]:'');
 for(let n=colors.filter(c=>!c).length;n>0;n--){
  const pending=rs.map((_,i)=>i).filter(i=>!colors[i]);
  pending.sort((a,b)=>new Set(edges[b].map(i=>colors[i]).filter(Boolean)).size-new Set(edges[a].map(i=>colors[i]).filter(Boolean)).size||edges[b].length-edges[a].length||a-b);
  const i=pending[0],used=new Set(edges[i].map(j=>colors[j]));
  const choices=palette.filter(c=>!used.has(c));
  if(choices.length)colors[i]=choices[Math.floor(random()*choices.length)];
  else {colors[i]=palette.slice().sort((a,b)=>edges[i].filter(j=>colors[j]===a).length-edges[i].filter(j=>colors[j]===b).length)[0];}
 }
 return colors;
}

/** Monday–Friday first-course defaults; weekends remain automatic. */
export const FIRST_COURSE_COLORS: Record<number,number> = {1:0,2:1,3:2,4:6,5:4};

export function preferredCourseColor(course:{weekday:number;colorIndex:number;colorOverride?:boolean},isFirst:boolean):number|undefined{
 if(course.colorOverride===true&&Number.isInteger(course.colorIndex)&&course.colorIndex>=0&&course.colorIndex<COURSE_PALETTE.length)return course.colorIndex;
 return isFirst?FIRST_COURSE_COLORS[course.weekday]:undefined;
}

/** Assign only missing colors to the full timetable, never to a visible week. */
export function freezeCourseColors(courses:Course[],seed?:number):Course[]{
 if(courses.every(c=>Number.isInteger(c.autoColorIndex)&&c.autoColorIndex!>=0&&c.autoColorIndex!<COURSE_PALETTE.length))return courses;
 const first=new Map<number,number>();
 for(const c of courses)first.set(c.weekday,Math.min(first.get(c.weekday)??Infinity,c.startPeriod));
 const nodes=courses.map(c=>({day:c.weekday,start:c.startPeriod,end:c.endPeriod,col:0,cols:1,
  pinnedColor:c.colorOverride?c.colorIndex:(c.autoColorIndex??preferredCourseColor(c,c.startPeriod===first.get(c.weekday)))}));
 const colors=assignCourseColors(nodes,seed??Math.floor(Math.random()*4294967295));
 return courses.map((c,i)=>({...c,autoColorIndex:c.autoColorIndex??COURSE_PALETTE.indexOf(colors[i])}));
}
export function storedCourseColor(course:Course):string{
 const index=course.colorOverride?course.colorIndex:(course.autoColorIndex??course.colorIndex);
 return COURSE_PALETTE[((index%COURSE_PALETTE.length)+COURSE_PALETTE.length)%COURSE_PALETTE.length];
}
