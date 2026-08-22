Set-StrictMode -Version Latest

if (-not $IsWindows) {
    throw 'Pscx.WinAdmin is supported only on Windows.'
}

function Add-ShortPath {
    <#
    .SYNOPSIS
        Adds a ShortPath property to file-system objects.
    .DESCRIPTION
        Resolves each input object's Windows 8.3 path through Get-ShortPath and
        adds it as a ShortPath note property.
    .PARAMETER InputObject
        A FileInfo or DirectoryInfo object to annotate.
    .EXAMPLE
        Get-ChildItem | Add-ShortPath | Format-Table ShortPath, FullName
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.IO.FileSystemInfo] $InputObject
    )

    process {
        if (-not (Get-Command 'Pscx\Get-ShortPath' -ErrorAction SilentlyContinue)) {
            Import-Module Pscx -ErrorAction Stop
        }
        $shortPathInfo = Pscx\Get-ShortPath -LiteralPath $InputObject.FullName
        Add-Member -InputObject $InputObject -MemberType NoteProperty `
            -Name ShortPath -Value $shortPathInfo.ShortPath -Force
        $InputObject
    }
}

function Invoke-BatchFile {
    <#
    .SYNOPSIS
        Invokes a batch file and retains its environment changes.
    .DESCRIPTION
        Runs a .bat or .cmd file through cmd.exe and applies the resulting
        environment-variable changes to the current PowerShell process.
    .PARAMETER Path
        Path to a .bat or .cmd file.
    .PARAMETER Parameters
        Arguments passed to the batch file.
    .EXAMPLE
        Invoke-BatchFile 'C:\Tools\Configure.cmd' '-quiet'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Path,

        [Parameter(Position = 1)]
        [string] $Parameters
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    if (-not $PSCmdlet.ShouldProcess(
        $resolvedPath,
        'Invoke batch file and apply its environment changes'
    )) {
        return
    }
    $tempFile = [IO.Path]::GetTempFileName()
    try {
        cmd.exe /d /c " `"$resolvedPath`" $Parameters && set " > $tempFile
        if ($LASTEXITCODE -ne 0) {
            throw "Batch file exited with code ${LASTEXITCODE}: $resolvedPath"
        }

        Get-Content -LiteralPath $tempFile | ForEach-Object {
            if ($_ -match '^(.*?)=(.*)$') {
                [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
            }
            else {
                $_
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function Add-ShortPath, Invoke-BatchFile
