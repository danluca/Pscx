[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ModulePath,

    [Parameter(Mandatory)]
    [string] $ResultsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$policy = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'Tests/TestPolicy.psd1')
$baseline = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'Tests/StaticAnalysisBaseline.psd1')
$analyzerVersion = [string]$policy.PSScriptAnalyzerVersion
$toolModuleRoot = Join-Path $repositoryRoot '.tools/modules'
$analyzerManifest = Join-Path $toolModuleRoot "PSScriptAnalyzer/$analyzerVersion/PSScriptAnalyzer.psd1"

if (-not (Test-Path -LiteralPath $analyzerManifest)) {
    New-Item -ItemType Directory -Path $toolModuleRoot -Force | Out-Null
    Write-Output "Saving PSScriptAnalyzer $analyzerVersion to $toolModuleRoot"
    Save-PSResource -Name PSScriptAnalyzer -Version $analyzerVersion -Repository PSGallery `
        -Path $toolModuleRoot -TrustRepository
}
if (-not (Test-Path -LiteralPath $analyzerManifest)) {
    throw "PSScriptAnalyzer $analyzerVersion was not saved at the expected path: $analyzerManifest"
}

Import-Module $analyzerManifest -Force -ErrorAction Stop
if ((Get-Module PSScriptAnalyzer).Version -ne [version]$analyzerVersion) {
    throw "Expected PSScriptAnalyzer $analyzerVersion but loaded $((Get-Module PSScriptAnalyzer).Version)."
}

$excludedDirectoryPattern = '[\\/](?:\.git|\.tools|artifacts|Output|bin|obj)[\\/]'
$allFiles = @(
    Get-ChildItem -LiteralPath $repositoryRoot -Recurse -File |
        Where-Object FullName -NotMatch $excludedDirectoryPattern
)
$powerShellFiles = @($allFiles | Where-Object Extension -In '.ps1', '.psm1', '.psd1')
$resultsPath = [IO.Path]::GetFullPath($ResultsPath)
New-Item -ItemType Directory -Path $resultsPath -Force | Out-Null
$powerShellExecutable = (Get-Process -Id $PID).Path
$analyzerFileScript = Join-Path $PSScriptRoot 'Invoke-PscxAnalyzerFile.ps1'
$ruleNames = @(
    Get-ScriptAnalyzerRule |
        Where-Object RuleName -NE 'PSUseToExportFieldsInManifest' |
        Select-Object -ExpandProperty RuleName
)
$ruleMidpoint = [math]::Ceiling($ruleNames.Count / 2)
$ruleBatches = @(
    $ruleNames[0..($ruleMidpoint - 1)] -join ','
    $ruleNames[$ruleMidpoint..($ruleNames.Count - 1)] -join ','
)
$analysisWork = @(
    foreach ($file in $powerShellFiles) {
        foreach ($ruleBatch in $ruleBatches) {
            [pscustomobject]@{ Path = $file.FullName; Rules = $ruleBatch }
        }
    }
)
$serializedDiagnostics = @(
    $analysisWork | ForEach-Object -Parallel {
        & $using:powerShellExecutable -NoLogo -NoProfile -NonInteractive -File `
            $using:analyzerFileScript -AnalyzerManifest $using:analyzerManifest `
            -Path $_.Path -IncludeRule $_.Rules
        if ($LASTEXITCODE -ne 0) {
            throw "PSScriptAnalyzer failed for $($_.Path) with exit code $LASTEXITCODE."
        }
    } -ThrottleLimit 4
)
$diagnostics = @(
    foreach ($serialized in $serializedDiagnostics) {
        $serialized | ConvertFrom-Json
    }
)
$errors = @($diagnostics | Where-Object Severity -EQ Error)
if ($errors.Count -gt 0) {
    $errors | Format-Table RuleName, ScriptPath, Line, Message -AutoSize | Out-String | Write-Output
    throw "PSScriptAnalyzer reported $($errors.Count) error(s)."
}

$analyzerCounts = @{}
foreach ($severity in 'Warning', 'Information') {
    $count = @($diagnostics | Where-Object Severity -EQ $severity).Count
    $analyzerCounts[$severity] = $count
    $maximum = [int]$baseline.PSScriptAnalyzer[$severity]
    if ($count -gt $maximum) {
        throw "PSScriptAnalyzer $severity count increased from $maximum to $count."
    }
}

$manifestFiles = @(
    Get-ChildItem -LiteralPath $ModulePath -Recurse -Filter *.psd1 -File |
        Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match '(?m)^\s*ModuleVersion\s*=' }
)
foreach ($manifestFile in $manifestFiles) {
    Test-ModuleManifest -Path $manifestFile.FullName -ErrorAction Stop | Out-Null
}

$xmlFiles = @($allFiles | Where-Object Extension -In '.xml', '.ps1xml')
foreach ($xmlFile in $xmlFiles) {
    [xml](Get-Content -LiteralPath $xmlFile.FullName -Raw) | Out-Null
}
foreach ($typeFile in Get-ChildItem -LiteralPath $ModulePath -Recurse -Filter *.Types.ps1xml -File) {
    Update-TypeData -PrependPath $typeFile.FullName -ErrorAction Stop
}
foreach ($formatFile in Get-ChildItem -LiteralPath $ModulePath -Recurse -Filter *.Format.ps1xml -File) {
    Update-FormatData -PrependPath $formatFile.FullName -ErrorAction Stop
}

# Only the Full Windows package can enumerate the complete cross-platform and
# Windows public surface. One matrix leg is sufficient to enforce the shared
# committed README; Core legs still run all other static checks.
if (Test-Path -LiteralPath (Join-Path $ModulePath 'PscxWin.psd1')) {
    & $powerShellExecutable -NoLogo -NoProfile -NonInteractive -File `
        (Join-Path $repositoryRoot 'Tools/Update-PscxReadmeCatalog.ps1') `
        -ModulePath $ModulePath -ReadmePath (Join-Path $repositoryRoot 'README.md') -Check
    if ($LASTEXITCODE -ne 0) {
        throw "README public API catalog validation failed with exit code $LASTEXITCODE."
    }
}

$formatExtensions = @('.cs', '.ps1', '.psm1', '.psd1', '.md', '.xml', '.ps1xml', '.yml', '.yaml')
$formatCounts = @{}
foreach ($extension in $formatExtensions) {
    $counts = @{ TrailingWhitespace = 0; MissingFinalNewline = 0; LeadingTab = 0 }
    foreach ($file in $allFiles | Where-Object Extension -EQ $extension) {
        $content = [IO.File]::ReadAllText($file.FullName)
        $counts.TrailingWhitespace += [regex]::Matches($content, '(?m)[ \t]+$').Count
        $counts.LeadingTab += [regex]::Matches($content, '(?m)^\t+').Count
        if ($content.Length -gt 0 -and -not $content.EndsWith("`n")) {
            $counts.MissingFinalNewline++
        }
    }
    $formatCounts[$extension] = $counts
    foreach ($rule in $counts.Keys) {
        $maximum = [int]$baseline.Formatting[$extension][$rule]
        if ($counts[$rule] -gt $maximum) {
            throw "Formatting violation $rule for $extension increased from $maximum to $($counts[$rule])."
        }
    }
}

[ordered]@{
    Status = 'Passed'
    PSScriptAnalyzerVersion = $analyzerVersion
    PowerShellFileCount = $powerShellFiles.Count
    AnalyzerCounts = $analyzerCounts
    ModuleManifestCount = $manifestFiles.Count
    XmlFileCount = $xmlFiles.Count
    FormattingCounts = $formatCounts
} | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath (Join-Path $resultsPath 'Pscx.StaticAnalysis.summary.json') -Encoding utf8
