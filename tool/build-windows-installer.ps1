param(
    [string]$Version = '',
    [string]$ReleaseDir = '',
    [string]$ArtifactsDir = '',
    [string]$InnoSetupPath = '',
    [string]$WindowsSigningThumbprint = $env:SPRACHE_WINDOWS_SIGNING_THUMBPRINT,
    [string]$TimestampUrl = 'https://timestamp.digicert.com',
    [string]$SignToolPath = '',
    [switch]$RequireWindowsCodeSigning
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$clientRoot = Join-Path $repoRoot 'apps\client'
$pubspecPath = Join-Path $clientRoot 'pubspec.yaml'
$installerDefinition = Join-Path $repoRoot 'packaging\windows\Sprache.iss'

if ([string]::IsNullOrWhiteSpace($Version)) {
    $versionMatch = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*(?<name>\d+\.\d+\.\d+)\+\d+\s*$' |
        Select-Object -First 1
    if ($null -eq $versionMatch) {
        throw "Could not read release version from $pubspecPath"
    }
    $Version = $versionMatch.Matches[0].Groups['name'].Value
}
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Installer version must use major.minor.patch: $Version"
}

if ([string]::IsNullOrWhiteSpace($ReleaseDir)) {
    $ReleaseDir = Join-Path $clientRoot 'build\windows\x64\runner\Release'
}
if ([string]::IsNullOrWhiteSpace($ArtifactsDir)) {
    $ArtifactsDir = Join-Path $repoRoot 'artifacts'
}

$releasePath = [IO.Path]::GetFullPath($ReleaseDir)
$artifactsPath = [IO.Path]::GetFullPath($ArtifactsDir)
if (-not (Test-Path -LiteralPath (Join-Path $releasePath 'sprache.exe') -PathType Leaf)) {
    throw "Windows release executable not found: $releasePath"
}
if (-not (Test-Path -LiteralPath (Join-Path $releasePath 'data\app.so') -PathType Leaf)) {
    throw "Windows Flutter data is incomplete: $releasePath"
}

if ([string]::IsNullOrWhiteSpace($InnoSetupPath)) {
    $knownCompilerPaths = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
        'C:\Program Files\Inno Setup 6\ISCC.exe'
    )
    $InnoSetupPath = $knownCompilerPaths |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($InnoSetupPath) -or
    -not (Test-Path -LiteralPath $InnoSetupPath -PathType Leaf)) {
    throw 'Inno Setup 6 compiler was not found. Install it with: winget install --id JRSoftware.InnoSetup --exact --scope user'
}

New-Item -ItemType Directory -Path $artifactsPath -Force | Out-Null

$compilerArguments = @(
    "/DMyAppVersion=$Version",
    "/DReleaseDir=$releasePath",
    "/DInstallerOutputDir=$artifactsPath",
    $installerDefinition
)
& $InnoSetupPath @compilerArguments
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed with exit code $LASTEXITCODE"
}

$installerPath = Join-Path $artifactsPath "Sprache-Windows-Setup-$Version-google-x64.exe"
if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
    throw "Installer output was not created: $installerPath"
}

& (Join-Path $PSScriptRoot 'sign-windows-file.ps1') `
    -Path $installerPath `
    -CertificateThumbprint $WindowsSigningThumbprint `
    -TimestampUrl $TimestampUrl `
    -SignToolPath $SignToolPath `
    -RequireSignature:$RequireWindowsCodeSigning

$installer = Get-Item -LiteralPath $installerPath
$hash = Get-FileHash -LiteralPath $installerPath -Algorithm SHA256
$signature = Get-AuthenticodeSignature -LiteralPath $installerPath
[pscustomobject]@{
    Path = $installer.FullName
    Length = $installer.Length
    SHA256 = $hash.Hash.ToLowerInvariant()
    Authenticode = $signature.Status
}
