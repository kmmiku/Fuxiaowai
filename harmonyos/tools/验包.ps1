<#
  验包.ps1 —— 上传 AGC 前的自检（对齐 AGC「完整性校验」的几项硬要求）
  用法：
    .\验包.ps1
    .\验包.ps1 -App .\福小外-0.1.0-signed.app -Hap .\福小外-0.1.0-signed.hap
  退出码：0 = 全部通过；1 = 有问题（看 ✗ 行）
#>
param(
  [string]$App = '',
  [string]$Hap = ''
)

$ErrorActionPreference = 'Continue'
$java = 'D:\DevEco Studio\jbr\bin\java.exe'
$signJar = 'D:\DevEco Studio\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar'
$fail = 0
function Ok([string]$m)  { Write-Host "  ✓ $m" -ForegroundColor Green }
function Bad([string]$m) { Write-Host "  ✗ $m" -ForegroundColor Red; $script:fail++ }
function Info([string]$m){ Write-Host "    $m" }

$root = Split-Path -Parent $PSScriptRoot
if (-not $App) {
  $fxwVersion = (Get-Content -LiteralPath (Join-Path $root 'AppScope\app.json5') -Raw -Encoding UTF8 | ConvertFrom-Json).app.versionName
  $App = Join-Path $root "dist\福小外-$fxwVersion-signed.app"
}
if (-not $Hap) {
  $guess = [System.IO.Path]::ChangeExtension($App, '.hap')
  if (Test-Path $guess) { $Hap = $guess } else { $Hap = '' }
}
if (-not (Test-Path $App)) { Bad "找不到 .app：$App"; exit 1 }
foreach ($t in @($java, $signJar)) { if (-not (Test-Path $t)) { Bad "缺少工具：$t"; exit 1 } }

