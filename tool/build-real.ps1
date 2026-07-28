param(
    [ValidateSet('all', 'android', 'windows')]
    [string]$Target = 'all',
    [string]$FlutterPath = "$env:LOCALAPPDATA\Programs\flutter\bin\flutter.bat",
    [string]$ApiBaseUrl = 'https://sprache-api-production.up.railway.app',
    [string]$AndroidClientId = '1054343487948-v3u90fo5nmbrk4hn7ss2gnrg601phkuv.apps.googleusercontent.com',
    [string]$ServerClientId = '1054343487948-g6b3fp20ooq86agro7nsb129oqr9df82.apps.googleusercontent.com',
    [string]$DesktopClientId = '1054343487948-791d7jh7m90rt4cs1ncgkf6l5eecehut.apps.googleusercontent.com'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$clientRoot = Join-Path $repoRoot 'apps\client'
$artifactsRoot = Join-Path $repoRoot 'artifacts'

if (-not (Test-Path -LiteralPath $FlutterPath -PathType Leaf)) {
    throw "Flutter executable not found: $FlutterPath"
}

foreach ($requiredValue in @{
    API_BASE_URL = $ApiBaseUrl
    GOOGLE_ANDROID_CLIENT_ID = $AndroidClientId
    GOOGLE_SERVER_CLIENT_ID = $ServerClientId
    GOOGLE_DESKTOP_CLIENT_ID = $DesktopClientId
}.GetEnumerator()) {
    if ([string]::IsNullOrWhiteSpace($requiredValue.Value)) {
        throw "Missing required build value: $($requiredValue.Key)"
    }
}

New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null

Push-Location $clientRoot
try {
    & $FlutterPath pub get
    if ($LASTEXITCODE -ne 0) {
        throw "flutter pub get failed with exit code $LASTEXITCODE"
    }

    if ($Target -in @('all', 'android')) {
        & $FlutterPath build apk --release `
            --dart-define=APP_ENV=production `
            --dart-define=ENABLE_MOCK_MODE=false `
            --dart-define="API_BASE_URL=$ApiBaseUrl" `
            --dart-define="GOOGLE_ANDROID_CLIENT_ID=$AndroidClientId" `
            --dart-define="GOOGLE_SERVER_CLIENT_ID=$ServerClientId"
        if ($LASTEXITCODE -ne 0) {
            throw "Android release build failed with exit code $LASTEXITCODE"
        }

        $apkSource = Join-Path $clientRoot 'build\app\outputs\flutter-apk\app-release.apk'
        $apkTarget = Join-Path $artifactsRoot 'Sprache-Android-1.15.1-google-debug-signed.apk'
        Copy-Item -LiteralPath $apkSource -Destination $apkTarget -Force
    }

    if ($Target -in @('all', 'windows')) {
        & $FlutterPath build windows --release `
            --dart-define=APP_ENV=production `
            --dart-define=ENABLE_MOCK_MODE=false `
            --dart-define="API_BASE_URL=$ApiBaseUrl" `
            --dart-define="GOOGLE_DESKTOP_CLIENT_ID=$DesktopClientId"
        if ($LASTEXITCODE -ne 0) {
            throw "Windows release build failed with exit code $LASTEXITCODE"
        }

        $windowsRelease = Join-Path $clientRoot 'build\windows\x64\runner\Release'
        $windowsTarget = Join-Path $artifactsRoot 'Sprache-Windows-1.15.1-google-x64.zip'
        Compress-Archive -Path (Join-Path $windowsRelease '*') -DestinationPath $windowsTarget -CompressionLevel Optimal -Force
    }
}
finally {
    Pop-Location
}

$realArtifacts = Get-ChildItem -LiteralPath $artifactsRoot -File |
    Where-Object { $_.Name -like 'Sprache-*-1.15.1-google-*' } |
    Sort-Object Name

$checksumLines = foreach ($artifact in $realArtifacts) {
    $hash = Get-FileHash -LiteralPath $artifact.FullName -Algorithm SHA256
    "$($hash.Hash.ToLowerInvariant())  $($artifact.Name)"
}

$checksumPath = Join-Path $artifactsRoot 'SHA256SUMS-1.15.1-google.txt'
$checksumLines | Set-Content -LiteralPath $checksumPath -Encoding utf8

Write-Host 'Real-mode artifacts:'
$realArtifacts | ForEach-Object {
    Write-Host "  $($_.FullName)"
}
Write-Host "  $checksumPath"
