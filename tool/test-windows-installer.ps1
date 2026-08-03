param(
    [string]$Version = '',
    [string]$InstallerPath = '',
    [string]$RuntimeEvidencePath = '',
    [string]$RuntimeCaptureDirectory = '.\artifacts\verification\windows-installer-runtime',
    [ValidateSet('REAL', 'MOCK')]
    [string]$RuntimeMode = 'REAL',
    [ValidateRange(1, 60)]
    [int]$StartupWaitSeconds = 12,
    [switch]$ForceFailureAfterInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$spracheUninstallRegistryKey = '{07105448-EEAE-4779-8358-BE6573C587FC}_is1'
$spracheClassesRoot = 'HKCU:\Software\Classes'
$spracheFileProgramId = 'Sprache.Import'
$spracheImportExtensions = @('.csv', '.tsv', '.xlsx', '.json', '.jsonl')

function Get-SpracheInstallations {
    $registryRoots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    foreach ($registryRoot in $registryRoots) {
        if (-not (Test-Path -LiteralPath $registryRoot)) {
            continue
        }

        foreach ($entry in Get-ChildItem -LiteralPath $registryRoot -ErrorAction SilentlyContinue) {
            $properties = Get-ItemProperty -LiteralPath $entry.PSPath -ErrorAction SilentlyContinue
            if ($null -eq $properties) {
                continue
            }

            $displayNameProperty = $properties.PSObject.Properties['DisplayName']
            $displayVersionProperty = $properties.PSObject.Properties['DisplayVersion']
            $installLocationProperty = $properties.PSObject.Properties['InstallLocation']
            $displayName = if ($null -eq $displayNameProperty) {
                ''
            }
            else {
                [string]$displayNameProperty.Value
            }
            $isSpracheAppId =
                $entry.PSChildName -ieq $script:spracheUninstallRegistryKey
            $isSpracheDisplayName = $displayName -match '^Sprache(?:\s|$)'
            if ($isSpracheAppId -or $isSpracheDisplayName) {
                [pscustomobject]@{
                    RegistryPath = $entry.PSPath
                    DisplayName = $displayName
                    DisplayVersion = if ($null -eq $displayVersionProperty) {
                        ''
                    }
                    else {
                        [string]$displayVersionProperty.Value
                    }
                    InstallLocation = if ($null -eq $installLocationProperty) {
                        ''
                    }
                    else {
                        [string]$installLocationProperty.Value
                    }
                }
            }
        }
    }
}

function Get-SpracheAssociationResidues {
    $residues = @()
    foreach ($ownedPath in @(
        (Join-Path $script:spracheClassesRoot $script:spracheFileProgramId),
        (Join-Path $script:spracheClassesRoot 'Applications\sprache.exe'),
        (Join-Path $script:spracheClassesRoot 'sprache')
    )) {
        if (Test-Path -LiteralPath $ownedPath) {
            $residues += $ownedPath
        }
    }
    foreach ($extension in $script:spracheImportExtensions) {
        $openWithPath = Join-Path $script:spracheClassesRoot "$extension\OpenWithProgids"
        if (-not (Test-Path -LiteralPath $openWithPath)) {
            continue
        }
        $openWithKey = Get-Item -LiteralPath $openWithPath -ErrorAction SilentlyContinue
        if ($null -ne $openWithKey -and
            @($openWithKey.GetValueNames()) -contains $script:spracheFileProgramId) {
            $residues += "$openWithPath::$($script:spracheFileProgramId)"
        }
    }
    return $residues
}

function Assert-SpracheAssociationsInstalled {
    param([Parameter(Mandatory = $true)][string]$ExpectedExecutable)

    $expectedExecutablePath = [IO.Path]::GetFullPath($ExpectedExecutable)
    $fileCommandPath = Join-Path $script:spracheClassesRoot "$($script:spracheFileProgramId)\shell\open\command"
    $protocolPath = Join-Path $script:spracheClassesRoot 'sprache'
    $protocolCommandPath = Join-Path $protocolPath 'shell\open\command'
    foreach ($requiredKey in @($fileCommandPath, $protocolPath, $protocolCommandPath)) {
        if (-not (Test-Path -LiteralPath $requiredKey)) {
            throw "Installed file association key is missing: $requiredKey"
        }
    }

    $fileCommand = [string](Get-Item -LiteralPath $fileCommandPath).GetValue('')
    $protocolCommand = [string](Get-Item -LiteralPath $protocolCommandPath).GetValue('')
    if ($fileCommand -notlike "*$expectedExecutablePath*" -or $fileCommand -notlike '*%1*') {
        throw "Installed file association command is invalid: $fileCommand"
    }
    if ($protocolCommand -notlike "*$expectedExecutablePath*" -or $protocolCommand -notlike '*%1*') {
        throw "Installed protocol command is invalid: $protocolCommand"
    }
    $urlProtocol = (Get-ItemProperty -LiteralPath $protocolPath -ErrorAction Stop).PSObject.Properties['URL Protocol']
    if ($null -eq $urlProtocol) {
        throw 'Installed sprache:// protocol is missing the URL Protocol marker.'
    }

    $supportedTypesPath = Join-Path $script:spracheClassesRoot 'Applications\sprache.exe\SupportedTypes'
    if (-not (Test-Path -LiteralPath $supportedTypesPath)) {
        throw "Installed SupportedTypes key is missing: $supportedTypesPath"
    }
    $supportedTypes = Get-Item -LiteralPath $supportedTypesPath -ErrorAction Stop
    $supportedTypeNames = @($supportedTypes.GetValueNames())
    foreach ($extension in $script:spracheImportExtensions) {
        $openWithPath = Join-Path $script:spracheClassesRoot "$extension\OpenWithProgids"
        $openWith = Get-Item -LiteralPath $openWithPath -ErrorAction Stop
        if (@($openWith.GetValueNames()) -notcontains $script:spracheFileProgramId) {
            throw "$extension is missing the Sprache OpenWithProgids registration."
        }
        if ($openWith.GetValueKind($script:spracheFileProgramId) -ne
            [Microsoft.Win32.RegistryValueKind]::String -or
            [string]$openWith.GetValue($script:spracheFileProgramId) -ne '') {
            throw "$extension has an invalid Sprache OpenWithProgids registration."
        }
        if ($supportedTypeNames -notcontains $extension) {
            throw "$extension is missing from Sprache SupportedTypes."
        }
        if ($supportedTypes.GetValueKind($extension) -ne
            [Microsoft.Win32.RegistryValueKind]::String -or
            [string]$supportedTypes.GetValue($extension) -ne '') {
            throw "$extension has an invalid Sprache SupportedTypes registration."
        }
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $repoRoot 'apps\client\pubspec.yaml'
if ([string]::IsNullOrWhiteSpace($Version)) {
    $versionMatch = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*(?<name>\d+\.\d+\.\d+)\+\d+\s*$' |
        Select-Object -First 1
    if ($null -eq $versionMatch) {
        throw "Could not read release version from $pubspecPath"
    }
    $Version = $versionMatch.Matches[0].Groups['name'].Value
}
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Installer version must use major.minor.patch: $Version"
}

if ([string]::IsNullOrWhiteSpace($InstallerPath)) {
    $InstallerPath = Join-Path $repoRoot "artifacts\Sprache-Windows-Setup-$Version-google-x64.exe"
}
$installer = [IO.Path]::GetFullPath($InstallerPath)
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
    throw "Windows installer not found: $installer"
}

$outputsRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot 'outputs'))
$installDir = [IO.Path]::GetFullPath(
    (Join-Path $outputsRoot "installer-smoke-$Version-$PID\Sprache")
)
$allowedPrefix = $outputsRoot + [IO.Path]::DirectorySeparatorChar
if (-not $installDir.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe installer smoke target: $installDir"
}
if (Test-Path -LiteralPath $installDir) {
    throw "Installer smoke target already exists: $installDir"
}

