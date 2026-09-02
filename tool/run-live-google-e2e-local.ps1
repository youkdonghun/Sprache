param(
    [string]$OAuthUrlFile = '',
    [switch]$FileOnly,
    [switch]$ReuseSession
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$managedEnvironment = @(
    'SPRACHE_LIVE_OAUTH_URL_FILE',
    'SPRACHE_LIVE_OAUTH_FILE_ONLY',
    'SPRACHE_LIVE_REUSE_SESSION'
)
$previousEnvironment = @{}
foreach ($name in $managedEnvironment) {
    $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable(
        $name,
        'Process'
    )
}

try {
    if (-not [string]::IsNullOrWhiteSpace($OAuthUrlFile)) {
        $env:SPRACHE_LIVE_OAUTH_URL_FILE = $OAuthUrlFile
    }
    if ($FileOnly) {
        $env:SPRACHE_LIVE_OAUTH_FILE_ONLY = '1'
    }
    if ($ReuseSession) {
        $env:SPRACHE_LIVE_REUSE_SESSION = '1'
    }

    & (Join-Path $PSScriptRoot 'run-live-google-e2e.ps1')
    if ($LASTEXITCODE -ne 0) {
        throw "Live Google E2E failed with exit code $LASTEXITCODE"
    }
}
finally {
    foreach ($name in $managedEnvironment) {
        [Environment]::SetEnvironmentVariable(
            $name,
            $previousEnvironment[$name],
            'Process'
        )
    }
    if (-not [string]::IsNullOrWhiteSpace($OAuthUrlFile) -and
        (Test-Path -LiteralPath $OAuthUrlFile -PathType Leaf)) {
        Remove-Item -LiteralPath $OAuthUrlFile -Force
    }
}
