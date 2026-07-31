param(
    [string]$Version = '',
    [string]$InstallerPath = '',
    [ValidateRange(1, 60)]
    [int]$StartupWaitSeconds = 12,
    [switch]$ForceFailureAfterInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

$existingInstallations = Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue |
    Get-ItemProperty -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq 'Sprache' }
if (@($existingInstallations).Count -gt 0) {
    throw 'A registered Sprache installation already exists. Refusing to replace its uninstall registration during the smoke test.'
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

$registryEntries = Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue |
    Get-ItemProperty -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq 'Sprache' }
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
    InstallLog = $logPath
}