$existingInstallations = @(Get-SpracheInstallations)
if (@($existingInstallations).Count -gt 0) {
    $installationSummary = $existingInstallations |
        ForEach-Object {
            "$($_.DisplayName) $($_.DisplayVersion) at $($_.InstallLocation)"
        }
    throw "A registered Sprache installation already exists. Refusing to replace its uninstall registration during the smoke test: $($installationSummary -join '; ')"
}
$existingAssociationResidues = @(Get-SpracheAssociationResidues)
if ($existingAssociationResidues.Count -gt 0) {
    throw "Sprache file associations already exist. Refusing a destructive smoke test: $($existingAssociationResidues -join '; ')"
}
$defaultInstallDirectory = Join-Path $env:LOCALAPPDATA 'Programs\Sprache'
$orphanedInstallationFiles = @(
    (Join-Path $defaultInstallDirectory 'sprache.exe'),
    (Join-Path $defaultInstallDirectory 'unins000.exe')
) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
if (@($orphanedInstallationFiles).Count -gt 0) {
    throw "Sprache installation files exist without a detected uninstall registration. Refusing a destructive smoke test: $defaultInstallDirectory"
}
$runningSprache = @(Get-Process -Name 'sprache' -ErrorAction SilentlyContinue)
if ($runningSprache.Count -gt 0) {
    throw 'A Sprache process is running. Close it before running the installer smoke test.'
}

