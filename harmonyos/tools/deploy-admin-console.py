"""Run on the VPS as root after uploading the five console files to STAGE.

No credentials are printed. This release patches the deployed backend rather
than replacing it with the workspace's unrelated hardened draft.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import time
import urllib.error
import urllib.request

APP = Path('/opt/fxw-service')
ROOT = Path('/var/lib/fxw')
STAGE = Path('/opt/fxw-admin-stage-20261114')
FILES = ['server.js', 'dashboard.html', 'admin-console.js', 'admin.js', 'admin.css']
EXPECTED_SOURCE = 'b65089a2d33bfc2f5375ba7e62bcb4a557034cd237931a1e337b1191f8657ed6'


def command(*args):
    return subprocess.run(args, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=45).stdout


def patch_source(source):
    marker = 'const server = http.createServer(async (req, res) => {'
    route = '  const p = url.pathname;'
    if source.count(marker) != 1 or source.count(route) != 1 or 'adminConsole' in source:
        raise RuntimeError('Unexpected backend version; refused to patch')
    source = source.replace(marker, "const adminConsole = require('./admin-console').createAdminConsole({ ROOT, TICKET_DIR, TTL_MS, PORT, BIND, json, checkAuth, needAuth });\n" + marker)
    return source.replace(route, route + '\n  adminConsole.observe(req, res, url);\n  if (await adminConsole.handle(req, res, url)) return;')


def manifest():
    return {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT / 'tickets').iterdir()) if p.is_file()}


def verify_credentials(source, environment):
    # Evaluate just the two existing constant expressions in Node. Values remain
    # on this host and are used only for loopback verification.
    declarations = []
    for name in ['ADMIN_USER', 'ADMIN_PASS']:
        match = re.search(r'^const ' + name + r' = (.+);$', source, re.M)
        if not match:
            raise RuntimeError('Cannot resolve administrator configuration')
        declarations.append('const ' + name + ' = ' + match.group(1) + ';')
    script = '\n'.join(declarations) + '\nprocess.stdout.write(JSON.stringify([ADMIN_USER,ADMIN_PASS]));'
    result = subprocess.run(['node'], input=script.encode(), env=environment, check=True, capture_output=True, timeout=5)
    user, password = json.loads(result.stdout)
    return 'Basic ' + base64.b64encode((user + ':' + password).encode()).decode()


def request(port, route, auth=None, body=None):
    headers = {'Host': 'fuxiaowai.xyz'}
    if auth:
        headers['Authorization'] = auth
    if body is not None:
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request('http://127.0.0.1:' + str(port) + route, headers=headers, data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()


def main():
    if os.geteuid() != 0:
        raise RuntimeError('Root deployment required')
    source = (APP / 'server.js').read_text(encoding='utf-8')
    if hashlib.sha256(source.encode()).hexdigest() != EXPECTED_SOURCE:
        raise RuntimeError('Live backend changed since inspection; refused to overwrite')
    patched = patch_source(source)
    for name in FILES[1:]:
        if not (STAGE / name).is_file():
            raise RuntimeError('Missing staged file: ' + name)
    # Capture current runtime environment without emitting it or saving it.
    pid = command('systemctl', 'show', 'fxw-share.service', '-p', 'MainPID', '--value').decode().strip()
    environment = dict(os.environ)
    for item in Path('/proc/' + pid + '/environ').read_bytes().split(b'\0'):
        if b'=' in item:
            key, value = item.split(b'=', 1)
            environment[key.decode()] = value.decode()
    port = int(environment.get('FXW_PORT', '80'))
    auth = verify_credentials(source, environment)
    backup = Path('/var/backups/fxw') / ('admin-' + time.strftime('%Y%m%d-%H%M%S'))
    backup.mkdir(parents=True, mode=0o700)
    os.chmod(backup, 0o700)
    originals = backup / 'source'
    originals.mkdir(mode=0o700)
    existed = {name: (APP / name).is_file() for name in FILES}
    for name in FILES:
        if existed[name]:
            shutil.copy2(APP / name, originals / name)
            os.chmod(originals / name, 0o600)
    (STAGE / 'server.js').write_text(patched, encoding='utf-8')
    for name in ['server.js', 'admin-console.js', 'admin.js']:
        command('node', '--check', str(STAGE / name))
    stopped = False
    cleared = 0
    before = None
    try:
        command('systemctl', 'stop', 'fxw-share.service')
        stopped = True
        before = manifest()
        (backup / 'tickets-sha256.json').write_text(json.dumps(before), encoding='utf-8')
        os.chmod(backup / 'tickets-sha256.json', 0o600)
        archive = backup / 'data.tar.gz'
        with tarfile.open(archive, 'w:gz') as tar:
            tar.add(ROOT, arcname='fxw')
        os.chmod(archive, 0o600)
        key = backup / 'backup.key'
        key.write_text(os.urandom(48).hex(), encoding='ascii')
        os.chmod(key, 0o600)
        encrypted = backup / 'data.tar.gz.enc'
        command('openssl', 'enc', '-aes-256-cbc', '-pbkdf2', '-iter', '200000', '-salt', '-in', str(archive), '-out', str(encrypted), '-pass', 'file:' + str(key))
        os.chmod(encrypted, 0o600)
        # Verify encrypted backup before removing plaintext or modifying data.
        restored = backup / 'verify.tar.gz'
        command('openssl', 'enc', '-d', '-aes-256-cbc', '-pbkdf2', '-iter', '200000', '-in', str(encrypted), '-out', str(restored), '-pass', 'file:' + str(key))
        if hashlib.sha256(restored.read_bytes()).digest() != hashlib.sha256(archive.read_bytes()).digest():
            raise RuntimeError('Backup verification failed')
        restored.unlink(); archive.unlink()
        for name in FILES:
            destination = APP / name
            temp = APP / (name + '.admin-next')
            shutil.copy2(STAGE / name, temp)
            os.chmod(temp, 0o644)
            os.replace(temp, destination)
        # User explicitly authorized clearing current feedback, never tickets.
        feedback = (ROOT / 'feedback').resolve()
        if feedback != Path('/var/lib/fxw/feedback'):
            raise RuntimeError('Unexpected feedback path')
        for item in feedback.iterdir():
            if item.is_file() and re.fullmatch(r'[a-f0-9]{16}\.json', item.name):
                item.unlink(); cleared += 1
        image_dir = feedback / 'img'
        if image_dir.is_dir() and not image_dir.is_symlink():
            for item in image_dir.iterdir():
                if item.is_file() and re.fullmatch(r'[a-f0-9]{16}_\d{1,2}\.(jpeg|png|webp)', item.name):
                    item.unlink()
        if manifest() != before:
            raise RuntimeError('Ticket integrity mismatch before restart')
        # Write deployment audit before starting the sole service process.
        record_script = "const c=require('./admin-console').createAdminConsole({ROOT:'/var/lib/fxw',TICKET_DIR:'/var/lib/fxw/tickets',TTL_MS:2592000000,PORT:0,BIND:'127.0.0.1',json(){},checkAuth(){return true},needAuth(){},externalProbe:false});c.record('deploy');c.record('feedback.clear');c.close().then(()=>{});"
        subprocess.run(['node', '-e', record_script], cwd=APP, check=True, capture_output=True, timeout=5)
        command('systemctl', 'start', 'fxw-share.service')
        stopped = False
        for _ in range(30):
            try:
                if request(port, '/healthz')[0] == 200:
                    break
            except OSError:
                pass
            time.sleep(.2)
        else:
            raise RuntimeError('Health check failed after restart')
        protected = ['/admin', '/admin/admin.js', '/admin/admin.css', '/api/admin/stats', '/api/admin/tickets', '/api/admin/feedback', '/api/admin/ticket-search', '/api/admin/probes', '/api/admin/alerts', '/api/admin/audit']
        for route in protected:
            if request(port, route)[0] != 401:
                raise RuntimeError('Authentication boundary failed: ' + route)
            status, body = request(port, route, auth)
            if status != 200:
                raise RuntimeError('Authenticated route failed: ' + route)
            if route == '/admin' and '福小外 · 管理后台'.encode() not in body:
                raise RuntimeError('Dashboard version mismatch')
            if route == '/api/admin/feedback' and json.loads(body)['total'] != 0:
                raise RuntimeError('Feedback not empty after authorized reset')
        valid_tested = False
        for name in before:
            try:
                data = json.loads((ROOT / 'tickets' / name).read_text())
                if data.get('createdAt', 0) + 2592000000 <= time.time() * 1000:
                    continue
                status, result = request(port, '/api/admin/inspect', auth, {'code': name[:-5]})
                if status != 200 or not json.loads(result)['ok']:
                    raise RuntimeError('Existing code inspection failed')
                status, result = request(port, '/api/share/' + name[:-5])
                if status != 200 or json.loads(result).get('courses') != data.get('courses'):
                    raise RuntimeError('Existing public share changed')
                valid_tested = True
                break
            except (ValueError, TypeError):
                continue
        if manifest() != before:
            raise RuntimeError('Ticket integrity mismatch after verification')
        # HTTPS requests carry no credentials here.
        with urllib.request.urlopen('https://fuxiaowai.xyz/healthz', timeout=10) as response:
            if response.status != 200 or response.read().strip() != b'ok':
                raise RuntimeError('Public HTTPS health check failed')
        report = {'deployedAt': time.strftime('%Y-%m-%d %H:%M:%S %z'), 'backup': str(backup), 'ticketsBefore': len(before), 'ticketsAfter': len(manifest()), 'ticketHashesUnchanged': True, 'feedbackCleared': cleared, 'authenticatedRoutesVerified': len(protected), 'existingShareReadVerified': valid_tested, 'httpsHealth': 200, 'sourceHashes': {name: hashlib.sha256((APP / name).read_bytes()).hexdigest() for name in FILES}}
        (backup / 'deployment-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps(report, ensure_ascii=False))
    except Exception:
        command('systemctl', 'stop', 'fxw-share.service')
        for name in FILES:
            if existed[name]:
                shutil.copy2(originals / name, APP / name)
                os.chmod(APP / name, 0o644)
            elif (APP / name).is_file():
                (APP / name).unlink()
        # Rollback restores feedback only. Ticket files are never restored or overwritten.
        encrypted = backup / 'data.tar.gz.enc'
        if encrypted.is_file():
            restored = backup / 'rollback.tar.gz'
            command('openssl', 'enc', '-d', '-aes-256-cbc', '-pbkdf2', '-iter', '200000', '-in', str(encrypted), '-out', str(restored), '-pass', 'file:' + str(backup / 'backup.key'))
            with tarfile.open(restored, 'r:gz') as tar:
                for member in tar.getmembers():
                    if member.name.startswith('fxw/feedback/') and member.isfile():
                        destination = ROOT / member.name.removeprefix('fxw/')
                        if destination.resolve().is_relative_to((ROOT / 'feedback').resolve()):
                            destination.parent.mkdir(parents=True, exist_ok=True)
                            with tar.extractfile(member) as src, destination.open('wb') as dst:
                                shutil.copyfileobj(src, dst)
                            os.chmod(destination, 0o600)
            restored.unlink()
        command('systemctl', 'start', 'fxw-share.service')
        print('Deployment failed; source and feedback rolled back. Tickets were not overwritten.')
        raise
    finally:
        if stopped:
            command('systemctl', 'start', 'fxw-share.service')


if __name__ == '__main__':
    main()
