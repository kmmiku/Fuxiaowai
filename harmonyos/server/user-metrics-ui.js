'use strict';
(()=>{
 let offset=0,busy=false;const $=id=>document.getElementById(id);
 async function load(){if(busy)return;busy=true;try{
  const response=await fetch('/api/admin/users?offset='+offset,{cache:'no-store',credentials:'same-origin'});
  if(!response.ok)throw new Error('统计读取失败，请确认管理员认证');const d=await response.json();
  $('users-total').textContent=d.total;$('users-note').textContent='';$('users-note').hidden=true;
  $('users-rows').replaceChildren(...d.users.map(u=>{const tr=document.createElement('tr');for(const value of [u.userId,u.registeredAt]){const td=document.createElement('td');td.textContent=value;tr.append(td);}return tr;}));
  $('users-prev').disabled=offset===0;$('users-next').disabled=offset+50>=d.total;
  const ns='http://www.w3.org/2000/svg';const make=(tag,attrs,text)=>{const e=document.createElementNS(ns,tag);for(const [k,v]of Object.entries(attrs))e.setAttribute(k,v);if(text!==undefined)e.textContent=text;return e;};
  const svg=make('svg',{viewBox:'0 0 800 280',role:'img','aria-label':'最近7天新增注册人数',style:'width:100%;max-height:320px;display:block;font:13px system-ui'});
  const max=Math.max(4,Math.ceil(Math.max(...d.daily.map(v=>v.count))/4)*4),x=i=>65+i*112,y=v=>220-v/max*175;
  const defs=make('defs',{}),gradient=make('linearGradient',{id:'user-area',x1:0,y1:0,x2:0,y2:1});gradient.append(make('stop',{offset:'0%','stop-color':'#5268ff','stop-opacity':'.24'}),make('stop',{offset:'100%','stop-color':'#5268ff','stop-opacity':'.01'}));defs.append(gradient);svg.append(defs);
  for(let i=0;i<=4;i++){const value=max*i/4;svg.append(make('line',{x1:65,x2:737,y1:y(value),y2:y(value),stroke:'#e9edf5','stroke-dasharray':'4 5'}),make('text',{x:48,y:y(value)+4,'text-anchor':'end',fill:'#8993a6'},value));}
  const points=d.daily.map((v,i)=>x(i)+','+y(v.count)).join(' ');svg.append(make('polygon',{points:'65,220 '+points+' 737,220',fill:'url(#user-area)'}),make('polyline',{points,fill:'none',stroke:'#5268ff','stroke-width':3,'stroke-linejoin':'round','stroke-linecap':'round'}));
  d.daily.forEach((v,i)=>{const dot=make('circle',{cx:x(i),cy:y(v.count),r:5,fill:'#fff',stroke:'#5268ff','stroke-width':3});dot.append(make('title',{},v.day+'：'+v.count+'人'));svg.append(dot,make('text',{x:x(i),y:y(v.count)-14,'text-anchor':'middle',fill:'#5268ff','font-weight':600},v.count),make('text',{x:x(i),y:252,'text-anchor':'middle',fill:'#8993a6'},v.day.slice(5)));});$('users-chart').replaceChildren(svg);

 }catch(e){$('users-note').hidden=false;$('users-note').textContent=e.message;}finally{busy=false;}}
 $('users-refresh').onclick=load;$('users-prev').onclick=()=>{offset=Math.max(0,offset-50);load();};$('users-next').onclick=()=>{offset+=50;load();};
 document.querySelector('[data-page="users"]').addEventListener('click',load);
 setInterval(()=>{if(!document.hidden&&!$('page-users').hidden)load();},30000);
})();
