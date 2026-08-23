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
        'Pscx.UserPreferences.ps1',
        'Pscx.ico'
    ) | ForEach-Object {
        Copy-RequiredItem (Join-Path $coreOutput $_) $moduleRoot
    }

    Copy-MatchingItem $coreOutput 'YamlDotNet.*' $moduleRoot
    @('FormatData', 'Modules', 'TypeData') | ForEach-Object {
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
    }

    $summary = [ordered]@{
        Status = if ($failures.Count -eq 0) { 'Passed' } else { 'Failed' }
        BuildScope = $resolvedBuildScope
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        Suites = $outcomes
    }
    $summary | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $testResultsPath 'Pscx.TestSummary.json') -Encoding utf8

    if ($failures.Count -gt 0) {
        throw "Unified tests failed. $($failures -join ' | ')"
    }
}

function Invoke-Package {
    New-ModuleStage
    Invoke-Help

    Write-Step "Create unified Pscx $packageVersion ZIP"
    Remove-BuildDirectory $packageOutputPath
    New-Item -ItemType Directory -Path $packageOutputPath -Force | Out-Null
    $archivePath = Join-Path $packageOutputPath "Pscx-$packageVersion.zip"
    $packageRoots = @($moduleRoot, $archiveModuleRoot, $timeModuleRoot)
    if ($resolvedBuildScope -eq 'Full') {
        $packageRoots += $winAdminModuleRoot
    }
    Compress-Archive -LiteralPath $packageRoots -DestinationPath $archivePath
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
    $manifestPath = Join-Path $moduleRoot 'Pscx.psd1'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "The staged package is missing: $manifestPath"
    }

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
