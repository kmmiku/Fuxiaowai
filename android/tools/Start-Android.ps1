param([switch]$Build,[switch]$Restart)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$androidSdk=$env:ANDROID_SDK_ROOT
if(-not $androidSdk){$androidSdk=$env:ANDROID_HOME}
if(-not $androidSdk){
  $props=Join-Path $projectRoot 'android\local.properties'
  if(Test-Path -LiteralPath $props){
    $found=Select-String -LiteralPath $props -Pattern '^sdk\.dir=(.+)$' | Select-Object -First 1
    if($found){$androidSdk=($found.Matches[0].Groups[1].Value -replace '\\\\','\').Trim()}
  }
}
if(-not $androidSdk){throw 'Android SDK not found; set ANDROID_SDK_ROOT or android/local.properties sdk.dir'}
$adb=Join-Path $androidSdk 'platform-tools\adb.exe'
$emulator=Join-Path $androidSdk 'emulator\emulator.exe'
$avd='fxw'
$apk=Join-Path $projectRoot 'android\app\build\outputs\apk\debug\app-debug.apk'
$shot=Join-Path $projectRoot 'Map\evidence\boot-shot.png'
function Get-FxwSerial {
  foreach($line in (& $adb devices)) {
    if($line -match '^(emulator-\d+)\s+device\s*$') {
      $candidate=$Matches[1]
      $name=((& $adb -s $candidate emu avd name 2>$null) | Where-Object {$_ -and $_.Trim() -ne 'OK'} | Select-Object -First 1)
      if($name -and $name.Trim() -eq $avd){return $candidate}
    }
  }
  return $null
}
Push-Location $projectRoot
try {
  if($Build) {
    & npm.cmd run build;if($LASTEXITCODE -ne 0){throw 'Web build failed'}
    & npx.cmd cap sync android;if($LASTEXITCODE -ne 0){throw 'Capacitor sync failed'}
    if(-not $env:JAVA_HOME){$env:JAVA_HOME=Join-Path $androidSdk 'jdk17'}
    if(-not $env:GRADLE_USER_HOME){$env:GRADLE_USER_HOME=Join-Path $androidSdk 'gradle-home'}
    & .\android\gradlew.bat -p android :app:assembleDebug --console=plain
    if($LASTEXITCODE -ne 0){throw 'APK build failed'}
  }
  if(-not(Test-Path -LiteralPath $apk)){throw "APK not found; run this script with -Build: $apk"}
  $serial=Get-FxwSerial
  if($Restart -and $serial) {
    & $adb -s $serial emu kill | Out-Null
    for($i=0;$i -lt 20;$i++){Start-Sleep -Milliseconds 500;if(-not(Get-FxwSerial)){break}}
    $serial=$null
  }
  if(-not $serial) {
    # User explicitly requests a visible, interactive emulator window.
    Start-Process -FilePath $emulator -ArgumentList "-avd $avd -netdelay none -netspeed full -no-boot-anim" -WindowStyle Normal
    for($i=0;$i -lt 60;$i++){Start-Sleep -Seconds 2;$serial=Get-FxwSerial;if($serial){break}}
  }
  if(-not $serial){throw 'fxw device did not become available'}
  $booted=$false
  for($i=0;$i -lt 60;$i++) {
    if(((& $adb -s $serial shell getprop sys.boot_completed) -join '').Trim() -eq '1'){$booted=$true;break}
    Start-Sleep -Seconds 2
  }
  if(-not $booted){throw 'fxw did not finish booting'}
  Write-Host "Device: $serial (fxw)"
  & $adb -s $serial install -r $apk
  if($LASTEXITCODE -ne 0){throw 'Install failed; existing application/data have not been removed'}
  & $adb -s $serial shell am start -W -n com.fuxiaowai.timetable/.MainActivity
  if($LASTEXITCODE -ne 0){throw 'Application launch failed'}
  New-Item -ItemType Directory -Path (Split-Path -Parent $shot) -Force | Out-Null
  Start-Sleep -Seconds 3
  & $adb -s $serial shell screencap -p /sdcard/fxw-boot.png
  & $adb -s $serial pull /sdcard/fxw-boot.png $shot
  if($LASTEXITCODE -ne 0){throw 'Screenshot capture failed'}
  Write-Host "Screenshot: $shot"
} finally {Pop-Location}
