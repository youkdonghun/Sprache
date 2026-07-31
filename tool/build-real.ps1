param(
    [ValidateSet('all', 'android', 'windows')]
    [string]$Target = 'all',
    [string]$FlutterPath = "$env:LOCALAPPDATA\Programs\flutter\bin\flutter.bat",
    [string]$ApiBaseUrl = 'https://sprache-api-production.up.railway.app',
    [string]$AndroidClientId = '1054343487948-v3u90fo5nmbrk4hn7ss2gnrg601phkuv.apps.googleusercontent.com',
    [string]$ServerClientId = '1054343487948-g6b3fp20ooq86agro7nsb129oqr9df82.apps.googleusercontent.com',
    [string]$DesktopClientId = '1054343487948-791d7jh7m90rt4cs1ncgkf6l5eecehut.apps.googleusercontent.com',
    [string]$PrivacyPolicyUrl = $(if ([string]::IsNullOrWhiteSpace($env:SPRACHE_PRIVACY_POLICY_URL)) {
        'https://sprache-api-production.up.railway.app/privacy'
    } else {
        $env:SPRACHE_PRIVACY_POLICY_URL
    }),
    [string]$InnoSetupPath = '',
    [string]$WindowsSigningThumbprint = $env:SPRACHE_WINDOWS_SIGNING_THUMBPRINT,
    [string]$WindowsTimestampUrl = 'https://timestamp.digicert.com',
    [string]$SignToolPath = '',
    [switch]$RequireBrokerReady,
    [switch]$RequirePrivacyPolicyUrl,
    [switch]$RequireAndroidReleaseSigning,
    [switch]$RequireWindowsCodeSigning
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$clientRoot = Join-Path $repoRoot 'apps\client'
$artifactsRoot = Join-Path $repoRoot 'artifacts'
$pubspecPath = Join-Path $clientRoot 'pubspec.yaml'
$versionMatch = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*(?<name>\d+\.\d+\.\d+)\+\d+\s*$' |
    Select-Object -First 1
if ($null -eq $versionMatch) {
    throw "Could not read release version from $pubspecPath"
}
$releaseVersion = $versionMatch.Matches[0].Groups['name'].Value

if (-not (Test-Path -LiteralPath $FlutterPath -PathType Leaf)) {
    throw "Flutter executable not found: $FlutterPath"
}

foreach ($requiredValue in @{
    API_BASE_URL = $ApiBaseUrl
    APP_VERSION = $releaseVersion
    GOOGLE_ANDROID_CLIENT_ID = $AndroidClientId
    GOOGLE_SERVER_CLIENT_ID = $ServerClientId
    GOOGLE_DESKTOP_CLIENT_ID = $DesktopClientId
}.GetEnumerator()) {
    if ([string]::IsNullOrWhiteSpace($requiredValue.Value)) {
        throw "Missing required build value: $($requiredValue.Key)"
    }
}
if (-not [string]::IsNullOrWhiteSpace($PrivacyPolicyUrl) -and
    -not $PrivacyPolicyUrl.StartsWith('https://', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'PRIVACY_POLICY_URL must use HTTPS when configured'
}
if ($RequirePrivacyPolicyUrl -and [string]::IsNullOrWhiteSpace($PrivacyPolicyUrl)) {
    throw 'A public HTTPS privacy policy URL is required for a publishable build.'
}

$androidSigningVariableNames = @(
    'SPRACHE_ANDROID_KEYSTORE_PATH',
    'SPRACHE_ANDROID_KEYSTORE_PASSWORD',
    'SPRACHE_ANDROID_KEY_ALIAS',
    'SPRACHE_ANDROID_KEY_PASSWORD'
)
$androidSigningValues = @{}
if ($Target -in @('all', 'android')) {
    foreach ($variableName in $androidSigningVariableNames) {
        $value = [Environment]::GetEnvironmentVariable($variableName)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $androidSigningValues[$variableName] = $value
        }
    }
}
$androidReleaseSigningConfigured =
    $androidSigningValues.Count -eq $androidSigningVariableNames.Count
if ($Target -in @('all', 'android') -and
    $androidSigningValues.Count -gt 0 -and
    -not $androidReleaseSigningConfigured) {
    $missingSigningValues = $androidSigningVariableNames |
        Where-Object { -not $androidSigningValues.ContainsKey($_) }
    throw "Android release signing is only partially configured. Missing: $($missingSigningValues -join ', ')"
}
if ($Target -in @('all', 'android') -and
    $RequireAndroidReleaseSigning -and
    -not $androidReleaseSigningConfigured) {
    throw 'Android release signing is required, but the four SPRACHE_ANDROID_* variables are not configured.'
}
if ($Target -in @('all', 'android') -and $androidReleaseSigningConfigured) {
    $keystorePath = $androidSigningValues['SPRACHE_ANDROID_KEYSTORE_PATH']
    if (-not [IO.Path]::IsPathRooted($keystorePath)) {
        throw 'SPRACHE_ANDROID_KEYSTORE_PATH must be an absolute path.'
    }
    if (-not (Test-Path -LiteralPath $keystorePath -PathType Leaf)) {
        throw "Android release keystore was not found: $keystorePath"
    }
}
$androidSigningLabel = if ($androidReleaseSigningConfigured) { 'release' } else { 'debug' }

if ($Target -in @('all', 'windows')) {
    $brokerReady = $false
    try {
        $health = Invoke-RestMethod -Uri "$($ApiBaseUrl.TrimEnd('/'))/health" -Method Get -TimeoutSec 15
        $brokerReady = $health.desktopOAuthBroker -eq 'ready'
    }
    catch {
        Write-Warning "Could not verify Railway desktop OAuth broker health."
    }
    if (-not $brokerReady) {
        $message = 'Railway desktop OAuth broker is not ready. The build will keep local study available, but Windows Google login will show a configuration diagnostic.'
        if ($RequireBrokerReady) {
            throw $message
        }
        Write-Warning $message
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
            --dart-define="APP_VERSION=$releaseVersion" `
            --dart-define="API_BASE_URL=$ApiBaseUrl" `
            --dart-define="PRIVACY_POLICY_URL=$PrivacyPolicyUrl" `
            --dart-define="GOOGLE_ANDROID_CLIENT_ID=$AndroidClientId" `
            --dart-define="GOOGLE_SERVER_CLIENT_ID=$ServerClientId"
        if ($LASTEXITCODE -ne 0) {
            throw "Android release build failed with exit code $LASTEXITCODE"
        }

        $apkSource = Join-Path $clientRoot 'build\app\outputs\flutter-apk\app-release.apk'
        $apkTarget = Join-Path $artifactsRoot "Sprache-Android-$releaseVersion-google-$androidSigningLabel-signed.apk"
        Copy-Item -LiteralPath $apkSource -Destination $apkTarget -Force
    }

    if ($Target -in @('all', 'windows')) {
        & $FlutterPath build windows --release `
            --dart-define=APP_ENV=production `
            --dart-define=ENABLE_MOCK_MODE=false `
            --dart-define="APP_VERSION=$releaseVersion" `
            --dart-define="API_BASE_URL=$ApiBaseUrl" `
            --dart-define="PRIVACY_POLICY_URL=$PrivacyPolicyUrl" `
            --dart-define="GOOGLE_DESKTOP_CLIENT_ID=$DesktopClientId"
        if ($LASTEXITCODE -ne 0) {
            throw "Windows release build failed with exit code $LASTEXITCODE"
        }

        $windowsRelease = Join-Path $clientRoot 'build\windows\x64\runner\Release'
        & (Join-Path $PSScriptRoot 'sign-windows-file.ps1') `
            -Path (Join-Path $windowsRelease 'sprache.exe') `
            -CertificateThumbprint $WindowsSigningThumbprint `
            -TimestampUrl $WindowsTimestampUrl `
            -SignToolPath $SignToolPath `
            -RequireSignature:$RequireWindowsCodeSigning

        $windowsTarget = Join-Path $artifactsRoot "Sprache-Windows-$releaseVersion-google-x64.zip"
        Compress-Archive -Path (Join-Path $windowsRelease '*') -DestinationPath $windowsTarget -CompressionLevel Optimal -Force

        & (Join-Path $PSScriptRoot 'build-windows-installer.ps1') `
            -Version $releaseVersion `
            -ReleaseDir $windowsRelease `
            -ArtifactsDir $artifactsRoot `
            -InnoSetupPath $InnoSetupPath `
            -WindowsSigningThumbprint $WindowsSigningThumbprint `
            -TimestampUrl $WindowsTimestampUrl `
            -SignToolPath $SignToolPath `
            -RequireWindowsCodeSigning:$RequireWindowsCodeSigning
    }
}
finally {
    Pop-Location
}

$realArtifacts = Get-ChildItem -LiteralPath $artifactsRoot -File |
    Where-Object { $_.Name -like "Sprache-*-$releaseVersion-google-*" } |
    Sort-Object Name

$checksumLines = foreach ($artifact in $realArtifacts) {
    $hash = Get-FileHash -LiteralPath $artifact.FullName -Algorithm SHA256
    "$($hash.Hash.ToLowerInvariant())  $($artifact.Name)"
}

$checksumPath = Join-Path $artifactsRoot "SHA256SUMS-$releaseVersion-google.txt"
$checksumLines | Set-Content -LiteralPath $checksumPath -Encoding utf8

Write-Host 'Real-mode artifacts:'
$realArtifacts | ForEach-Object {
    Write-Host "  $($_.FullName)"
}
Write-Host "  $checksumPath"
