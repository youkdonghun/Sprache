Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$previousPath = [Environment]::GetEnvironmentVariable('Path', 'Process')
try {
    $nugetExe = Join-Path $env:LOCALAPPDATA 'Programs\nuget\nuget.exe'
    if (-not (Test-Path -LiteralPath $nugetExe -PathType Leaf)) {
        throw "NuGet is required for the Windows build but was not found: $nugetExe"
    }
    $gitExe = @(
        (Join-Path $env:ProgramFiles 'Git\cmd\git.exe')
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe')
        (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe')
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($gitExe)) {
        throw 'Git is required by Flutter but no supported Git installation was found.'
    }

    $pathEntries = $previousPath -split ';' |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $pathPrefix = @((Split-Path -Parent $nugetExe), (Split-Path -Parent $gitExe)) |
        Where-Object { $pathEntries -notcontains $_ } |
        Select-Object -Unique
    [Environment]::SetEnvironmentVariable(
        'Path',
        (@($pathPrefix) + @($pathEntries)) -join ';',
        'Process'
    )

    & (Join-Path $PSScriptRoot 'build-real.ps1') -Target windows
    if ($LASTEXITCODE -ne 0) {
        throw "Windows REAL build failed with exit code $LASTEXITCODE"
    }
}
finally {
    [Environment]::SetEnvironmentVariable('Path', $previousPath, 'Process')
}
