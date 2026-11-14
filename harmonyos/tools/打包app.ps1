param(
  [string]$CertFile  = '',
  [string]$Profile   = '',
  [string]$Keystore  = $env:FXW_KEYSTORE,
  [string]$KeyAlias  = 'fuxiaowai',
  [string]$KeyPwd    = $env:FXW_KEY_PASSWORD,
  [string]$SignAlg   = '',
  [string]$Hap       = '',
  [string]$PackInfo  = '',
  [string]$AppTemplate = '',
  [string]$Out       = ''
)

# 用 AGC 签发的 .cer + .p7b 给 release 版 hap 签名，再打成 AGC 可上传的 .app
# 用法：把 AGC 下载的两个文件丢到「下载」或 assets\signing，直接 .\打包app.ps1
#
# 关键点（2026-11-13 修）：AGC 的「软件包解析失败」主要来自 .app 结构不完整——
# 用 app_packing_tool 只塞了 hap + pack.info，缺 hvigor 生成的 pac.json，条目顺序也不同。
# 现在改成以 hvigor 的 fuxiaowai-default-unsigned.app 为模板，只把里面的
# entry-default.hap 换成用 AGC 证书签过的 hap，pack.info / pac.json / 条目顺序原样保留。

# java 会往 stderr 打 WARN（如 Missing parameter: outproof / Unsafe 警告），
# ErrorActionPreference=Stop 会把它们当致命错误，所以这里用 Continue，失败只认退出码
$ErrorActionPreference = 'Continue'
$java   = 'D:\DevEco Studio\jbr\bin\java.exe'
$sign   = 'D:\DevEco Studio\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar'
$pack   = 'D:\DevEco Studio\sdk\default\openharmony\toolchains\lib\app_packing_tool.jar'
$proj   = Split-Path -Parent $PSScriptRoot
$build  = 'D:\fxw_build\hardening\HarmonyOs'

