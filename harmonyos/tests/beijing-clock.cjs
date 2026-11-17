const test=require('node:test');
const assert=require('node:assert/strict');
const {loadEts}=require('./ets-loader.cjs');
test('Beijing civil time stays independent of system timezone and advances by uptime',()=>{
 const {BeijingClock:c}=loadEts('entry/src/main/ets/common/util/BeijingClock.ets');
 let tick=100;
 c.configure(()=>tick);c.accept(Date.parse('2026-11-15T15:59:59Z'));
 assert.equal(c.dayKey(),'2026-11-15');
 tick+=1000;
 assert.equal(c.dayKey(),'2026-11-16');
 assert.equal(c.civil().getUTCDay(),1);
 assert.equal(c.civil().getUTCHours(),0);
});
test('term calculations use the calibrated day',()=>{
 const cache=new Map();
 const mocks={'../../data/local/TimetableStateStore':{TimetableStateStore:{term:()=>({startMonday:'2026-08-31',totalWeeks:20})}}};
 const {BeijingClock:c}=loadEts('entry/src/main/ets/common/util/BeijingClock.ets',mocks,cache);
 c.configure(()=>1);c.accept(Date.parse('2026-11-15T16:00:00Z'));
 const cal=loadEts('entry/src/main/ets/common/util/TermCalendar.ets',mocks,cache);
 assert.equal(cal.currentWeek(20),12);
 assert.equal(cal.weekDates(12).todayIndex,0);
 assert.equal(cal.weekDates(12).dates[0],'16');
});
const test2=test;
test2('timezone changes cannot alter the Beijing date',()=>{
 const previous=process.env.TZ;
 try {
  for(const tz of ['UTC','America/Los_Angeles','Asia/Shanghai']) {
   process.env.TZ=tz;
   const {BeijingClock:c}=loadEts('entry/src/main/ets/common/util/BeijingClock.ets');
   c.configure(()=>1);c.accept(Date.parse('2026-11-15T16:00:00Z'));
   assert.equal(c.dayKey(),'2026-11-16');
  }
 } finally { if(previous===undefined) delete process.env.TZ;else process.env.TZ=previous; }
});
