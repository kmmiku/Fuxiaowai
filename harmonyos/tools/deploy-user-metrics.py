"""Incremental deployment. Password is read outside repository and never printed."""
import pathlib,paramiko,time
base=pathlib.Path(__file__).resolve().parent.parent
c=paramiko.SSHClient();c.load_system_host_keys();c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
password=pathlib.Path('D:/fxw_build.vps_pass').read_text().strip()
c.connect('113.45.242.182',username='root',password=password,timeout=15);password=None
sftp=c.open_sftp();app='/opt/fxw-service';stamp=time.strftime('%Y%m%d-%H%M%S');backup=app+'/metrics-backup-'+stamp
def command(value):
 _,out,err=c.exec_command(value);status=out.channel.recv_exit_status()
 if status:raise RuntimeError('Remote deployment step failed; output omitted')
 return out.read().decode()
command('mkdir -m 700 '+backup)
original={n:sftp.open(app+'/'+n).read() for n in ['server.js','admin.js','dashboard.html']}
for n,data in original.items():
 with sftp.open(backup+'/'+n,'wb') as f:f.write(data)
source=original['server.js'].decode('utf-8-sig')
assert 'userMetrics' not in source
source=source.replace('const server = http.createServer(async (req, res) => {',"const userMetrics = require('./user-metrics').createUserMetrics({ ROOT, json, checkAuth, needAuth, readBody });\nconst server = http.createServer(async (req, res) => {")
marker='  adminConsole.observe(req, res, url);';assert marker in source
source=source.replace(marker,"  if(p==='/admin/user-metrics-ui.js' && req.method==='GET'){if(!checkAuth(req)){needAuth(req,res);return;}send(req,res,200,fs.readFileSync(path.join(__dirname,'user-metrics-ui.js')),'text/javascript; charset=utf-8');return;}\n"+marker)
marker='  // --- 公开：创建口令 ---';assert marker in source
source=source.replace(marker,'  if (await userMetrics.handle(req,res,url)) return;\n'+marker)
files={'server.js':source.encode()}
# Preserve live UI changes by applying only this feature's additions.
dash=original['dashboard.html'].decode('utf-8-sig');local=(base/'server/dashboard.html').read_text(encoding='utf-8-sig')
section=local[local.index('<section class="page" id="page-users"'):local.index('<footer class="footnote" id="last-updated">')]
dash=dash.replace('<button class="nav-button" data-page="update">','<button class="nav-button" data-page="users">用户列表</button><button class="nav-button" data-page="update">').replace('<footer class="footnote" id="last-updated">',section+'<footer class="footnote" id="last-updated">').replace('</head>','<script src="/admin/user-metrics-ui.js" defer></script></head>')
admin=original['admin.js'].decode('utf-8-sig').replace('update:loadUpdate})','update:loadUpdate,users:()=>Promise.resolve()})').replace("'audit','update'].includes","'audit','update','users'].includes")
files.update({'dashboard.html':dash.encode(),'admin.js':admin.encode()})
for n in ['user-metrics.js','user-metrics-ui.js']:files[n]=(base/'server'/n).read_bytes()
try:
 for n,data in files.items():
  with sftp.open(app+'/'+n,'wb') as f:f.write(data)
 command('cd '+app+' && node --check server.js && node --check user-metrics.js && node --check user-metrics-ui.js && node --check admin.js')
 command('systemctl restart fxw-share');time.sleep(2)
 assert command('systemctl is-active fxw-share').strip()=='active'
 assert command('curl -fsS http://127.0.0.1:8080/healthz').strip()=='ok'
 print('Deployment active; health ok; backup: '+backup)
except Exception:
 for n,data in original.items():
  with sftp.open(app+'/'+n,'wb') as f:f.write(data)
 command('systemctl restart fxw-share');raise
finally:sftp.close();c.close()
