param(
    [string]$Version = '',
    [string]$ExpectedApiBaseUrl = 'https://sprache-api-production.up.railway.app',
    [string]$ExpectedPrivacyPolicyUrl = $(if ([string]::IsNullOrWhiteSpace($env:SPRACHE_PRIVACY_POLICY_URL)) {
        'https://sprache-api-production.up.railway.app/privacy'
    } else {
        $env:SPRACHE_PRIVACY_POLICY_URL
    }),
    [switch]$RequireAndroidReleaseSigning,
    [switch]$RequireWindowsCodeSigning,
    [switch]$RunInstallerSmoke,
    [switch]$CleanOldArtifacts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-ZipEntryBytes {
    param([IO.Compression.ZipArchiveEntry]$Entry)

    $entryStream = $Entry.Open()
    $memoryStream = New-Object IO.MemoryStream
    try {
        $entryStream.CopyTo($memoryStream)
        $memoryStream.ToArray()
    }
    finally {
        $entryStream.Dispose()
        $memoryStream.Dispose()
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$clientRoot = Join-Path $repoRoot 'apps\client'
$artifactsRoot = Join-Path $repoRoot 'artifacts'
$pubspecPath = Join-Path $clientRoot 'pubspec.yaml'
$versionMatch = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*(?<name>\d+\.\d+\.\d+)\+(?<code>\d+)\s*$' |
    Select-Object -First 1
if ($null -eq $versionMatch) {
    throw "Could not read release version from $pubspecPath"
}
$currentVersion = $versionMatch.Matches[0].Groups['name'].Value
$versionCode = [int]$versionMatch.Matches[0].Groups['code'].Value
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = $currentVersion
}
if ($Version -ne $currentVersion) {
    throw "Release verifier only checks the current pubspec version $currentVersion, not $Version."
}

$releaseApkPath = Join-Path $artifactsRoot "Sprache-Android-$Version-google-release-signed.apk"
$debugApkPath = Join-Path $artifactsRoot "Sprache-Android-$Version-google-debug-signed.apk"
$apkPath = if (Test-Path -LiteralPath $releaseApkPath -PathType Leaf) {
    $releaseApkPath
}
elseif (Test-Path -LiteralPath $debugApkPath -PathType Leaf) {
    $debugApkPath
}
else {
    throw "Android release artifact was not found for $Version."
}
$windowsZipPath = Join-Path $artifactsRoot "Sprache-Windows-$Version-google-x64.zip"
$installerPath = Join-Path $artifactsRoot "Sprache-Windows-Setup-$Version-google-x64.exe"
$checksumPath = Join-Path $artifactsRoot "SHA256SUMS-$Version-google.txt"
foreach ($requiredPath in @($windowsZipPath, $installerPath, $checksumPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Release artifact was not found: $requiredPath"
    }
}

$checksumEntries = @{}
foreach ($line in Get-Content -LiteralPath $checksumPath -Encoding utf8) {
    if ($line -notmatch '^(?<hash>[0-9a-f]{64})\s{2}(?<name>.+)$') {
        throw "Malformed checksum line: $line"
    }
    if ($checksumEntries.ContainsKey($Matches.name)) {
        throw "Duplicate checksum entry: $($Matches.name)"
    }
    $checksumEntries[$Matches.name] = $Matches.hash
}
foreach ($entry in $checksumEntries.GetEnumerator()) {
    $entryPath = Join-Path $artifactsRoot $entry.Key
    if (-not (Test-Path -LiteralPath $entryPath -PathType Leaf)) {
        throw "Checksum references a missing artifact: $($entry.Key)"
    }
    $actualHash = (Get-FileHash -LiteralPath $entryPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $entry.Value) {
        throw "Checksum mismatch for $($entry.Key)"
    }
}
foreach ($requiredChecksumName in @(
    (Split-Path -Leaf $apkPath),
    (Split-Path -Leaf $windowsZipPath),
    (Split-Path -Leaf $installerPath)
)) {
    if (-not $checksumEntries.ContainsKey($requiredChecksumName)) {
        throw "Checksum file does not include $requiredChecksumName"
    }
}

$androidSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$buildTools = Get-ChildItem -LiteralPath (Join-Path $androidSdk 'build-tools') -Directory |
    Sort-Object Name -Descending |
    Select-Object -First 1
if ($null -eq $buildTools) {
    throw 'Android SDK build-tools were not found.'
}
$aaptPath = Join-Path $buildTools.FullName 'aapt.exe'
$apkSignerPath = Join-Path $buildTools.FullName 'apksigner.bat'
foreach ($androidTool in @($aaptPath, $apkSignerPath)) {
    if (-not (Test-Path -LiteralPath $androidTool -PathType Leaf)) {
        throw "Android verification tool was not found: $androidTool"
    }
}

$badgingOutput = & $aaptPath dump badging $apkPath 2>&1
$aaptExitCode = $LASTEXITCODE
if ($aaptExitCode -ne 0) {
    throw "aapt failed with exit code $aaptExitCode"
}
$badging = ($badgingOutput | Select-Object -First 1) -join "`n"
$expectedBadging =
    "package: name='com.youkdonghun.sprache' versionCode='$versionCode' versionName='$Version'"
if (-not $badging.StartsWith($expectedBadging, [StringComparison]::Ordinal)) {
    throw "Unexpected Android package metadata: $badging"
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $apkSignatureLines = & $apkSignerPath verify --verbose --print-certs $apkPath 2>&1
    $apkSignerExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
$apkSignatureOutput = $apkSignatureLines -join "`n"
if ($apkSignerExitCode -ne 0) {
    throw "apksigner failed with exit code $apkSignerExitCode"
}
if ($apkSignatureOutput -notmatch 'Verified using v2 scheme .*: true') {
    throw 'Android artifact is not verified with APK Signature Scheme v2.'
}
$isAndroidDebugSigned = $apkSignatureOutput -match 'CN=Android Debug'
if ($RequireAndroidReleaseSigning -and $isAndroidDebugSigned) {
    throw 'Android artifact is still signed with the Debug certificate.'
}
$apkNameClaimsDebug = (Split-Path -Leaf $apkPath) -like '*-debug-signed.apk'
if ($apkNameClaimsDebug -ne $isAndroidDebugSigned) {
    throw 'Android artifact filename does not match its signing certificate.'
}

$installer = Get-Item -LiteralPath $installerPath
if ($installer.VersionInfo.ProductVersion.Trim() -ne $Version) {
    throw "Unexpected installer product version: $($installer.VersionInfo.ProductVersion)"
}
$installerSignature = Get-AuthenticodeSignature -LiteralPath $installerPath
if ($RequireWindowsCodeSigning -and
    $installerSignature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
    throw "Windows installer Authenticode signature is not valid: $($installerSignature.Status)"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$binaryRows = @()
$requiredBinaryTexts = @($ExpectedApiBaseUrl, $Version)
if (-not [string]::IsNullOrWhiteSpace($ExpectedPrivacyPolicyUrl)) {
    if (-not $ExpectedPrivacyPolicyUrl.StartsWith('https://', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Expected privacy policy URL must use HTTPS.'
    }
    $requiredBinaryTexts += $ExpectedPrivacyPolicyUrl
}
$forbiddenBinaryTexts = @(
    'http://127.0.0.1:3000',
    'GOOGLE_DESKTOP_CLIENT_SECRET'
)

$apkArchive = [IO.Compression.ZipFile]::OpenRead($apkPath)
try {
    $androidAppEntries = @(
        $apkArchive.Entries |
            Where-Object { ($_.FullName -replace '\\', '/') -match '^lib/[^/]+/libapp\.so$' }
    )
    if ($androidAppEntries.Count -ne 3) {
        throw "Expected three Android libapp.so binaries, found $($androidAppEntries.Count)."
    }
    foreach ($entry in $androidAppEntries) {
        $bytes = Read-ZipEntryBytes -Entry $entry
        $binaryText = [Text.Encoding]::UTF8.GetString($bytes)
        foreach ($requiredText in $requiredBinaryTexts) {
            if ($binaryText.IndexOf($requiredText, [StringComparison]::Ordinal) -lt 0) {
                throw "Android binary $($entry.FullName) is missing required value: $requiredText"
            }
        }
        foreach ($forbiddenText in $forbiddenBinaryTexts) {
            if ($binaryText.IndexOf($forbiddenText, [StringComparison]::Ordinal) -ge 0) {
                throw "Android binary $($entry.FullName) contains forbidden value: $forbiddenText"
            }
        }
        $binaryRows += [pscustomobject]@{
            Platform = 'Android'
            Binary = $entry.FullName
            Bytes = $bytes.Length
        }
    }
}
finally {
    $apkArchive.Dispose()
}

$windowsArchive = [IO.Compression.ZipFile]::OpenRead($windowsZipPath)
try {
    $normalizedEntries = @{}
    foreach ($entry in $windowsArchive.Entries) {
        $normalizedEntries[($entry.FullName -replace '\\', '/')] = $entry
    }
    foreach ($requiredZipEntry in @(
        'sprache.exe',
        'data/app.so',
        'data/flutter_assets/assets/templates/Sprache-word-import-template.xlsx'
    )) {
        if (-not $normalizedEntries.ContainsKey($requiredZipEntry)) {
            throw "Windows ZIP is missing: $requiredZipEntry"
        }
    }
    $windowsAppBytes = Read-ZipEntryBytes -Entry $normalizedEntries['data/app.so']
    $windowsExeBytes = Read-ZipEntryBytes -Entry $normalizedEntries['sprache.exe']
    $windowsAppText = [Text.Encoding]::UTF8.GetString($windowsAppBytes)
    foreach ($requiredText in $requiredBinaryTexts) {
        if ($windowsAppText.IndexOf($requiredText, [StringComparison]::Ordinal) -lt 0) {
            throw "Windows app.so is missing required value: $requiredText"
        }
    }
    foreach ($forbiddenText in $forbiddenBinaryTexts) {
        if ($windowsAppText.IndexOf($forbiddenText, [StringComparison]::Ordinal) -ge 0) {
            throw "Windows app.so contains forbidden value: $forbiddenText"
        }
    }
    $binaryRows += [pscustomobject]@{
        Platform = 'Windows'
        Binary = 'data/app.so'
        Bytes = $windowsAppBytes.Length
    }
    $windowsZipEntryCount = $windowsArchive.Entries.Count
}
finally {
    $windowsArchive.Dispose()
}

$temporaryWindowsExe = Join-Path ([IO.Path]::GetTempPath()) "sprache-release-verify-$([Guid]::NewGuid().ToString('N')).exe"
try {
    [IO.File]::WriteAllBytes($temporaryWindowsExe, $windowsExeBytes)
    $windowsExeSignature = Get-AuthenticodeSignature -LiteralPath $temporaryWindowsExe
}
finally {
    if (Test-Path -LiteralPath $temporaryWindowsExe -PathType Leaf) {
        [IO.File]::Delete($temporaryWindowsExe)
    }
}
if ($RequireWindowsCodeSigning) {
    if ($null -eq $windowsExeSignature -or
        $windowsExeSignature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
        throw 'Windows application Authenticode signature is not valid.'
    }
}

if ($RunInstallerSmoke) {
    & (Join-Path $PSScriptRoot 'test-windows-installer.ps1') `
        -Version $Version `
        -InstallerPath $installerPath
    if ($LASTEXITCODE -ne 0) {
        throw "Windows installer smoke test failed with exit code $LASTEXITCODE"
    }
}

if ($CleanOldArtifacts) {
    & (Join-Path $PSScriptRoot 'clean-release-artifacts.ps1') `
        -KeepVersion $Version `
        -Confirm:$false
    if ($LASTEXITCODE -ne 0) {
        throw "Old release artifact cleanup failed with exit code $LASTEXITCODE"
    }
}

$binaryRows | Format-Table -AutoSize
[pscustomobject]@{
    Version = "$Version+$versionCode"
    AndroidArtifact = Split-Path -Leaf $apkPath
    AndroidSigning = if ($isAndroidDebugSigned) { 'Debug' } else { 'Release' }
    WindowsZipEntries = $windowsZipEntryCount
    InstallerAuthenticode = $installerSignature.Status
    ChecksumsVerified = $checksumEntries.Count
    PrivacyPolicyUrlEmbedded = -not [string]::IsNullOrWhiteSpace($ExpectedPrivacyPolicyUrl)
    InstallerSmokeRun = [bool]$RunInstallerSmoke
    OldArtifactsCleanupRun = [bool]$CleanOldArtifacts
}
