param(
    [string]$DesktopClientId = '1054343487948-791d7jh7m90rt4cs1ncgkf6l5eecehut.apps.googleusercontent.com',
    [string]$AndroidClientId = '1054343487948-v3u90fo5nmbrk4hn7ss2gnrg601phkuv.apps.googleusercontent.com',
    [string]$ServerClientId = '1054343487948-g6b3fp20ooq86agro7nsb129oqr9df82.apps.googleusercontent.com',
    [string]$PrivacyPolicyUrl = $(if ([string]::IsNullOrWhiteSpace($env:SPRACHE_PRIVACY_POLICY_URL)) {
        'https://youkdonghun.github.io/Sprache/privacy/'
    } else {
        $env:SPRACHE_PRIVACY_POLICY_URL
    }),
    [switch]$RequireReady
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-GoogleClientId {
    param([string]$Value)
    return -not [string]::IsNullOrWhiteSpace($Value) -and
        $Value -match '^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$'
}

$desktopReady = Test-GoogleClientId -Value $DesktopClientId
$androidReady = Test-GoogleClientId -Value $AndroidClientId
$serverReady = Test-GoogleClientId -Value $ServerClientId
$privacyReady = -not [string]::IsNullOrWhiteSpace($PrivacyPolicyUrl) -and
    $PrivacyPolicyUrl.StartsWith('https://', [StringComparison]::OrdinalIgnoreCase)
$ready = $desktopReady -and $androidReady -and $serverReady -and $privacyReady

[pscustomobject]@{
    DesktopOAuthMode = 'direct-pkce'
    DriveBindingStore = 'google-drive-appdata-pointer'
    DesktopClientIdConfigured = $desktopReady
    AndroidClientIdConfigured = $androidReady
    ServerClientIdConfigured = $serverReady
    PrivacyPolicyUrl = $PrivacyPolicyUrl
    WindowsGoogleLoginReady = $desktopReady
    ReleaseGoogleReady = $ready
}

if (-not $ready) {
    $message = 'Google 연결에 필요한 공개 Client ID와 HTTPS 개인정보처리방침 URL을 확인해 주세요.'
    if ($RequireReady) {
        throw $message
    }
    Write-Warning $message
}