New-Item -ItemType Directory -Path $outputsRoot -Force | Out-Null
$logPath = Join-Path $outputsRoot "installer-smoke-$Version-$PID.log"
$installedExe = Join-Path $installDir 'sprache.exe'
$installedAppSo = Join-Path $installDir 'data\app.so'
$uninstaller = Join-Path $installDir 'unins000.exe'
$installProcess = $null
$appProcess = $null
$runtimeResult = $null
$uninstallExitCode = $null
$operationError = ''
$cleanupError = ''
try {
    $installProcess = Start-Process -FilePath $installer -ArgumentList @(
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/SP-',
        '/CURRENTUSER',
        '/TASKS=""',
        "/DIR=$installDir",
        "/LOG=$logPath"
    ) -Wait -PassThru -WindowStyle Hidden
    if ($installProcess.ExitCode -ne 0) {
        throw "Installer exited with code $($installProcess.ExitCode)"
    }

    foreach ($requiredPath in @($installedExe, $installedAppSo, $uninstaller)) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "Installed file is missing: $requiredPath"
        }
    }
    if ($ForceFailureAfterInstall) {
        throw 'Forced smoke failure after install for cleanup verification.'
    }

    $appProcess = Start-Process -FilePath $installedExe -WorkingDirectory $installDir -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds $StartupWaitSeconds
    $appProcess.Refresh()
    if ($appProcess.HasExited) {
        throw "Installed Sprache exited early with code $($appProcess.ExitCode)"
    }
    if ($appProcess.MainWindowTitle -ne 'Sprache') {
        throw "Installed Sprache has unexpected window title: '$($appProcess.MainWindowTitle)'"
    }
    $runtimeResult = [pscustomobject]@{
        Installer = $installer
        InstallExitCode = $installProcess.ExitCode
        InstalledExe = $installedExe
        Responding = $appProcess.Responding
        MainWindowHandle = $appProcess.MainWindowHandle
        MainWindowTitle = $appProcess.MainWindowTitle
        WorkingSetMB = [math]::Round($appProcess.WorkingSet64 / 1MB, 1)
    }
    Assert-SpracheAssociationsInstalled -ExpectedExecutable $installedExe
    if (-not [string]::IsNullOrWhiteSpace($RuntimeEvidencePath)) {
        Stop-Process -Id $appProcess.Id -ErrorAction Stop
        $appProcess.WaitForExit(5000) | Out-Null
        & (Join-Path $PSScriptRoot 'verify-windows-runtime.ps1') `
            -ExePath $installedExe `
            -OutputDirectory $RuntimeCaptureDirectory `
            -RuntimeEvidencePath $RuntimeEvidencePath `
            -Version $Version `
            -Mode $RuntimeMode `
            -CapturePixels
    }
}
catch {
    $operationError = $_.Exception.Message
}
finally {
    if ($null -ne $appProcess -and -not $appProcess.HasExited) {
        try {
            Stop-Process -Id $appProcess.Id -ErrorAction Stop
            $appProcess.WaitForExit(5000) | Out-Null
        }
        catch {
            $cleanupError = "Could not stop the smoke-test app: $($_.Exception.Message)"
        }
    }

    if (Test-Path -LiteralPath $uninstaller -PathType Leaf) {
        try {
            $uninstallProcess = Start-Process -FilePath $uninstaller -ArgumentList @(
                '/VERYSILENT',
                '/SUPPRESSMSGBOXES',
                '/NORESTART'
            ) -Wait -PassThru -WindowStyle Hidden
            $uninstallExitCode = $uninstallProcess.ExitCode
            if ($uninstallExitCode -ne 0) {
                throw "Uninstaller exited with code $uninstallExitCode"
            }

            for ($attempt = 0; $attempt -lt 10 -and
                (Test-Path -LiteralPath $installDir); $attempt++) {
                Start-Sleep -Seconds 1
            }
            if (Test-Path -LiteralPath $installDir) {
                throw "Installer smoke directory remained after uninstall: $installDir"
            }
        }
        catch {
            $uninstallMessage = $_.Exception.Message
            if ([string]::IsNullOrWhiteSpace($cleanupError)) {
                $cleanupError = $uninstallMessage
            }
            else {
                $cleanupError = "$cleanupError; $uninstallMessage"
            }
        }
    }
    elseif (Test-Path -LiteralPath $installDir) {
        $missingUninstallerMessage = "Smoke-test files exist without an uninstaller: $installDir"
        if ([string]::IsNullOrWhiteSpace($cleanupError)) {
            $cleanupError = $missingUninstallerMessage
        }
        else {
            $cleanupError = "$cleanupError; $missingUninstallerMessage"
        }
    }
}

