'use strict';
(()=>{
 const $=id=>document.getElementById(id);
 const state={page:'codes',ticketOffset:0,ticketTotal:0,ticketQuery:'',ticketStatus:'',tickets:[],feedbackOffset:0,feedbackTotal:0,feedback:[],selectedFeedback:null,stats:null,lastSuccess:0};
 const active=new Map(),again=new Set(),failures=new Map();let toastTimer,pollTimer,backoff=5000,cycle=0,pollGeneration=0;
 const labels={stats:'统计',tickets:'口令列表',feedback:'反馈',probes:'系统探针',alerts:'异常告警',audit:'操作记录'};
 const actions={'ticket.inspect':'检测口令','ticket.delete':'删除口令','feedback.read':'标为已读','feedback.delete':'删除反馈','feedback.clear':'清空历史反馈','deploy':'后台升级部署'};
 const statusNames={valid:'有效',expired:'已过期',invalid:'快照异常',missing:'不存在',unchecked:'待检测',healthy:'正常',error:'异常',unknown:'未采集',pending:'等待采样'};
 const fmt=n=>Number.isFinite(Number(n))?Number(n).toLocaleString('zh-CN'):'—';
 const date=n=>n&&Number.isFinite(Number(n))?new Date(Number(n)).toLocaleString('zh-CN',{hour12:false}):'—';
 const size=n=>{if(!Number.isFinite(Number(n)))return '—';n=Number(n);for(const u of ['B','KB','MB','GB','TB']){if(n<1024||u==='TB')return (n>=100||u==='B'?n.toFixed(0):n.toFixed(1))+' '+u;n/=1024;}};
 const uptime=n=>{n=Math.max(0,Number(n)||0);return `${Math.floor(n/86400)}天 ${Math.floor(n%86400/3600)}小时 ${Math.floor(n%3600/60)}分`;};
 const mask=code=>String(code).slice(0,6)+' ··· '+String(code).slice(-4);
 function el(tag,text,className){const e=document.createElement(tag);if(text!==undefined&&text!==null)e.textContent=String(text);if(className)e.className=className;return e;}
 function badge(text,kind=''){return el('span',text,'badge '+kind);}
 function empty(parent,text){parent.replaceChildren(el('div',text,'empty'));}
 function fields(parent,items){parent.replaceChildren();for(const [label,value]of items){parent.append(el('dt',label),el('dd',value??'—'));}}
 function toast(message){clearTimeout(toastTimer);$('toast').textContent=message;$('toast').hidden=false;toastTimer=setTimeout(()=>$('toast').hidden=true,3500);}
 async function api(route,{method='GET',body}={}){
  const controller=new AbortController(),timeout=setTimeout(()=>controller.abort(),12000);
  try{const response=await fetch(route,{method,body:body===undefined?undefined:JSON.stringify(body),headers:body===undefined?{}:{'Content-Type':'application/json'},credentials:'same-origin',cache:'no-store',signal:controller.signal});
   if(response.status===401)throw new Error('管理员认证已失效，请重新登录或刷新页面');
   const data=await response.json().catch(()=>null);
   if(!response.ok||!data||data.ok!==true)throw new Error(data?.msg||'请求失败（HTTP '+response.status+'）');
   return data;
  }catch(error){if(error.name==='AbortError')throw new Error('请求超时，数据可能已过期');throw error;}finally{clearTimeout(timeout);}
 }
 function connection(){
  const errors=[...failures].map(([key,msg])=>(labels[key]||key)+'：'+msg);
  $('global-error').hidden=!errors.length;$('global-error').textContent=errors.join('；');
  $('connection').dataset.state=errors.length?'error':state.lastSuccess?'ok':'pending';
  $('connection').textContent=document.hidden?'页面已隐藏 · 轮询暂停':errors.length?'部分数据异常':state.lastSuccess?'数据已连接':'正在连接';
  $('last-updated').textContent=state.lastSuccess?'最近成功读取：'+date(state.lastSuccess)+' · 各板块采样时间独立，失败时保留旧值并提示':'福小外 · 后台数据仅供管理员使用';
 }
 async function task(key,work){
  if(active.has(key)){again.add(key);return active.get(key);}
  const promise=(async()=>{try{await work();failures.delete(key);state.lastSuccess=Date.now();}catch(error){failures.set(key,error.message);}finally{active.delete(key);connection();if(again.delete(key)&&!document.hidden)task(key,work);}})();
  active.set(key,promise);return promise;
 }
 async function loadStats(){return task('stats',async()=>{
  const s=await api('/api/admin/stats');state.stats=s;
  $('ticket-count').textContent=fmt(s.tickets.count);$('ticket-today').textContent=fmt(s.tickets.today);$('ticket-bytes').textContent=size(s.tickets.bytes);$('ticket-ttl').textContent=fmt(s.limits.ttlDays)+' 天';
  $('feedback-count').textContent=fmt(s.feedback.unread);
  fields($('service-limits'),[['总请求限额',fmt(s.limits.ratePerMin)+' 次 / IP / 分钟'],['分享体积上限',size(s.limits.maxBody)],['课程数量上限',fmt(s.limits.maxCourses)+' 门'],['口令有效期',s.limits.ttlDays+' 天'],['最早口令',date(s.tickets.oldest)],['最新口令',date(s.tickets.newest)],['反馈总量 / 今日',fmt(s.feedback.total)+' / '+fmt(s.feedback.today)]]);
 });}
 async function loadTickets(){return task('tickets',async()=>{
  const params=new URLSearchParams({offset:state.ticketOffset,limit:20,q:state.ticketQuery,status:state.ticketStatus});
  const data=await api('/api/admin/ticket-search?'+params);state.tickets=data.rows;state.ticketTotal=data.total;
  if(state.ticketOffset>=data.total&&state.ticketOffset>0){state.ticketOffset=Math.max(0,Math.floor((data.total-1)/20)*20);again.add('tickets');return;}
  $('ticket-rows').replaceChildren();
  for(const r of data.rows){const tr=el('tr');const td=el('td');td.append(el('code',mask(r.code)));tr.append(td,el('td',(r.term||'未填写学期')+' / '+r.week+'周'),el('td',fmt(r.count)),el('td',date(r.createdAt)));
   const status=el('td');status.append(badge(statusNames[r.status]||'待检测',r.status==='invalid'?'danger':r.status==='expired'?'warning':''));tr.append(status);
   const buttons=el('td',null,'actions');for(const [action,label]of [['inspect','检测'],['copy','复制'],['delete','删除']]){const b=el('button',label,action==='delete'?'quiet danger':'quiet');b.type='button';b.dataset.ticketAction=action;b.dataset.code=r.code;buttons.append(b);}tr.append(buttons);$('ticket-rows').append(tr);
  }
  if(!data.rows.length){const tr=el('tr'),td=el('td','暂无匹配的口令','empty');td.colSpan=6;tr.append(td);$('ticket-rows').append(tr);}
  $('ticket-summary').textContent=`匹配 ${fmt(data.total)} 条 / 全部 ${fmt(data.allTotal)} 条 · 第 ${Math.floor(state.ticketOffset/20)+1} 页`;
  $('ticket-prev').disabled=state.ticketOffset===0;$('ticket-next').disabled=state.ticketOffset+20>=data.total;$('tickets-time').textContent='更新于 '+date(Date.now());
 });}
 function renderInspection(data){
  const status=$('inspect-status');status.className='badge '+(data.status==='valid'?'good':data.status==='expired'?'warning':'danger');status.textContent=statusNames[data.status]||'未知';
  const content=$('inspect-content');content.replaceChildren();
  if(data.message)content.append(el('p',data.message));
  const dl=el('dl');fields(dl,[['口令',mask(data.code)],['创建时间',date(data.createdAt)],['到期时间',date(data.expiresAt)],['学期 / 周次',(data.term||'—')+' / '+(data.week??'—')],['课程数量',data.count===undefined?'—':fmt(data.count)]]);content.append(dl);
  if(data.checks){const checks=el('div',null,'checks');for(const c of data.checks)checks.append(badge((c.ok?'通过 · ':'异常 · ')+c.name,c.ok?'good':'danger'));content.append(checks);}
  for(const warning of data.warnings||[])content.append(el('p',warning,'hint'));
  content.append(el('p','此检测没有改写数据，也不会改变口令有效期。','hint'));
  $('inspect-panel').hidden=false;$('inspect-panel').classList.remove('detail-enter');void $('inspect-panel').offsetWidth;$('inspect-panel').classList.add('detail-enter');
 }
 async function inspectCode(code){
  code=String(code).trim();if(!/^[a-f0-9]{32}$/i.test(code)){toast('请输入32位十六进制口令');$('inspect-code').focus();return;}
  const b=$('inspect-submit');if(b.disabled)return;b.disabled=true;b.textContent='检测中…';
  try{const data=await api('/api/admin/inspect',{method:'POST',body:{code}});renderInspection(data);$('inspect-hint').textContent='检测完成于 '+date(Date.now());}
  catch(error){$('inspect-panel').hidden=true;$('inspect-hint').textContent='检测失败：'+error.message;toast(error.message);}
  finally{b.disabled=false;b.textContent='检测口令';}
 }
 async function copy(value){try{if(!navigator.clipboard)throw new Error('请使用 HTTPS 入口复制口令');await navigator.clipboard.writeText(value);toast('已复制完整口令');}catch(error){toast(error.message||'复制失败，请检查浏览器权限');}}
 function confirmAction(title,description){return new Promise(resolve=>{const dialog=$('confirm-dialog');if(dialog.open){resolve(false);return;}$('confirm-title').textContent=title;$('confirm-description').textContent=description;dialog.returnValue='cancel';dialog.addEventListener('close',()=>resolve(dialog.returnValue==='confirm'),{once:true});dialog.showModal();});}
 async function deleteTicket(code,button){
  if(!await confirmAction('删除分享口令','将删除口令 '+mask(code)+'。持有该口令的用户将无法再导入；此操作不会删除用户设备内已导入的课程。'))return;
  button.disabled=true;try{await api('/api/admin/tickets/'+encodeURIComponent(code),{method:'DELETE'});toast('口令已删除');await Promise.all([loadTickets(),loadStats()]);}catch(error){toast(error.message);}finally{button.disabled=false;}
 }
 async function loadFeedback(){return task('feedback',async()=>{
  const data=await api('/api/admin/feedback?offset='+state.feedbackOffset+'&limit=50');state.feedback=data.rows;state.feedbackTotal=data.total;
  if(state.feedbackOffset>=data.total&&state.feedbackOffset>0){state.feedbackOffset=Math.max(0,Math.floor((data.total-1)/50)*50);again.add('feedback');return;}
  renderFeedbackList();$('feedback-summary').textContent='共 '+fmt(data.total)+' 条';$('feedback-page').textContent='第 '+(Math.floor(state.feedbackOffset/50)+1)+' 页';$('feedback-prev').disabled=!state.feedbackOffset;$('feedback-next').disabled=state.feedbackOffset+50>=data.total;
  const selected=state.feedback.find(r=>r.id===state.selectedFeedback);if(selected)renderFeedbackDetail(selected,false);else if(state.selectedFeedback){state.selectedFeedback=null;empty($('feedback-detail'),'选择一条反馈查看详情');}
 });}
 function renderFeedbackList(){
  const query=$('feedback-query').value.trim().toLowerCase(),status=$('feedback-status').value;
  const rows=state.feedback.filter(r=>(!status||(status==='read'?r.read:!r.read))&&(!query||[r.text,r.version,r.device].some(x=>String(x||'').toLowerCase().includes(query))));
  const list=$('feedback-list');list.replaceChildren();
  for(const r of rows){const b=el('button',null,'feedback-item');b.type='button';b.dataset.feedbackId=r.id;b.setAttribute('aria-pressed',String(r.id===state.selectedFeedback));b.append(el('strong',String(r.text||'图片反馈').slice(0,66)));
   const meta=el('div',null,'row');if(!r.read)meta.append(el('span',null,'unread-dot'));meta.append(el('span',(r.read?'已读':'未读')+' · '+(r.version||'版本未知')),el('span',date(r.createdAt)));b.append(meta);list.append(b);
  }
  if(!rows.length)empty(list,state.feedbackTotal?'本页没有匹配留言':'暂无反馈留言');
 }
 function renderFeedbackDetail(r,animate=true){
  const panel=$('feedback-detail');panel.replaceChildren();const heading=el('div',null,'panel-head');heading.append(el('h2','反馈详情'),badge(r.read?'已读':'未读',r.read?'good':''));panel.append(heading,el('p',r.text||'（仅图片）','message'));
  const dl=el('dl');fields(dl,[['提交时间',date(r.createdAt)],['应用 / 版本',(r.app||'福小外')+' / '+(r.version||'—')],['设备',r.device||'—']]);
  const contact=el('dd');const reveal=el('button',r.contact?'查看联系方式':'未提供联系方式','quiet');reveal.type='button';reveal.disabled=!r.contact;reveal.addEventListener('click',()=>{contact.replaceChildren(el('span',r.contact));});dl.append(el('dt','联系方式'),contact);contact.append(reveal);panel.append(dl);
  const attachments=el('div',null,'attachments');for(const url of r.images||[]){if(!/^\/api\/admin\/feedback\/img\/[a-f0-9]{16}_\d{1,2}\.(?:jpeg|png|webp)$/.test(url))continue;const b=el('button',null,'attachment');b.type='button';b.setAttribute('aria-label','放大反馈截图');const image=el('img');image.src=url;image.alt='反馈附件';image.loading='lazy';b.append(image);b.addEventListener('click',()=>{$('image-preview').src=url;$('image-dialog').showModal();});attachments.append(b);}panel.append(attachments);
  const controls=el('div',null,'detail-actions');const read=el('button',r.read?'已标为已读':'标为已读','primary');read.type='button';read.disabled=!!r.read;read.addEventListener('click',async()=>{read.disabled=true;try{await api('/api/admin/feedback/read',{method:'POST',body:{ids:[r.id]}});r.read=true;renderFeedbackList();renderFeedbackDetail(r,false);loadStats();toast('已标为已读');}catch(error){read.disabled=false;toast(error.message);}});
  const del=el('button','删除留言','danger');del.type='button';del.addEventListener('click',async()=>{if(!await confirmAction('删除反馈','将删除这条留言及其截图，操作不可撤销。'))return;del.disabled=true;try{await api('/api/admin/feedback/'+encodeURIComponent(r.id),{method:'DELETE'});state.selectedFeedback=null;empty(panel,'反馈已删除');await Promise.all([loadFeedback(),loadStats()]);toast('反馈已删除');}catch(error){del.disabled=false;toast(error.message);}});controls.append(read,del);panel.append(controls);
  if(animate){panel.classList.remove('detail-enter');void panel.offsetWidth;panel.classList.add('detail-enter');}
 }
 async function loadProbes(){return task('probes',async()=>{
  const data=await api('/api/admin/probes'),m=data.metrics,resources=$('resource-metrics');resources.replaceChildren();
  for(const [name,metric,note]of [['CPU 使用率',m.cpu,data.host.cores+' 核 / 主机整体'],['主机内存',m.mem,size(m.mem.used)+' / '+size(m.mem.total)],['磁盘使用率',m.disk,size(m.disk.used)+' / '+size(m.disk.total)]]){const card=el('div',null,'metric'),value=Number.isFinite(metric.percent)?metric.percent:null;card.append(el('p',name,'metric-label'),el('div',value===null?'未采集':value.toFixed(1)+'%','metric-value'),el('p',note,'metric-note'));const track=el('div',null,'track'),bar=el('span');bar.style.width=Math.max(0,Math.min(100,value||0))+'%';track.append(bar);card.append(track);resources.append(card);}
  const healthText=h=>(statusNames[h.state]||'未采集')+(h.latencyMs!==undefined?' · '+h.latencyMs+' ms':'')+(h.status?' / HTTP '+h.status:'');
  fields($('probe-health'),[['本机应用健康',healthText(data.health)],['公网 HTTPS',healthText(data.external)],['公网检查时间',date(data.external.checkedAt)],['证书到期',date(data.external.certificateExpiresAt)]]);
  fields($('probe-process'),[['应用运行时长',uptime(data.uptimeSec)],['进程 RSS',size(m.proc.rss)],['JS 已用堆',size(m.proc.heap)],['事件循环平均延迟',Number(m.proc.eventLoopMs).toFixed(1)+' ms']]);
  fields($('probe-host'),[['主机',data.host.hostname],['负载 1 / 5 / 15 分钟',data.host.load.map(n=>n.toFixed(2)).join(' / ')],['网络接收',m.net.state==='healthy'?size(m.net.rxBps)+'/s':'等待采样'],['网络发送',m.net.state==='healthy'?size(m.net.txBps)+'/s':'等待采样'],['磁盘可用',size(m.disk.avail)]]);
  $('probe-time').textContent='采样于 '+date(data.sampledAt);if(data.storageError)throw new Error(data.storageError);
 });}
 function alertItem(item){
  const wrapper=el('div',null,'alert-item'),row=el('div',null,'row'),isActive=item.state==='active';
  row.append(badge(isActive?'告警中':item.state==='resolved'?'已恢复':'重启后待复核',isActive?item.level==='danger'?'danger':'warning':item.state==='resolved'?'good':'warning'),el('span',item.title,'alert-title'));wrapper.append(row,el('p',item.detail));wrapper.append(el('p','发生：'+date(item.time)+(item.resolvedAt?' · 恢复：'+date(item.resolvedAt):''),'small'));return wrapper;
 }
 async function loadAlerts(){return task('alerts',async()=>{
  const data=await api('/api/admin/alerts');$('alert-count').textContent=data.active.length;$('alerts-active-count').textContent=data.active.length+' 项';$('alerts-time').textContent='采样于 '+date(data.sampledAt);
  $('active-alerts').replaceChildren();for(const r of data.active)$('active-alerts').append(alertItem(r));if(!data.active.length)empty($('active-alerts'),data.sampledAt?'当前未触发告警 · 不代表所有功能已完成业务验证':'等待系统采样');
  $('alert-history').replaceChildren();for(const r of data.rows)$('alert-history').append(alertItem(r));if(!data.rows.length)empty($('alert-history'),'暂无告警记录');if(data.storageError)throw new Error(data.storageError);
 });}
 async function loadAudit(){return task('audit',async()=>{
  const data=await api('/api/admin/audit');$('audit-rows').replaceChildren();for(const r of data.rows){const tr=el('tr'),outcome=el('td');outcome.append(badge(r.status>=200&&r.status<300?'成功':'失败 · '+r.status,r.status<300?'good':'danger'));tr.append(el('td',date(r.time)),el('td',r.actor),el('td',actions[r.action]||r.action),el('td',r.target?'#'+r.target:'—'),outcome);$('audit-rows').append(tr);}if(!data.rows.length){const row=el('tr'),cell=el('td','暂无操作记录','empty');cell.colSpan=5;row.append(cell);$('audit-rows').append(row);}$('audit-time').textContent='更新于 '+date(data.time);if(data.storageError)throw new Error(data.storageError);
 });}
 function loadPage(){return ({codes:loadTickets,feedback:loadFeedback,probes:loadProbes,alerts:loadAlerts,audit:loadAudit})[state.page]();}
 function navigate(page){if(!['codes','feedback','probes','alerts','audit'].includes(page))page='codes';state.page=page;document.querySelectorAll('[data-page]').forEach(b=>{if(b.dataset.page===page)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');});document.querySelectorAll('.page').forEach(s=>s.hidden=s.id!=='page-'+page);try{sessionStorage.setItem('fxw-admin-page',page);}catch{}loadPage();}
 document.querySelectorAll('[data-page]').forEach(b=>b.addEventListener('click',()=>navigate(b.dataset.page)));
 $('inspect-form').addEventListener('submit',event=>{event.preventDefault();inspectCode($('inspect-code').value);});
 $('inspect-clear').addEventListener('click',()=>{$('inspect-code').value='';$('inspect-panel').hidden=true;$('inspect-code').focus();});
 $('tickets-filter').addEventListener('submit',event=>{event.preventDefault();state.ticketQuery=$('ticket-query').value.trim();state.ticketStatus=$('ticket-status').value;state.ticketOffset=0;loadTickets();});
 $('ticket-prev').addEventListener('click',()=>{state.ticketOffset=Math.max(0,state.ticketOffset-20);loadTickets();});$('ticket-next').addEventListener('click',()=>{state.ticketOffset+=20;loadTickets();});
 $('ticket-rows').addEventListener('click',event=>{const b=event.target.closest('[data-ticket-action]');if(!b)return;const code=b.dataset.code;if(b.dataset.ticketAction==='copy')copy(code);else if(b.dataset.ticketAction==='delete')deleteTicket(code,b);else{$('inspect-code').value=code;inspectCode(code);$('inspect-form').scrollIntoView({block:'center',behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'});}});
 $('feedback-list').addEventListener('click',event=>{const b=event.target.closest('[data-feedback-id]');if(!b)return;state.selectedFeedback=b.dataset.feedbackId;renderFeedbackList();const row=state.feedback.find(r=>r.id===state.selectedFeedback);if(row)renderFeedbackDetail(row);});
 for(const id of ['feedback-query','feedback-status'])$(id).addEventListener(id==='feedback-query'?'input':'change',renderFeedbackList);
 $('feedback-prev').addEventListener('click',()=>{state.feedbackOffset=Math.max(0,state.feedbackOffset-50);loadFeedback();});$('feedback-next').addEventListener('click',()=>{state.feedbackOffset+=50;loadFeedback();});
 $('close-image').addEventListener('click',()=>$('image-dialog').close());$('image-dialog').addEventListener('close',()=>$('image-preview').removeAttribute('src'));
 $('refresh-all').addEventListener('click',async()=>{const b=$('refresh-all');b.disabled=true;b.classList.add('syncing');await Promise.all([loadStats(),loadAlerts(),loadPage()]);b.disabled=false;b.classList.remove('syncing');toast(failures.size?'部分数据未能刷新，请查看上方提示':'数据已刷新');});
 async function poll(){
  const generation=++pollGeneration;clearTimeout(pollTimer);if(document.hidden){connection();return;}
  cycle++;await loadStats();if(generation!==pollGeneration||document.hidden)return;
  if(cycle%3===0){await loadAlerts();if(generation!==pollGeneration||document.hidden)return;await loadPage();}
  if(generation!==pollGeneration||document.hidden)return;
  backoff=failures.size?Math.min(60000,Math.max(10000,backoff*2)):5000;pollTimer=setTimeout(poll,backoff);
 }
 document.addEventListener('visibilitychange',()=>{++pollGeneration;clearTimeout(pollTimer);connection();if(!document.hidden){loadPage();loadAlerts();poll();}});
 $('http-warning').hidden=location.protocol!=='http:'||['localhost','127.0.0.1'].includes(location.hostname);
 let saved='codes';try{saved=sessionStorage.getItem('fxw-admin-page')||saved;}catch{}navigate(saved);loadAlerts();poll();
})();
