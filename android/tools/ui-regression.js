async (page) => {
  await page.addInitScript(() => {
    if (!Element.prototype.checkVisibility) Element.prototype.checkVisibility = function () { const s=getComputedStyle(this); return s.display!=='none' && s.visibility!=='hidden'; };
    const OriginalDate=Date, fixed=new OriginalDate(2026,10,14,9,0,0).getTime();
    window.Date=class extends OriginalDate {constructor(...args){if(args.length)super(...args);else super(fixed)} static now(){return fixed}};
    localStorage.clear();
    const dark=new URL(location.href).searchParams.get('dark')==='1';
    localStorage.setItem('fxw_settings',JSON.stringify({dark,cellHeight:60}));
    localStorage.setItem('fxw_credential',JSON.stringify({user:'QA2024',pwd:'',remember:false,autoUpdate:false,lastSyncAt:0,autoDay:''}));
    localStorage.setItem('fxw_a_QA2024_profile',JSON.stringify({name:'测试用户',studentId:'QA2024',clazz:'测试班',major:'测试专业',grade:'2024'}));
    localStorage.setItem('fxw_a_QA2024_courses_t1',JSON.stringify([{id:'qa-1',name:'测试课程',teacher:'测试教师',room:'A101',campus:'测试校区',weekday:6,startPeriod:1,endPeriod:2,weeks:Array.from({length:20},(_,i)=>i+1),colorIndex:0}]));
  });
  const results=[];
  for(const [width,dark] of [[390,false],[320,true]]) {
    await page.setViewportSize({width,height:844});
    for(const route of ['home','login','profile','feedback','account','personal','periods','appearance','courses','timetable-settings','term','remind','widget','calendar','grades','exam','add-course','faq','more','about']) {
      const shots=[],texts=[];
      for(const port of [4174,4175]) {
        await page.goto(`http://127.0.0.1:${port}/?dark=${dark?1:0}#/${route}`);
        await page.waitForTimeout(1200);
        await page.addStyleTag({content:'*,*::before,*::after{animation:none!important;transition:none!important;caret-color:transparent!important}'});
        await page.mouse.move(0,0);
        shots.push(Array.from(await page.screenshot({timeout:5000})));
        texts.push(await page.locator('body').innerText());
      }
      results.push({route,width,dark,identical:shots[0].length===shots[1].length&&shots[0].every((v,i)=>v===shots[1][i]),textSame:texts[0]===texts[1]});
    }
  }
  return results;
}
