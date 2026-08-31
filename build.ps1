[CmdletBinding()]
param(
    [ValidateSet(
        'Clean',
        'Restore',
        'Compile',
        'Help',
        'Test',
        'Pester',
        'Static',
        'Dashboard',
        'Catalog',
        'TestPipeline',
        'ImportTest',
        'Package',
        'Validate',
        'Audit',
        'PublishPrep',
        'CI'
    )]
    [string[]] $Task = @('CI'),

    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release',

    [ValidateSet('Auto', 'Core', 'Full')]
    [string] $BuildScope = 'Auto',

    [ValidateRange(0, 65535)]
    [int] $BuildNumber = 0,

    [string] $CommitSha,

    [string] $ArtifactsPath = (Join-Path $PSScriptRoot 'artifacts'),

    [switch] $Release,

    [string] $ExpectedTag,

    [string] $PowerShellPath = 'pwsh',

    [string] $ExpectedPowerShellVersion
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

$repositoryRoot = $PSScriptRoot
$solutionPath = Join-Path $repositoryRoot 'Src/Pscx.sln'
$coreProjectPath = Join-Path $repositoryRoot 'Src/Pscx.InternalTests/Pscx.InternalTests.csproj'
$archiveProjectPath = Join-Path $repositoryRoot 'Src/Pscx.Archive/Pscx.Archive.csproj'
$winAdminProjectPath = Join-Path $repositoryRoot 'Src/Pscx.WinAdmin/Pscx.WinAdmin.csproj'
$internalTestProjectPath = Join-Path $repositoryRoot 'Src/Pscx.InternalTests/Pscx.InternalTests.csproj'
$versionFilePath = Join-Path $repositoryRoot 'Directory.Build.props'
$testPolicyFilePath = Join-Path $repositoryRoot 'Tests/TestPolicy.psd1'
$artifactsRoot = [System.IO.Path]::GetFullPath($ArtifactsPath)
$moduleRoot = Join-Path $artifactsRoot 'module/Pscx'
$archiveModuleRoot = Join-Path $artifactsRoot 'module/Pscx.Archive'
$timeModuleRoot = Join-Path $artifactsRoot 'module/Pscx.Time'
$winAdminModuleRoot = Join-Path $artifactsRoot 'module/Pscx.WinAdmin'
$helpOutputPath = Join-Path $artifactsRoot 'help'
$packageOutputPath = Join-Path $artifactsRoot 'packages'
$releaseLayoutRoot = Join-Path $artifactsRoot 'release-layout'
$testResultsPath = Join-Path $artifactsRoot 'test-results'
$resolvedBuildScope = if ($BuildScope -eq 'Auto') {
    if ($IsWindows) { 'Full' } else { 'Core' }
}
else {
    $BuildScope
}
$buildTargetPath = if ($resolvedBuildScope -eq 'Full') {
    $solutionPath
}
else {
    $coreProjectPath
}

if ($resolvedBuildScope -eq 'Full' -and -not $IsWindows) {
    throw 'Full builds include Pscx.Win and are supported only on Windows. Use -BuildScope Core on this platform.'
}

function Write-Step {
    param([string] $Message)
    Write-Host "`n==> $Message"
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)]
        [string] $FilePath,

        [Parameter(Mandatory)]
        [string[]] $ArgumentList
    )

    Write-Host "> $FilePath $($ArgumentList -join ' ')"
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "'$FilePath' exited with code $LASTEXITCODE."
    }
}

function Get-RelativePath {
    param([string] $Path)
    return [System.IO.Path]::GetRelativePath($repositoryRoot, $Path)
}

