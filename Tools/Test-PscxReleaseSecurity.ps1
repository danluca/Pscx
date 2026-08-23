[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $PackagePath,

    [Parameter(Mandatory)]
    [string] $ResultsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

$packagePath = (Resolve-Path -LiteralPath $PackagePath).Path
$resultsPath = [IO.Path]::GetFullPath($ResultsPath)
New-Item -ItemType Directory -Path (Split-Path -Parent $resultsPath) -Force | Out-Null

$report = [ordered]@{
    Package = [IO.Path]::GetFileName($packagePath)
    PackageSha256 = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash
    Scanner = 'Microsoft Defender Antivirus'
    Status = 'Skipped'
    Executable = $null
    ExitCode = $null
    AntivirusEnabled = $null
    SignatureVersion = $null
    Reason = $null
}

if (-not $IsWindows) {
    $report.Reason = 'Microsoft Defender release scanning is available only on Windows.'
}
else {
    $defenderCandidates = @()
    $platformRoot = Join-Path $env:ProgramData 'Microsoft/Windows Defender/Platform'
    if (Test-Path -LiteralPath $platformRoot -PathType Container) {
        $defenderCandidates += @(
            Get-ChildItem -LiteralPath $platformRoot -Directory |
                Sort-Object Name -Descending |
                ForEach-Object { Join-Path $_.FullName 'MpCmdRun.exe' }
        )
    }
    $defenderCandidates += Join-Path $env:ProgramFiles 'Windows Defender/MpCmdRun.exe'
    $defender = $defenderCandidates |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1

    $defenderStatus = if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
        Get-MpComputerStatus -ErrorAction SilentlyContinue
    }
    if ($defenderStatus) {
        $report.AntivirusEnabled = [bool]$defenderStatus.AntivirusEnabled
        $report.SignatureVersion = [string]$defenderStatus.AntivirusSignatureVersion
    }
    if ($defender) {
        $report.Executable = $defender
    }

    if (-not $defender) {
        $report.Reason = 'MpCmdRun.exe is not installed on this Windows host.'
    }
    elseif ($defenderStatus -and
        (-not $defenderStatus.AMServiceEnabled -or -not $defenderStatus.AntivirusEnabled)) {
        $report.Reason = 'Microsoft Defender Antivirus is installed but disabled on this Windows host.'
    }
    else {
        & $defender -Scan -ScanType 3 -File $packagePath -DisableRemediation
        $report.ExitCode = $LASTEXITCODE
        if ($LASTEXITCODE -eq 0) {
            $report.Status = 'Passed'
        }
        else {
            $report.Status = 'Failed'
            $report.Reason = "Microsoft Defender returned exit code $LASTEXITCODE."
        }
    }
}

$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $resultsPath -Encoding utf8
Write-Host "Release security report: $resultsPath"

if ($report.Status -eq 'Failed') {
    throw $report.Reason
}
if ($report.Status -eq 'Skipped') {
    Write-Warning $report.Reason
}
