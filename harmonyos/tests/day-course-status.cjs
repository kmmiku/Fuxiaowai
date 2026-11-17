const test=require('node:test');
const assert=require('node:assert/strict');
const {loadEts}=require('./ets-loader.cjs');
const {hasCourseEnded}=loadEts('entry/src/main/ets/common/util/DayCourseStatus.ets');
test('daily course stays red before or during class and turns blue at the end',()=>{
 assert.equal(hasCourseEnded('10:00',new Date(Date.UTC(2026,10,16,8,0))),false);
 assert.equal(hasCourseEnded('10:00',new Date(Date.UTC(2026,10,16,9,59,59))),false);
 assert.equal(hasCourseEnded('10:00',new Date(Date.UTC(2026,10,16,10,0))),true);
 assert.equal(hasCourseEnded('10:00',new Date(Date.UTC(2026,10,16,11,0))),true);
});
test('custom and evening end times are used while invalid values stay pending',()=>{
 assert.equal(hasCourseEnded('21:45',new Date(Date.UTC(2026,10,16,21,44))),false);
 assert.equal(hasCourseEnded('21:45',new Date(Date.UTC(2026,10,16,21,45))),true);
 assert.equal(hasCourseEnded('9:05',new Date(Date.UTC(2026,10,16,9,5))),true);
 for(const end of ['', '24:00','12:60','unknown']) assert.equal(hasCourseEnded(end,new Date(Date.UTC(2026,10,16,23,59))),false);
});
