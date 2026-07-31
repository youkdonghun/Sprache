param(
    [string]$ApiBaseUrl = 'https://sprache-api-production.up.railway.app',
    [switch]$RequireReady
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ApiBaseUrl.StartsWith('https://', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'API_BASE_URL must use HTTPS for the production Google readiness check'
}

$healthUrl = "$($ApiBaseUrl.TrimEnd('/'))/health"
try {
    $health = Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec 15
}
catch {
    throw "Railway health check failed at $healthUrl. Local study remains available; verify the Railway deployment and network before Google login."
}

if ($health.status -ne 'ok' -or $health.service -ne 'sprache-api') {
    throw "Railway returned an unexpected health response at $healthUrl."
}

$brokerState = if ($null -eq $health.desktopOAuthBroker) {
    'api_update_required'
}
else {
    [string]$health.desktopOAuthBroker
}
$ready = $brokerState -eq 'ready'

$result = [pscustomobject]@{
    ApiBaseUrl = $ApiBaseUrl.TrimEnd('/')
    ApiHealthy = $true
    DesktopOAuthBroker = $brokerState
    WindowsGoogleLoginReady = $ready
}
$result

if (-not $ready) {
    $message = if ($brokerState -eq 'api_update_required') {
        'Railway API is reachable but does not expose desktopOAuthBroker. Deploy the current API before Windows Google login.'
    }
    else {
        'Railway API is healthy, but Windows Google login is not ready. Register GOOGLE_DESKTOP_CLIENT_ID and GOOGLE_DESKTOP_CLIENT_SECRET together as Railway sealed variables, then wait for the redeployment.'
    }
    if ($RequireReady) {
        throw $message
    }
    Write-Warning $message
}
