param(
    [ValidateSet('all', 'android', 'windows')]
    [string]$Target = 'all',
    [string]$FlutterPath = "$env:LOCALAPPDATA\Programs\flutter\bin\flutter.bat",
    [string]$AndroidClientId = '1054343487948-v3u90fo5nmbrk4hn7ss2gnrg601phkuv.apps.googleusercontent.com',
    [string]$ServerClientId = '1054343487948-g6b3fp20ooq86agro7nsb129oqr9df82.apps.googleusercontent.com',
    [string]$DesktopClientId = '1054343487948-o7nkfj4qmiilacvbln7alfgqrced6ior.apps.googleusercontent.com',
    [string]$PrivacyPolicyUrl = $(if ([string]::IsNullOrWhiteSpace($env:SPRACHE_PRIVACY_POLICY_URL)) {
        'https://youkdonghun.github.io/Sprache/privacy/'
    } else {
        $env:SPRACHE_PRIVACY_POLICY_URL
    }),
    [string]$InnoSetupPath = '',
    [string]$WindowsSigningThumbprint = $env:SPRACHE_WINDOWS_SIGNING_THUMBPRINT,
    [string]$WindowsTimestampUrl = 'https://timestamp.digicert.com',
    [string]$SignToolPath = '',
    [switch]$RequirePrivacyPolicyUrl,
    [switch]$RequireAndroidReleaseSigning,
    [switch]$RequireWindowsCodeSigning,
    [switch]$InternalAndroidStagingBuild,
    [switch]$InternalWindowsStagingBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-PathInside {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Candidate,
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $candidatePath = [IO.Path]::GetFullPath($Candidate).TrimEnd('\', '/')
    $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    if ($candidatePath.Equals($rootPath, [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    $rootPrefix = $rootPath + [IO.Path]::DirectorySeparatorChar
    return $candidatePath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-AsciiPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    foreach ($character in $Path.ToCharArray()) {
        if ([int]$character -gt 127) {
            throw "$Label must contain ASCII characters only: $Path"
        }
    }
}

function Assert-NoReparsePoints {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Boundary,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $candidatePath = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $boundaryPath = [IO.Path]::GetFullPath($Boundary).TrimEnd('\', '/')
    if (-not (Test-PathInside -Candidate $candidatePath -Root $boundaryPath)) {
        throw "$Label escaped its approved boundary: $candidatePath"
    }

    $currentPath = $candidatePath
    while ($true) {
        if (-not (Test-Path -LiteralPath $currentPath)) {
            throw "$Label contains a missing path component: $currentPath"
        }
        $currentItem = Get-Item -LiteralPath $currentPath -Force
        if (($currentItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Label contains a reparse point: $currentPath"
        }
        if ($currentPath.Equals($boundaryPath, [StringComparison]::OrdinalIgnoreCase)) {
            break
        }

        $parentPath = [IO.Path]::GetFullPath((Split-Path -Parent $currentPath)).TrimEnd('\', '/')
        if ($parentPath.Equals($currentPath, [StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-PathInside -Candidate $parentPath -Root $boundaryPath)) {
            throw "$Label could not be traced safely to its approved boundary: $candidatePath"
        }
        $currentPath = $parentPath
    }
}

function Resolve-GitExecutable {
    $gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($null -ne $gitCommand -and
        (Test-Path -LiteralPath $gitCommand.Source -PathType Leaf)) {
        return $gitCommand.Source
    }

    $gitCandidates = @(
        (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'),
        $(if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) {
            Join-Path ${env:ProgramFiles(x86)} 'Git\cmd\git.exe'
        }),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe')
    )
    foreach ($candidate in $gitCandidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and
            (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return [IO.Path]::GetFullPath($candidate)
        }
    }
    throw 'Git executable was not found. Git is required to stage tracked and untracked working-tree files.'
}

function Copy-WorkingTreeToAndroidStaging {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,
        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot,
        [ValidateSet('Android', 'Windows')]
        [string]$Platform = 'Android'
    )

    $sourcePath = [IO.Path]::GetFullPath($SourceRoot)
    $destinationPath = [IO.Path]::GetFullPath($DestinationRoot)
    if (Test-PathInside -Candidate $destinationPath -Root $sourcePath) {
        throw "$Platform staging must not be inside the repository: $destinationPath"
    }
    if (Test-PathInside -Candidate $sourcePath -Root $destinationPath) {
        throw "Repository must not be inside $Platform staging: $sourcePath"
    }
    if (Test-Path -LiteralPath $destinationPath) {
        throw "$Platform staging path already exists and will not be overwritten: $destinationPath"
    }

    $git = Resolve-GitExecutable
    [string]$gitFileList = & $git -C $sourcePath ls-files -z --cached --others --exclude-standard
    if ($LASTEXITCODE -ne 0) {
        throw "Could not enumerate the Git working tree (exit code $LASTEXITCODE)."
    }
    $relativeFiles = @($gitFileList -split [char]0 | Where-Object { $_.Length -gt 0 })
    # Flutter regenerates local.properties, but these ignored wrapper files are
    # needed before Gradle can start in a clean working-tree copy.
    foreach ($androidBootstrapFile in @(
        'apps/client/android/gradlew',
        'apps/client/android/gradlew.bat',
        'apps/client/android/gradle/wrapper/gradle-wrapper.jar',
        'apps/client/android/local.properties'
    )) {
        if ((Test-Path -LiteralPath (Join-Path $sourcePath $androidBootstrapFile) -PathType Leaf) -and
            $androidBootstrapFile -notin $relativeFiles) {
            $relativeFiles += $androidBootstrapFile
        }
    }
    if ($relativeFiles.Count -eq 0) {
        throw "Git did not return any files to stage from $sourcePath"
    }

    New-Item -ItemType Directory -Path $destinationPath | Out-Null
    $excludedSegments = @('.git', 'build', 'node_modules', 'artifacts')
    $copiedCount = 0
    foreach ($relativeFile in $relativeFiles) {
        $normalizedRelative = $relativeFile.Replace('\', '/')
        if ([IO.Path]::IsPathRooted($normalizedRelative)) {
            throw "Git returned an absolute path, refusing to stage it: $relativeFile"
        }
        $segments = @($normalizedRelative.Split('/'))
        $unsafeSegments = @(
            $segments | Where-Object {
                [string]::IsNullOrWhiteSpace($_) -or $_ -in @('.', '..')
            }
        )
        if ($segments.Count -eq 0 -or $unsafeSegments.Count -gt 0) {
            throw "Git returned an unsafe relative path: $relativeFile"
        }
        $excludedMatches = @($segments | Where-Object { $_ -in $excludedSegments })
        if ($excludedMatches.Count -gt 0) {
            continue
        }

        $nativeRelative = $normalizedRelative.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $sourceFile = [IO.Path]::GetFullPath((Join-Path $sourcePath $nativeRelative))
        $destinationFile = [IO.Path]::GetFullPath((Join-Path $destinationPath $nativeRelative))
        if (-not (Test-PathInside -Candidate $sourceFile -Root $sourcePath)) {
            throw "Source file escaped the repository: $sourceFile"
        }
        if (-not (Test-PathInside -Candidate $destinationFile -Root $destinationPath)) {
            throw "Destination file escaped $Platform staging: $destinationFile"
        }
        Assert-NoReparsePoints `
            -Path (Split-Path -Parent $sourceFile) `
            -Boundary $sourcePath `
            -Label "$Platform staging source path"
        if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
            # Deleted tracked files are intentionally absent from the staged working tree.
            if (-not (Test-Path -LiteralPath $sourceFile)) {
                continue
            }
            throw "Only regular working-tree files can be staged: $sourceFile"
        }
        $sourceItem = Get-Item -LiteralPath $sourceFile -Force
        if (($sourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing to follow a reparse point while staging: $sourceFile"
        }

        $destinationDirectory = Split-Path -Parent $destinationFile
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        Assert-NoReparsePoints `
            -Path $destinationDirectory `
            -Boundary $destinationPath `
            -Label "$Platform staging destination path"
        Copy-Item -LiteralPath $sourceFile -Destination $destinationFile
        $copiedCount++
    }
    if ($copiedCount -eq 0) {
        throw "No working-tree files were copied to $Platform staging: $destinationPath"
    }
    Write-Host "$Platform ASCII staging copied $copiedCount files to $destinationPath"
}

function Copy-VerifiedArtifact {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,
        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $source = [IO.Path]::GetFullPath($SourcePath)
    $destination = [IO.Path]::GetFullPath($DestinationPath)
    $approvedSourceRoot = [IO.Path]::GetFullPath($SourceRoot)
    $approvedDestinationRoot = [IO.Path]::GetFullPath($DestinationRoot)
    if (-not (Test-PathInside -Candidate $source -Root $approvedSourceRoot) -or
        $source.Equals($approvedSourceRoot, [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-PathInside -Candidate $destination -Root $approvedDestinationRoot) -or
        $destination.Equals($approvedDestinationRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label transfer paths failed containment validation."
    }
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "$Label was not produced: $source"
    }
    $sourceItem = Get-Item -LiteralPath $source -Force
    if ($sourceItem.Length -le 0) {
        throw "$Label is empty: $source"
    }
    if (($sourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "$Label source must not be a reparse point: $source"
    }

    $destinationDirectory = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
        throw "$Label destination directory was not found: $destinationDirectory"
    }
    $transferPath = Join-Path $destinationDirectory ".$([IO.Path]::GetFileName($destination)).transfer-$PID.tmp"
    if (Test-Path -LiteralPath $transferPath) {
        throw "$Label transfer path already exists: $transferPath"
    }

    try {
        Copy-Item -LiteralPath $source -Destination $transferPath
        $transferItem = Get-Item -LiteralPath $transferPath
        if ($transferItem.Length -ne $sourceItem.Length) {
            throw "$Label transfer size verification failed."
        }
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $transferHash = (Get-FileHash -LiteralPath $transferPath -Algorithm SHA256).Hash
        if (-not $sourceHash.Equals($transferHash, [StringComparison]::OrdinalIgnoreCase)) {
            throw "$Label transfer checksum verification failed."
        }
        Move-Item -LiteralPath $transferPath -Destination $destination -Force
        $destinationItem = Get-Item -LiteralPath $destination
        $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        if ($destinationItem.Length -ne $sourceItem.Length -or
            -not $sourceHash.Equals($destinationHash, [StringComparison]::OrdinalIgnoreCase)) {
            throw "$Label destination verification failed."
        }
        Write-Host "$Label copied and SHA-256 verified: $destination"
    }
    finally {
        if (Test-Path -LiteralPath $transferPath -PathType Leaf) {
            Remove-Item -LiteralPath $transferPath -Force
        }
    }
}

function Stop-AndroidGradleDaemonBestEffort {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClientRoot,
        [ValidateRange(1000, 60000)]
        [int]$TimeoutMilliseconds = 15000
    )

    $androidRoot = Join-Path ([IO.Path]::GetFullPath($ClientRoot)) 'android'
    $gradleWrapper = Join-Path $androidRoot 'gradlew.bat'
    if (-not (Test-Path -LiteralPath $gradleWrapper -PathType Leaf)) {
        Write-Warning "Gradle daemon stop was skipped because the wrapper was not found: $gradleWrapper"
        return
    }

    $stopProcess = $null
    try {
        $stopProcess = Start-Process `
            -FilePath $gradleWrapper `
            -ArgumentList '--stop' `
            -WorkingDirectory $androidRoot `
            -WindowStyle Hidden `
            -PassThru
        if (-not $stopProcess.WaitForExit($TimeoutMilliseconds)) {
            Stop-Process -Id $stopProcess.Id -Force -ErrorAction SilentlyContinue
            Write-Warning "Gradle daemon stop timed out after $TimeoutMilliseconds ms."
            return
        }
        if ($stopProcess.ExitCode -ne 0) {
            Write-Warning "Gradle daemon stop exited with code $($stopProcess.ExitCode)."
            return
        }
        Write-Host 'Gradle daemon stop completed.'
    }
    catch {
        Write-Warning "Gradle daemon stop could not be completed: $($_.Exception.Message)"
    }
    finally {
        if ($null -ne $stopProcess) {
            $stopProcess.Dispose()
        }
    }
}

function Remove-VerifiedAndroidStaging {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StagingRoot,
        [Parameter(Mandatory = $true)]
        [string]$StagingBase,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedLeaf,
        [ValidateRange(1, 20)]
        [int]$MaxAttempts = 8,
        [ValidateRange(50, 10000)]
        [int]$RetryDelayMilliseconds = 1500,
        [ValidateSet('Android', 'Windows')]
        [string]$Platform = 'Android'
    )

    $stagingPath = [IO.Path]::GetFullPath($StagingRoot)
    $basePath = [IO.Path]::GetFullPath($StagingBase)
    if (-not (Test-PathInside -Candidate $stagingPath -Root $basePath) -or
        $stagingPath.Equals($basePath, [StringComparison]::OrdinalIgnoreCase) -or
        -not (Split-Path -Leaf $stagingPath).Equals($ExpectedLeaf, [StringComparison]::Ordinal)) {
        throw "Refusing to remove an unverified $Platform staging path: $stagingPath"
    }
    if (-not (Test-Path -LiteralPath $stagingPath)) {
        return $true
    }

    $lastFailure = $null
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if (-not (Test-Path -LiteralPath $stagingPath)) {
            return $true
        }
        if (-not (Test-Path -LiteralPath $stagingPath -PathType Container)) {
            throw "$Platform staging cleanup target is not a directory: $stagingPath"
        }
        Assert-NoReparsePoints `
            -Path $stagingPath `
            -Boundary $basePath `
            -Label "$Platform staging cleanup path"
        try {
            Remove-Item `
                -LiteralPath $stagingPath `
                -Recurse `
                -Force `
                -ErrorAction Stop
            if (-not (Test-Path -LiteralPath $stagingPath)) {
                return $true
            }
            $lastFailure = 'the staging directory still exists after Remove-Item returned'
        }
        catch {
            $lastFailure = $_.Exception.Message
        }

        if ($attempt -lt $MaxAttempts) {
            Write-Warning "$Platform staging cleanup attempt $attempt/$MaxAttempts failed; retrying in $RetryDelayMilliseconds ms. $lastFailure"
            Start-Sleep -Milliseconds $RetryDelayMilliseconds
        }
    }

    Write-Warning "$Platform staging cleanup exhausted $MaxAttempts attempts. $lastFailure"
    return $false
}

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$clientRoot = Join-Path $repoRoot 'apps\client'
$artifactsRoot = Join-Path $repoRoot 'artifacts'
$pubspecPath = Join-Path $clientRoot 'pubspec.yaml'
$versionMatch = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*(?<name>\d+\.\d+\.\d+)\+(?<build>\d+)\s*$' |
    Select-Object -First 1
if ($null -eq $versionMatch) {
    throw "Could not read release version from $pubspecPath"
}
$releaseVersion = $versionMatch.Matches[0].Groups['name'].Value
$releaseBuildNumber = [int]$versionMatch.Matches[0].Groups['build'].Value
$isWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$androidRequested = $Target -in @('all', 'android')
$windowsRequested = $Target -in @('all', 'windows')
$androidStagingMarkerName = 'SPRACHE_ANDROID_ASCII_STAGING_ROOT'
$androidStagingMarker = [Environment]::GetEnvironmentVariable($androidStagingMarkerName, 'Process')
$windowsStagingMarkerName = 'SPRACHE_WINDOWS_ASCII_STAGING_ROOT'
$windowsStagingMarker = [Environment]::GetEnvironmentVariable($windowsStagingMarkerName, 'Process')
$windowsStagingBaseName = 'SW'

if ($InternalAndroidStagingBuild -and $InternalWindowsStagingBuild) {
    throw 'Android and Windows internal staging modes cannot be enabled together.'
}

if ($InternalAndroidStagingBuild) {
    if (-not $isWindowsHost -or $Target -ne 'android') {
        throw 'Internal Android staging mode is only valid for an Android-only build on Windows.'
    }
    if ([string]::IsNullOrWhiteSpace($androidStagingMarker)) {
        throw "Internal Android staging mode requires the $androidStagingMarkerName process marker."
    }
    $markedStagingRoot = [IO.Path]::GetFullPath($androidStagingMarker)
    if (-not $repoRoot.Equals($markedStagingRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Internal Android staging marker does not match the staged repository: $markedStagingRoot"
    }
    $internalLocalAppData = [Environment]::GetEnvironmentVariable('LOCALAPPDATA', 'Process')
    if ([string]::IsNullOrWhiteSpace($internalLocalAppData) -or
        -not [IO.Path]::IsPathRooted($internalLocalAppData)) {
        throw 'Internal Android staging requires an absolute LOCALAPPDATA path.'
    }
    $expectedInternalStagingBase = [IO.Path]::GetFullPath(
        (Join-Path $internalLocalAppData 'SpracheBuild')
    )
    if (-not (Test-PathInside -Candidate $repoRoot -Root $expectedInternalStagingBase) -or
        $repoRoot.Equals($expectedInternalStagingBase, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Internal Android staging repository is outside the approved base: $repoRoot"
    }
    $expectedStagingName = '^android-' + [regex]::Escape($releaseVersion) + '-\d+$'
    if ((Split-Path -Leaf $repoRoot) -notmatch $expectedStagingName) {
        throw "Internal Android staging directory has an unexpected name: $repoRoot"
    }
    Assert-AsciiPath -Path $repoRoot -Label 'Android staging path'
}
elseif ($isWindowsHost -and $androidRequested -and
    -not [string]::IsNullOrWhiteSpace($androidStagingMarker)) {
    throw "Recursive Android staging was blocked because $androidStagingMarkerName is already set."
}

if ($InternalWindowsStagingBuild) {
    if (-not $isWindowsHost -or $Target -ne 'windows') {
        throw 'Internal Windows staging mode is only valid for a Windows-only build on Windows.'
    }
    if ([string]::IsNullOrWhiteSpace($windowsStagingMarker)) {
        throw "Internal Windows staging mode requires the $windowsStagingMarkerName process marker."
    }
    $markedWindowsStagingRoot = [IO.Path]::GetFullPath($windowsStagingMarker)
    if (-not $repoRoot.Equals($markedWindowsStagingRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Internal Windows staging marker does not match the staged repository: $markedWindowsStagingRoot"
    }
    $internalWindowsLocalAppData = [Environment]::GetEnvironmentVariable('LOCALAPPDATA', 'Process')
    if ([string]::IsNullOrWhiteSpace($internalWindowsLocalAppData) -or
        -not [IO.Path]::IsPathRooted($internalWindowsLocalAppData)) {
        throw 'Internal Windows staging requires an absolute LOCALAPPDATA path.'
    }
    $expectedWindowsStagingBase = [IO.Path]::GetFullPath(
        (Join-Path $internalWindowsLocalAppData $windowsStagingBaseName)
    )
    if (-not (Test-PathInside -Candidate $repoRoot -Root $expectedWindowsStagingBase) -or
        $repoRoot.Equals($expectedWindowsStagingBase, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Internal Windows staging repository is outside the approved base: $repoRoot"
    }
    $expectedWindowsStagingName = '^w-' + [regex]::Escape($releaseVersion) + '-\d+$'
    if ((Split-Path -Leaf $repoRoot) -notmatch $expectedWindowsStagingName) {
        throw "Internal Windows staging directory has an unexpected name: $repoRoot"
    }
    Assert-AsciiPath -Path $repoRoot -Label 'Windows staging path'
}
elseif ($isWindowsHost -and $windowsRequested -and
    -not [string]::IsNullOrWhiteSpace($windowsStagingMarker)) {
    throw "Recursive Windows staging was blocked because $windowsStagingMarkerName is already set."
}

if (-not (Test-Path -LiteralPath $FlutterPath -PathType Leaf)) {
    throw "Flutter executable not found: $FlutterPath"
}

foreach ($requiredValue in @{
    APP_VERSION = $releaseVersion
    GOOGLE_ANDROID_CLIENT_ID = $AndroidClientId
    GOOGLE_SERVER_CLIENT_ID = $ServerClientId
    GOOGLE_DESKTOP_CLIENT_ID = $DesktopClientId
}.GetEnumerator()) {
    if ([string]::IsNullOrWhiteSpace($requiredValue.Value)) {
        throw "Missing required build value: $($requiredValue.Key)"
    }
}
if (-not [string]::IsNullOrWhiteSpace($PrivacyPolicyUrl) -and
    -not $PrivacyPolicyUrl.StartsWith('https://', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'PRIVACY_POLICY_URL must use HTTPS when configured'
}
if ($RequirePrivacyPolicyUrl -and [string]::IsNullOrWhiteSpace($PrivacyPolicyUrl)) {
    throw 'A public HTTPS privacy policy URL is required for a publishable build.'
}

$androidSigningVariableNames = @(
    'SPRACHE_ANDROID_KEYSTORE_PATH',
    'SPRACHE_ANDROID_KEYSTORE_PASSWORD',
    'SPRACHE_ANDROID_KEY_ALIAS',
    'SPRACHE_ANDROID_KEY_PASSWORD'
)
$androidSigningValues = @{}
if ($Target -in @('all', 'android')) {
    foreach ($variableName in $androidSigningVariableNames) {
        $value = [Environment]::GetEnvironmentVariable($variableName)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $androidSigningValues[$variableName] = $value
        }
    }
}
$androidReleaseSigningConfigured =
    $androidSigningValues.Count -eq $androidSigningVariableNames.Count
if ($Target -in @('all', 'android') -and
    $androidSigningValues.Count -gt 0 -and
    -not $androidReleaseSigningConfigured) {
    $missingSigningValues = $androidSigningVariableNames |
        Where-Object { -not $androidSigningValues.ContainsKey($_) }
    throw "Android release signing is only partially configured. Missing: $($missingSigningValues -join ', ')"
}
if ($Target -in @('all', 'android') -and
    $RequireAndroidReleaseSigning -and
    -not $androidReleaseSigningConfigured) {
    throw 'Android release signing is required, but the four SPRACHE_ANDROID_* variables are not configured.'
}
if ($Target -in @('all', 'android') -and $androidReleaseSigningConfigured) {
    $keystorePath = $androidSigningValues['SPRACHE_ANDROID_KEYSTORE_PATH']
    if (-not [IO.Path]::IsPathRooted($keystorePath)) {
        throw 'SPRACHE_ANDROID_KEYSTORE_PATH must be an absolute path.'
    }
    if (-not (Test-Path -LiteralPath $keystorePath -PathType Leaf)) {
        throw "Android release keystore was not found: $keystorePath"
    }
}
$androidSigningLabel = if ($androidReleaseSigningConfigured) { 'release' } else { 'debug' }

New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null

if ($isWindowsHost -and $androidRequested -and -not $InternalAndroidStagingBuild) {
    $localAppDataValue = [Environment]::GetEnvironmentVariable('LOCALAPPDATA', 'Process')
    if ([string]::IsNullOrWhiteSpace($localAppDataValue) -or
        -not [IO.Path]::IsPathRooted($localAppDataValue)) {
        throw 'LOCALAPPDATA must be an absolute path before Android staging can be created.'
    }
    $localAppDataPath = [IO.Path]::GetFullPath($localAppDataValue)
    if (-not (Test-Path -LiteralPath $localAppDataPath -PathType Container)) {
        throw "LOCALAPPDATA directory was not found: $localAppDataPath"
    }
    $stagingBase = [IO.Path]::GetFullPath((Join-Path $localAppDataPath 'SpracheBuild'))
    Assert-AsciiPath -Path $stagingBase -Label 'Android staging base'
    if ((Test-PathInside -Candidate $stagingBase -Root $repoRoot) -or
        (Test-PathInside -Candidate $repoRoot -Root $stagingBase)) {
        throw "Android staging base and repository must be separate: $stagingBase"
    }
    New-Item -ItemType Directory -Path $stagingBase -Force | Out-Null
    $stagingBaseItem = Get-Item -LiteralPath $stagingBase -Force
    if (($stagingBaseItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Android staging base must not be a reparse point: $stagingBase"
    }

    $stagingLeaf = "android-$releaseVersion-$PID"
    $androidStagingRoot = [IO.Path]::GetFullPath((Join-Path $stagingBase $stagingLeaf))
    Assert-AsciiPath -Path $androidStagingRoot -Label 'Android staging path'
    $stagingSucceeded = $false
    $previousStagingMarker = $androidStagingMarker
    try {
        Copy-WorkingTreeToAndroidStaging `
            -SourceRoot $repoRoot `
            -DestinationRoot $androidStagingRoot
        $stagedBuildScript = Join-Path $androidStagingRoot 'tool\build-real.ps1'
        if (-not (Test-Path -LiteralPath $stagedBuildScript -PathType Leaf)) {
            throw "Staged Android build script was not copied: $stagedBuildScript"
        }

        [Environment]::SetEnvironmentVariable(
            $androidStagingMarkerName,
            $androidStagingRoot,
            'Process'
        )
        $stagedBuildParameters = @{
            Target = 'android'
            FlutterPath = $FlutterPath
            AndroidClientId = $AndroidClientId
            ServerClientId = $ServerClientId
            DesktopClientId = $DesktopClientId
            PrivacyPolicyUrl = $PrivacyPolicyUrl
            RequirePrivacyPolicyUrl = [bool]$RequirePrivacyPolicyUrl
            RequireAndroidReleaseSigning = [bool]$RequireAndroidReleaseSigning
            InternalAndroidStagingBuild = $true
        }
        try {
            & $stagedBuildScript @stagedBuildParameters
        }
        finally {
            Stop-AndroidGradleDaemonBestEffort `
                -ClientRoot (Join-Path $androidStagingRoot 'apps\client')
        }

        $stagedArtifactsRoot = Join-Path $androidStagingRoot 'artifacts'
        $apkName = "Sprache-Android-$releaseVersion-google-$androidSigningLabel-signed.apk"
        $stagedApk = [IO.Path]::GetFullPath((Join-Path $stagedArtifactsRoot $apkName))
        $apkTarget = [IO.Path]::GetFullPath((Join-Path $artifactsRoot $apkName))
        if (-not (Test-PathInside -Candidate $stagedApk -Root $stagedArtifactsRoot) -or
            -not (Test-PathInside -Candidate $apkTarget -Root $artifactsRoot)) {
            throw 'Android artifact transfer paths failed containment validation.'
        }
        if (-not (Test-Path -LiteralPath $stagedApk -PathType Leaf)) {
            throw "Staged Android APK was not produced: $stagedApk"
        }
        $stagedApkItem = Get-Item -LiteralPath $stagedApk
        if ($stagedApkItem.Length -le 0) {
            throw "Staged Android APK is empty: $stagedApk"
        }

        $transferPath = Join-Path $artifactsRoot ".$apkName.transfer-$PID.tmp"
        if (Test-Path -LiteralPath $transferPath) {
            throw "Android artifact transfer path already exists: $transferPath"
        }
        try {
            Copy-Item -LiteralPath $stagedApk -Destination $transferPath
            $transferItem = Get-Item -LiteralPath $transferPath
            if ($transferItem.Length -ne $stagedApkItem.Length) {
                throw 'Android APK transfer size verification failed.'
            }
            $stagedApkHash = (Get-FileHash -LiteralPath $stagedApk -Algorithm SHA256).Hash
            $transferHash = (Get-FileHash -LiteralPath $transferPath -Algorithm SHA256).Hash
            if (-not $stagedApkHash.Equals($transferHash, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'Android APK transfer checksum verification failed.'
            }
            Move-Item -LiteralPath $transferPath -Destination $apkTarget -Force
            Write-Host "Android APK copied and SHA-256 verified: $apkTarget"
        }
        finally {
            if (Test-Path -LiteralPath $transferPath -PathType Leaf) {
                Remove-Item -LiteralPath $transferPath -Force
            }
        }
        $stagingSucceeded = $true
    }
    finally {
        [Environment]::SetEnvironmentVariable(
            $androidStagingMarkerName,
            $previousStagingMarker,
            'Process'
        )
        if ($stagingSucceeded) {
            $cleanupSucceeded = $false
            try {
                $cleanupSucceeded = Remove-VerifiedAndroidStaging `
                    -StagingRoot $androidStagingRoot `
                    -StagingBase $stagingBase `
                    -ExpectedLeaf $stagingLeaf
            }
            catch {
                Write-Warning "Android staging cleanup was blocked safely: $($_.Exception.Message)"
            }
            if (-not $cleanupSucceeded) {
                Write-Warning "Android APK is already copied and verified. Staging remains only for diagnostics: $androidStagingRoot"
            }
        }
        else {
            Write-Warning "Android staging was preserved for diagnostics: $androidStagingRoot"
        }
    }
}

if ($isWindowsHost -and $windowsRequested -and -not $InternalWindowsStagingBuild) {
    $windowsLocalAppDataValue = [Environment]::GetEnvironmentVariable('LOCALAPPDATA', 'Process')
    if ([string]::IsNullOrWhiteSpace($windowsLocalAppDataValue) -or
        -not [IO.Path]::IsPathRooted($windowsLocalAppDataValue)) {
        throw 'LOCALAPPDATA must be an absolute path before Windows staging can be created.'
    }
    $windowsLocalAppDataPath = [IO.Path]::GetFullPath($windowsLocalAppDataValue)
    if (-not (Test-Path -LiteralPath $windowsLocalAppDataPath -PathType Container)) {
        throw "LOCALAPPDATA directory was not found: $windowsLocalAppDataPath"
    }
    # Keep the staging root deliberately short. Some MSBuild plugin tlog paths
    # still enforce MAX_PATH even when long paths are enabled system-wide.
    $windowsStagingBase = [IO.Path]::GetFullPath(
        (Join-Path $windowsLocalAppDataPath $windowsStagingBaseName)
    )
    Assert-AsciiPath -Path $windowsStagingBase -Label 'Windows staging base'
    if ((Test-PathInside -Candidate $windowsStagingBase -Root $repoRoot) -or
        (Test-PathInside -Candidate $repoRoot -Root $windowsStagingBase)) {
        throw "Windows staging base and repository must be separate: $windowsStagingBase"
    }
    New-Item -ItemType Directory -Path $windowsStagingBase -Force | Out-Null
    $windowsStagingBaseItem = Get-Item -LiteralPath $windowsStagingBase -Force
    if (($windowsStagingBaseItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Windows staging base must not be a reparse point: $windowsStagingBase"
    }

    $windowsStagingLeaf = "w-$releaseVersion-$PID"
    $windowsStagingRoot = [IO.Path]::GetFullPath(
        (Join-Path $windowsStagingBase $windowsStagingLeaf)
    )
    Assert-AsciiPath -Path $windowsStagingRoot -Label 'Windows staging path'
    $windowsStagingSucceeded = $false
    $previousWindowsStagingMarker = $windowsStagingMarker
    try {
        Copy-WorkingTreeToAndroidStaging `
            -SourceRoot $repoRoot `
            -DestinationRoot $windowsStagingRoot `
            -Platform 'Windows'
        $stagedWindowsBuildScript = Join-Path $windowsStagingRoot 'tool\build-real.ps1'
        if (-not (Test-Path -LiteralPath $stagedWindowsBuildScript -PathType Leaf)) {
            throw "Staged Windows build script was not copied: $stagedWindowsBuildScript"
        }

        [Environment]::SetEnvironmentVariable(
            $windowsStagingMarkerName,
            $windowsStagingRoot,
            'Process'
        )
        $stagedWindowsBuildParameters = @{
            Target = 'windows'
            FlutterPath = $FlutterPath
            AndroidClientId = $AndroidClientId
            ServerClientId = $ServerClientId
            DesktopClientId = $DesktopClientId
            PrivacyPolicyUrl = $PrivacyPolicyUrl
            InnoSetupPath = $InnoSetupPath
            WindowsSigningThumbprint = $WindowsSigningThumbprint
            WindowsTimestampUrl = $WindowsTimestampUrl
            SignToolPath = $SignToolPath
            RequirePrivacyPolicyUrl = [bool]$RequirePrivacyPolicyUrl
            RequireWindowsCodeSigning = [bool]$RequireWindowsCodeSigning
            InternalWindowsStagingBuild = $true
        }
        & $stagedWindowsBuildScript @stagedWindowsBuildParameters

        $stagedWindowsArtifactsRoot = [IO.Path]::GetFullPath(
            (Join-Path $windowsStagingRoot 'artifacts')
        )
        $windowsArtifacts = @(
            @{
                Name = "Sprache-Windows-$releaseVersion-google-x64.zip"
                Label = 'Windows ZIP'
            },
            @{
                Name = "Sprache-Windows-Setup-$releaseVersion-google-x64.exe"
                Label = 'Windows installer'
            },
            @{
                Name = "SHA256SUMS-$releaseVersion-google.txt"
                Label = 'Windows checksum manifest'
            }
        )
        foreach ($windowsArtifact in $windowsArtifacts) {
            Copy-VerifiedArtifact `
                -SourcePath (Join-Path $stagedWindowsArtifactsRoot $windowsArtifact.Name) `
                -DestinationPath (Join-Path $artifactsRoot $windowsArtifact.Name) `
                -SourceRoot $stagedWindowsArtifactsRoot `
                -DestinationRoot $artifactsRoot `
                -Label $windowsArtifact.Label
        }
        $windowsStagingSucceeded = $true
    }
    finally {
        [Environment]::SetEnvironmentVariable(
            $windowsStagingMarkerName,
            $previousWindowsStagingMarker,
            'Process'
        )
        if ($windowsStagingSucceeded) {
            $windowsCleanupSucceeded = $false
            try {
                $windowsCleanupSucceeded = Remove-VerifiedAndroidStaging `
                    -StagingRoot $windowsStagingRoot `
                    -StagingBase $windowsStagingBase `
                    -ExpectedLeaf $windowsStagingLeaf `
                    -Platform 'Windows'
            }
            catch {
                Write-Warning "Windows staging cleanup was blocked safely: $($_.Exception.Message)"
            }
            if (-not $windowsCleanupSucceeded) {
                Write-Warning "Windows artifacts are already copied and verified. Staging remains only for diagnostics: $windowsStagingRoot"
            }
        }
        else {
            Write-Warning "Windows staging was preserved for diagnostics: $windowsStagingRoot"
        }
    }
}

$runDirectAndroid = $androidRequested -and
    (-not $isWindowsHost -or $InternalAndroidStagingBuild)
$runDirectWindows = $windowsRequested -and
    (-not $isWindowsHost -or $InternalWindowsStagingBuild)
if ($runDirectAndroid -or $runDirectWindows) {
    Push-Location $clientRoot
    try {
        & $FlutterPath pub get
        if ($LASTEXITCODE -ne 0) {
            throw "flutter pub get failed with exit code $LASTEXITCODE"
        }

        if ($runDirectAndroid) {
            & $FlutterPath build apk --release `
                --dart-define=APP_ENV=production `
                --dart-define=ENABLE_MOCK_MODE=false `
                --dart-define="APP_VERSION=$releaseVersion" `
                --dart-define="PRIVACY_POLICY_URL=$PrivacyPolicyUrl" `
                --dart-define="GOOGLE_ANDROID_CLIENT_ID=$AndroidClientId" `
                --dart-define="GOOGLE_SERVER_CLIENT_ID=$ServerClientId"
            if ($LASTEXITCODE -ne 0) {
                throw "Android release build failed with exit code $LASTEXITCODE"
            }

            $apkSource = Join-Path $clientRoot 'build\app\outputs\flutter-apk\app-release.apk'
            $apkTarget = Join-Path $artifactsRoot "Sprache-Android-$releaseVersion-google-$androidSigningLabel-signed.apk"
            Copy-Item -LiteralPath $apkSource -Destination $apkTarget -Force
        }

        if ($runDirectWindows) {
            & $FlutterPath build windows --release `
                --dart-define=APP_ENV=production `
                --dart-define=ENABLE_MOCK_MODE=false `
                --dart-define=RELEASE_PROBE_MODE=REAL `
                --dart-define="APP_VERSION=$releaseVersion" `
                --dart-define="RELEASE_BUILD_NUMBER=$releaseBuildNumber" `
                --dart-define=RELEASE_PROBE_KIND=native-runtime `
                --dart-define="PRIVACY_POLICY_URL=$PrivacyPolicyUrl" `
                --dart-define="GOOGLE_DESKTOP_CLIENT_ID=$DesktopClientId"
            if ($LASTEXITCODE -ne 0) {
                throw "Windows release build failed with exit code $LASTEXITCODE"
            }

            $windowsRelease = Join-Path $clientRoot 'build\windows\x64\runner\Release'
            & (Join-Path $PSScriptRoot 'sign-windows-file.ps1') `
                -Path (Join-Path $windowsRelease 'sprache.exe') `
                -CertificateThumbprint $WindowsSigningThumbprint `
                -TimestampUrl $WindowsTimestampUrl `
                -SignToolPath $SignToolPath `
                -RequireSignature:$RequireWindowsCodeSigning

            $windowsTarget = Join-Path $artifactsRoot "Sprache-Windows-$releaseVersion-google-x64.zip"
            Compress-Archive -Path (Join-Path $windowsRelease '*') -DestinationPath $windowsTarget -CompressionLevel Optimal -Force

            & (Join-Path $PSScriptRoot 'build-windows-installer.ps1') `
                -Version $releaseVersion `
                -ReleaseDir $windowsRelease `
                -ArtifactsDir $artifactsRoot `
                -InnoSetupPath $InnoSetupPath `
                -WindowsSigningThumbprint $WindowsSigningThumbprint `
                -TimestampUrl $WindowsTimestampUrl `
                -SignToolPath $SignToolPath `
                -RequireWindowsCodeSigning:$RequireWindowsCodeSigning
        }
    }
    finally {
        Pop-Location
    }
}

$realArtifacts = Get-ChildItem -LiteralPath $artifactsRoot -File |
    Where-Object { $_.Name -like "Sprache-*-$releaseVersion-google-*" } |
    Sort-Object Name

$checksumLines = foreach ($artifact in $realArtifacts) {
    $hash = Get-FileHash -LiteralPath $artifact.FullName -Algorithm SHA256
    "$($hash.Hash.ToLowerInvariant())  $($artifact.Name)"
}

$checksumPath = Join-Path $artifactsRoot "SHA256SUMS-$releaseVersion-google.txt"
$checksumLines | Set-Content -LiteralPath $checksumPath -Encoding utf8

Write-Host 'Real-mode artifacts:'
$realArtifacts | ForEach-Object {
    Write-Host "  $($_.FullName)"
}
Write-Host "  $checksumPath"
