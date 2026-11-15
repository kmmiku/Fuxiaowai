import { Capacitor, CapacitorHttp, registerPlugin } from '@capacitor/core';
import { App } from '@capacitor/app';
import { toast } from '../ui/toast';
const UpdateLink=registerPlugin<{open(options:{url:string}):Promise<void>}>('UpdateLink');
let busy=false,checked=false;
async function showAnnouncement(version:string,content:string):Promise<{update:boolean;ignore:boolean}>{
 return new Promise(resolve=>{
 const dialog=document.createElement('dialog');
 dialog.setAttribute('aria-label','更新公告');
 Object.assign(dialog.style,{border:'none',borderRadius:'24px',padding:'24px',width:'min(360px, calc(100vw - 48px))',boxSizing:'border-box',background:'var(--card, #fff)',color:'var(--text, #20232b)'});
 const title=document.createElement('h2');title.textContent='更新公告';title.style.margin='0 0 10px';
 const subtitle=document.createElement('p');subtitle.textContent='发现新版本 '+version;
 const body=document.createElement('p');body.textContent=content;Object.assign(body.style,{whiteSpace:'pre-wrap',maxHeight:'45vh',overflow:'auto',lineHeight:'1.6'});
 const label=document.createElement('label'),checkbox=document.createElement('input');checkbox.type='checkbox';label.append(checkbox,document.createTextNode(' 忽略此版本'));
 const actions=document.createElement('div');Object.assign(actions.style,{display:'flex',gap:'12px',marginTop:'22px'});
 const finish=(update:boolean)=>{const ignore=checkbox.checked;dialog.remove();resolve({update,ignore});};
 for(const [text,update] of [['暂不更新',false],['立即更新',true]] as const){
 const button=document.createElement('button');button.textContent=text;Object.assign(button.style,{flex:'1',border:'none',borderRadius:'12px',padding:'12px',background:update?'#4058ff':'#f1f2f7',color:update?'#fff':'#555'});button.onclick=()=>finish(update);actions.append(button);
 }
 dialog.append(title,subtitle,body,label,actions);dialog.oncancel=e=>{e.preventDefault();finish(false);};document.body.append(dialog);dialog.showModal();
 });
}
export async function checkAppUpdate(automatic=false):Promise<void>{
 if(busy||(automatic&&checked))return;
 busy=true;if(automatic)checked=true;
 try{
 if(!Capacitor.isNativePlatform()){if(!automatic)toast('请在安卓应用中检测更新');return;}
 if(!automatic)toast('正在检测更新…');
 const info=await App.getInfo();
 const response=await CapacitorHttp.get({url:'http://113.45.242.182/api/app-update?platform=android',connectTimeout:5000,readTimeout:5000});
 if(response.status!==200)throw Error();
 const data=typeof response.data==='string'?JSON.parse(response.data):response.data,r=data?.release;
 if(!data?.ok)throw Error();
 if(!r){if(!automatic)toast('当前暂无已发布的新版本');return;}
 if(r.platform!=='android'||!Number.isSafeInteger(r.versionCode)||typeof r.content!=='string'||r.content.length>2500||typeof r.versionName!=='string')throw Error();
 if(r.versionCode<=Number(info.build)){if(!automatic)toast('当前已是最新版本');return;}
 const url=new URL(r.updateUrl);if(url.protocol!=='https:'||url.username||url.password)throw Error();
 const key='fxw_android_update_ignored';
 if(automatic&&localStorage.getItem(key)===String(r.versionCode))return;
 const choice=await showAnnouncement(r.versionName,r.content);
 if(choice.update)await UpdateLink.open({url:url.href});
 else if(choice.ignore)localStorage.setItem(key,String(r.versionCode));

 }catch{if(!automatic)toast('暂时无法检查更新，请稍后重试');}finally{busy=false;}
}
