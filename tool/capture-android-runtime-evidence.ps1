param(
    [string]$ApkPath = '',
    [string]$OutputPath = '.\artifacts\verification\runtime-android.json',
    [string]$ScreenshotPath = '.\artifacts\verification\android-first-frame.png',
    [string]$DeviceSerial = '',
    [ValidateSet('REAL', 'MOCK')]
    [string]$Mode = 'REAL',
    [switch]$AllowPhysicalDevice
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$pubspecPath = Join-Path $repoRoot 'apps\client\pubspec.yaml'
$versionMatch = Select-String `
    -LiteralPath $pubspecPath `
    -Pattern '^version:\s*(?<name>\d+\.\d+\.\d+)\+(?<code>\d+)\s*$' |
    Select-Object -First 1
if ($null -eq $versionMatch) {
    throw "Could not read release version from $pubspecPath"
}
$version = $versionMatch.Matches[0].Groups['name'].Value
$buildNumber = [int]$versionMatch.Matches[0].Groups['code'].Value

if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $releaseApk = Join-Path $repoRoot "artifacts\Sprache-Android-$version-google-release-signed.apk"
    $debugApk = Join-Path $repoRoot "artifacts\Sprache-Android-$version-google-debug-signed.apk"
    $ApkPath = if (Test-Path -LiteralPath $releaseApk -PathType Leaf) {
        $releaseApk
    }
    else {
        $debugApk
    }
}
$resolvedApk = (Resolve-Path -LiteralPath $ApkPath).Path
if ((Get-Item -LiteralPath $resolvedApk).Length -le 0) {
    throw "Android APK is empty: $resolvedApk"
}

$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adb -PathType Leaf)) {
    $adbCommand = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($null -eq $adbCommand) {
        throw 'adb.exe was not found.'
    }
    $adb = $adbCommand.Source
}

& $adb start-server | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'adb server did not start.'
}
$onlineDevices = @(
    & $adb devices |
        Select-Object -Skip 1 |
        ForEach-Object {
            if ($_ -match '^(?<serial>\S+)\s+device$') { $Matches.serial }
        }
)
if ([string]::IsNullOrWhiteSpace($DeviceSerial)) {
    if ($onlineDevices.Count -ne 1) {
        throw "Expected exactly one online Android target, found $($onlineDevices.Count). Use -DeviceSerial."
    }
    $DeviceSerial = $onlineDevices[0]
}
elseif ($DeviceSerial -notin $onlineDevices) {
    throw "Android target is not online: $DeviceSerial"
}

$isEmulator = $DeviceSerial.StartsWith('emulator-', [StringComparison]::OrdinalIgnoreCase)
if (-not $isEmulator) {
    $qemu = (& $adb -s $DeviceSerial shell getprop ro.kernel.qemu 2>$null) -join ''
    $isEmulator = $qemu.Trim() -eq '1'
}
if (-not $isEmulator -and -not $AllowPhysicalDevice) {
    throw 'Physical-device installation requires the explicit -AllowPhysicalDevice switch.'
}

$packageName = 'com.youkdonghun.sprache'
& $adb -s $DeviceSerial install -r $resolvedApk
if ($LASTEXITCODE -ne 0) {
    throw 'APK installation failed.'
}

$packageInfo = (& $adb -s $DeviceSerial shell dumpsys package $packageName) -join "`n"
if ($packageInfo -notmatch "versionCode=$buildNumber(?:\s|$)" -or
    $packageInfo -notmatch "versionName=$([regex]::Escape($version))(?:\s|$)") {
    throw "Installed Android package version does not match $version+$buildNumber."
}

& $adb -s $DeviceSerial shell am force-stop $packageName | Out-Null
& $adb -s $DeviceSerial shell dumpsys gfxinfo $packageName reset | Out-Null
$startupStopwatch = [Diagnostics.Stopwatch]::StartNew()
& $adb -s $DeviceSerial shell monkey `
    -p $packageName `
    -c android.intent.category.LAUNCHER `
    1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'Android launch command failed.'
}

$firstFrameMillis = $null
$lastFocus = ''
$lastFrameCount = 0
for ($attempt = 0; $attempt -lt 120; $attempt++) {
    Start-Sleep -Milliseconds 250
    $activityState = (& $adb -s $DeviceSerial shell dumpsys activity activities) -join "`n"
    $lastFocus = $activityState
    $isForeground =
        $activityState -match "mResumedActivity:.*$([regex]::Escape($packageName))"
    $gfxInfo = (& $adb -s $DeviceSerial shell dumpsys gfxinfo $packageName) -join "`n"
    if ($gfxInfo -match 'Total frames rendered:\s*(?<count>\d+)') {
        $lastFrameCount = [int]$Matches.count
    }
    if ($isForeground -and $lastFrameCount -gt 0) {
        $firstFrameMillis = $startupStopwatch.ElapsedMilliseconds
        break
    }
}
if ($null -eq $firstFrameMillis -or $firstFrameMillis -gt 60000) {
    throw (
        "Android did not prove a foreground rendered frame. " +
        "frames=$lastFrameCount focusFound=$($lastFocus -match [regex]::Escape($packageName))"
    )
}

$resolvedScreenshot = [IO.Path]::GetFullPath((Join-Path (Get-Location) $ScreenshotPath))
$screenshotDirectory = Split-Path -Parent $resolvedScreenshot
New-Item -ItemType Directory -Force -Path $screenshotDirectory | Out-Null
$remoteScreenshot = "/sdcard/sprache-first-frame-$PID.png"
try {
    & $adb -s $DeviceSerial shell screencap -p $remoteScreenshot | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Android screenshot capture failed.'
    }
    & $adb -s $DeviceSerial pull $remoteScreenshot $resolvedScreenshot | Out-Null
    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path -LiteralPath $resolvedScreenshot -PathType Leaf) -or
        (Get-Item -LiteralPath $resolvedScreenshot).Length -lt 4096) {
        throw 'Android first-frame screenshot is missing or empty.'
    }
}
finally {
    & $adb -s $DeviceSerial shell rm -f $remoteScreenshot | Out-Null
}

$resolvedOutput = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
$outputDirectory = Split-Path -Parent $resolvedOutput
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$evidence = [ordered]@{
    format = 'sprache-runtime-evidence-v1'
    platform = 'android'
    mode = $Mode
    version = $version
    buildNumber = $buildNumber
    launched = $true
    firstFrameRendered = $true
    firstFrameMillis = [int]$firstFrameMillis
    probe = 'native-runtime'
    checkedAt = [DateTime]::UtcNow.ToString('o')
}
$utf8WithoutBom = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText(
    $resolvedOutput,
    (($evidence | ConvertTo-Json -Depth 3) + "`n"),
    $utf8WithoutBom
)

[pscustomobject]@{
    Device = $DeviceSerial
    Emulator = $isEmulator
    Apk = $resolvedApk
    Version = "$version+$buildNumber"
    Frames = $lastFrameCount
    FirstFrameMillis = $firstFrameMillis
    Screenshot = $resolvedScreenshot
    RuntimeEvidence = $resolvedOutput
}
