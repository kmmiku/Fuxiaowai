param([string]$BuildDir = 'D:\fxw_build\hardening\HarmonyOs')
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$allowed = [IO.Path]::GetFullPath('D:\fxw_build\hardening\')
$target = [IO.Path]::GetFullPath($BuildDir)
if (-not $target.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase) -or $target -match '[^\x00-\x7F]') {
  throw '构建目录必须位于 D:\fxw_build\hardening 下的 ASCII 路径。'
}
$node = 'D:\DevEco Studio\tools\node\node.exe'
Push-Location $project
try {
  $ErrorActionPreference = 'Continue'
  & $node --test 'tests/*.cjs' 2>&1 | ForEach-Object { Write-Host $_.ToString() }
  $ErrorActionPreference = 'Stop'
  if ($LASTEXITCODE -ne 0) { throw '回归测试失败，停止构建。' }
  New-Item -ItemType Directory -Path $target -Force | Out-Null
  foreach ($dir in @('entry','AppScope','hvigor')) {
    # Both resolved endpoints are known before using mirror mode.
    $dest = [IO.Path]::GetFullPath((Join-Path $target $dir))
    if (-not $dest.StartsWith($target + '\', [StringComparison]::OrdinalIgnoreCase)) { throw '同步路径越界。' }
    & robocopy (Join-Path $project $dir) $dest /MIR /XD build oh_modules /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -ge 8) { throw "同步 $dir 失败。" }
  }
  foreach ($file in @('build-profile.json5','hvigorfile.ts','oh-package.json5')) {
    Copy-Item -LiteralPath (Join-Path $project $file) -Destination (Join-Path $target $file) -Force
  }
  $inputs = @(Get-ChildItem -LiteralPath (Join-Path $project 'entry\src'),(Join-Path $project 'AppScope') -File -Recurse)
  $inputs += Get-Item -LiteralPath (Join-Path $project 'build-profile.json5'),(Join-Path $project 'oh-package.json5')
  $hashes = @($inputs | Sort-Object FullName | ForEach-Object {
    [pscustomobject]@{ path=$_.FullName.Substring($project.Length+1); sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
  })
  $env:DEVECO_SDK_HOME='D:\DevEco Studio\sdk'
  $env:JAVA_HOME='D:\DevEco Studio\jbr'
  $env:PATH='D:\DevEco Studio\jbr\bin;D:\DevEco Studio\tools\node;'+$env:PATH
  $env:_JAVA_OPTIONS='-Xmx384m -XX:MaxMetaspaceSize=192m -XX:ReservedCodeCacheSize=64m'
  $env:NODE_OPTIONS='--max-old-space-size=1536'
  Set-Location $target
  $log = Join-Path $target 'build-release.log'
  $ErrorActionPreference = 'Continue'
  & 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --no-daemon assembleApp --mode project -p product=default -p buildMode=release *> $log
  $ErrorActionPreference = 'Stop'
  if (-not (Select-String -LiteralPath $log -SimpleMatch 'BUILD SUCCESSFUL' -Quiet)) {
    Get-Content -LiteralPath $log -Tail 80
    throw 'Hvigor 构建失败。'
  }
  $version = (Get-Content -LiteralPath (Join-Path $project 'AppScope\app.json5') -Raw -Encoding UTF8 | ConvertFrom-Json).app.versionName
  $manifest = [pscustomobject]@{ version=$version; builtAt=[DateTime]::UtcNow.ToString('o'); source=$hashes; buildDir=$target }
  New-Item -ItemType Directory -Path (Join-Path $project 'dist') -Force | Out-Null
  $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $project 'dist\build-manifest.json') -Encoding UTF8
  Write-Host "构建成功：$version；日志：$log"
} finally { Pop-Location }