$tmp = Join-Path $env:TEMP ("fxwcheck_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp | Out-Null

try {
  Write-Host ''
  Write-Host "== 1. 结构 ==" -ForegroundColor Cyan
  Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
  $zip = [System.IO.Compression.ZipFile]::OpenRead($App)
  $names = @($zip.Entries | ForEach-Object { $_.FullName })
  Info (".app 条目：" + ($names -join ' / '))
  foreach ($need in @('entry-default.hap', 'pack.info', 'pac.json')) {
    if ($names -contains $need) { Ok "含 $need" } else { Bad "缺 $need（AGC 会解析失败）" }
  }
  $inner = Join-Path $tmp 'entry-default.hap'
  $entry = $zip.GetEntry('entry-default.hap')
  if ($entry) {
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $inner, $true)
    Info ("包内 hap 大小：" + $entry.Length + " B")
  }
  $zip.Dispose()

  Write-Host ''
  Write-Host "== 2. 包内 hap 的签名 ==" -ForegroundColor Cyan
  & $java -jar $signJar verify-app -inFile $inner -outCertChain (Join-Path $tmp 'chain.cer') -outProfile (Join-Path $tmp 'p.p7b') 2>&1 |
    ForEach-Object { if ($_ -match 'Signing Block|verify codesign|Digest|Verify success|ERROR') { Info $_.ToString().Trim() } }
  if ($LASTEXITCODE -eq 0) { Ok '签名块校验通过（verify-app success）' } else { Bad '包内 hap 没有有效签名块（AGC 991 的直接原因）' }

  Write-Host ''
  Write-Host "== 3. 证书链顺序 ==" -ForegroundColor Cyan
  $chainPath = Join-Path $tmp 'chain.cer'
  $ders = @()
  if (Test-Path $chainPath) {
    $raw = [System.IO.File]::ReadAllText($chainPath)
    $m = [regex]::Matches($raw, '-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----')
    foreach ($x in $m) {
      $b64 = $x.Value -replace '-----[^-]+-----', ''
      $ders += , ([System.Convert]::FromBase64String(($b64 -replace '\s', '')))
    }
  }
  if ($ders.Count -lt 1) { Bad '签名块里读不到证书链' }
  else {
    Info ("证书块数：" + $ders.Count)
    for ($i = 0; $i -lt $ders.Count; $i++) {
      $c = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 (, $ders[$i])
      $sha = [System.Security.Cryptography.SHA256]::Create().ComputeHash($ders[$i])
      Info ("  块{0}: {1}" -f $i, $c.Subject)
      if ($c.Subject -eq $c.Issuer) { Bad "块$i 是自签根证书——AGC 要求链首为叶子证书" }
      if ($i -eq 0 -and $c.Subject -ne $c.Issuer) { Ok '链首是叶子证书（非自签）' }
    }
  }

  Write-Host ''
  Write-Host "== 4. Profile 与证书是否配对 ==" -ForegroundColor Cyan
  $json = Join-Path $tmp 'vp.json'
  & $java -jar $signJar verify-profile -inFile (Join-Path $tmp 'p.p7b') -outFile $json 2>&1 | Out-Null
  if (Test-Path $json) {
    $txt = [System.IO.File]::ReadAllText($json)
    if ($txt -match '"verifiedPassed"\s*:\s*true') { Ok 'Profile 本身签名有效' } else { Bad 'Profile 验签失败' }
    foreach ($k in @('type', 'app-distribution-type', 'bundle-name')) {
      $mm = [regex]::Match($txt, '"' + $k + '"\s*:\s*"([^"]*)"')
      if ($mm.Success) { Info ("$k = " + $mm.Groups[1].Value) }
    }
    if ($txt -match '"app-distribution-type"\s*:\s*"app_gallery"') { Ok '分发类型 app_gallery（应用市场包）' } else { Bad '分发类型不是 app_gallery' }
    if ($txt -match '"type"\s*:\s*"release"') { Ok 'Profile 类型 release' } else { Bad 'Profile 不是 release 类型' }
    $pm = [regex]::Match($txt, '"distribution-certificate"\s*:\s*"([^"]+)"')
    if ($pm.Success) {
      $pem = $pm.Groups[1].Value -replace '\\r', '' -replace '\\n', "`n"
      $pb = [regex]::Replace($pem, '-----[^-]+-----', '') -replace '\s', ''
      $pder = [System.Convert]::FromBase64String($pb)
      if ($ders.Count -ge 1) {
        $h1 = [System.Security.Cryptography.SHA256]::Create().ComputeHash($pder)
        $h2 = [System.Security.Cryptography.SHA256]::Create().ComputeHash($ders[0])
        if ([System.Convert]::ToBase64String($h1) -eq [System.Convert]::ToBase64String($h2)) {
          Ok 'Profile 里的 distribution-certificate == 签名链第一张（配对正确）'
        } else { Bad 'Profile 的 distribution-certificate 与签名证书不一致' }
      }
    } else { Bad 'Profile 里没有 distribution-certificate' }
  } else { Bad 'verify-profile 没产出结果' }

  Write-Host ''
  Write-Host "== 5. 与同名 .hap 是否一致 ==" -ForegroundColor Cyan
  if ($Hap -and (Test-Path $Hap)) {
    $h1 = (Get-FileHash $inner -Algorithm SHA256).Hash
    $h2 = (Get-FileHash $Hap -Algorithm SHA256).Hash
    if ($h1 -eq $h2) { Ok "包内 hap 与 $([System.IO.Path]::GetFileName($Hap)) 字节一致" } else { Bad '包内 hap 与同名 .hap 不一致' }
  } else { Info '没给 -Hap，跳过' }

  Write-Host ''
  $a = Get-Item $App
  Write-Host ("最终包：{0}" -f $a.FullName)
  Write-Host ("         {0} B   SHA-256 {1}" -f $a.Length, (Get-FileHash $App -Algorithm SHA256).Hash.ToLower())
  Write-Host ''
  if ($fail -eq 0) { Write-Host '✓ 全部检查通过，可以上传 AGC。' -ForegroundColor Green; exit 0 }
  else { Write-Host "✗ 有 $fail 项不通过，先修好再上传。" -ForegroundColor Red; exit 1 }
}
finally {
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
