[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ModulePath,

    [Parameter(Mandatory)]
    [ValidateSet('Core', 'Full')]
    [string] $BuildScope,

    [Parameter(Mandatory)]
    [string] $ResultsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$policy = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'Tests/TestPolicy.psd1')
$pesterVersion = [string]$policy.PesterVersion
$toolModuleRoot = Join-Path $repositoryRoot '.tools/modules'
$pesterManifest = Join-Path $toolModuleRoot "Pester/$pesterVersion/Pester.psd1"

if (-not (Test-Path -LiteralPath $pesterManifest)) {
    New-Item -ItemType Directory -Path $toolModuleRoot -Force | Out-Null
    Write-Host "Saving Pester $pesterVersion to $toolModuleRoot"
    Save-PSResource -Name Pester -Version $pesterVersion -Repository PSGallery `
        -Path $toolModuleRoot -TrustRepository
}
if (-not (Test-Path -LiteralPath $pesterManifest)) {
    throw "Pester $pesterVersion was not saved at the expected path: $pesterManifest"
}

Import-Module $pesterManifest -Force -ErrorAction Stop
if ((Get-Module Pester).Version -ne [version]$pesterVersion) {
    throw "Expected Pester $pesterVersion but loaded $((Get-Module Pester).Version)."
}

$modulePath = (Resolve-Path -LiteralPath $ModulePath).Path
$resultsPath = [System.IO.Path]::GetFullPath($ResultsPath)
New-Item -ItemType Directory -Path $resultsPath -Force | Out-Null
$testResultPath = Join-Path $resultsPath 'Pscx.Pester.xml'
$coveragePath = Join-Path $resultsPath 'Pscx.PowerShell.coverage.xml'
$coverageFiles = @(
    Get-ChildItem -LiteralPath $modulePath -Recurse -File -Filter *.psm1 |
        Select-Object -ExpandProperty FullName
)

$container = New-PesterContainer `
    -Path (Join-Path $repositoryRoot 'Tests/Pscx.Package.Tests.ps1') `
    -Data @{ ModulePath = $modulePath; BuildScope = $BuildScope }
$configuration = New-PesterConfiguration
$configuration.Run.Container = $container
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Normal'
$configuration.Output.RenderMode = 'Plaintext'
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputFormat = 'NUnit3'
$configuration.TestResult.OutputPath = $testResultPath
$configuration.CodeCoverage.Enabled = $true
$configuration.CodeCoverage.Path = $coverageFiles
$configuration.CodeCoverage.OutputFormat = 'Cobertura'
$configuration.CodeCoverage.OutputPath = $coveragePath
$configuration.CodeCoverage.CoveragePercentTarget =
    [decimal]$policy.PowerShellCoverageMinimumPercent

$result = Invoke-Pester -Configuration $configuration
$summary = [ordered]@{
    Framework = 'Pester'
    Version = $pesterVersion
    Result = $result.Result
    TotalCount = $result.TotalCount
    PassedCount = $result.PassedCount
    FailedCount = $result.FailedCount
    SkippedCount = $result.SkippedCount
    CoveragePercent = $result.CodeCoverage.CoveragePercent
    CoverageMinimumPercent = [decimal]$policy.PowerShellCoverageMinimumPercent
    TestResultPath = $testResultPath
    CoveragePath = $coveragePath
}
$summary | ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath (Join-Path $resultsPath 'Pscx.Pester.summary.json') -Encoding utf8

if ($result.FailedCount -gt 0 -or $result.Result -ne 'Passed') {
    throw "Pester failed: $($result.FailedCount) of $($result.TotalCount) tests failed."
}
if ($result.CodeCoverage.CoveragePercent -lt [decimal]$policy.PowerShellCoverageMinimumPercent) {
    throw "PowerShell coverage $($result.CodeCoverage.CoveragePercent)% is below the $($policy.PowerShellCoverageMinimumPercent)% minimum."
}