$registryEntries = @(Get-SpracheInstallations)
$registryEntryCount = @($registryEntries).Count
if ($registryEntryCount -ne 0) {
    $registryMessage = "Installer smoke left $registryEntryCount uninstall registry entries."
    if ([string]::IsNullOrWhiteSpace($cleanupError)) {
        $cleanupError = $registryMessage
    }
    else {
        $cleanupError = "$cleanupError; $registryMessage"
    }
}
$associationResidues = @(Get-SpracheAssociationResidues)
if ($associationResidues.Count -ne 0) {
    $associationMessage = "Installer smoke left file association entries: $($associationResidues -join '; ')"
    if ([string]::IsNullOrWhiteSpace($cleanupError)) {
        $cleanupError = $associationMessage
    }
    else {
        $cleanupError = "$cleanupError; $associationMessage"
    }
}

if (-not [string]::IsNullOrWhiteSpace($operationError)) {
    if (-not [string]::IsNullOrWhiteSpace($cleanupError)) {
        throw "$operationError Cleanup also failed: $cleanupError"
    }
    throw $operationError
}
if (-not [string]::IsNullOrWhiteSpace($cleanupError)) {
    throw $cleanupError
}

$runtimeResult
[pscustomobject]@{
    UninstallExitCode = $uninstallExitCode
    InstallDirectoryRemoved = $true
    UninstallRegistryEntries = $registryEntryCount
    FileAssociationEntries = @($associationResidues).Count
    InstallLog = $logPath
}
