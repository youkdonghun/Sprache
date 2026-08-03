param(
    [string]$CredentialPath = "$env:LOCALAPPDATA\Sprache\credentials\desktop-oauth-secret.dpapi",
    [string]$OAuthUrlFile = '',
    [switch]$FileOnly,
    [switch]$ReuseSession
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $CredentialPath -PathType Leaf)) {
    throw "Encrypted desktop OAuth credential not found: $CredentialPath"
}

Add-Type -AssemblyName System.Security
$hex = [System.IO.File]::ReadAllText($CredentialPath).Trim()
if (($hex.Length % 2) -ne 0 -or $hex -notmatch '^[0-9A-Fa-f]+$') {
    throw 'Encrypted desktop OAuth credential is not valid hex.'
}

$protectedBytes = New-Object byte[] ($hex.Length / 2)
for ($index = 0; $index -lt $protectedBytes.Length; $index++) {
    $protectedBytes[$index] = [Convert]::ToByte(
        $hex.Substring($index * 2, 2),
        16
    )
}

$plainBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
    $protectedBytes,
    $null,
    [System.Security.Cryptography.DataProtectionScope]::CurrentUser
)
$managedEnvironment = @(
    'SPRACHE_GOOGLE_DESKTOP_CLIENT_SECRET',
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
    $clientSecret = [System.Text.Encoding]::UTF8.GetString($plainBytes)
    if ($clientSecret -notmatch '^GOCSPX-[A-Za-z0-9_-]+$') {
        throw 'Decrypted desktop OAuth credential has an invalid shape.'
    }

    $env:SPRACHE_GOOGLE_DESKTOP_CLIENT_SECRET = $clientSecret
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
    if ($plainBytes) {
        [Array]::Clear($plainBytes, 0, $plainBytes.Length)
    }
    if ($protectedBytes) {
        [Array]::Clear($protectedBytes, 0, $protectedBytes.Length)
    }
    $clientSecret = $null
}
