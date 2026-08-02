[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$KeepVersion
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$artifactsPath = [IO.Path]::GetFullPath((Join-Path $repoRoot 'artifacts'))
$expectedArtifactsPath = [IO.Path]::GetFullPath((Join-Path $repoRoot 'artifacts'))
if (-not $artifactsPath.Equals(
        $expectedArtifactsPath,
        [StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Unsafe artifacts path: $artifactsPath"
}
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'package.json') -PathType Leaf) -or
    -not (Test-Path -LiteralPath (Join-Path $repoRoot 'apps\client\pubspec.yaml') -PathType Leaf)) {
    throw "Repository markers were not found below $repoRoot"
}
if (-not (Test-Path -LiteralPath $artifactsPath -PathType Container)) {
    throw "Artifacts directory was not found: $artifactsPath"
}

$artifactPatterns = @(
    '^Sprache-Android-(?<Version>\d+\.\d+\.\d+)-(?:google|mock)-(?:debug|release)-signed\.apk$',
    '^Sprache-Windows-(?<Version>\d+\.\d+\.\d+)-(?:google|mock)-x64\.zip$',
    '^Sprache-Windows-Setup-(?<Version>\d+\.\d+\.\d+)-(?:google|mock)-x64\.exe$',
    '^SHA256SUMS-(?<Version>\d+\.\d+\.\d+)-(?:google|mock)\.txt$'
)

function Get-ReleaseArtifactVersion {
    param([Parameter(Mandatory = $true)][string]$Name)

    foreach ($pattern in $script:artifactPatterns) {
        if ($Name -match $pattern) {
            return $Matches.Version
        }
    }
    return $null
}

function Get-Sha256Hash {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [IO.File]::OpenRead($Path)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $algorithm.ComputeHash($stream)
        return ([BitConverter]::ToString($bytes)).Replace('-', '')
    }
    finally {
        $algorithm.Dispose()
        $stream.Dispose()
    }
}

$checksumFiles = @(
    Get-ChildItem -LiteralPath $artifactsPath -File |
        Where-Object {
            $_.Name -match "^SHA256SUMS-$([regex]::Escape($KeepVersion))-(?:google|mock)\.txt$"
        }
)
if ($checksumFiles.Count -eq 0) {
    throw "No checksum manifest exists for keep version $KeepVersion. Build and verify the new release before cleanup."
}

$verifiedPayloadCount = 0
foreach ($checksumFile in $checksumFiles) {
    foreach ($line in Get-Content -LiteralPath $checksumFile.FullName -Encoding utf8) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($line -notmatch '^(?<Hash>[0-9a-fA-F]{64})\s{2}(?<Name>.+)$') {
            throw "Malformed checksum line in $($checksumFile.Name): $line"
        }

        $expectedHash = $Matches.Hash
        $payloadName = $Matches.Name
        if ([IO.Path]::GetFileName($payloadName) -ne $payloadName) {
            throw "Checksum contains an unsafe artifact path: $payloadName"
        }
        $payloadVersion = Get-ReleaseArtifactVersion -Name $payloadName
        if ($null -eq $payloadVersion -or $payloadVersion -ne $KeepVersion -or
            $payloadName -like 'SHA256SUMS-*') {
            throw "Checksum references an unexpected artifact for ${KeepVersion}: $payloadName"
        }

        $payloadPath = Join-Path $artifactsPath $payloadName
        if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) {
            throw "Checksum references a missing artifact: $payloadName"
        }
        $actualHash = Get-Sha256Hash -Path $payloadPath
        if ($actualHash -ine $expectedHash) {
            throw "Checksum mismatch for $payloadName"
        }
        $verifiedPayloadCount++
    }
}
if ($verifiedPayloadCount -eq 0) {
    throw "No release payloads were verified for $KeepVersion"
}

$removed = @()
$kept = @()
$unmatched = @()
foreach ($file in Get-ChildItem -LiteralPath $artifactsPath -File) {
    $artifactVersion = Get-ReleaseArtifactVersion -Name $file.Name
    if ($null -eq $artifactVersion) {
        $unmatched += $file.Name
        continue
    }
    if ($artifactVersion -eq $KeepVersion) {
        $kept += $file.Name
        continue
    }

    if ($PSCmdlet.ShouldProcess(
            $file.FullName,
            "Remove old Sprache release artifact version $artifactVersion"
        )) {
        Remove-Item -LiteralPath $file.FullName -Force
        $removed += $file.Name
    }
}

[pscustomobject]@{
    KeepVersion = $KeepVersion
    VerifiedPayloads = $verifiedPayloadCount
    RemovedArtifacts = $removed.Count
    KeptArtifacts = $kept.Count
    UnmatchedFilesPreserved = $unmatched.Count
}
