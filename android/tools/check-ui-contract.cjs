const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),ts=require('typescript'),assert=require('node:assert/strict');
const baseline=process.argv[2]||'f2ce3c4';
const crypto=require('node:crypto');
const approved=require('../Map/approved-ui-20261114.json');
const hash=s=>crypto.createHash('sha256').update(s.replace(/\r\n/g,'\n')).digest('hex');
const approvedCopy={"src/pages/AccountPage.tsx": [["凭据当前保存在应用私有目录，其他应用读不到；上架前会改成 HUKS 加密存储。", "凭据由 Android Keystore 保护后保存在本机；请勿向他人提供密码或会话。"]], "src/pages/AboutPage.tsx": [["不上传任何个人信息", "主动分享和反馈按需上传"]], "src/pages/PrivacyDocPage.tsx": [["福小外 · 开发者不运营服务器，所有个人数据保存在你的设备上", "福小外 · 登录资料主要保存在本机，主动分享和反馈会上传指定内容"]]};
const printer=ts.createPrinter({removeComments:true});
function markup(text,file){text=text.replace(/\r\n/g,'\n');const root=ts.createSourceFile(file,text,ts.ScriptTarget.Latest,true,ts.ScriptKind.TSX),out=[];function visit(node){if(ts.isJsxElement(node)||ts.isJsxSelfClosingElement(node)||ts.isJsxFragment(node)){out.push(printer.printNode(ts.EmitHint.Unspecified,node,root));return;}ts.forEachChild(node,visit);}visit(root);return out;}
let count=0;
for(const name of fs.readdirSync('src/pages').filter(n=>n.endsWith('.tsx'))){const file='src/pages/'+name;const current=markup(fs.readFileSync(file,'utf8'),file);if(approved.pages[file]){assert.equal(hash(JSON.stringify(current)),approved.pages[file],'Approved UI changed: '+file);}else{let old=cp.execFileSync('git',['show',baseline+':'+file],{encoding:'utf8'});for(const [before,after] of approvedCopy[file]||[])old=old.replace(before,after);assert.deepEqual(current,markup(old,file),'UI markup changed: '+file);}count++;}
for(const [file,expected] of Object.entries(approved.files))assert.equal(hash(fs.readFileSync(file,'utf8')),expected,'Approved UI changed: '+file);
const excludes=Object.keys(approved.files).map(file=>':(exclude)'+file);
cp.execFileSync('git',['diff','--exit-code',baseline,'--','src/styles','src/components','src/ui',...excludes]);
console.log(JSON.stringify({baseline,pages:count,jsx:'baseline plus approved privacy copy and P1-P6 changes',styles:'baseline plus approved calendar and campus styles',components:'unchanged',uiUtilities:'baseline plus approved TimetableIcon'}));
