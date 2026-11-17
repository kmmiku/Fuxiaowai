"""Incremental release, run on VPS; credentials remain in process memory."""
import base64,hashlib,json,os,re,shutil,subprocess,time,urllib.request,urllib.error
from pathlib import Path
APP=Path('/opt/fxw-service');STAGE=Path('/opt/fxw-update-stage-20261115');ROOT=Path('/var/lib/fxw')
FILES=['admin-console.js','admin.js','admin.css','dashboard.html']
EXPECTED='55af3d91d06a5c4ec590e5ea518a07344d4c8ac98e778a307d2c8fe9bf30328f'
def run(*args):return subprocess.run(args,check=True,capture_output=True,timeout=40).stdout
assert hashlib.sha256((APP/'admin-console.js').read_bytes()).hexdigest()==EXPECTED,'Unexpected live module; refused'
source=(APP/'server.js').read_text()
assert 'adminConsole.handle(req, res, url)' in source,'Missing route extension'
pid=run('systemctl','show','-p','MainPID','--value','fxw-share').decode().strip()
env=dict(os.environ)
for item in Path('/proc/'+pid+'/environ').read_bytes().split(b'\0'):
 if b'=' in item:
  k,v=item.split(b'=',1);env[k.decode()]=v.decode()
declarations=[]
for name in ['ADMIN_USER','ADMIN_PASS']:
 match=re.search(r'^const '+name+r' = (.+);$',source,re.M);assert match,'Unknown auth configuration';declarations.append('const '+name+' = '+match.group(1)+';')
script='\n'.join(declarations)+'\nprocess.stdout.write(JSON.stringify([ADMIN_USER,ADMIN_PASS]));'
auth=base64.b64encode((':'.join(json.loads(subprocess.run(['node'],input=script.encode(),env=env,capture_output=True,check=True,timeout=5).stdout))).encode()).decode()
port=env.get('FXW_PORT','8080')
def request(route,method='GET',body=None,authenticated=False,origin=None):
 headers={'Host':'fuxiaowai.xyz','Content-Type':'application/json'}
 if authenticated:headers['Authorization']='Basic '+auth
 if origin:headers['Origin']=origin
 req=urllib.request.Request('http://127.0.0.1:'+port+route,method=method,headers=headers,data=None if body is None else json.dumps(body).encode())
 try:
  with urllib.request.urlopen(req,timeout=10) as r:return r.status,r.read()
 except urllib.error.HTTPError as e:return e.code,e.read()
def manifest():
 return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for sub in ['tickets','feedback'] for p in (ROOT/sub).rglob('*') if p.is_file()}
for f in ['admin-console.js','admin.js']:run('node','--check',str(STAGE/f))
before=manifest();serverhash=hashlib.sha256((APP/'server.js').read_bytes()).hexdigest()
backup=Path('/var/backups/fxw/update-'+time.strftime('%Y%m%d-%H%M%S'));backup.mkdir(mode=0o700,parents=True)
for f in FILES:shutil.copy2(APP/f,backup/f)
announcement=ROOT/'admin/app-update.json'
original=announcement.read_bytes() if announcement.exists() else None
try:
 for f in FILES:shutil.copy2(STAGE/f,APP/f)
 run('systemctl','restart','fxw-share')
 for i in range(30):
  try:
   if request('/healthz')[0]==200:break
  except Exception:pass
  time.sleep(.3)
 assert request('/healthz')[0]==200
 assert request('/api/admin/app-update')[0]==401
 assert request('/api/app-update')[0]==200
 status,body=request('/api/admin/app-update',authenticated=True);assert status==200
 previous=json.loads(body)['release']
 assert request('/api/admin/app-update','PUT',{},True,'https://evil.example')[0]==403
 if previous is None:
  # Installed source version, not a fictitious future release; remove immediately after validation.
  sample={'versionCode':1000001,'versionName':'0.1.1','content':'Deployment verification'}
  assert request('/api/admin/app-update','PUT',sample,True)[0]==200
  assert json.loads(request('/api/app-update')[1])['release']['versionCode']==1000001
  assert request('/api/admin/app-update','DELETE',authenticated=True)[0]==200
  assert json.loads(request('/api/app-update')[1])['release'] is None
 assert before==manifest(),'Business data changed'
 assert serverhash==hashlib.sha256((APP/'server.js').read_bytes()).hexdigest()
 report={'backup':str(backup),'health':200,'authenticatedManagement':200,'unauthenticatedManagement':401,'crossOriginWrite':403,'publicUpdate':200,'businessDataUnchanged':True,'serverUnchanged':True,'publicationAndWithdrawalTested':previous is None,'existingAnnouncementPreserved':previous is not None,'files':{f:hashlib.sha256((APP/f).read_bytes()).hexdigest() for f in FILES}}
 (backup/'report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
except Exception:
 if original is None:announcement.unlink(missing_ok=True)
 else:announcement.write_bytes(original)
 for f in FILES:shutil.copy2(backup/f,APP/f)
 run('systemctl','restart','fxw-share')
 raise
