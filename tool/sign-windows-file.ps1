param(
    [Parameter(Mandatory = $true)]
    [string[]]$Path,
    [string]$CertificateThumbprint = $env:SPRACHE_WINDOWS_SIGNING_THUMBPRINT,
    [string]$TimestampUrl = 'https://timestamp.digicert.com',
    [string]$SignToolPath = '',
    [switch]$RequireSignature
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$normalizedThumbprint = ($CertificateThumbprint -replace '\s', '').ToUpperInvariant()
if ([string]::IsNullOrWhiteSpace($normalizedThumbprint)) {
    if ($RequireSignature) {
        throw 'Windows code signing is required, but SPRACHE_WINDOWS_SIGNING_THUMBPRINT is not configured.'
    }
    Write-Verbose 'Windows code signing skipped because no certificate thumbprint was provided.'
    return
}
if ($normalizedThumbprint -notmatch '^[0-9A-F]{40}$') {
    throw 'Windows code signing certificate thumbprint must be a 40-character SHA-1 certificate thumbprint.'
}

$timestampUri = $null
if (-not [Uri]::TryCreate($TimestampUrl, [UriKind]::Absolute, [ref]$timestampUri) -or
    $timestampUri.Scheme -ne 'https') {
    throw 'Windows timestamp URL must be an absolute HTTPS URL.'
}

if ([string]::IsNullOrWhiteSpace($SignToolPath)) {
    $windowsKitsRoot = 'C:\Program Files (x86)\Windows Kits\10\bin'
    $SignToolPath = Get-ChildItem -LiteralPath $windowsKitsRoot -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
        Sort-Object FullName -Descending |
        Select-Object -ExpandProperty FullName -First 1
}
if ([string]::IsNullOrWhiteSpace($SignToolPath) -or
    -not (Test-Path -LiteralPath $SignToolPath -PathType Leaf)) {
    throw 'Windows SDK SignTool was not found.'
}

$certificatePath = "Cert:\CurrentUser\My\$normalizedThumbprint"
if (-not (Test-Path -LiteralPath $certificatePath)) {
    throw "Windows code signing certificate was not found in CurrentUser\My: $normalizedThumbprint"
}
$certificate = Get-Item -LiteralPath $certificatePath
if (-not $certificate.HasPrivateKey) {
    throw "Windows code signing certificate has no private key: $normalizedThumbprint"
}
$hasCodeSigningUsage = @(
    $certificate.EnhancedKeyUsageList |
        Where-Object { $_.ObjectId.Value -eq '1.3.6.1.5.5.7.3.3' }
).Count -gt 0
if (-not $hasCodeSigningUsage) {
    throw "Certificate is not valid for code signing: $normalizedThumbprint"
}
if ($certificate.NotAfter -le (Get-Date)) {
    throw "Windows code signing certificate has expired: $normalizedThumbprint"
}

$results = foreach ($rawPath in $Path) {
    $filePath = [IO.Path]::GetFullPath($rawPath)
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        throw "File to sign was not found: $filePath"
    }

    & $SignToolPath sign `
        /sha1 $normalizedThumbprint `
        /s My `
        /fd SHA256 `
        /tr $TimestampUrl `
        /td SHA256 `
        $filePath
    if ($LASTEXITCODE -ne 0) {
        throw "SignTool failed to sign $filePath with exit code $LASTEXITCODE"
    }

    & $SignToolPath verify /pa /tw $filePath
    if ($LASTEXITCODE -ne 0) {
        throw "SignTool failed to verify $filePath with exit code $LASTEXITCODE"
    }

    $signature = Get-AuthenticodeSignature -LiteralPath $filePath
    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
        throw "Authenticode signature is not valid for $filePath`: $($signature.Status)"
    }
    $timestampCertificateSubject =
        if ($null -eq $signature.TimeStamperCertificate) {
            ''
        }
        else {
            $signature.TimeStamperCertificate.Subject
        }

    [pscustomobject]@{
        Path = $filePath
        Status = $signature.Status
        Subject = $signature.SignerCertificate.Subject
        Thumbprint = $signature.SignerCertificate.Thumbprint
        TimestampCertificate = $timestampCertificateSubject
    }
}

$results
