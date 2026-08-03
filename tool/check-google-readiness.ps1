param(
    [string]$DesktopClientId = '1054343487948-o7nkfj4qmiilacvbln7alfgqrced6ior.apps.googleusercontent.com',
    [string]$AndroidClientId = '1054343487948-v3u90fo5nmbrk4hn7ss2gnrg601phkuv.apps.googleusercontent.com',
    [string]$ServerClientId = '1054343487948-g6b3fp20ooq86agro7nsb129oqr9df82.apps.googleusercontent.com',
    [string]$AppleClientId = '1054343487948-8ueu92l0ov3259rs8psun40c6iu4arel.apps.googleusercontent.com',
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
$appleReady = Test-GoogleClientId -Value $AppleClientId
$desktopClientSecretReady = -not [string]::IsNullOrWhiteSpace(
    [Environment]::GetEnvironmentVariable(
        'SPRACHE_GOOGLE_DESKTOP_CLIENT_SECRET',
        'Process'
    )
)
$privacyReady = -not [string]::IsNullOrWhiteSpace($PrivacyPolicyUrl) -and
    $PrivacyPolicyUrl.StartsWith('https://', [StringComparison]::OrdinalIgnoreCase)
$windowsReady = $desktopReady -and $desktopClientSecretReady
$configurationReady = $windowsReady -and $androidReady -and $serverReady -and
    $appleReady -and $privacyReady

[pscustomobject]@{
    DesktopOAuthMode = 'direct-pkce-with-client-credential'
    DriveBindingStore = 'google-drive-appdata-pointer'
    DesktopClientIdConfigured = $desktopReady
    DesktopClientSecretConfigured = $desktopClientSecretReady
    AndroidClientIdConfigured = $androidReady
    ServerClientIdConfigured = $serverReady
    AppleClientIdConfigured = $appleReady
    PrivacyPolicyUrl = $PrivacyPolicyUrl
    WindowsGoogleBuildReady = $windowsReady
    WindowsGoogleLoginVerified = $false
    AppleGoogleBuildReady = $appleReady
    AppleGoogleLoginVerified = $false
    ReleaseGoogleConfigurationReady = $configurationReady
    ReleaseGoogleRuntimeVerified = $false
    VerificationNote = 'This check validates build configuration only. Complete the platform live-login checklist before claiming Google OAuth works.'
}

if (-not $configurationReady) {
    $message = 'Google 빌드 구성에 필요한 플랫폼 Client ID, Windows 빌드 시크릿 환경 변수, HTTPS 개인정보처리방침 URL을 확인해 주세요.'
    if ($RequireReady) {
        throw $message
    }
    Write-Warning $message
}
