// Encrypted, verified app-data backup. Output and key must live outside the repository in a private directory.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawn}=require('node:child_process'),{pipeline}=require('node:stream/promises');
async function main(){
 const [serial,directory]=process.argv.slice(2);
 if(!/^emulator-\d+$/.test(serial||'')||!directory)throw Error('Expected an explicit emulator serial and private backup directory');
 const root=path.resolve(directory),repository=path.resolve(__dirname,'..');
 if(root===repository||root.startsWith(repository+path.sep))throw Error('Private backup must be outside the repository');
 fs.mkdirSync(root,{recursive:true});
 const file=path.join(root,'app-data.fxwb'),keyFile=path.join(root,'backup.key');
 const key=crypto.randomBytes(32),iv=crypto.randomBytes(12);
 fs.writeFileSync(keyFile,key,{flag:'wx',mode:0o600});
 const output=fs.createWriteStream(file,{flags:'wx',mode:0o600});output.write(Buffer.concat([Buffer.from('FXWB1'),iv]));
 const cipher=crypto.createCipheriv('aes-256-gcm',key,iv),hash=crypto.createHash('sha256');
 const adb=process.env.ADB_PATH||'adb';
 const child=spawn(adb,['-s',serial,'exec-out','run-as','com.fuxiaowai.timetable','tar','-cf','-','.'],{stdio:['ignore','pipe','pipe']});
 const closed=new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',resolve)});
 child.stderr.resume();child.stdout.on('data',b=>hash.update(b));
 await pipeline(child.stdout,cipher,output);
 if(await closed!==0)throw Error('App-data archive failed; do not use this backup');
 fs.appendFileSync(file,cipher.getAuthTag());
 const expected=hash.digest('hex'),sealed=fs.readFileSync(file),dec=crypto.createDecipheriv('aes-256-gcm',key,sealed.subarray(5,17));
 dec.setAuthTag(sealed.subarray(-16));const plain=Buffer.concat([dec.update(sealed.subarray(17,-16)),dec.final()]);
 if(crypto.createHash('sha256').update(plain).digest('hex')!==expected)throw Error('Backup verification failed');
 plain.fill(0);key.fill(0);
 fs.writeFileSync(path.join(root,'verification.json'),JSON.stringify({verified:true,bytes:sealed.length,cipherSha256:crypto.createHash('sha256').update(sealed).digest('hex'),note:'Restore app files only on the same device with its Keystore identity retained. This is not a cross-device key backup.'},null,2),{mode:0o600});
 console.log(JSON.stringify({verified:true,encryptedBackup:file,keyFile,bytes:sealed.length}));
}
main().catch(()=>{console.error('Encrypted backup failed; preserve the private directory for inspection.');process.exitCode=1;});
