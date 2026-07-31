param(
  [string]$ExePath = ".\apps\client\build\windows\x64\runner\Release\sprache.exe",
  [string]$OutputDirectory = ".\artifacts\verification\windows-native-runtime",
  [switch]$CapturePixels,
  [switch]$KeepRunning
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$resolvedExe = (Resolve-Path -LiteralPath $ExePath).Path
$resolvedOutput = [System.IO.Path]::GetFullPath(
  (Join-Path (Get-Location) $OutputDirectory)
)
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null

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

$process = Start-Process -FilePath $resolvedExe -PassThru
$results = [System.Collections.Generic.List[object]]::new()

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
    $visibleSampleRatio = $null
    if ($CapturePixels) {
      $imagePath = Join-Path $resolvedOutput "$($target.Name).png"
      $bitmap = [System.Drawing.Bitmap]::new($capturedWidth, $capturedHeight)
      $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
      try {
        $deviceContext = $graphics.GetHdc()
        try {
          $screenDeviceContext =
            [SpracheWindowCapture.NativeMethods]::GetDC([IntPtr]::Zero)
          if ($screenDeviceContext -eq [IntPtr]::Zero) {
            throw "GetDC failed for $($target.Name)."
          }
          try {
            $captured = [SpracheWindowCapture.NativeMethods]::BitBlt(
              $deviceContext,
              0,
              0,
              $capturedWidth,
              $capturedHeight,
              $screenDeviceContext,
              $windowRect.Left,
              $windowRect.Top,
              0x40CC0020
            )
          } finally {
            [SpracheWindowCapture.NativeMethods]::ReleaseDC(
              [IntPtr]::Zero,
              $screenDeviceContext
            ) | Out-Null
          }
        } finally {
          $graphics.ReleaseHdc($deviceContext)
        }
        if (-not $captured) {
          throw "BitBlt failed for $($target.Name)."
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
} finally {
  if (-not $KeepRunning -and -not $process.HasExited) {
    $process.CloseMainWindow() | Out-Null
    if (-not $process.WaitForExit(5000)) {
      Stop-Process -Id $process.Id
    }
  }
}
