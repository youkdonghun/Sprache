param(
  [string]$OutputDirectory = ".\artifacts\verification\windows-engine-runtime"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path $PSScriptRoot -Parent
$resolvedOutput = [System.IO.Path]::GetFullPath(
  (Join-Path $repositoryRoot $OutputDirectory)
)
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null
$portableOutput = $resolvedOutput.Replace("\", "/")

Push-Location $repositoryRoot
try {
  & node .\tool\run-flutter.mjs `
    test `
    integration_test/windows_runtime_ui_e2e_test.dart `
    -d windows `
    "--dart-define=WINDOWS_RUNTIME_VISUAL_OUTPUT=$portableOutput"
  if ($LASTEXITCODE -ne 0) {
    throw "Windows Flutter engine UI E2E failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}

Write-Output "Windows engine screenshots: $resolvedOutput"
