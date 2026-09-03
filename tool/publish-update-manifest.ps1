param(
    [string]$Repository = 'youkdonghun/Sprache',
    [string]$Tag = '',
    [switch]$VerifyOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$pubspecPath = Join-Path $repoRoot 'apps\client\pubspec.yaml'
$manifestPath = Join-Path $repoRoot 'apps\client\web\release.json'

$versionMatch = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*(?<name>\d+\.\d+\.\d+)\+(?<build>\d+)\s*$' |
    Select-Object -First 1
if ($null -eq $versionMatch) {
    throw "Could not read release version from $pubspecPath"
}
$version = $versionMatch.Matches[0].Groups['name'].Value
$buildNumber = [int]$versionMatch.Matches[0].Groups['build'].Value
if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = "v$version"
}
if ($Tag -ne "v$version") {
    throw "Tag $Tag does not match pubspec version v$version."
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Update manifest was not found: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1 -or
    $manifest.version -ne $version -or
    [int]$manifest.buildNumber -ne $buildNumber) {
    throw "release.json does not match pubspec version $version+$buildNumber."
}

function Get-ReleaseAssets {
    $releaseJson = & gh release view $Tag --repo $Repository --json tagName,isDraft,isPrerelease,assets 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Could not read GitHub release $Tag`: $releaseJson"
    }
    $release = $releaseJson | ConvertFrom-Json
    if ($release.isDraft -or $release.isPrerelease) {
        throw "Update release $Tag must be a published stable release."
    }
    $assets = @{}
    foreach ($asset in $release.assets) {
        $assets[$asset.name] = $asset
    }
    return $assets
}

$assets = Get-ReleaseAssets
foreach ($platform in @('windows', 'android')) {
    $artifact = $manifest.artifacts.$platform
    if ($null -eq $artifact -or [string]::IsNullOrWhiteSpace($artifact.fileName)) {
        throw "release.json is missing the $platform download entry."
    }
    if (-not $assets.ContainsKey($artifact.fileName)) {
        throw "GitHub release $Tag is missing $($artifact.fileName)."
    }
    if ([long]$assets[$artifact.fileName].size -ne [long]$artifact.sizeBytes) {
        throw "GitHub release size does not match release.json: $($artifact.fileName)"
    }
}

if (-not $VerifyOnly) {
    & gh release upload $Tag $manifestPath --clobber --repo $Repository
    if ($LASTEXITCODE -ne 0) {
        throw "Could not upload release.json to GitHub release $Tag."
    }
    $assets = Get-ReleaseAssets
}

if (-not $assets.ContainsKey('release.json')) {
    throw "GitHub release $Tag is missing release.json."
}

$cacheKey = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$latestManifestUrl = "https://github.com/$Repository/releases/latest/download/release.json?check=$cacheKey"
$liveJson = & curl.exe --fail --silent --show-error --location $latestManifestUrl 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "The public update endpoint did not respond: $liveJson"
}
$liveManifest = $liveJson | ConvertFrom-Json
if ($liveManifest.version -ne $version -or
    [int]$liveManifest.buildNumber -ne $buildNumber) {
    throw "The public update endpoint returned $($liveManifest.version)+$($liveManifest.buildNumber), expected $version+$buildNumber."
}

[pscustomobject]@{
    Repository = $Repository
    Tag = $Tag
    Version = "$version+$buildNumber"
    Mode = if ($VerifyOnly) { 'Verified' } else { 'Published and verified' }
    Endpoint = "https://github.com/$Repository/releases/latest/download/release.json"
    ManifestBytes = [long]$assets['release.json'].size
} | Format-List
