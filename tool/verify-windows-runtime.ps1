param(
  [string]$ExePath = ".\apps\client\build\windows\x64\runner\Release\sprache.exe",
  [string]$OutputDirectory = ".\artifacts\verification\windows-native-runtime",
  [string]$RuntimeEvidencePath = "",
  [string]$Version = "",
  [int]$BuildNumber = 0,
  [ValidateSet("REAL", "MOCK")]
  [string]$Mode = "REAL",
  [switch]$CapturePixels,
  [switch]$KeepRunning
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-AbsolutePath {
  param([Parameter(Mandatory = $true)][string]$PathValue)

  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return [System.IO.Path]::GetFullPath($PathValue)
  }
  return [System.IO.Path]::GetFullPath(
    (Join-Path -Path (Get-Location).Path -ChildPath $PathValue)
  )
}

$resolvedExe = (Resolve-Path -LiteralPath $ExePath).Path
$resolvedOutput = Resolve-AbsolutePath -PathValue $OutputDirectory
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null

$runtimeProbeEvidenceFileName = "sprache-runtime-evidence-v1.json"
$runtimeProbeFrameFileName = "sprache-runtime-frame-v1.png"
$resolvedEvidencePath = $null
$runtimeProbeEvidencePath = $null
$runtimeProbeFramePath = $null
if (-not [string]::IsNullOrWhiteSpace($RuntimeEvidencePath)) {
  if (-not $CapturePixels) {
    throw "RuntimeEvidencePath requires -CapturePixels to prove a rendered frame."
  }
  $resolvedEvidencePath = Resolve-AbsolutePath -PathValue $RuntimeEvidencePath
  $runtimeProbeDirectory = Join-Path $resolvedOutput "in-app-probe"
  $env:SPRACHE_ENABLE_RELEASE_PROBE = "1"
  $env:SPRACHE_RELEASE_PROBE_DIRECTORY = $runtimeProbeDirectory
  $runtimeProbeEvidencePath = Join-Path `
    $runtimeProbeDirectory `
    $runtimeProbeEvidenceFileName
  $runtimeProbeFramePath = Join-Path `
    $runtimeProbeDirectory `
    $runtimeProbeFrameFileName
  foreach ($staleProbeFile in @(
    $runtimeProbeEvidencePath,
    $runtimeProbeFramePath
  )) {
    if (Test-Path -LiteralPath $staleProbeFile -PathType Leaf) {
      Remove-Item -LiteralPath $staleProbeFile -Force
    }
  }
  $repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
  $pubspecPath = Join-Path $repoRoot "apps\client\pubspec.yaml"
  $versionMatch = Select-String `
    -LiteralPath $pubspecPath `
    -Pattern '^version:\s*(?<name>\d+\.\d+\.\d+)\+(?<code>\d+)\s*$' |
    Select-Object -First 1
  if ($null -eq $versionMatch) {
    throw "Could not read release version from $pubspecPath"
  }
  $pubspecVersion = $versionMatch.Matches[0].Groups["name"].Value
  $pubspecBuildNumber = [int]$versionMatch.Matches[0].Groups["code"].Value
  if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = $pubspecVersion
  }
  if ($BuildNumber -eq 0) {
    $BuildNumber = $pubspecBuildNumber
  }
  if ($Version -ne $pubspecVersion -or $BuildNumber -ne $pubspecBuildNumber) {
    throw (
      "Runtime evidence version $Version+$BuildNumber does not match " +
      "pubspec $pubspecVersion+$pubspecBuildNumber."
    )
  }
}

Add-Type -AssemblyName System.Drawing

