param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'
$appExecutable = Join-Path -Path $PSScriptRoot -ChildPath 'sprache.exe'
$classesRoot = 'HKCU:\Software\Classes'
$fileProgramId = 'Sprache.Import'
$extensions = @('.csv', '.tsv', '.xlsx', '.json', '.jsonl')

if ($Uninstall) {
  foreach ($extension in $extensions) {
    $openWithPath = Join-Path $classesRoot "$extension\OpenWithProgids"
    if (Test-Path -LiteralPath $openWithPath) {
      Remove-ItemProperty -LiteralPath $openWithPath -Name $fileProgramId -ErrorAction SilentlyContinue
    }
  }
  Remove-Item -LiteralPath (Join-Path $classesRoot $fileProgramId) -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath (Join-Path $classesRoot 'Applications\sprache.exe') -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath (Join-Path $classesRoot 'sprache') -Recurse -Force -ErrorAction SilentlyContinue
  Write-Host 'Sprache file associations were removed for the current user.'
  exit 0
}

if (-not (Test-Path -LiteralPath $appExecutable -PathType Leaf)) {
  throw "sprache.exe was not found beside this script: $appExecutable"
}

$programPath = Join-Path $classesRoot $fileProgramId
New-Item -Path $programPath -Force | Out-Null
Set-Item -LiteralPath $programPath -Value 'Sprache 학습 자료'
New-Item -Path (Join-Path $programPath 'DefaultIcon') -Force | Out-Null
Set-Item -LiteralPath (Join-Path $programPath 'DefaultIcon') -Value "`"$appExecutable`",0"
New-Item -Path (Join-Path $programPath 'shell\open\command') -Force | Out-Null
Set-Item -LiteralPath (Join-Path $programPath 'shell\open\command') -Value "`"$appExecutable`" `"%1`""

$applicationPath = Join-Path $classesRoot 'Applications\sprache.exe'
New-Item -Path (Join-Path $applicationPath 'SupportedTypes') -Force | Out-Null
New-Item -Path (Join-Path $applicationPath 'shell\open\command') -Force | Out-Null
Set-Item -LiteralPath (Join-Path $applicationPath 'shell\open\command') -Value "`"$appExecutable`" `"%1`""

foreach ($extension in $extensions) {
  $openWithPath = Join-Path $classesRoot "$extension\OpenWithProgids"
  New-Item -Path $openWithPath -Force | Out-Null
  New-ItemProperty -LiteralPath $openWithPath -Name $fileProgramId -PropertyType Binary -Value ([byte[]]@()) -Force | Out-Null
  New-ItemProperty -LiteralPath (Join-Path $applicationPath 'SupportedTypes') -Name $extension -PropertyType String -Value '' -Force | Out-Null
}

$protocolPath = Join-Path $classesRoot 'sprache'
New-Item -Path $protocolPath -Force | Out-Null
Set-Item -LiteralPath $protocolPath -Value 'URL:Sprache Protocol'
New-ItemProperty -LiteralPath $protocolPath -Name 'URL Protocol' -PropertyType String -Value '' -Force | Out-Null
New-Item -Path (Join-Path $protocolPath 'DefaultIcon') -Force | Out-Null
Set-Item -LiteralPath (Join-Path $protocolPath 'DefaultIcon') -Value "`"$appExecutable`",0"
New-Item -Path (Join-Path $protocolPath 'shell\open\command') -Force | Out-Null
Set-Item -LiteralPath (Join-Path $protocolPath 'shell\open\command') -Value "`"$appExecutable`" `"%1`""

Write-Host 'Sprache is available in Open with for CSV, TSV, XLSX, JSON, and JSONL files.'
Write-Host 'Existing default applications were not changed.'
