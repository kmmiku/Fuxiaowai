const {test}=require('node:test');const assert=require('node:assert/strict');const {loadEts}=require('./ets-loader.cjs');
test('logout immediately replaces existing widget payload with empty state',async()=>{
 const pushed=[];const cache=new Map();const mocks={'@kit.FormKit':{formBindingData:{createFormBindingData:v=>v},formProvider:{updateForm:async(id,payload)=>pushed.push({id,payload})}},'@ohos.data.preferences':{default:{getPreferences:async()=>({getAllSync:()=>({'form_42':'day_card'})})}},'../common/util/TermCalendar':{currentWeek:()=>1,TOTAL_WEEKS:20}};
 const {WidgetRefresh}=loadEts('entry/src/main/ets/widget/WidgetRefresh.ets',mocks,cache);
 const date=new Date().getDay()||7;await WidgetRefresh.update({},[{name:'private course',room:'101',weekday:date,startPeriod:1,endPeriod:2,weeks:[1],colorIndex:0}],[]);await WidgetRefresh.update({},[],[]);
 assert.equal(pushed.length,2);assert.equal(pushed[1].payload.empty,'1');assert.equal(pushed[1].payload.lines,'');assert.equal(pushed[1].id,'42');
});
