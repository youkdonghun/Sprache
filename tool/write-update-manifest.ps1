param(
    [string[]]$Notes = @(
        '앱 안에서 새 버전을 확인하고 바로 설치할 수 있습니다.',
        '다운로드 파일의 크기와 SHA-256을 확인한 뒤에만 설치합니다.',
        '업데이트 확인은 사용자가 버튼을 누를 때만 실행됩니다.'
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$pubspecPath = Join-Path $repoRoot 'apps\client\pubspec.yaml'
$outputPath = Join-Path $repoRoot 'apps\client\web\release.json'
$artifactsRoot = Join-Path $repoRoot 'artifacts'
$versionMatch = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*(?<name>\d+\.\d+\.\d+)\+(?<build>\d+)\s*$' |
    Select-Object -First 1
if ($null -eq $versionMatch) {
    throw "Could not read release version from $pubspecPath"
}
$version = $versionMatch.Matches[0].Groups['name'].Value
$buildNumber = [int]$versionMatch.Matches[0].Groups['build'].Value

$androidCandidates = @(
    Get-ChildItem -LiteralPath $artifactsRoot -File -Filter "Sprache-Android-$version-google-*-signed.apk"
)
$windowsCandidates = @(
    Get-ChildItem -LiteralPath $artifactsRoot -File -Filter "Sprache-Windows-Setup-$version-google-x64.exe"
)
if ($androidCandidates.Count -ne 1) {
    throw "Expected exactly one Android $version APK, found $($androidCandidates.Count)."
}
if ($windowsCandidates.Count -ne 1) {
    throw "Expected exactly one Windows $version installer, found $($windowsCandidates.Count)."
}

function New-DownloadArtifact {
    param(
        [Parameter(Mandatory = $true)]
        [IO.FileInfo]$File,
        [Parameter(Mandatory = $true)]
        [ValidateSet('apk', 'installer')]
        [string]$Kind
    )

    $escapedName = [Uri]::EscapeDataString($File.Name)
    return [ordered]@{
        kind = $Kind
        url = "https://github.com/youkdonghun/Sprache/releases/download/v$version/$escapedName"
        fileName = $File.Name
        sha256 = (Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        sizeBytes = [long]$File.Length
    }
}

$releasePage = "https://github.com/youkdonghun/Sprache/releases/tag/v$version"
$manifest = [ordered]@{
    schemaVersion = 1
    version = $version
    buildNumber = $buildNumber
    publishedAt = [DateTime]::UtcNow.ToString('o')
    title = "Sprache $version"
    notes = @($Notes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 8)
    releasePageUrl = $releasePage
    artifacts = [ordered]@{
        windows = New-DownloadArtifact -File $windowsCandidates[0] -Kind 'installer'
        android = New-DownloadArtifact -File $androidCandidates[0] -Kind 'apk'
        pwa = [ordered]@{
            kind = 'web'
            url = 'https://sprache6.github.io/app/'
        }
        macos = [ordered]@{
            kind = 'releasePage'
            url = $releasePage
        }
        ios = [ordered]@{
            kind = 'releasePage'
            url = $releasePage
        }
    }
}

$temporaryPath = "$outputPath.tmp-$PID"
try {
    $json = $manifest | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($temporaryPath, "$json`n", [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryPath -Destination $outputPath -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
}

Get-Item -LiteralPath $outputPath | Select-Object FullName, Length, LastWriteTime
