const { test } = require('node:test');
const assert = require('node:assert/strict');
const { load, storage } = require('./load.cjs');
const record={id:'1',course:'测试课',credit:1,score:80,gpa:3,term:'',nature:''};
function setup(fetchGrades) {
 const s=storage(); s.setItem('fxw_credential',JSON.stringify({user:'A',pwd:''})); s.setItem('fxw_a_A_profile',JSON.stringify({grade:'2024'}));
 const app=load('src/core/gradeStore.ts',{globals:{localStorage:s},mocks:{'./zhengfang':{ensureJwSession:()=>true,currentSemester:()=>({xnm:2026,xqm:3}),fetchGrades,clearPersistedJwSession(){},markSession(){},persistJwSession(){}},'./portal':{}}});
 return {...app,s};
}
test('one failed term never publishes partial grades over complete cache',async()=>{
 const {exports:g}=setup(async(y,t)=>{if(y===2025&&t===12)throw Error('network');return [record]});
 g.saveGradesCache('A',{at:1,items:[record],terms:[],summary:g.summarize([record])});
 const r=await g.syncGrades({user:'A',pwd:''}); assert.equal(r.ok,false);assert.equal(g.loadGradesCache('A').at,1);
});
test('future second term is never queried in first term',async()=>{
 const calls=[];const {exports:g}=setup(async(y,t)=>{calls.push([y,t]);return [record]});
 await g.syncGrades({user:'A',pwd:''});assert.equal(calls.some(([y,t])=>y===2026&&t===12),false);
});
test('switching account while grade request is pending prevents old cache publication',async()=>{
 let release;const gate=new Promise(r=>release=r);const {exports:g,s}=setup(async()=>{await gate;return [record]});
 const task=g.syncGrades({user:'A',pwd:''});s.setItem('fxw_credential',JSON.stringify({user:'B',pwd:''}));release();
 assert.equal((await task).ok,false);assert.equal(g.loadGradesCache('A'),null);
});
test('concurrent grade requests for same account share one collection',async()=>{
 let calls=0;const {exports:g}=setup(async()=>{calls++;return [record]});await Promise.all([g.syncGrades({user:'A',pwd:''}),g.syncGrades({user:'A',pwd:''})]);assert.equal(calls,5);
});
