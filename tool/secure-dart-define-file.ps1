function New-SpracheSecureDartDefineFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Values
    )

    $path = Join-Path `
        ([System.IO.Path]::GetTempPath()) `
        ("sprache-dart-defines-{0}-{1}.json" -f $PID, [Guid]::NewGuid().ToString('N'))
    $json = $Values | ConvertTo-Json -Compress
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($json)
    $created = $false
    $stream = $null
    try {
        if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
            $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $security = [System.Security.AccessControl.FileSecurity]::new()
            $security.SetOwner($identity.User)
            $security.SetAccessRuleProtection($true, $false)
            $security.AddAccessRule(
                [System.Security.AccessControl.FileSystemAccessRule]::new(
                    $identity.User,
                    [System.Security.AccessControl.FileSystemRights]::FullControl,
                    [System.Security.AccessControl.AccessControlType]::Allow
                )
            )
            # This FileStream overload applies the protected ACL atomically at
            # creation and keeps the handle exclusive while content is written.
            $stream = [System.IO.FileStream]::new(
                $path,
                [System.IO.FileMode]::CreateNew,
                [System.Security.AccessControl.FileSystemRights]::FullControl,
                [System.IO.FileShare]::None,
                4096,
                [System.IO.FileOptions]::WriteThrough,
                $security
            )
            $created = $true
        }
        else {
            # On Unix the file remains empty and exclusively held until chmod
            # succeeds, so no credential exists under inherited permissions.
            $stream = [System.IO.File]::Open(
                $path,
                [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None
            )
            $created = $true
            & chmod 600 $path
            if ($LASTEXITCODE -ne 0) {
                throw "Could not restrict temporary Dart define file permissions: $path"
            }
        }

        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null

        return $path
    }
    catch {
        if ($null -ne $stream) {
            try {
                if ($stream.CanWrite -and $stream.Length -gt 0) {
                    $stream.Position = 0
                    $stream.Write((New-Object byte[] $stream.Length), 0, $stream.Length)
                    $stream.Flush($true)
                }
            }
            catch {
                # Continue to close and delete while preserving the root error.
            }
            try {
                $stream.Dispose()
            }
            catch {
                # Path-based cleanup below must still run if close/flush fails.
            }
            $stream = $null
        }
        if ($created -and (Test-Path -LiteralPath $path -PathType Leaf)) {
            try {
                $length = (Get-Item -LiteralPath $path).Length
                if ($length -gt 0) {
                    [System.IO.File]::WriteAllBytes(
                        $path,
                        (New-Object byte[] $length)
                    )
                }
                [System.IO.File]::Delete($path)
            }
            catch {
                # Preserve the original creation/ACL error for the caller.
            }
        }
        throw
    }
    finally {
        if ($bytes) {
            [Array]::Clear($bytes, 0, $bytes.Length)
        }
        $json = $null
    }
}

function Remove-SpracheSecureDartDefineFile {
    [CmdletBinding()]
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or
        -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }
    $resolved = [System.IO.Path]::GetFullPath($Path)
    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if (-not $resolved.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not [System.IO.Path]::GetFileName($resolved).StartsWith(
            'sprache-dart-defines-',
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw "Refusing to remove an unexpected Dart define file: $resolved"
    }

    $length = (Get-Item -LiteralPath $resolved).Length
    if ($length -gt 0) {
        [System.IO.File]::WriteAllBytes($resolved, (New-Object byte[] $length))
    }
    Remove-Item -LiteralPath $resolved -Force
}