if (-not ("SpracheWindowCapture.NativeMethods" -as [type])) {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace SpracheWindowCapture {
  [StructLayout(LayoutKind.Sequential)]
  public struct Rect {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
  }

  public static class NativeMethods {
    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetWindowRect(IntPtr hWnd, out Rect rect);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetClientRect(IntPtr hWnd, out Rect rect);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool MoveWindow(
      IntPtr hWnd,
      int x,
      int y,
      int width,
      int height,
      [MarshalAs(UnmanagedType.Bool)] bool repaint
    );

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ShowWindow(IntPtr hWnd, int command);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool PrintWindow(
      IntPtr hWnd,
      IntPtr destinationDeviceContext,
      uint flags
    );

    [DllImport("user32.dll")]
    public static extern IntPtr GetDC(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern int ReleaseDC(IntPtr hWnd, IntPtr deviceContext);

    [DllImport("gdi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool BitBlt(
      IntPtr destinationDeviceContext,
      int destinationX,
      int destinationY,
      int width,
      int height,
      IntPtr sourceDeviceContext,
      int sourceX,
      int sourceY,
      uint rasterOperation
    );

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetProcessDPIAware();
  }
}
"@
}

[SpracheWindowCapture.NativeMethods]::SetProcessDPIAware() | Out-Null

$targets = @(
  [pscustomobject]@{ Name = "minimum-380x520"; Width = 380; Height = 520 },
  [pscustomobject]@{ Name = "focus-420x640"; Width = 420; Height = 640 },
  [pscustomobject]@{ Name = "standard-1040x760"; Width = 1040; Height = 760 }
)

$startupStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$process = Start-Process `
  -FilePath $resolvedExe `
  -WorkingDirectory (Split-Path -Parent $resolvedExe) `
  -PassThru
$results = [System.Collections.Generic.List[object]]::new()
$firstFrameMillis = $null

try {
  $deadline = [DateTime]::UtcNow.AddSeconds(30)
  do {
    Start-Sleep -Milliseconds 250
    $process.Refresh()
  } while (
    $process.MainWindowHandle -eq [IntPtr]::Zero -and
    -not $process.HasExited -and
    [DateTime]::UtcNow -lt $deadline
  )

  if ($process.HasExited) {
    throw "Sprache exited before creating a main window. Exit code: $($process.ExitCode)"
  }
  if ($process.MainWindowHandle -eq [IntPtr]::Zero) {
    throw "Sprache did not create a main window within 30 seconds."
  }

  $windowHandle = $process.MainWindowHandle
  [SpracheWindowCapture.NativeMethods]::ShowWindow($windowHandle, 9) | Out-Null
  $startupDeadline = [DateTime]::UtcNow.AddSeconds(20)
  do {
    Start-Sleep -Milliseconds 500
    $process.Refresh()
  } while (
    (
      -not $process.Responding -or
      [string]::IsNullOrWhiteSpace($process.MainWindowTitle)
    ) -and
    -not $process.HasExited -and
    [DateTime]::UtcNow -lt $startupDeadline
  )
  if ($process.HasExited) {
    throw "Sprache exited during startup. Exit code: $($process.ExitCode)"
  }
  if (-not $process.Responding) {
    throw "Sprache did not become responsive within 20 seconds."
  }
  if ($process.MainWindowTitle -ne "Sprache") {
    throw (
      "Unexpected Sprache window title: '$($process.MainWindowTitle)'. " +
      "Expected 'Sprache'."
    )
  }
  Start-Sleep -Seconds 4

  $inAppEvidence = $null
  $runtimeFrameOutput = $null
  if ($null -ne $resolvedEvidencePath) {
    $probeDeadline = [DateTime]::UtcNow.AddSeconds(60)
    do {
      if ((Test-Path -LiteralPath $runtimeProbeEvidencePath -PathType Leaf) -and
          (Test-Path -LiteralPath $runtimeProbeFramePath -PathType Leaf)) {
        break
      }
      if ($process.HasExited) {
        throw "Sprache exited before publishing its in-app frame probe."
      }
      Start-Sleep -Milliseconds 250
      $process.Refresh()
    } while ([DateTime]::UtcNow -lt $probeDeadline)

    if (-not (Test-Path -LiteralPath $runtimeProbeEvidencePath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $runtimeProbeFramePath -PathType Leaf)) {
      throw "Sprache did not publish its in-app frame probe within 60 seconds."
    }

    $inAppEvidence = Get-Content `
      -LiteralPath $runtimeProbeEvidencePath `
      -Raw |
      ConvertFrom-Json
    if ($inAppEvidence.format -ne "sprache-runtime-evidence-v1" -or
        $inAppEvidence.platform -ne "windows" -or
        $inAppEvidence.mode -ne $Mode -or
        $inAppEvidence.version -ne $Version -or
        [int]$inAppEvidence.buildNumber -ne $BuildNumber -or
        $inAppEvidence.launched -ne $true -or
        $inAppEvidence.firstFrameRendered -ne $true -or
        $inAppEvidence.probe -ne "native-runtime") {
      throw "The in-app release probe metadata is invalid."
    }
    if ([string]$inAppEvidence.firstFrameMillis -notmatch '^\d+$') {
      throw "The in-app firstFrameMillis value is invalid."
    }
    $firstFrameMillis = [int]$inAppEvidence.firstFrameMillis
    if ($firstFrameMillis -lt 0 -or $firstFrameMillis -gt 60000) {
      throw "The in-app first frame was not rendered within 60 seconds."
    }
    if ($inAppEvidence.frameFile -ne $runtimeProbeFrameFileName -or
        [string]$inAppEvidence.frameSha256 -notmatch '^[0-9a-f]{64}$') {
      throw "The in-app frame file metadata is invalid."
    }
    $actualFrameSha256 = (
      Get-FileHash -LiteralPath $runtimeProbeFramePath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    if ($actualFrameSha256 -ne $inAppEvidence.frameSha256) {
      throw "The in-app frame SHA-256 does not match its evidence."
    }
    [byte[]]$pngSignature = Get-Content `
      -LiteralPath $runtimeProbeFramePath `
      -Encoding Byte `
      -TotalCount 8
    if ([BitConverter]::ToString($pngSignature) -ne '89-50-4E-47-0D-0A-1A-0A') {
      throw "The in-app frame is not a PNG image."
    }

    $evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
    New-Item -ItemType Directory -Force -Path $evidenceDirectory | Out-Null
    $runtimeFrameOutput = Join-Path `
      $evidenceDirectory `
      $runtimeProbeFrameFileName
    Copy-Item `
      -LiteralPath $runtimeProbeFramePath `
      -Destination $runtimeFrameOutput `
      -Force
    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText(
      $resolvedEvidencePath,
      (($inAppEvidence | ConvertTo-Json -Depth 4 -Compress) + "`n"),
      $utf8WithoutBom
    )
  }

  foreach ($target in $targets) {
    $moved = [SpracheWindowCapture.NativeMethods]::MoveWindow(
      $windowHandle,
      80,
      80,
      $target.Width,
      $target.Height,
      $true
    )
    if (-not $moved) {
      throw "MoveWindow failed for $($target.Name)."
    }

    [SpracheWindowCapture.NativeMethods]::SetForegroundWindow($windowHandle) |
      Out-Null
    $responsiveDeadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
      Start-Sleep -Milliseconds 500
      $process.Refresh()
    } while (
      -not $process.Responding -and
      -not $process.HasExited -and
      [DateTime]::UtcNow -lt $responsiveDeadline
    )

    if ($process.HasExited) {
      throw "Sprache exited at $($target.Name). Exit code: $($process.ExitCode)"
    }
    if (-not $process.Responding) {
      throw "Sprache stopped responding at $($target.Name)."
    }
    Start-Sleep -Milliseconds 750

    $windowRect = [SpracheWindowCapture.Rect]::new()
    $clientRect = [SpracheWindowCapture.Rect]::new()
    if (
      -not [SpracheWindowCapture.NativeMethods]::GetWindowRect(
        $windowHandle,
        [ref]$windowRect
      )
    ) {
      throw "GetWindowRect failed for $($target.Name)."
    }
    if (
      -not [SpracheWindowCapture.NativeMethods]::GetClientRect(
        $windowHandle,
        [ref]$clientRect
      )
    ) {
      throw "GetClientRect failed for $($target.Name)."
    }

    $capturedWidth = $windowRect.Right - $windowRect.Left
    $capturedHeight = $windowRect.Bottom - $windowRect.Top
    if ($capturedWidth -le 0 -or $capturedHeight -le 0) {
      throw "Sprache returned an invalid window rectangle for $($target.Name)."
    }

    $imagePath = $null
    $captureMethod = $null
    $visibleSampleRatio = $null
    if ($CapturePixels -and $null -ne $inAppEvidence) {
      $imagePath = $runtimeFrameOutput
      $captureMethod = "flutter-repaint-boundary"
    } elseif ($CapturePixels) {
      $imagePath = Join-Path $resolvedOutput "$($target.Name).png"
      $bitmap = [System.Drawing.Bitmap]::new($capturedWidth, $capturedHeight)
      $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
      try {
        $captureMethod = "CopyFromScreen"
        try {
          $graphics.CopyFromScreen(
            $windowRect.Left,
            $windowRect.Top,
            0,
            0,
            [System.Drawing.Size]::new($capturedWidth, $capturedHeight),
            [System.Drawing.CopyPixelOperation]::SourceCopy
          )
        } catch {
          throw (
            "Visible screen capture failed for $($target.Name): " +
            $_.Exception.Message
          )
        }

        $sampleCount = 0
        $visibleSampleCount = 0
        for ($x = 0; $x -lt $capturedWidth; $x += 8) {
          for ($y = 0; $y -lt $capturedHeight; $y += 8) {
            $pixel = $bitmap.GetPixel($x, $y)
            $sampleCount += 1
            if ($pixel.R -gt 18 -or $pixel.G -gt 18 -or $pixel.B -gt 18) {
              $visibleSampleCount += 1
            }
          }
        }
        $visibleSampleRatio = $visibleSampleCount / [double]$sampleCount
        if ($visibleSampleRatio -lt 0.2) {
          throw (
            "Captured pixels are mostly blank for $($target.Name): " +
            "$([Math]::Round($visibleSampleRatio, 3)) visible."
          )
        }

        if ($null -eq $firstFrameMillis) {
          $firstFrameMillis = $startupStopwatch.ElapsedMilliseconds
        }

        $bitmap.Save($imagePath, [System.Drawing.Imaging.ImageFormat]::Png)
      } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
      }
    }

    $results.Add(
      [pscustomobject]@{
        name = $target.Name
        requestedOuterWidth = $target.Width
        requestedOuterHeight = $target.Height
        actualOuterWidth = $capturedWidth
        actualOuterHeight = $capturedHeight
        clientWidth = $clientRect.Right - $clientRect.Left
        clientHeight = $clientRect.Bottom - $clientRect.Top
        responding = $process.Responding
        title = $process.MainWindowTitle
        captureMethod = $captureMethod
        visibleSampleRatio = if ($null -eq $visibleSampleRatio) {
          $null
        } else {
          [Math]::Round($visibleSampleRatio, 4)
        }
        image = $imagePath
      }
    )
  }

  $resultPath = Join-Path $resolvedOutput "runtime-window-sizes.json"
  $results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $resultPath -Encoding utf8
  $results | Format-Table -AutoSize
  Write-Output "Result: $resultPath"

  if (-not [string]::IsNullOrWhiteSpace($RuntimeEvidencePath)) {
    if ($null -eq $firstFrameMillis -or $firstFrameMillis -gt 60000) {
      throw "The in-app first frame was not captured within 60 seconds."
    }
    if ($null -eq $inAppEvidence -or
        -not (Test-Path -LiteralPath $resolvedEvidencePath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $runtimeFrameOutput -PathType Leaf)) {
      throw "The verified in-app runtime evidence pair is incomplete."
    }
    Write-Output "Runtime evidence: $resolvedEvidencePath"
    Write-Output "Runtime frame: $runtimeFrameOutput"
  }
} finally {
  if (-not $KeepRunning -and -not $process.HasExited) {
    $process.CloseMainWindow() | Out-Null
    if (-not $process.WaitForExit(5000)) {
      Stop-Process -Id $process.Id
    }
  }
}
