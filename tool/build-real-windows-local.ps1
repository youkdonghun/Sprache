param(
    [string]$CredentialPath = "$env:LOCALAPPDATA\Sprache\credentials\desktop-oauth-secret.dpapi"
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
$previousSecret = [Environment]::GetEnvironmentVariable(
    'SPRACHE_GOOGLE_DESKTOP_CLIENT_SECRET',
    'Process'
)
$previousPath = [Environment]::GetEnvironmentVariable('Path', 'Process')

try {
    $nugetExe = Join-Path $env:LOCALAPPDATA 'Programs\nuget\nuget.exe'
    if (-not (Test-Path -LiteralPath $nugetExe -PathType Leaf)) {
        throw "NuGet is required for the Windows build but was not found: $nugetExe"
    }
    $nugetDirectory = Split-Path -Parent $nugetExe

    $gitExe = @(
        (Join-Path $env:ProgramFiles 'Git\cmd\git.exe')
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe')
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($gitExe)) {
        throw 'Git is required by Flutter but no supported Git installation was found.'
    }
    $gitDirectory = Split-Path -Parent $gitExe

    $pathEntries = $previousPath -split ';' |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $pathPrefix = @($nugetDirectory, $gitDirectory) |
        Where-Object { $pathEntries -notcontains $_ } |
        Select-Object -Unique
    $buildPath = (@($pathPrefix) + @($pathEntries)) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $buildPath, 'Process')

    $clientSecret = [System.Text.Encoding]::UTF8.GetString($plainBytes)
    if ($clientSecret -notmatch '^GOCSPX-[A-Za-z0-9_-]+$') {
        throw 'Decrypted desktop OAuth credential has an invalid shape.'
    }
    [Environment]::SetEnvironmentVariable(
        'SPRACHE_GOOGLE_DESKTOP_CLIENT_SECRET',
        $clientSecret,
        'Process'
    )
    & (Join-Path $PSScriptRoot 'build-real.ps1') -Target windows
    if ($LASTEXITCODE -ne 0) {
        throw "Windows REAL build failed with exit code $LASTEXITCODE"
    }
}
finally {
    [Environment]::SetEnvironmentVariable('Path', $previousPath, 'Process')
    [Environment]::SetEnvironmentVariable(
        'SPRACHE_GOOGLE_DESKTOP_CLIENT_SECRET',
        $previousSecret,
        'Process'
    )
    if ($plainBytes) {
        [Array]::Clear($plainBytes, 0, $plainBytes.Length)
    }
    if ($protectedBytes) {
        [Array]::Clear($protectedBytes, 0, $protectedBytes.Length)
    }
    $clientSecret = $null
}