function Assert-ManagedPath {
    param([string] $Path)

    $resolvedRoot = [System.IO.Path]::GetFullPath($repositoryRoot).TrimEnd('\', '/')
    $resolvedArtifacts = [System.IO.Path]::GetFullPath($artifactsRoot).TrimEnd('\', '/')
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $separator = [System.IO.Path]::DirectorySeparatorChar
    $isRepositoryChild = $resolvedPath.StartsWith(
        "$resolvedRoot$separator",
        [System.StringComparison]::OrdinalIgnoreCase
    )
    $isArtifactPath = $resolvedPath.Equals(
        $resolvedArtifacts,
        [System.StringComparison]::OrdinalIgnoreCase
    ) -or $resolvedPath.StartsWith(
        "$resolvedArtifacts$separator",
        [System.StringComparison]::OrdinalIgnoreCase
    )

    if (-not ($isRepositoryChild -or $isArtifactPath)) {
        throw "Refusing to modify an unmanaged path: $resolvedPath"
    }
}

function Remove-BuildDirectory {
    param([string] $Path)

    Assert-ManagedPath $Path
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Copy-RequiredItem {
    param(
        [string] $Source,
        [string] $Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Required build output is missing: $(Get-RelativePath $Source). Run the Compile task first."
    }

    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

function Copy-MatchingItem {
    param(
        [string] $SourcePath,
        [string] $Pattern,
        [string] $Destination
    )

    $items = @(Get-ChildItem -LiteralPath $SourcePath -Filter $Pattern -File)
    if ($items.Count -eq 0) {
        throw "No files matching '$Pattern' were found under $(Get-RelativePath $SourcePath)."
    }

    $items | Copy-Item -Destination $Destination -Force
}

function Remove-AuthenticodeSignatureBlock {
    param([string] $Path)

    $content = Get-Content -LiteralPath $Path -Raw
    $content = [regex]::Replace(
        $content,
        '(?ms)^# SIG # Begin signature block\r?\n.*?# SIG # End signature block\r?\n?',
        ''
    )
    Set-Content -LiteralPath $Path -Value $content.TrimEnd() -Encoding utf8
}

function Set-ManifestVersion {
    param(
        [string] $Path,
        [string] $ModuleVersion,
        [string] $Prerelease,
        [string] $RequiredPowerShellVersion
    )

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -notmatch '(?m)^\s*ModuleVersion\s*=') {
        return
    }

    $content = [regex]::Replace(
        $content,
        '(?m)^(\s*ModuleVersion\s*=\s*)[''"][^''"]+[''"](?<suffix>.*)$',
        "`${1}'$ModuleVersion'`${suffix}",
        1
    )
    $content = [regex]::Replace(
        $content,
        '(?m)^(\s*PowerShellVersion\s*=\s*)[''"][^''"]+[''"](?<suffix>.*)$',
        "`${1}'$RequiredPowerShellVersion'`${suffix}",
        1
    )

    if ([System.IO.Path]::GetFileName($Path) -in @(
        'Pscx.psd1',
        'Pscx.Archive.psd1',
        'Pscx.Time.psd1',
        'Pscx.WinAdmin.psd1'
    )) {
        if ($Prerelease) {
            $content = [regex]::Replace(
                $content,
                "(?m)^(?<indent>\s*)#\s*Prerelease\s*=\s*['""][^'""]*['""]",
                "`${indent}Prerelease = '$Prerelease'",
                1
            )
        }
        else {
            $content = [regex]::Replace(
                $content,
                "(?m)^(?<indent>\s*)Prerelease\s*=\s*['""][^'""]*['""]",
                "`${indent}# Prerelease is stamped for CI builds.",
                1
            )
        }
    }

    Set-Content -LiteralPath $Path -Value $content.TrimEnd() -Encoding utf8
    Remove-AuthenticodeSignatureBlock -Path $Path
}

function Invoke-Clean {
    Write-Step 'Clean'
    Remove-BuildDirectory $artifactsRoot

    Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'Src') -Directory |
        ForEach-Object {
            Remove-BuildDirectory (Join-Path $_.FullName 'bin')
            Remove-BuildDirectory (Join-Path $_.FullName 'obj')
        }
}

function Invoke-Restore {
    Write-Step "Restore $resolvedBuildScope build"
    Invoke-NativeCommand dotnet @('restore', $buildTargetPath, '--nologo')
    if ($resolvedBuildScope -eq 'Core') {
        Invoke-NativeCommand dotnet @('restore', $archiveProjectPath, '--nologo')
    }
}

function Get-MSBuildVersionArguments {
    return @(
        "-p:PscxBuildNumber=$BuildNumber",
        "-p:PscxCommitSha=$shortCommitSha",
        "-p:PscxPackageVersion=$packageVersion",
        "-p:InformationalVersion=$informationalVersion",
        "-p:PscxBuildScope=$resolvedBuildScope"
    )
}

function Invoke-Compile {
    Write-Step "Compile $packageVersion ($resolvedBuildScope)"
    $arguments = @(
        'build',
        $buildTargetPath,
        '--configuration',
        $Configuration,
        '--no-restore',
        '--nologo'
    ) + (Get-MSBuildVersionArguments)
    Invoke-NativeCommand dotnet $arguments
    if ($resolvedBuildScope -eq 'Core') {
        $archiveArguments = @(
            'build',
            $archiveProjectPath,
            '--configuration',
            $Configuration,
            '--no-restore',
            '--nologo'
        ) + (Get-MSBuildVersionArguments)
        Invoke-NativeCommand dotnet $archiveArguments
    }
}

function New-ModuleStage {
    Write-Step "Assemble module $packageVersion"
    Remove-BuildDirectory (Join-Path $artifactsRoot 'module')
    New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $archiveModuleRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $timeModuleRoot -Force | Out-Null
    if ($resolvedBuildScope -eq 'Full') {
        New-Item -ItemType Directory -Path $winAdminModuleRoot -Force | Out-Null
    }

    $coreOutput = Join-Path $repositoryRoot "Src/Pscx/bin/$Configuration/net10.0"
    $windowsOutput = Join-Path $repositoryRoot "Src/Pscx.Win/bin/$Configuration/net10.0"
    $archiveOutput = Join-Path $repositoryRoot "Src/Pscx.Archive/bin/$Configuration/net10.0"
    $timeOutput = Join-Path $repositoryRoot "Src/Pscx.Time/bin/$Configuration/net10.0"
    $winAdminOutput = Join-Path $repositoryRoot "Src/Pscx.WinAdmin/bin/$Configuration/net10.0-windows"

    @(
        'Pscx.Core.dll',
        'Pscx.dll',
        'Pscx.psd1',
        'Pscx.psm1',
        'Pscx.Update.psm1',
        'Update-Pscx.ps1',
        'Pscx.UserPreferences.ps1',
        'Pscx.ico'
    ) | ForEach-Object {
        Copy-RequiredItem (Join-Path $coreOutput $_) $moduleRoot
    }

    Copy-MatchingItem $coreOutput 'YamlDotNet.*' $moduleRoot
    @('Certificates', 'FormatData', 'Modules', 'TypeData') | ForEach-Object {
        Copy-RequiredItem (Join-Path $coreOutput $_) $moduleRoot
    }

    if ($resolvedBuildScope -eq 'Full') {
        @('Pscx.Win.dll', 'PscxWin.psd1', 'PscxWin.psm1') | ForEach-Object {
            Copy-RequiredItem (Join-Path $windowsOutput $_) $moduleRoot
        }

        @('FormatData', 'Modules', 'TypeData') | ForEach-Object {
            Copy-RequiredItem (Join-Path $windowsOutput $_) $moduleRoot
        }
    }

    if ($resolvedBuildScope -eq 'Full') {
        $windowsApps = Join-Path $moduleRoot 'Apps/Win'
        New-Item -ItemType Directory -Path $windowsApps -Force | Out-Null

        Copy-MatchingItem (Join-Path $repositoryRoot 'Imports/Less-678') 'less*.*' $windowsApps
        Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/Less-678/license') (Join-Path $windowsApps 'LICENSE_less_orig.txt')
        Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/Less-678/LICENSE_win.txt') (Join-Path $windowsApps 'LICENSE_less_win.txt')
        Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/gsudo/win/gsudo.exe') (Join-Path $windowsApps 'gsudo.exe')
        Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/gsudo/win/gsudo.exe') (Join-Path $windowsApps 'sudo.exe')
        Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/gsudo/win/Invoke-ElevatedCommand.ps1') (Join-Path $windowsApps 'Invoke-Elevated.ps1')
        Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/gsudo/LICENSE.txt') (Join-Path $windowsApps 'LICENSE_sudo.txt')
    }
    Copy-RequiredItem (Join-Path $repositoryRoot 'CHANGELOG.md') (Join-Path $moduleRoot 'CHANGELOG.md')
    Copy-RequiredItem (Join-Path $repositoryRoot 'LICENSE') (Join-Path $moduleRoot 'LICENSE.txt')

    @('Pscx.Archive.dll', 'Pscx.Archive.psd1', 'SharpCompress.dll', 'THIRD-PARTY-NOTICES.md') | ForEach-Object {
        Copy-RequiredItem (Join-Path $archiveOutput $_) $archiveModuleRoot
    }
    @('FormatData', 'TypeData') | ForEach-Object {
        Copy-RequiredItem (Join-Path $archiveOutput $_) $archiveModuleRoot
    }
    Copy-RequiredItem (Join-Path $repositoryRoot 'CHANGELOG.md') (Join-Path $archiveModuleRoot 'CHANGELOG.md')
    Copy-RequiredItem (Join-Path $repositoryRoot 'LICENSE') (Join-Path $archiveModuleRoot 'LICENSE.txt')

    @(
        'Pscx.Time.dll',
        'Pscx.Time.psd1',
        'Pscx.Time.psm1',
        'NodaTime.dll',
        'NodaTime.xml',
        'THIRD-PARTY-NOTICES.md'
    ) | ForEach-Object {
        Copy-RequiredItem (Join-Path $timeOutput $_) $timeModuleRoot
    }
    Copy-RequiredItem (Join-Path $repositoryRoot 'CHANGELOG.md') (Join-Path $timeModuleRoot 'CHANGELOG.md')
    Copy-RequiredItem (Join-Path $repositoryRoot 'LICENSE') (Join-Path $timeModuleRoot 'LICENSE.txt')

    if ($resolvedBuildScope -eq 'Full') {
        @(
            'Pscx.Core.dll',
            'Pscx.WinAdmin.dll',
            'Pscx.WinAdmin.psd1',
            'Pscx.WinAdmin.psm1'
        ) |
            ForEach-Object {
                Copy-RequiredItem (Join-Path $winAdminOutput $_) $winAdminModuleRoot
            }
        Copy-RequiredItem (Join-Path $repositoryRoot 'CHANGELOG.md') `
            (Join-Path $winAdminModuleRoot 'CHANGELOG.md')
        Copy-RequiredItem (Join-Path $repositoryRoot 'LICENSE') `
            (Join-Path $winAdminModuleRoot 'LICENSE.txt')
    }

    Get-ChildItem -LiteralPath (Join-Path $artifactsRoot 'module') -Recurse -Filter *.psd1 -File |
        ForEach-Object {
            Set-ManifestVersion -Path $_.FullName -ModuleVersion $moduleVersion -Prerelease $manifestPrerelease `
                -RequiredPowerShellVersion $powerShellMinimumVersion
        }
}

function Invoke-Help {
    if (-not (Test-Path -LiteralPath (Join-Path $archiveModuleRoot 'Pscx.Archive.psd1'))) {
        New-ModuleStage
    }

    Write-Step 'Validate Markdown and generate external help'
    Remove-BuildDirectory $helpOutputPath
    $cultureOutputPath = Join-Path $helpOutputPath 'en-US'
    New-Item -ItemType Directory -Path $cultureOutputPath -Force | Out-Null

    Invoke-NativeCommand $PowerShellPath @(
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-File',
        (Join-Path $repositoryRoot 'Tools/Invoke-PscxHelp.ps1'),
        '-ModulePath',
        $moduleRoot,
        '-OutputPath',
        $cultureOutputPath,
        '-BuildScope',
        $resolvedBuildScope
    )

    Copy-RequiredItem $cultureOutputPath $moduleRoot

    $archiveCultureOutputPath = Join-Path $helpOutputPath 'Pscx.Archive/en-US'
    New-Item -ItemType Directory -Path $archiveCultureOutputPath -Force | Out-Null
    Invoke-NativeCommand $PowerShellPath @(
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-File',
        (Join-Path $repositoryRoot 'Tools/Invoke-PscxHelp.ps1'),
        '-ModulePath',
        $archiveModuleRoot,
        '-OutputPath',
        $archiveCultureOutputPath,
        '-BuildScope',
        $resolvedBuildScope,
        '-PackageName',
        'Pscx.Archive'
    )
    Copy-RequiredItem $archiveCultureOutputPath $archiveModuleRoot

    $timeCultureOutputPath = Join-Path $helpOutputPath 'Pscx.Time/en-US'
    New-Item -ItemType Directory -Path $timeCultureOutputPath -Force | Out-Null
    Invoke-NativeCommand $PowerShellPath @(
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-File',
        (Join-Path $repositoryRoot 'Tools/Invoke-PscxHelp.ps1'),
        '-ModulePath',
        $timeModuleRoot,
        '-OutputPath',
        $timeCultureOutputPath,
        '-BuildScope',
        $resolvedBuildScope,
        '-PackageName',
        'Pscx.Time'
    )
    Copy-RequiredItem $timeCultureOutputPath $timeModuleRoot

    if ($resolvedBuildScope -eq 'Full') {
        $winAdminCultureOutputPath = Join-Path $helpOutputPath 'Pscx.WinAdmin/en-US'
        New-Item -ItemType Directory -Path $winAdminCultureOutputPath -Force | Out-Null
        Invoke-NativeCommand $PowerShellPath @(
            '-NoLogo',
            '-NoProfile',
            '-NonInteractive',
            '-File',
            (Join-Path $repositoryRoot 'Tools/Invoke-PscxHelp.ps1'),
            '-ModulePath',
            $winAdminModuleRoot,
            '-OutputPath',
            $winAdminCultureOutputPath,
            '-BuildScope',
            $resolvedBuildScope,
            '-PackageName',
            'Pscx.WinAdmin'
        )
        Copy-RequiredItem $winAdminCultureOutputPath $winAdminModuleRoot
    }
}

function Invoke-Test {
    Write-Step 'Run cross-platform internal tests with managed-code coverage'
    $managedResultsPath = Join-Path $testResultsPath 'managed'
    Remove-BuildDirectory $managedResultsPath
    New-Item -ItemType Directory -Path $managedResultsPath -Force | Out-Null
    $arguments = @(
        'test',
        $internalTestProjectPath,
        '--configuration',
        $Configuration,
        '--no-build',
        '--no-restore',
        '--nologo',
        '--results-directory',
        $managedResultsPath,
        '--logger',
        'trx;LogFileName=Pscx.InternalTests.trx',
        '--collect',
        'XPlat Code Coverage'
    ) + (Get-MSBuildVersionArguments)

    Invoke-NativeCommand dotnet $arguments

    $coverageFiles = @(Get-ChildItem -LiteralPath $managedResultsPath -Recurse -Filter coverage.cobertura.xml -File)
    $coverageGroups = @($coverageFiles | Group-Object { (Get-FileHash -LiteralPath $_.FullName).Hash })
    if ($coverageGroups.Count -ne 1) {
        throw "Expected one distinct managed coverage report; found $($coverageGroups.Count)."
    }
    Copy-Item -LiteralPath $coverageGroups[0].Group[0].FullName `
        -Destination (Join-Path $testResultsPath 'Pscx.Managed.coverage.xml') -Force

    [xml] $testResult = Get-Content -LiteralPath (Join-Path $managedResultsPath 'Pscx.InternalTests.trx') -Raw
    [xml] $coverage = Get-Content -LiteralPath (Join-Path $testResultsPath 'Pscx.Managed.coverage.xml') -Raw
    $counters = $testResult.TestRun.ResultSummary.Counters
    $coveragePercent = 100 * [decimal]::Parse(
        [string]$coverage.coverage.'line-rate',
        [System.Globalization.CultureInfo]::InvariantCulture
    )
    $summary = [ordered]@{
        Framework = '.NET/NUnit'
        TotalCount = [int]$counters.total
        PassedCount = [int]$counters.passed
        FailedCount = [int]$counters.failed
        SkippedCount = [int]$counters.notExecuted
        CoveragePercent = [Math]::Round($coveragePercent, 3)
        CoverageMinimumPercent = [decimal]$testPolicy.ManagedCoverageMinimumPercent
        TestResultPath = Join-Path $managedResultsPath 'Pscx.InternalTests.trx'
        CoveragePath = Join-Path $testResultsPath 'Pscx.Managed.coverage.xml'
    }
    $summary | ConvertTo-Json -Depth 4 |
        Set-Content -LiteralPath (Join-Path $testResultsPath 'Pscx.Managed.summary.json') -Encoding utf8

    if ($coveragePercent -lt [decimal]$testPolicy.ManagedCoverageMinimumPercent) {
        throw "Managed coverage $coveragePercent% is below the $($testPolicy.ManagedCoverageMinimumPercent)% minimum."
    }
}

function Invoke-PesterTest {
    Write-Step 'Run packaged-module Pester tests with PowerShell coverage'
    Invoke-NativeCommand $PowerShellPath @(
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-File',
        (Join-Path $repositoryRoot 'Tools/Invoke-PscxPester.ps1'),
        '-ModulePath',
        $moduleRoot,
        '-ArchiveModulePath',
        $archiveModuleRoot,
        '-TimeModulePath',
        $timeModuleRoot,
        '-WinAdminModulePath',
        $winAdminModuleRoot,
        '-BuildScope',
        $resolvedBuildScope,
        '-ResultsPath',
        $testResultsPath,
        '-PowerShellPath',
        $PowerShellPath
    )
}

function Invoke-StaticValidation {
    Write-Step 'Run repository static validation'
    Invoke-NativeCommand $PowerShellPath @(
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-File',
        (Join-Path $repositoryRoot 'Tools/Test-PscxStatic.ps1'),
        '-ModulePath',
        $moduleRoot,
        '-ResultsPath',
        $testResultsPath,
        '-PowerShellPath',
        $PowerShellPath
    )

    Invoke-NativeCommand $PowerShellPath @(
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-File',
        (Join-Path $repositoryRoot 'Tools/Test-PscxRedistributedBinary.ps1'),
        '-ResultsPath',
        (Join-Path $testResultsPath 'Pscx.RedistributedBinaries.json')
    )
}

function Invoke-TestDashboard {
    Write-Step 'Generate self-contained HTML test dashboard'
    Invoke-NativeCommand $PowerShellPath @(
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-File',
        (Join-Path $repositoryRoot 'Tools/New-PscxTestDashboard.ps1'),
        '-ResultsPath',
        $testResultsPath,
        '-OutputPath',
        (Join-Path $testResultsPath 'Pscx.TestDashboard.html')
    )
}

function Invoke-Catalog {
    if ($resolvedBuildScope -ne 'Full') {
        throw 'The complete README catalog requires a Full Windows package.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $moduleRoot 'PscxWin.psd1'))) {
        throw 'The Full packaged module is missing. Run the Package task first.'
    }

    Write-Step 'Update README public API catalog'
    Invoke-NativeCommand $PowerShellPath @(
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-File',
        (Join-Path $repositoryRoot 'Tools/Update-PscxReadmeCatalog.ps1'),
        '-ModulePath',
        $moduleRoot,
        '-ReadmePath',
        (Join-Path $repositoryRoot 'README.md')
    )
}

function Invoke-UnifiedTest {
    Write-Step 'Run unified release-blocking test suites'
    New-Item -ItemType Directory -Path $testResultsPath -Force | Out-Null
    $outcomes = [ordered]@{}
    $failures = [System.Collections.Generic.List[string]]::new()

    foreach ($suite in @(
        [ordered]@{ Name = 'Managed'; Action = { Invoke-Test } },
        [ordered]@{ Name = 'Pester'; Action = { Invoke-PesterTest } },
        [ordered]@{ Name = 'Static'; Action = { Invoke-StaticValidation } }
    )) {
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        try {
            & $suite.Action
            $outcomes[$suite.Name] = [ordered]@{ Status = 'Passed'; Error = $null }
        }
        catch {
            $message = $_.Exception.Message
            $outcomes[$suite.Name] = [ordered]@{ Status = 'Failed'; Error = $message }
            $failures.Add("$($suite.Name): $message")
            Write-Error "$($suite.Name) suite failed: $message" -ErrorAction Continue
        }
        finally {
            $stopwatch.Stop()
            $outcomes[$suite.Name].DurationSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
        }
    }

    $summary = [ordered]@{
        Status = if ($failures.Count -eq 0) { 'Passed' } else { 'Failed' }
        BuildScope = $resolvedBuildScope
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        Suites = $outcomes
    }
    $summary | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $testResultsPath 'Pscx.TestSummary.json') -Encoding utf8

    try {
        Invoke-TestDashboard
    }
    catch {
        $message = $_.Exception.Message
        $failures.Add("Dashboard: $message")
        $summary.Status = 'Failed'
        $summary | ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath (Join-Path $testResultsPath 'Pscx.TestSummary.json') -Encoding utf8
        Write-Error "Dashboard generation failed: $message" -ErrorAction Continue
    }

    if ($failures.Count -gt 0) {
        throw "Unified tests failed. $($failures -join ' | ')"
    }
}

function Invoke-Package {
    New-ModuleStage
    Invoke-Help

    Write-Step "Create unified Pscx $packageVersion ZIP"
    Remove-BuildDirectory $packageOutputPath
    Remove-BuildDirectory $releaseLayoutRoot
    New-Item -ItemType Directory -Path $packageOutputPath -Force | Out-Null
    New-Item -ItemType Directory -Path $releaseLayoutRoot -Force | Out-Null
    $packageModules = @(
        @{ Name = 'Pscx'; SourcePath = $moduleRoot }
        @{ Name = 'Pscx.Archive'; SourcePath = $archiveModuleRoot }
        @{ Name = 'Pscx.Time'; SourcePath = $timeModuleRoot }
    )
    if ($resolvedBuildScope -eq 'Full') {
        $packageModules += @{ Name = 'Pscx.WinAdmin'; SourcePath = $winAdminModuleRoot }
    }
    try {
        foreach ($packageModule in $packageModules) {
            $versionRoot = Join-Path $releaseLayoutRoot "$($packageModule.Name)/$moduleVersion"
            New-Item -ItemType Directory -Path $versionRoot -Force | Out-Null
            Get-ChildItem -LiteralPath $packageModule.SourcePath -Force |
                Copy-Item -Destination $versionRoot -Recurse -Force
        }

        $archivePath = Join-Path $packageOutputPath "Pscx-$packageVersion.zip"
        $packageRoots = @($packageModules | ForEach-Object {
                Join-Path $releaseLayoutRoot $_.Name
            })
        Compress-Archive -LiteralPath $packageRoots -DestinationPath $archivePath
    }
    finally {
        Remove-BuildDirectory $releaseLayoutRoot
    }
}

function Assert-ReleaseArchiveLayout {
    param([Parameter(Mandatory)][string] $ArchivePath)

    $expectedModules = @('Pscx', 'Pscx.Archive', 'Pscx.Time')
    if ($resolvedBuildScope -eq 'Full') {
        $expectedModules += 'Pscx.WinAdmin'
    }

    $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $entries = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\\', '/') })
        $fileEntries = @($archive.Entries | Where-Object { $_.Name } |
                ForEach-Object { $_.FullName.Replace('\\', '/') })
        $topLevelNames = @($entries | ForEach-Object { ($_ -split '/')[0] } | Sort-Object -Unique)
        $unexpectedRoots = @($topLevelNames | Where-Object { $_ -notin $expectedModules })
        if ($unexpectedRoots.Count -gt 0) {
            throw "The release ZIP contains unexpected roots: $($unexpectedRoots -join ', ')."
        }

        foreach ($moduleName in $expectedModules) {
            $versionPrefix = "$moduleName/$moduleVersion/"
            $moduleEntries = @($fileEntries | Where-Object { $_.StartsWith("$moduleName/") })
            if ($moduleEntries.Count -eq 0) {
                throw "The release ZIP contains no files for '$moduleName'."
            }
            $misplacedEntries = @($moduleEntries | Where-Object { -not $_.StartsWith($versionPrefix) })
            if ($misplacedEntries.Count -gt 0) {
                throw "The release ZIP contains files outside '$versionPrefix': $($misplacedEntries -join ', ')."
            }
            $manifestEntry = "$versionPrefix$moduleName.psd1"
            if ($manifestEntry -notin $fileEntries) {
                throw "The release ZIP is missing '$manifestEntry'."
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}

function Invoke-Validate {
    Write-Step 'Validate version and package'

    $sourceVersionLocations = @(
        'Src/ConsoleApp/ConsoleApp.csproj',
        'Src/Pscx/Pscx.csproj',
        'Src/Pscx.Core/Pscx.Core.csproj',
        'Src/Pscx.Archive/Pscx.Archive.csproj',
        'Src/Pscx.Time/Pscx.Time.csproj',
        'Src/Pscx.WinAdmin/Pscx.WinAdmin.csproj',
        'Src/Pscx.InternalTests/Pscx.InternalTests.csproj',
        'Src/Pscx.Win/Pscx.Win.csproj',
        'Src/AssemblyInfo.Shared.cs',
        'Src/Pscx.Core/Properties/PscxAssemblyInfo.cs',
        '.github/workflows'
    )

    foreach ($location in $sourceVersionLocations) {
        $path = Join-Path $repositoryRoot $location
        $files = if (Test-Path -LiteralPath $path -PathType Container) {
            Get-ChildItem -LiteralPath $path -Recurse -File
        }
        else {
            Get-Item -LiteralPath $path
        }

        foreach ($file in $files) {
            if ((Get-Content -LiteralPath $file.FullName -Raw) -match [regex]::Escape($moduleVersion)) {
                throw "The semantic version is duplicated in $(Get-RelativePath $file.FullName); keep it only in Directory.Build.props."
            }
        }
    }

    $sourceManifests = Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'Src') -Recurse -Filter *.psd1 -File |
        Where-Object {
            $_.FullName -notmatch '[\\/](bin|obj)[\\/]' -and
            (Get-Content -LiteralPath $_.FullName -Raw) -match '(?m)^\s*ModuleVersion\s*='
        }
    foreach ($manifest in $sourceManifests) {
        $data = Import-PowerShellDataFile -LiteralPath $manifest.FullName
        if ($data.ModuleVersion -ne [version]'0.0.0') {
            throw "Source manifest $(Get-RelativePath $manifest.FullName) must use the 0.0.0 build-time placeholder."
        }
        if ($data.PowerShellVersion -ne [version]'0.0') {
            throw "Source manifest $(Get-RelativePath $manifest.FullName) must use the 0.0 PowerShell-version placeholder."
        }
    }

    $manifestPath = Join-Path $moduleRoot 'Pscx.psd1'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "The staged package is missing. Run the Package task first."
    }

    $manifest = Test-ModuleManifest -Path $manifestPath
    if ($manifest.Version -ne [version]$moduleVersion) {
        throw "Staged module version '$($manifest.Version)' does not match '$moduleVersion'."
    }
    if ($manifest.PowerShellVersion -ne [version]$powerShellMinimumVersion) {
        throw "Staged PowerShell requirement '$($manifest.PowerShellVersion)' does not match '$powerShellMinimumVersion'."
    }

    if ($manifestPrerelease -and $manifest.PrivateData.PSData.Prerelease -ne $manifestPrerelease) {
        throw "Staged module prerelease '$($manifest.PrivateData.PSData.Prerelease)' does not match '$manifestPrerelease'."
    }

    $archiveManifestPath = Join-Path $archiveModuleRoot 'Pscx.Archive.psd1'
    $archiveManifest = Test-ModuleManifest -Path $archiveManifestPath
    if ($archiveManifest.Version -ne [version]$moduleVersion -or
        $archiveManifest.PowerShellVersion -ne [version]$powerShellMinimumVersion) {
        throw 'The staged Pscx.Archive manifest does not match the centralized version policy.'
    }
    if ($manifestPrerelease -and $archiveManifest.PrivateData.PSData.Prerelease -ne $manifestPrerelease) {
        throw "Staged Pscx.Archive prerelease '$($archiveManifest.PrivateData.PSData.Prerelease)' does not match '$manifestPrerelease'."
    }

    $timeManifestPath = Join-Path $timeModuleRoot 'Pscx.Time.psd1'
    $timeManifest = Test-ModuleManifest -Path $timeManifestPath
    if ($timeManifest.Version -ne [version]$moduleVersion -or
        $timeManifest.PowerShellVersion -ne [version]$powerShellMinimumVersion) {
        throw 'The staged Pscx.Time manifest does not match the centralized version policy.'
    }
    if ($manifestPrerelease -and $timeManifest.PrivateData.PSData.Prerelease -ne $manifestPrerelease) {
        throw "Staged Pscx.Time prerelease '$($timeManifest.PrivateData.PSData.Prerelease)' does not match '$manifestPrerelease'."
    }

    $winAdminManifestPath = Join-Path $winAdminModuleRoot 'Pscx.WinAdmin.psd1'
    if ($resolvedBuildScope -eq 'Full') {
        $winAdminManifest = Import-PowerShellDataFile -LiteralPath $winAdminManifestPath
        if ([version]$winAdminManifest.ModuleVersion -ne [version]$moduleVersion -or
            [version]$winAdminManifest.PowerShellVersion -ne [version]$powerShellMinimumVersion) {
            throw 'The staged Pscx.WinAdmin manifest does not match the centralized version policy.'
        }
        if ($manifestPrerelease -and
            $winAdminManifest.PrivateData.PSData.Prerelease -ne $manifestPrerelease) {
            throw "Staged Pscx.WinAdmin prerelease '$($winAdminManifest.PrivateData.PSData.Prerelease)' does not match '$manifestPrerelease'."
        }
    }
    elseif (Test-Path -LiteralPath $winAdminManifestPath) {
        throw 'A Core package must not contain Pscx.WinAdmin.'
    }

    $assemblyNames = @('Pscx.Core.dll', 'Pscx.dll')
    if ($resolvedBuildScope -eq 'Full') {
        $assemblyNames += 'Pscx.Win.dll'
    }
    elseif (Test-Path -LiteralPath (Join-Path $moduleRoot 'Pscx.Win.dll')) {
        throw 'A Core package must not contain Pscx.Win.dll.'
    }

    foreach ($assemblyName in $assemblyNames) {
        $assemblyPath = Join-Path $moduleRoot $assemblyName
        $assemblyVersion = [System.Reflection.AssemblyName]::GetAssemblyName($assemblyPath).Version
        $fileInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($assemblyPath)
        if ($assemblyVersion.ToString() -ne "$moduleVersion.0") {
            throw "$assemblyName has assembly version '$assemblyVersion'; expected '$moduleVersion.0'."
        }
        if ($fileInfo.FileVersion -ne "$moduleVersion.$BuildNumber") {
            throw "$assemblyName has file version '$($fileInfo.FileVersion)'; expected '$moduleVersion.$BuildNumber'."
        }
        if ($fileInfo.ProductVersion -ne $informationalVersion) {
            throw "$assemblyName has informational version '$($fileInfo.ProductVersion)'; expected '$informationalVersion'."
        }
    }

    $archiveAssemblyPath = Join-Path $archiveModuleRoot 'Pscx.Archive.dll'
    $archiveAssemblyVersion = [System.Reflection.AssemblyName]::GetAssemblyName($archiveAssemblyPath).Version
    $archiveFileInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($archiveAssemblyPath)
    if ($archiveAssemblyVersion.ToString() -ne "$moduleVersion.0" -or
        $archiveFileInfo.FileVersion -ne "$moduleVersion.$BuildNumber" -or
        $archiveFileInfo.ProductVersion -ne $informationalVersion) {
        throw 'Pscx.Archive.dll does not match the centralized assembly version policy.'
    }

    $timeAssemblyPath = Join-Path $timeModuleRoot 'Pscx.Time.dll'
    $timeAssemblyVersion = [System.Reflection.AssemblyName]::GetAssemblyName($timeAssemblyPath).Version
    $timeFileInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($timeAssemblyPath)
    if ($timeAssemblyVersion.ToString() -ne "$moduleVersion.0" -or
        $timeFileInfo.FileVersion -ne "$moduleVersion.$BuildNumber" -or
        $timeFileInfo.ProductVersion -ne $informationalVersion) {
        throw 'Pscx.Time.dll does not match the centralized assembly version policy.'
    }

    if ($resolvedBuildScope -eq 'Full') {
        $winAdminAssemblyPath = Join-Path $winAdminModuleRoot 'Pscx.WinAdmin.dll'
        $winAdminAssemblyVersion =
            [System.Reflection.AssemblyName]::GetAssemblyName($winAdminAssemblyPath).Version
        $winAdminFileInfo =
            [System.Diagnostics.FileVersionInfo]::GetVersionInfo($winAdminAssemblyPath)
        if ($winAdminAssemblyVersion.ToString() -ne "$moduleVersion.0" -or
            $winAdminFileInfo.FileVersion -ne "$moduleVersion.$BuildNumber" -or
            $winAdminFileInfo.ProductVersion -ne $informationalVersion) {
            throw 'Pscx.WinAdmin.dll does not match the centralized assembly version policy.'
        }

        $mainCoreAssemblyPath = Join-Path $moduleRoot 'Pscx.Core.dll'
        $winAdminCoreAssemblyPath = Join-Path $winAdminModuleRoot 'Pscx.Core.dll'
        if ((Get-FileHash -LiteralPath $mainCoreAssemblyPath -Algorithm SHA256).Hash -ne
            (Get-FileHash -LiteralPath $winAdminCoreAssemblyPath -Algorithm SHA256).Hash) {
            throw 'The Pscx and Pscx.WinAdmin copies of Pscx.Core.dll are not identical.'
        }
    }

    $forbiddenMainPayload = @(
        'Pscx.Archive.dll',
        'Pscx.WinAdmin.dll',
        'Pscx.Time.dll',
        'NodaTime.dll',
        'NodaTime.xml',
        'SharpCompress.dll',
        'SevenZipSharp.dll',
        '7z.dll',
        '7z.exe',
        '7zz'
    )
    foreach ($name in $forbiddenMainPayload) {
        if (Get-ChildItem -LiteralPath $moduleRoot -Recurse -File -Filter $name) {
            throw "The default Pscx package must not contain optional or legacy archive payload '$name'."
        }
    }
    $archivePayloadNames = @(Get-ChildItem -LiteralPath $archiveModuleRoot -Recurse -File | Select-Object -ExpandProperty Name)
    if ($archivePayloadNames -match 'SevenZipSharp|^(7z\.dll|7z\.exe|7zz)$') {
        throw 'Pscx.Archive must contain only the managed SharpCompress backend, not legacy native payloads.'
    }

    $binaryValidationArguments = @(
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-File',
        (Join-Path $repositoryRoot 'Tools/Test-PscxRedistributedBinary.ps1'),
        '-PackageRoot',
        (Join-Path $artifactsRoot 'module'),
        '-ResultsPath',
        (Join-Path $testResultsPath 'Pscx.PackageContents.json')
    )
    if ($resolvedBuildScope -eq 'Full') {
        $binaryValidationArguments += '-ExpectedWindowsPayload'
    }
    Invoke-NativeCommand $PowerShellPath $binaryValidationArguments

    $archivePath = Join-Path $packageOutputPath "Pscx-$packageVersion.zip"
    if (-not (Test-Path -LiteralPath $archivePath)) {
        throw "Expected package archive is missing: $(Get-RelativePath $archivePath)"
    }
    Assert-ReleaseArchiveLayout -ArchivePath $archivePath
    $changeLogPath = Join-Path $moduleRoot 'CHANGELOG.md'
    $changeLogContent = Get-Content -LiteralPath $changeLogPath -Raw
    if ($changeLogContent -notmatch "(?m)^##\s+$([regex]::Escape($moduleVersion))(?:\s|$)") {
        throw "The packaged changelog has no $moduleVersion release heading."
    }

    Invoke-NativeCommand $PowerShellPath @(
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-File',
        (Join-Path $repositoryRoot 'Tools/Test-PscxPackage.ps1'),
        '-ManifestPath',
        $manifestPath,
        '-ExpectedBuildScope',
        $resolvedBuildScope
    )
}

function Invoke-ImportTest {
    $manifestCandidates = @(
        @(
            (Join-Path $moduleRoot 'Pscx.psd1'),
            (Join-Path $moduleRoot "$moduleVersion/Pscx.psd1")
        ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    )
    if ($manifestCandidates.Count -ne 1) {
        throw "Expected exactly one staged or versioned Pscx manifest; found $($manifestCandidates.Count)."
    }
    $manifestPath = $manifestCandidates[0]

    New-Item -ItemType Directory -Path $testResultsPath -Force | Out-Null
    $versionLabel = if ($ExpectedPowerShellVersion) {
        $ExpectedPowerShellVersion
    }
    else {
        'host'
    }
    $platformLabel = if ($IsWindows) {
        'windows'
    }
    elseif ($IsMacOS) {
        'macos'
    }
    else {
        'linux'
    }
    $resultsPath = Join-Path $testResultsPath "import-$platformLabel-pwsh-$versionLabel.json"

    Write-Step "Test packaged import with PowerShell $versionLabel"
    $arguments = @(
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-File',
        (Join-Path $repositoryRoot 'Tools/Test-PscxPackage.ps1'),
        '-ManifestPath',
        $manifestPath,
        '-ExpectedBuildScope',
        $resolvedBuildScope,
        '-ResultsPath',
        $resultsPath
    )
    if ($ExpectedPowerShellVersion) {
        $arguments += @('-ExpectedPowerShellVersion', $ExpectedPowerShellVersion)
    }
    Invoke-NativeCommand $PowerShellPath $arguments
}

function Invoke-Audit {
    Write-Step 'Audit dependencies'
    Invoke-NativeCommand dotnet @('restore', $solutionPath, '--nologo')
    Invoke-NativeCommand dotnet @(
        'package',
        'list',
        '--project',
        $solutionPath,
        '--include-transitive',
        '--vulnerable',
        '--no-restore'
    )
}

function Assert-UnsignedPscxBinaries {
    if (-not $IsWindows) {
        return
    }

    $signedBinaries = @(
        Get-ChildItem -LiteralPath @(
            $moduleRoot,
            $archiveModuleRoot,
            $timeModuleRoot,
            $winAdminModuleRoot
        ) -Filter 'Pscx*.dll' -File -ErrorAction SilentlyContinue |
            Where-Object {
                (Get-AuthenticodeSignature -LiteralPath $_.FullName).Status -ne 'NotSigned'
            }
    )
    if ($signedBinaries.Count -gt 0) {
        $names = $signedBinaries.Name -join ', '
        throw "Release PSCX binaries must remain Authenticode-unsigned: $names"
    }
}

function Invoke-InstalledPackageTest {
    $archivePath = Join-Path $packageOutputPath "Pscx-$packageVersion.zip"
    Write-Step 'Validate bundled modules from the release ZIP in clean environments'
    foreach ($releasePackage in @(
        @{ Path = $archivePath; ModuleName = 'Pscx' },
        @{ Path = $archivePath; ModuleName = 'Pscx.Archive' }
        @{ Path = $archivePath; ModuleName = 'Pscx.Time' }
        if ($resolvedBuildScope -eq 'Full') {
            @{ Path = $archivePath; ModuleName = 'Pscx.WinAdmin' }
        }
    )) {
        Invoke-NativeCommand $PowerShellPath @(
            '-NoLogo',
            '-NoProfile',
            '-NonInteractive',
            '-File',
            (Join-Path $repositoryRoot 'Tools/Test-PscxReleasePackage.ps1'),
            '-PackagePath',
            $releasePackage.Path,
            '-ExpectedBuildScope',
            $resolvedBuildScope,
            '-ExpectedVersion',
            $moduleVersion,
            '-ModuleName',
            $releasePackage.ModuleName,
            '-PowerShellPath',
            $PowerShellPath
        )
    }
}

function New-ReleaseSbom {
    param(
        [string] $PackageName,
        [string] $ModulePath
    )

    $sbomToolRoot = Join-Path $repositoryRoot ".tools/sbom/$sbomToolVersion"
    $sbomExecutable = Join-Path $sbomToolRoot $(
        if ($IsWindows) { 'sbom-tool.exe' } else { 'sbom-tool' }
    )
    if (-not (Test-Path -LiteralPath $sbomExecutable -PathType Leaf)) {
        New-Item -ItemType Directory -Path $sbomToolRoot -Force | Out-Null
        Invoke-NativeCommand dotnet @(
            'tool',
            'install',
            'Microsoft.Sbom.DotNetTool',
            '--tool-path',
            $sbomToolRoot,
            '--version',
            $sbomToolVersion
        ) | Out-Host
    }

    $manifestRoot = Join-Path $ModulePath '_manifest'
    Remove-BuildDirectory $manifestRoot
    Write-Step "Generate SPDX 2.2 SBOM with Microsoft SBOM Tool $sbomToolVersion"
    Invoke-NativeCommand $sbomExecutable @(
        'generate',
        '-b',
        $ModulePath,
        '-bc',
        (Join-Path $repositoryRoot 'Src'),
        '-pn',
        $PackageName,
        '-pv',
        $packageVersion,
        '-ps',
        'PowerShell Core Community Extensions',
        '-nsb',
        'https://github.com/danluca/Pscx',
        '-mi',
        'SPDX:2.2'
    ) | Out-Host

    $generatedSbom = Join-Path $manifestRoot 'spdx_2.2/manifest.spdx.json'
    if (-not (Test-Path -LiteralPath $generatedSbom -PathType Leaf)) {
        throw "The SBOM tool did not create its expected manifest: $generatedSbom"
    }

    $validationPath = Join-Path $testResultsPath "$PackageName.Sbom.validation.json"
    New-Item -ItemType Directory -Path $testResultsPath -Force | Out-Null
    Invoke-NativeCommand $sbomExecutable @(
        'validate',
        '-b',
        $ModulePath,
        '-o',
        $validationPath,
        '-mi',
        'SPDX:2.2'
    ) | Out-Host

    $sbomPath = Join-Path $packageOutputPath "$PackageName-$packageVersion.spdx.json"
    Copy-Item -LiteralPath $generatedSbom -Destination $sbomPath -Force
    Remove-BuildDirectory $manifestRoot
    return $sbomPath
}

function New-ReleaseChecksums {
    param([string[]] $AssetPath)

    Write-Step 'Generate SHA-256 release checksums'
    $lines = foreach ($path in $AssetPath) {
        $resolvedPath = (Resolve-Path -LiteralPath $path).Path
        $hash = (Get-FileHash -LiteralPath $resolvedPath -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $([IO.Path]::GetFileName($resolvedPath))"
    }
    $checksumPath = Join-Path $packageOutputPath "Pscx-$packageVersion.sha256"
    Set-Content -LiteralPath $checksumPath -Value $lines -Encoding utf8
    return $checksumPath
}

function Invoke-PublishPrep {
    param([switch] $AlreadyValidated)

    if (-not $AlreadyValidated) {
        Invoke-Validate
    }
    $archivePath = Join-Path $packageOutputPath "Pscx-$packageVersion.zip"
    Invoke-InstalledPackageTest
    Assert-UnsignedPscxBinaries
    Invoke-NativeCommand $PowerShellPath @(
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-File',
        (Join-Path $repositoryRoot 'Tools/Test-PscxReleaseSecurity.ps1'),
        '-PackagePath',
        $archivePath,
        '-ResultsPath',
        (Join-Path $testResultsPath 'Pscx.ReleaseSecurity.json')
    )
    $sbomPath = New-ReleaseSbom -PackageName Pscx -ModulePath (Join-Path $artifactsRoot 'module')
    $checksumPath = New-ReleaseChecksums -AssetPath @($archivePath, $sbomPath)

    Write-Step 'Release preparation complete'
    Write-Host "Package : $(Get-RelativePath $archivePath)"
    Write-Host "SBOM    : $(Get-RelativePath $sbomPath)"
    Write-Host "SHA-256 : $(Get-RelativePath $checksumPath)"
    Write-Host 'GitHub Releases are the only publication channel; CI does not sign PSCX binaries or PowerShell files.'
}

[xml] $versionDocument = Get-Content -LiteralPath $versionFilePath -Raw
$testPolicy = Import-PowerShellDataFile -LiteralPath $testPolicyFilePath
$sbomToolVersion = [string]$testPolicy.SbomToolVersion
$artifactPathRoot = [System.IO.Path]::GetPathRoot($artifactsRoot).TrimEnd('\', '/')
if ($artifactsRoot.TrimEnd('\', '/') -eq $artifactPathRoot) {
    throw "ArtifactsPath cannot be a filesystem root: $artifactsRoot"
}
$protectedRepositoryPaths = @(
    $repositoryRoot,
    (Join-Path $repositoryRoot '.git'),
    (Join-Path $repositoryRoot '.github'),
    (Join-Path $repositoryRoot 'Src'),
    (Join-Path $repositoryRoot 'Tools')
) | ForEach-Object { [System.IO.Path]::GetFullPath($_).TrimEnd('\', '/') }
if ($artifactsRoot.TrimEnd('\', '/') -in $protectedRepositoryPaths) {
    throw "ArtifactsPath cannot replace a protected repository directory: $artifactsRoot"
}

$semanticVersion = [string]$versionDocument.Project.PropertyGroup.PscxVersionPrefix
$powerShellMinimumVersion = [string]$versionDocument.Project.PropertyGroup.PowerShellMinimumVersion
$powerShellSdkVersion = [string]$versionDocument.Project.PropertyGroup.PowerShellSdkVersion
$parsedPowerShellVersion = $null
if (-not [version]::TryParse($powerShellMinimumVersion, [ref]$parsedPowerShellVersion)) {
    throw "PowerShellMinimumVersion '$powerShellMinimumVersion' is invalid."
}
$parsedPowerShellVersion = $null
if (-not [version]::TryParse($powerShellSdkVersion, [ref]$parsedPowerShellVersion)) {
    throw "PowerShellSdkVersion '$powerShellSdkVersion' is invalid."
}
$versionMatch = [regex]::Match(
    $semanticVersion,
    '^(?<module>\d+\.\d+\.\d+)(?:-(?<prerelease>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$'
)
if (-not $versionMatch.Success) {
    throw "PscxVersionPrefix '$semanticVersion' is not a supported semantic version."
}

$moduleVersion = $versionMatch.Groups['module'].Value
$sourcePrerelease = $versionMatch.Groups['prerelease'].Value

if (-not $CommitSha) {
    $gitSha = & git -C $repositoryRoot rev-parse --verify HEAD 2>$null
    $CommitSha = if ($LASTEXITCODE -eq 0) { $gitSha } else { 'local' }
}
$shortCommitSha = if ($CommitSha -eq 'local') {
    'local'
}
else {
    $CommitSha.Substring(0, [Math]::Min(7, $CommitSha.Length))
}

if ($Release) {
    $packageVersion = $semanticVersion
    $manifestPrerelease = $sourcePrerelease
}
elseif ($BuildNumber -gt 0) {
    $manifestPrerelease = @($sourcePrerelease, "ci.$BuildNumber") |
        Where-Object { $_ } |
        Join-String -Separator '.'
    $packageVersion = "$moduleVersion-$manifestPrerelease"
}
else {
    $packageVersion = $semanticVersion
    $manifestPrerelease = $sourcePrerelease
}

$informationalVersion = "$packageVersion+build.$BuildNumber.sha.$shortCommitSha"

if ($ExpectedTag) {
    $expectedVersionTag = "v$semanticVersion"
    if ($ExpectedTag -ne $expectedVersionTag) {
        throw "Release tag '$ExpectedTag' does not match the authoritative version '$expectedVersionTag'."
    }
}

$expandedTasks = foreach ($item in $Task) {
    if ($item -in 'CI', 'TestPipeline') {
        'Clean', 'Restore', 'Compile', 'Package', 'UnifiedTest', 'Validate'
    }
    else {
        $item
    }
}

Write-Host "PSCX semantic version : $semanticVersion"
Write-Host "Package version       : $packageVersion"
Write-Host "Assembly version      : $moduleVersion.0"
Write-Host "File version          : $moduleVersion.$BuildNumber"
Write-Host "Informational version : $informationalVersion"
Write-Host "Artifacts             : $artifactsRoot"
Write-Host "Build scope           : $resolvedBuildScope"
Write-Host "PowerShell support    : $powerShellMinimumVersion - $powerShellSdkVersion"

$validated = $false
foreach ($item in $expandedTasks) {
    switch ($item) {
        Clean { Invoke-Clean }
        Restore { Invoke-Restore }
        Compile { Invoke-Compile }
        Help { Invoke-Help }
        Test { Invoke-Test }
        Pester { Invoke-PesterTest }
        Static { Invoke-StaticValidation }
        Dashboard { Invoke-TestDashboard }
        Catalog { Invoke-Catalog }
        UnifiedTest { Invoke-UnifiedTest }
        ImportTest { Invoke-ImportTest }
        Package { Invoke-Package }
        Validate {
            Invoke-Validate
            $validated = $true
        }
        Audit { Invoke-Audit }
        PublishPrep { Invoke-PublishPrep -AlreadyValidated:$validated }
    }
}


# SIG # Begin signature block
# MIInmgYJKoZIhvcNAQcCoIInizCCJ4cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA/IoFSq3fsV2dC
# nPU4pGYhIIUpVo0G61xM6ADgd/FTPqCCIHEwggWNMIIEdaADAgECAhAOmxiO+dAt
# 5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBa
# Fw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lD
# ZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3E
# MB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKy
# unWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsF
# xl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU1
# 5zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJB
# MtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObUR
# WBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6
# nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxB
# YKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5S
# UUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+x
# q4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIB
# NjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwP
# TzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMC
# AYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0Nc
# Vec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnov
# Lbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65Zy
# oUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFW
# juyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPF
# mCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9z
# twGpn1eqXijiuZQwggaUMIIEfKADAgECAgh1RsL97PvpATANBgkqhkiG9w0BAQsF
# ADCBljELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAk1OMRQwEgYDVQQHEwtNaW5uZWFw
# b2xpczESMBAGA1UEChMJTHVjYSBIb21lMQ8wDQYDVQQLEwZPZmZpY2UxGzAZBgNV
# BAMTEkx1Y2FzIENvZGUgUm9vdCBDQTEiMCAGCSqGSIb3DQEJARYTZGFubHVjYUBj
# b21jYXN0Lm5ldDAeFw0yMjAzMjYwMDAwMDBaFw00OTAzMjUyMzU5NTlaMIGVMQsw
# CQYDVQQGEwJVUzELMAkGA1UECBMCTU4xFDASBgNVBAcTC01pbm5lYXBvbGlzMRIw
# EAYDVQQKEwlMdWNhIEhvbWUxDzANBgNVBAsTBk9mZmljZTEaMBgGA1UEAxMRTHVj
# YXMgQ29kZSBSU0EgQ0ExIjAgBgkqhkiG9w0BCQEWE2Rhbmx1Y2FAY29tY2FzdC5u
# ZXQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDNxe4oUxTG+YdtMgDm
# PStZVzsgBoBPBD/2Y9Zsxaaj26ZknpP22kONwySOjVcqMolJwWAOyJtKyzxCCT2c
# bOdwS1ZoAZKpUjmB3HJeMmdhwlTth4irqmK5C/8lxB0Va+jelxEMXTceCd7I6YkW
# w4l23Yq1+Y1Qv+dIifsm7BOYidWzR9aSuGrSdizNk1giewDAYo8l5RhOEoRgWFHx
# vuM0lHcTmT+6U1IgBE+06I7FS/uQ8g/ajQJVm6QAXlCkNeFg3EbEtEyQbdUEKcDS
# a7O88OpnA5j3/UAfEXZfizr9d2GY86gMjE3QDiGr51I4uWcA2gmecZxXUpc2XWFu
# UBu3ikOAJTOTMq9Pi5tN7ZQwKzJQLESdJ8So73dJcI/hW6Bf2k2x17ldY/GO3KEf
# t8KtxSr9kLQ4fYiIhLdHDtje0Zm8QSQFabrE94ci8kB0tFM+7FuQ51E8YiU9fhk3
# eh1sHLwEXg1m7uea6YPFdlpSbx17EpfSnBeeWiH/LNkttTg2Mb7oogVDlecv31Ng
# TqbZzQ7MPRdjrW3L9HxU6YvKo7/cxzGRltmG1daA4pKc0KVUQ6RXL9WRKLQyEbdg
# uTfkXKS9jMtr0h52Zvw7fW3qCGyqI8BhANjPYiCsftckkx0KPefmsQNT/w+m4Qu/
# 97qycOhyLKfpndb9IJkEOcAu0wIDAQABo4HkMIHhMA8GA1UdEwEB/wQFMAMBAf8w
# HQYDVR0OBBYEFIBmtZ8QfiC4XB0vz9YiGsofRq8hMA4GA1UdDwEB/wQEAwIBxjAz
# BgNVHSUELDAqBggrBgEFBQcDAwYIKwYBBQUHAwgGCisGAQQBgjcCARUGCCsGAQUF
# BwMJMDEGA1UdEQQqMCiBEXNsdWNhQGNvbWNhc3QubmV0gRNkYW5sdWNhQGNvbWNh
# c3QubmV0MBEGCWCGSAGG+EIBAQQEAwIAATAkBglghkgBhvhCAQ0EFxYVTHVjYXMg
# Q29kZSBTaWduaW5nIENBMA0GCSqGSIb3DQEBCwUAA4ICAQByKgofmdGXu4v40lYW
# DUL7otFJstfYcp0S7SQpSMIGwNj89kdWENU9ciYYq70qy781kLLIDwyGSwwAju3w
# MqtbiAWhjKGuEXKQROHTs/HtPBEZ9NL99IVdhc+/DT9UzP/fpPk6N/TOaTGQQsmw
# vWovGtnprAxWcGwyDS/jtRrWv1MaiYjtoOFOIAwcsOdkd3sNl5P+VJLTRlQAnrgi
# 55vkFyibH5cgbXvcYg3SLOw9HEi5hUpQ76DdzqCa/CX4sqPstWNlKjQ8ehfi6AGa
# guFC25HcOhhoNZjjlgOP7a5i8KG/Gh2JuYmu8SkWivHJwMswLy3M6Vpd9euNXNSr
# 46EQ4iafNlij5rRxRQuPsjT/q4A4g3HCJZUBCN0HlXmJwiG/yRNJSvjsKGabW2qQ
# NilU2blO9JVRZKPnLGaKai6aRRHQ225kopalRPK4oTtkBjnJzbnXfECHNh0C3qIl
# 0MmgJ7Yf1HrGfj425zC56bH8jCJv3H3G3B4DdDDpRAQbW3/vsypPSce7YoB0JCYt
# UU95KI09G5Dl9GuGtupIaMfs05ECAQTGXvF6Olq6sRTyf7JROTmKBpiJO62a8xEg
# kTmJ9ZLrzBHNqVNzoljx+Zaa+5I3K5a1y6nccG26Th2+m/42kGm1XqfEyUbZybXB
# E5FC/7m39/hu0d703lrl32FtozCCBpswggSDoAMCAQICCAbX5YewM+U2MA0GCSqG
# SIb3DQEBCwUAMIGVMQswCQYDVQQGEwJVUzELMAkGA1UECBMCTU4xFDASBgNVBAcT
# C01pbm5lYXBvbGlzMRIwEAYDVQQKEwlMdWNhIEhvbWUxDzANBgNVBAsTBk9mZmlj
# ZTEaMBgGA1UEAxMRTHVjYXMgQ29kZSBSU0EgQ0ExIjAgBgkqhkiG9w0BCQEWE2Rh
# bmx1Y2FAY29tY2FzdC5uZXQwHhcNMjIwMzI2MDAwMDAwWhcNNDcwMzI1MjM1OTU5
# WjCBjDELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAk1OMRQwEgYDVQQHEwtNaW5uZWFw
# b2xpczESMBAGA1UEChMJTHVjYSBIb21lMQ8wDQYDVQQLEwZPZmZpY2UxETAPBgNV
# BAMTCERhbiBMdWNhMSIwIAYJKoZIhvcNAQkBFhNkYW5sdWNhQGNvbWNhc3QubmV0
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAt5i4r1HEGsNrSWsxNzkV
# A/opuBv3Xisr1Km43wuCW9BKaM73FlgPbPrOo1ynxsWAmvrOv2RKctcxqaEdhvY1
# aioK9HYu/OhCOwIbINnJFUDp3ecdJOFloUC7bE1eccGHRv40fUjLTNT7wcFaYjv7
# G+7jUhvL88BGSneBjyS2RXCn1EpFU0MmJ055tNyAL3zCBfGdtGqilMttfE63Nxf4
# uQfvT5Nloub5V2z07lx/uwA1ZE7pKXiHkZh4auLsb74d+nRKZhwUfKB9c42qfJMU
# iA9wlBbxMZ2Yxb9r+COJsB/TOGGyC1kdDgJ1M1XbxERgsf0FnUJOFCy/n5aozgW6
# hwM/UXxzAQKwLaRkjrk06G7MyYegL6XvHN0EFTFVg1VDFlFOvQ4OCNEtuEcMEfsN
# LFPxiVrfJf3NxcuX3VNMoJwXT716H4cVmvl3z8zWdWikRfUpkDuk17/lN+61KLss
# DMGaj3uGC8xxOWiUCR5Lg9P5dUIIjgGqNhFKiHJE7LvXZ7H63/yh1967P/C1h7mf
# u+3/vZ98H4nXfLCJ4jmAigUYG6jVZffeeogbcfgGR8v9c15binUdD3lWMQ3/PpdI
# GLsENA8MHqXVC/SAnvKm5pqVpFWOXqyBX3u2BJ9utF27Nsb2RoJqCFt7bB2engxM
# adPGGdJc2GbnuSMtdSV5chECAwEAAaOB9TCB8jAMBgNVHRMBAf8EAjAAMB0GA1Ud
# DgQWBBQZJ4PIxOjVfCmSYMBKp3+E/s/h4zAOBgNVHQ8BAf8EBAMCBsAwNQYDVR0l
# BC4wLAYIKwYBBQUHAwMGCCsGAQUFBwMIBgorBgEEAYI3AgEVBgorBgEEAYI3AgEW
# MDMGA1UdEQQsMCqBE2Rhbmx1Y2FAY29tY2FzdC5uZXSBE2Rhbmx1Y2EyMkBnbWFp
# bC5jb20wEQYJYIZIAYb4QgEBBAQDAgQQMDQGCWCGSAGG+EIBDQQnFiVEYW4gTHVj
# YSBjZXJ0aWZpY2F0ZSBmb3IgY29kZSBzaWduaW5nMA0GCSqGSIb3DQEBCwUAA4IC
# AQBIoCyjFppNigfzbRKb48zLEm3Imhuui2cJzAjYdex2WxWgcMbnklGvFuMwP6+K
# HtCMg2Q/vkEh3vM2iyh/fmKlYMGcJtTjzeE3bkStHl6AuYwBEC7xofNAg1SQBWGK
# iOeANeGJj88J8vLpMtKFMTAwf824EJzItZPpxLybdpv14XIeo9Gku6yd/hWticee
# xHbH5cXmBNkMlUPhaP8XpgnF4mF1QKRFNi3OmM36o/r2uVg2M5GXMRb9/FRTjeOz
# ApCmLhee0xF+42iAeYCYpkveMZra0CIcYnViyWeJi+xyx1OP7ZL8cVuIwDXvv3tk
# luAVwobgmwFz6tAMLzblQfUlE9WTdQrA0pzEg1jniWt2O95I+7JDieTP1CM1KxRw
# s2u8vJoxzls47ZmdiIoHcRO9exVUrfUF8rKIORaanY4fUwIiUQiie8GrUMTKrQCk
# Ly8/qN/YJyKxQmlKJxCqyfjoH7FvmaDqtdHaOhweiqF18HhymnHMblrIgctoEPqh
# 3/GURELo9yAhgZRTorw3jS8+uY2b2JRC7+EIbf4GS6rOYvgbdUBpGHRiaA0AeY7F
# 7J0DZncUy1yL1jj1/UzngrC7FIZXVF0WT3b59T5wm7fBo2642lRgD2eVXyj5Ygn4
# EebBYhHzbPbXhSUfdKFro6bVrzSp+a3MY+E0GlDUeLf6rjCCBrQwggScoAMCAQIC
# EA3HrFcF/yGZLkBDIgw6SYYwDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMx
# FTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNv
# bTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTI1MDUwNzAw
# MDAwMFoXDTM4MDExNDIzNTk1OVowaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRp
# Z2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVT
# dGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBALR4MdMKmEFyvjxGwBysddujRmh0tFEXnU2tjQ2UtZmW
# gyxU7UNqEY81FzJsQqr5G7A6c+Gh/qm8Xi4aPCOo2N8S9SLrC6Kbltqn7SWCWgzb
# NfiR+2fkHUiljNOqnIVD/gG3SYDEAd4dg2dDGpeZGKe+42DFUF0mR/vtLa4+gKPs
# YfwEu7EEbkC9+0F2w4QJLVSTEG8yAR2CQWIM1iI5PHg62IVwxKSpO0XaF9DPfNBK
# S7Zazch8NF5vp7eaZ2CVNxpqumzTCNSOxm+SAWSuIr21Qomb+zzQWKhxKTVVgtmU
# PAW35xUUFREmDrMxSNlr/NsJyUXzdtFUUt4aS4CEeIY8y9IaaGBpPNXKFifinT7z
# L2gdFpBP9qh8SdLnEut/GcalNeJQ55IuwnKCgs+nrpuQNfVmUB5KlCX3ZA4x5HHK
# S+rqBvKWxdCyQEEGcbLe1b8Aw4wJkhU1JrPsFfxW1gaou30yZ46t4Y9F20HHfIY4
# /6vHespYMQmUiote8ladjS/nJ0+k6MvqzfpzPDOy5y6gqztiT96Fv/9bH7mQyogx
# G9QEPHrPV6/7umw052AkyiLA6tQbZl1KhBtTasySkuJDpsZGKdlsjg4u70EwgWbV
# RSX1Wd4+zoFpp4Ra+MlKM2baoD6x0VR4RjSpWM8o5a6D8bpfm4CLKczsG7ZrIGNT
# AgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBTvb1NK
# 6eQGfHrK4pBW9i/USezLTjAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qYrhwP
# TzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYBBQUH
# AQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYI
# KwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRy
# dXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZMBcw
# CAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAF877FoAc
# /gc9EXZxML2+C8i1NKZ/zdCHxYgaMH9Pw5tcBnPw6O6FTGNpoV2V4wzSUGvI9NAz
# aoQk97frPBtIj+ZLzdp+yXdhOP4hCFATuNT+ReOPK0mCefSG+tXqGpYZ3essBS3q
# 8nL2UwM+NMvEuBd/2vmdYxDCvwzJv2sRUoKEfJ+nN57mQfQXwcAEGCvRR2qKtntu
# jB71WPYAgwPyWLKu6RnaID/B0ba2H3LUiwDRAXx1Neq9ydOal95CHfmTnM4I+ZI2
# rVQfjXQA1WSjjf4J2a7jLzWGNqNX+DF0SQzHU0pTi4dBwp9nEC8EAqoxW6q17r0z
# 0noDjs6+BFo+z7bKSBwZXTRNivYuve3L2oiKNqetRHdqfMTCW/NmKLJ9M+MtucVG
# yOxiDf06VXxyKkOirv6o02OoXN4bFzK0vlNMsvhlqgF2puE6FndlENSmE+9JGYxO
# GLS/D284NHNboDGcmWXfwXRy4kbu4QFhOm0xJuF2EZAOk5eCkhSxZON3rGlHqhpB
# /8MluDezooIs8CVnrpHMiD2wL40mm53+/j7tFaxYKIqL0Q4ssd8xHZnIn/7GELH3
# IdvG2XlM9q7WP/UwgOkw/HQtyRN62JK4S1C8uw3PdBunvAZapsiI5YKdvlarEvf8
# EA+8hcpSM9LHJmyrxaFtoza2zNaQ9k+5t1wwggbtMIIE1aADAgECAhAKgO8YS43x
# BYLRxHanlXRoMA0GCSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQK
# Ew5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBU
# aW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwHhcNMjUwNjA0MDAw
# MDAwWhcNMzYwOTAzMjM1OTU5WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGln
# aUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFNIQTI1NiBSU0E0MDk2IFRp
# bWVzdGFtcCBSZXNwb25kZXIgMjAyNSAxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEA0EasLRLGntDqrmBWsytXum9R/4ZwCgHfyjfMGUIwYzKomd8U1nH7
# C8Dr0cVMF3BsfAFI54um8+dnxk36+jx0Tb+k+87H9WPxNyFPJIDZHhAqlUPt281m
# HrBbZHqRK71Em3/hCGC5KyyneqiZ7syvFXJ9A72wzHpkBaMUNg7MOLxI6E9RaUue
# HTQKWXymOtRwJXcrcTTPPT2V1D/+cFllESviH8YjoPFvZSjKs3SKO1QNUdFd2adw
# 44wDcKgH+JRJE5Qg0NP3yiSyi5MxgU6cehGHr7zou1znOM8odbkqoK+lJ25LCHBS
# ai25CFyD23DZgPfDrJJJK77epTwMP6eKA0kWa3osAe8fcpK40uhktzUd/Yk0xUvh
# DU6lvJukx7jphx40DQt82yepyekl4i0r8OEps/FNO4ahfvAk12hE5FVs9HVVWcO5
# J4dVmVzix4A77p3awLbr89A90/nWGjXMGn7FQhmSlIUDy9Z2hSgctaepZTd0ILIU
# bWuhKuAeNIeWrzHKYueMJtItnj2Q+aTyLLKLM0MheP/9w6CtjuuVHJOVoIJ/DtpJ
# RE7Ce7vMRHoRon4CWIvuiNN1Lk9Y+xZ66lazs2kKFSTnnkrT3pXWETTJkhd76CID
# BbTRofOsNyEhzZtCGmnQigpFHti58CSmvEyJcAlDVcKacJ+A9/z7eacCAwEAAaOC
# AZUwggGRMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFOQ7/PIx7f391/ORcWMZUEPP
# YYzoMB8GA1UdIwQYMBaAFO9vU0rp5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB/wQE
# AwIHgDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgwgYUw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEFBQcw
# AoZRaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0
# VGltZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRYMFYw
# VKBSoFCGTmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRH
# NFRpbWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAEGTAX
# MAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBAGUqrfEc
# JwS5rmBB7NEIRJ5jQHIh+OT2Ik/bNYulCrVvhREafBYF0RkP2AGr181o2YWPoSHz
# 9iZEN/FPsLSTwVQWo2H62yGBvg7ouCODwrx6ULj6hYKqdT8wv2UV+Kbz/3ImZlJ7
# YXwBD9R0oU62PtgxOao872bOySCILdBghQ/ZLcdC8cbUUO75ZSpbh1oipOhcUT8l
# D8QAGB9lctZTTOJM3pHfKBAEcxQFoHlt2s9sXoxFizTeHihsQyfFg5fxUFEp7W42
# fNBVN4ueLaceRf9Cq9ec1v5iQMWTFQa0xNqItH3CPFTG7aEQJmmrJTV3Qhtfparz
# +BW60OiMEgV5GWoBy4RVPRwqxv7Mk0Sy4QHs7v9y69NBqycz0BZwhB9WOfOu/CIJ
# nzkQTwtSSpGGhLdjnQ4eBpjtP+XB3pQCtv4E5UCSDag6+iX8MmB10nfldPF9SVD7
# weCC3yXZi/uuhqdwkgVxuiMFzGVFwYbQsiGnoa9F5AaAyBjFBtXVLcKtapnMG3VH
# 3EmAp/jsJ3FVF3+d1SVDTmjFjLbNFZUWMXuZyvgLfgyPehwJVxwC+UpX2MSey2ue
# Iu9THFVkT+um1vshETaWyQo8gmBto/m3acaP9QsuLj3FNwFlTxq25+T4QwX9xa6I
# Ls84ZPvmpovq90K8eWyG2N01c4IhSOxqt81nMYIGfzCCBnsCAQEwgaIwgZUxCzAJ
# BgNVBAYTAlVTMQswCQYDVQQIEwJNTjEUMBIGA1UEBxMLTWlubmVhcG9saXMxEjAQ
# BgNVBAoTCUx1Y2EgSG9tZTEPMA0GA1UECxMGT2ZmaWNlMRowGAYDVQQDExFMdWNh
# cyBDb2RlIFJTQSBDQTEiMCAGCSqGSIb3DQEJARYTZGFubHVjYUBjb21jYXN0Lm5l
# dAIIBtflh7Az5TYwDQYJYIZIAWUDBAIBBQCggYQwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFjAvBgkqhkiG9w0BCQQxIgQgAHd9E4Q2uYwSZ1cacx+D
# vJupwHRlW0CO7y1T6HMmq0QwDQYJKoZIhvcNAQEBBQAEggIAdzvVWDVL5D5bJAyX
# 7/Ep/FcEpVa5aQjdLZkIqdxcd0zqoAXEKdx9eX8mJGvEkNdY3B+/7ud6STW+M0t1
# QjC7LDt1CUfkl4EBzhMTcRRjOpTssfzbtbZKj7GbL26Yq3WQgzwNjdONg3HPhO/+
# FXLfbC4agKlBieBFWXNVmMun10UbXddStXv2tyoApYDa/gTz/ZWhJG8OvSxeTiz6
# Os9suO2a/uhrZ7DhEcGQdmYBN+jKXZ35gnAWWUag4ZTe3gULxpkhwquP2rRu93l0
# /bYH0dONij5iyvpSzYTEeVqCrzStG9Yvc7bRKaSp/43aMPHgF4Ww9ipBkzTyqyH0
# CPSbXJuq3FKagCWQMYxQ7/BE0udjtcI8UdPp7x/ugQ9A5ylQBvKhb2LWfFbeiQnC
# tiq8TDkSZg/Hx3jYneoHCy7vlJhZeHqssumo1jVEV+6ZT0/tTCK3Qkg53kjQqCZf
# fsR2XkQRzWopQUF2Utg3F8O6k7iIFfg4WbPq89JZeCOd1O2I+YDI4IxEYL3iAdno
# V8W2VTG1ZdqcezxFM2+TLEAhBwvtWj0S0YzyP+uOT6YckNRb20itvoyeNpeVQDXV
# E6cmacl5ngOmVw4p1Usa183/hX58NSaTpliEXTvZp03XsbWAHCWHaK8u12a7na2b
# 3rhLPhtuaOsi8pVvOrHo0UbnbwShggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8C
# AQEwfTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/
# BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYg
# U0hBMjU2IDIwMjUgQ0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUA
# oGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYw
# ODMxMTY0MDU4WjAvBgkqhkiG9w0BCQQxIgQg2VBfNeS+zDFhdyOtmU1jkrBXodBk
# OLN+glx1EZumFqEwDQYJKoZIhvcNAQEBBQAEggIAnQ2tNLXCnkOoc09UFuJAOTGo
# Nz/uFRD299hbnOypNNSp9A/QRXAzH1yqMgs3VqBno3Dlj4ZHRzt3bjZ+Pmn5eaJ8
# ac0TsYBaba6ID5vEyayQqCOUwWqRyjfPMG6Mqc5gsHZ3PfMA6oghTPFwdCKmuBK9
# qmC1bhvilb+3cGOTVlAeIhki8Sbtan27fwcVprRzD9rmKQaMHjk4yC5dw1c5IyXY
# ImHGjY40pR+iFVLLMpS9wllSfsLkRiCrUXqEQyrxP0kRDT5BoOYhU7sxNmyeHOVA
# 973q8CmaVyVl3IvT631+oPC+bkAJkegeHw/dpe8xEH5sRZ5o7cktTpT5DwYNgBK4
# xyagGL35ue8BP9h1te4xfYRcQ5pmF3wsXqg2pvpuA+GalHafRrxId8yyfs98jrJg
# 6VkWhbCqOaicUdmnRHQChsOkcA9bFz2zsEsOm8SJb3/JqmCizRkJf73iAJjCJlnW
# B3C2TepBziYQTF/KxsVBJqmYiQzcSGNkSATOpJcv7yPBQQmehrON3K0HZIPsH2I1
# Ceym+6+xqkgTho5ZZdldcRNFesRYCb2iFf+uQwjAlFQfjETrNMiTxWwhYDx49gz3
# O4lhPTuc6Nv1Prcmk28tNkmF7HL7CkdTDLR7nMDrjANUQ1XTF7SLN7q8D/7XBfP0
# KlWHRKH5VbIpvYKbG8c=
# SIG # End signature block
