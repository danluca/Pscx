[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ManifestPath,

    [ValidateSet('Core', 'Full')]
    [string] $ExpectedBuildScope = 'Full',

    [string] $ExpectedPowerShellVersion,

    [string] $ResultsPath
)

$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

$actualPowerShellVersion = $PSVersionTable.PSVersion.ToString()
if ($ExpectedPowerShellVersion -and $actualPowerShellVersion -ne $ExpectedPowerShellVersion) {
    throw "Expected PowerShell $ExpectedPowerShellVersion but started $actualPowerShellVersion."
}

$manifestPath = (Resolve-Path -LiteralPath $ManifestPath).Path
$moduleRoot = Split-Path -Parent $manifestPath
$windowsAssemblyPath = Join-Path $moduleRoot 'Pscx.Win.dll'
if ($ExpectedBuildScope -eq 'Full' -and -not (Test-Path -LiteralPath $windowsAssemblyPath)) {
    throw 'The Full package is missing Pscx.Win.dll.'
}
if ($ExpectedBuildScope -eq 'Core' -and (Test-Path -LiteralPath $windowsAssemblyPath)) {
    throw 'The Core package unexpectedly contains Pscx.Win.dll.'
}

$warnings = @()
$elapsed = Measure-Command {
    Import-Module $manifestPath -Force -ErrorAction Stop -WarningVariable warnings
}
$commands = @(Get-Command -Module Pscx*)
if ($commands.Count -eq 0) {
    throw 'Packaged module exported no commands.'
}

$result = [ordered]@{
    PowerShellVersion = $actualPowerShellVersion
    PowerShellEdition = $PSVersionTable.PSEdition
    OS = $PSVersionTable.OS
    Platform = $PSVersionTable.Platform
    BuildScope = $ExpectedBuildScope
    ImportMilliseconds = [Math]::Round($elapsed.TotalMilliseconds, 3)
    CommandCount = $commands.Count
    WarningCount = $warnings.Count
    Warnings = @($warnings | ForEach-Object { $_.ToString() })
}

Write-Host "Validated $($commands.Count) packaged commands in $($result.ImportMilliseconds) ms using PowerShell $actualPowerShellVersion."

if ($ResultsPath) {
    $resultsPath = [System.IO.Path]::GetFullPath($ResultsPath)
    New-Item -ItemType Directory -Path (Split-Path -Parent $resultsPath) -Force | Out-Null
    $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $resultsPath -Encoding utf8
    Write-Host "Import results: $resultsPath"
}