function Fail($msg) { Write-Host "✗ $msg" -ForegroundColor Red; exit 1 }
if (-not $KeyPwd -or -not $Keystore) { Fail '请通过 FXW_KEYSTORE 与 FXW_KEY_PASSWORD 环境变量传入私钥与密码。' }
if (-not $Out) {
  $fxwVersion = (Get-Content -LiteralPath (Join-Path $proj 'AppScope\app.json5') -Raw -Encoding UTF8 | ConvertFrom-Json).app.versionName
  $Out = Join-Path $proj "dist\福小外-$fxwVersion-signed.app"
}
New-Item -ItemType Directory -Path (Split-Path $Out -Parent) -Force | Out-Null
$manifestPath = Join-Path $proj 'dist\build-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { Fail '缺少源码构建清单，请先运行 tools\构建.ps1。' }
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($record in $manifest.source) {
  $sourceFile = [IO.Path]::GetFullPath((Join-Path $proj $record.path))
  if (-not $sourceFile.StartsWith($proj + '\', [StringComparison]::OrdinalIgnoreCase) -or
      -not (Test-Path -LiteralPath $sourceFile) -or
      (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash -ne $record.sha256) {
    Fail '源码在构建后发生变化，请重新构建后签名。'
  }
}

# ---------- 1. 找证书与 Profile ----------
$skip = @('root.cer','subca.cer','root256.cer','subca256.cer','fuxiaowai256.p7b')
$searchDirs = @(
  (Join-Path $proj 'assets\signing'),
  (Join-Path $proj 'dist'),
  "$env:USERPROFILE\Downloads",
  "$env:USERPROFILE\Desktop",
  "$env:USERPROFILE\Documents",
  'D:\360安全浏览器下载'
)

if (-not $CertFile) {
  $cands = foreach ($d in $searchDirs) {
    if (Test-Path $d) {
      Get-ChildItem $d -Filter *.cer -File -ErrorAction SilentlyContinue |
        Where-Object { $skip -notcontains $_.Name }
    }
  }
  $cands = @($cands | Sort-Object LastWriteTime -Descending)
  if ($cands.Count -eq 0) {
    Fail "没找到 AGC 证书（*.cer）。把下载的证书放进 $($searchDirs[0]) 或 下载 文件夹，或用 -CertFile 指定。"
  }
  $CertFile = $cands[0].FullName
}
if (-not $Profile) {
  $cands = foreach ($d in $searchDirs) {
    if (Test-Path $d) {
      Get-ChildItem $d -Filter *.p7b -File -ErrorAction SilentlyContinue |
        Where-Object { $skip -notcontains $_.Name }
    }
  }
  $cands = @($cands | Sort-Object LastWriteTime -Descending)
  if ($cands.Count -eq 0) {
    Fail "没找到 AGC Profile（*.p7b）。同上，放进 $($searchDirs[0]) 或 下载 文件夹。"
  }
  $Profile = $cands[0].FullName
}

# ---------- 2. 找 release 版 hap 与 .app 模板 ----------
if (-not $Hap) {
  $c = @(@(
    (Join-Path $build 'entry\build\default\outputs\default\entry-default-unsigned.hap'),
    (Join-Path $proj  'entry\build\default\outputs\default\entry-default-unsigned.hap')
  ) | Where-Object { Test-Path $_ })
  if ($c.Count -eq 0) { Fail '没找到 entry-default-unsigned.hap，先跑一次 assembleApp。' }
  $Hap = [string]$c[0]
}

if (-not $PackInfo) { $PackInfo = Join-Path (Split-Path $Hap -Parent) 'pack.info' }
if (-not $AppTemplate) {
  $c = @(@(
    (Join-Path $build 'build\outputs\default\HarmonyOs-default-unsigned.app'),
    (Join-Path $proj  'build\outputs\default\fuxiaowai-default-unsigned.app')
  ) | Where-Object { Test-Path $_ })
  if ($c.Count -gt 0) { $AppTemplate = [string]$c[0] }
}

foreach ($f in @($Keystore, $CertFile, $Profile)) {
  if (-not (Test-Path $f)) { Fail "缺少文件：$f" }
}
if (-not (Test-Path $PackInfo)) { Fail "缺少 pack.info：$PackInfo（assembleApp 会一起生成）" }
if (-not $AppTemplate) {
  Fail '没有找到本次构建的 .app 模板，请先运行 tools\构建.ps1。'
}

Write-Host "证书     : $CertFile"
Write-Host "Profile  : $Profile"
Write-Host "密钥库   : $Keystore (alias=$KeyAlias)"
Write-Host "hap      : $Hap  ($([math]::Round((Get-Item $Hap).Length/1MB,2)) MB)"
if ($AppTemplate) { Write-Host "模板     : $AppTemplate" }
Write-Host ""

# ---------- 2.5 规整证书链：AGC 下载的 .cer 是「根 → 中间 CA → 叶子」倒序，
#                直接丢给 hap-sign-tool 会在签名块里写成 [Root, Leaf, CA]，
#                AGC 侧「软件包完整性校验不通过」。这里改成 [叶子, 中间 CA...]，
#                并把自签名的根证书去掉（根由华为侧信任链提供）。
function Get-CertChainPem {
  param([string]$Path)
  $raw = [System.IO.File]::ReadAllText($Path)
  $matches = [regex]::Matches($raw, '-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----')
  $list = @()
  foreach ($m in $matches) {
    $b64 = ($m.Value -replace '-----[^-]+-----', '') -replace '\s', ''
    $der = [System.Convert]::FromBase64String($b64)
    $c = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 (,$der)
    $list += [pscustomobject]@{ Cert = $c; Pem = $m.Value.Trim() + "`n"; Subj = $c.Subject; Iss = $c.Issuer }
  }
  if ($list.Count -eq 0) { Fail "读不出证书：$Path" }
  # 去掉自签名根（Subject == Issuer）
  $chain = @($list | Where-Object { $_.Subj -ne $_.Iss })
  if ($chain.Count -eq 0) { $chain = $list }
  # 找叶子：它的 Subject 不是任何其它证书的 Issuer
  $leaf = $chain | Where-Object {
    $me = $_.Subj
    -not ($chain | Where-Object { $_.Iss -eq $me -and $_.Subj -ne $me })
  } | Select-Object -First 1
  if (-not $leaf) { $leaf = $chain[0] }
  $ordered = @($leaf)
  $cur = $leaf
  for ($i = 0; $i -lt 8; $i++) {
    $next = $chain | Where-Object { $_.Subj -eq $cur.Iss } | Select-Object -First 1
    if (-not $next -or ($ordered | Where-Object { $_.Subj -eq $next.Subj })) { break }
    $ordered += $next
    $cur = $next
  }
  return ($ordered | ForEach-Object { $_.Pem }) -join ''
}

$chainDir = Join-Path $env:TEMP 'fxw_chain'
if (-not (Test-Path $chainDir)) { New-Item -ItemType Directory -Path $chainDir | Out-Null }
$chainPem = Join-Path $chainDir 'chain.pem'
$chainText = Get-CertChainPem -Path $CertFile
[System.IO.File]::WriteAllText($chainPem, $chainText, (New-Object System.Text.UTF8Encoding($false)))
$certCount = ([regex]::Matches($chainText, '-----BEGIN CERTIFICATE-----')).Count
Write-Host "证书链   : 规整为 $certCount 张（叶子在前，已去自签根）"
Write-Host ""

# ---------- 3. 签名 ----------
$tmp = Join-Path $env:TEMP ('fxw-app-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp | Out-Null
# 打成 .app 时要保持 hap 原始文件名（entry-default.hap），
# 否则 pack.info 里的 packages.name=entry-default 对不上，AGC 会判包不合法
$signedHap = Join-Path $tmp 'entry-default.hap'

$algs = if ($SignAlg) { @($SignAlg) } else { @('SHA256withECDSA','SHA384withECDSA') }
$ok = $false
foreach ($alg in $algs) {
  Write-Host "--- 签名（$alg）---"
  & $java -jar $sign sign-app -mode localSign -keyAlias $KeyAlias -keyPwd $KeyPwd `
    -appCertFile $chainPem -profileFile $Profile -inFile $Hap -signAlg $alg `
    -keystoreFile $Keystore -keystorePwd $KeyPwd -outFile $signedHap -compatibleVersion 12 2>&1 |
    ForEach-Object { if ($_ -match 'success|ERROR|Error Message|Sign Hap|profile type') { Write-Host "  $_" } }
  if ($LASTEXITCODE -eq 0 -and (Test-Path $signedHap)) { $ok = $true; Write-Host "  ✓ $alg 通过`n"; break }
  Write-Host "  $alg 不匹配，换下一个算法`n"
}
if (-not $ok) { Fail '签名失败：证书的密钥算法与 signAlg 都不匹配，或 keystore 口令不对。' }
$signAlg = $alg

# ---------- 4. 校验 ----------
Write-Host '--- 校验签名 ---'
& $java -jar $sign verify-app -inFile $signedHap `
  -outCertChain (Join-Path $tmp 'chain.cer') -outProfile (Join-Path $tmp 'p.p7b') 2>&1 |
  ForEach-Object { if ($_ -match 'Verify|Digest|success|ERROR') { Write-Host "  $_" } }
if ($LASTEXITCODE -ne 0) { Fail 'verify-app 失败，签出来的包不可用。' }

# ---------- 5. 打成 .app ----------
Write-Host '--- 打包 .app ---'
$outDir = Split-Path $Out -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
# 顺手留一份签名 hap：不想走 AGC 时，直接 hdc install 这个包
$hapKeep = [System.IO.Path]::ChangeExtension($Out, '.hap')
Copy-Item $signedHap $hapKeep -Force
if (Test-Path $Out) { Remove-Item $Out -Force }

if ($AppTemplate) {
  # 注意：绝对不能用 app_packing_tool 重新打包——它会重新解析 hap 并**丢掉签名块**
  # （实测：1,403,045 B 的签名 hap 进去，1,374,680 B 的无签名 hap 出来，
  #  verify-app 报 "signature not found"，AGC 侧就是这个「不通过(991)」）
  # 所以只把模板里的 entry-default.hap 换成签名好的那一份，其余条目原样搬：
  #   hap → deflate，pack.info / pac.json → stored（与 hvigor 产物一致）
  $pyExe = @(
    "$env:LOCALAPPDATA\Programs\Python\Python314\python.exe",
    "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
    "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1

  $mk = Join-Path $tmp 'mkapp.py'
  $mkBody = @'
import zipfile, sys
tpl, hap, out = sys.argv[1], sys.argv[2], sys.argv[3]
src = zipfile.ZipFile(tpl)
pac = src.read('pac.json'); pinfo = src.read('pack.info'); src.close()
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    z.write(hap, 'entry-default.hap', compress_type=zipfile.ZIP_DEFLATED)
    for name, data in (('pack.info', pinfo), ('pac.json', pac)):
        zi = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
        zi.compress_type = zipfile.ZIP_STORED
        zi.external_attr = 0
        z.writestr(zi, data)
'@
  [System.IO.File]::WriteAllText($mk, $mkBody, (New-Object System.Text.UTF8Encoding($true)))

  if ($pyExe) {
    & $pyExe -X utf8 $mk $AppTemplate $signedHap $Out 2>&1 | Out-Null
  } else {
    Add-Type -AssemblyName System.IO.Compression | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
    $src = [System.IO.Compression.ZipFile]::OpenRead($AppTemplate)
    $fs  = [System.IO.File]::Open($Out, [System.IO.FileMode]::CreateNew)
    $dst = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
    $he  = $dst.CreateEntry('entry-default.hap', [System.IO.Compression.CompressionLevel]::Optimal)
    $hs  = $he.Open(); $hf = [System.IO.File]::OpenRead($signedHap)
    $hf.CopyTo($hs); $hs.Dispose(); $hf.Dispose()
    foreach ($e in $src.Entries) {
      if ($e.FullName -eq 'entry-default.hap') { continue }
      $ne = $dst.CreateEntry($e.FullName, [System.IO.Compression.CompressionLevel]::NoCompression)
      $ns = $ne.Open(); $es = $e.Open(); $es.CopyTo($ns); $ns.Dispose(); $es.Dispose()
    }
    $dst.Dispose(); $fs.Dispose(); $src.Dispose()
  }
} else {
  & $java -jar $pack --mode app --hap-path $signedHap --pack-info-path $PackInfo `
    --out-path $Out --force true 2>&1 | Out-Null
}
if (-not (Test-Path $Out)) { Fail '打包 .app 失败。' }

# ---------- 5.5 给 .app 补 app 级签名块 ----------
# AGC「991 非法软件包」的真因就在这里：.app 中央目录之前必须有一段 app 签名块
# （hvigor 产物是 6,713 B / block count 2 / DigestAlgorithm SHA-256）。
# 手工拼包会把这个块丢掉；sign-app 对 .app 同样有效（先打 no need to sign code for :app，再写块）。
Write-Host '--- 给 .app 补 app 级签名块 ---'
$appSigned = Join-Path $tmp 'app-signed.app'
& $java -jar $sign sign-app -mode localSign -keyAlias $KeyAlias -keyPwd $KeyPwd `
  -appCertFile $chainPem -profileFile $Profile -inFile $Out -signAlg $signAlg `
  -keystoreFile $Keystore -keystorePwd $KeyPwd -outFile $appSigned -compatibleVersion 12 2>&1 |
  ForEach-Object { if ($_ -match 'signing block|success|ERROR') { Write-Host "  $_" } }
if (-not (Test-Path $appSigned)) { Fail '.app 补签名块失败（AGC 会判 991）。' }
Move-Item $appSigned $Out -Force
& $java -jar $sign verify-app -inFile $Out `
  -outCertChain (Join-Path $tmp 'app.cer') -outProfile (Join-Path $tmp 'app.p7b') 2>&1 |
  ForEach-Object { if ($_ -match 'Signing Block|Digest|Verify success|ERROR') { Write-Host "  $_" } }
if ($LASTEXITCODE -ne 0) { Fail '.app 签名块校验失败。' }

Write-Host '--- .app 结构 ---'
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
$z = [System.IO.Compression.ZipFile]::OpenRead($Out)
foreach ($e in $z.Entries) { Write-Host ("  {0,-20} {1,10}" -f $e.FullName, $e.Length) }
$insideHap = Join-Path $tmp 'inside.hap'
$ie = $z.GetEntry('entry-default.hap')
$is = $ie.Open(); $ifs = [System.IO.File]::Open($insideHap, [System.IO.FileMode]::Create)
$is.CopyTo($ifs); $ifs.Dispose(); $is.Dispose(); $z.Dispose()

# 守住底线：.app 里的 hap 必须与刚签好的 hap 逐字节相同（防止打包环节把签名块吃掉）
$h1 = (Get-FileHash $signedHap -Algorithm SHA256).Hash
$h2 = (Get-FileHash $insideHap -Algorithm SHA256).Hash
if ($h1 -ne $h2) { Fail '.app 内的 hap 与签名 hap 不一致——签名块被打包工具重写/剥离了。' }
Write-Host '  ✓ 包内 hap 与签名 hap 字节一致（签名保留）'

$resolvedTemp = [IO.Path]::GetFullPath($tmp)
$tempParent = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
if (-not $resolvedTemp.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase)) { Fail '临时目录越界，保留文件。' }
Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
$i = Get-Item $Out
Write-Host ''
Write-Host "✓ 完成：$($i.FullName)"
Write-Host "  $([math]::Round($i.Length/1MB,2)) MB   SHA-256 $((Get-FileHash $Out -Algorithm SHA256).Hash.ToLower())"
Write-Host "  签名 hap：$hapKeep"
Write-Host '  把这个 .app 传到 AGC「上传包」即可。'
