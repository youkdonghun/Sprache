param(
    [string]$FlutterPath = "$env:LOCALAPPDATA\Programs\flutter\bin\flutter.bat",
    [string]$DesktopClientId = '1054343487948-o7nkfj4qmiilacvbln7alfgqrced6ior.apps.googleusercontent.com'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$clientRoot = Join-Path $repoRoot 'apps\client'
$testPath = 'integration_test\live_google_drive_e2e_test.dart'
$readinessScript = Join-Path $PSScriptRoot 'check-google-readiness.ps1'

if (-not (Test-Path -LiteralPath $FlutterPath -PathType Leaf)) {
    throw "Flutter executable not found: $FlutterPath"
}
if ([string]::IsNullOrWhiteSpace($DesktopClientId)) {
    throw 'GOOGLE_DESKTOP_CLIENT_ID is required'
}
& $readinessScript -DesktopClientId $DesktopClientId -RequireReady
$oauthUrlFile = [Environment]::GetEnvironmentVariable(
    'SPRACHE_LIVE_OAUTH_URL_FILE',
    'Process'
)

Push-Location $clientRoot
try {
    & $FlutterPath test $testPath -d windows `
        --dart-define=RUN_LIVE_GOOGLE_E2E=true `
        --dart-define=APP_ENV=production `
        --dart-define=ENABLE_MOCK_MODE=false `
        --dart-define="GOOGLE_DESKTOP_CLIENT_ID=$DesktopClientId"
    if ($LASTEXITCODE -ne 0) {
        throw "Live Google E2E failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
    if (-not [string]::IsNullOrWhiteSpace($oauthUrlFile) -and
        (Test-Path -LiteralPath $oauthUrlFile -PathType Leaf)) {
        Remove-Item -LiteralPath $oauthUrlFile -Force
    }
}
