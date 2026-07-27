[CmdletBinding()]
param(
    [ValidateSet(
        'Clean',
        'Restore',
        'Compile',
        'Help',
        'Test',
        'TestAll',
        'Package',
        'Validate',
        'Audit',
        'PublishPrep',
        'CI'
    )]
    [string[]] $Task = @('CI'),

    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release',

    [ValidateRange(0, 65535)]
    [int] $BuildNumber = 0,

    [string] $CommitSha,

    [string] $ArtifactsPath = (Join-Path $PSScriptRoot 'artifacts'),

    [switch] $Release,

    [string] $ExpectedTag
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

$repositoryRoot = $PSScriptRoot
$solutionPath = Join-Path $repositoryRoot 'Src/Pscx.sln'
$testProjectPath = Join-Path $repositoryRoot 'Src/Pscx.UnitTests/Pscx.UnitTests.csproj'
$versionFilePath = Join-Path $repositoryRoot 'Directory.Build.props'
$artifactsRoot = [System.IO.Path]::GetFullPath($ArtifactsPath)
$moduleRoot = Join-Path $artifactsRoot 'module/Pscx'
$helpOutputPath = Join-Path $artifactsRoot 'help'
$packageOutputPath = Join-Path $artifactsRoot 'packages'
$testResultsPath = Join-Path $artifactsRoot 'test-results'

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
        [string] $Prerelease
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

    if ([System.IO.Path]::GetFileName($Path) -eq 'Pscx.psd1') {
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
    Write-Step 'Restore'
    Invoke-NativeCommand dotnet @('restore', $solutionPath, '--nologo')
}

function Get-MSBuildVersionArguments {
    return @(
        "-p:PscxBuildNumber=$BuildNumber",
        "-p:PscxCommitSha=$shortCommitSha",
        "-p:PscxPackageVersion=$packageVersion",
        "-p:InformationalVersion=$informationalVersion"
    )
}

function Invoke-Compile {
    Write-Step "Compile $packageVersion"
    $arguments = @(
        'build',
        $solutionPath,
        '--configuration',
        $Configuration,
        '--no-restore',
        '--nologo'
    ) + (Get-MSBuildVersionArguments)
    Invoke-NativeCommand dotnet $arguments
}

function New-ModuleStage {
    Write-Step "Assemble module $packageVersion"
    Remove-BuildDirectory (Join-Path $artifactsRoot 'module')
    New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null

    $coreOutput = Join-Path $repositoryRoot "Src/Pscx/bin/$Configuration/net10.0"
    $windowsOutput = Join-Path $repositoryRoot "Src/Pscx.Win/bin/$Configuration/net10.0"

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

    Copy-MatchingItem $coreOutput 'NodaTime.*' $moduleRoot
    @('FormatData', 'Modules', 'TypeData') | ForEach-Object {
        Copy-RequiredItem (Join-Path $coreOutput $_) $moduleRoot
    }

    @('Pscx.Win.dll', 'PscxWin.psd1', 'PscxWin.psm1') | ForEach-Object {
        Copy-RequiredItem (Join-Path $windowsOutput $_) $moduleRoot
    }

    Copy-MatchingItem $windowsOutput 'SevenZipSharp.*' $moduleRoot
    Copy-MatchingItem $windowsOutput 'YamlDotNet.*' $moduleRoot
    @('FormatData', 'Modules', 'TypeData') | ForEach-Object {
        Copy-RequiredItem (Join-Path $windowsOutput $_) $moduleRoot
    }

    $appsRoot = Join-Path $moduleRoot 'Apps'
    $windowsApps = Join-Path $appsRoot 'Win'
    $macApps = Join-Path $appsRoot 'macOS'
    $linuxApps = Join-Path $appsRoot 'Linux'
    New-Item -ItemType Directory -Path $windowsApps, $macApps, $linuxApps -Force | Out-Null

    Copy-MatchingItem (Join-Path $repositoryRoot 'Imports/Less-678') 'less*.*' $windowsApps
    Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/Less-678/license') (Join-Path $windowsApps 'LICENSE_less_orig.txt')
    Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/Less-678/LICENSE_win.txt') (Join-Path $windowsApps 'LICENSE_less_win.txt')
    Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/gsudo/win/gsudo.exe') (Join-Path $windowsApps 'gsudo.exe')
    Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/gsudo/win/gsudo.exe') (Join-Path $windowsApps 'sudo.exe')
    Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/gsudo/win/Invoke-ElevatedCommand.ps1') (Join-Path $windowsApps 'Invoke-Elevated.ps1')
    Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/gsudo/LICENSE.txt') (Join-Path $windowsApps 'LICENSE_sudo.txt')
    Copy-MatchingItem (Join-Path $repositoryRoot 'Imports/7zip/win/x64') '7z.*' $windowsApps
    Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/7zip/macOS/7zz') (Join-Path $macApps '7zz')
    Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/7zip/linux/x64/7zz') (Join-Path $linuxApps '7zz')
    Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/7zip/License.txt') (Join-Path $windowsApps 'LICENSE_7zip.txt')
    Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/7zip/License.txt') (Join-Path $macApps 'LICENSE_7zip.txt')
    Copy-RequiredItem (Join-Path $repositoryRoot 'Imports/7zip/License.txt') (Join-Path $linuxApps 'LICENSE_7zip.txt')
    Copy-RequiredItem (Join-Path $repositoryRoot 'CHANGELOG.md') (Join-Path $moduleRoot 'CHANGELOG.md')
    Copy-RequiredItem (Join-Path $repositoryRoot 'LICENSE') (Join-Path $moduleRoot 'LICENSE.txt')

    Get-ChildItem -LiteralPath $moduleRoot -Recurse -Filter *.psd1 -File |
        ForEach-Object {
            Set-ManifestVersion -Path $_.FullName -ModuleVersion $moduleVersion -Prerelease $manifestPrerelease
        }
}

function Invoke-Help {
    if (-not (Test-Path -LiteralPath (Join-Path $moduleRoot 'Pscx.psd1'))) {
        New-ModuleStage
    }

    Write-Step 'Generate help'
    Remove-BuildDirectory $helpOutputPath
    New-Item -ItemType Directory -Path $helpOutputPath -Force | Out-Null

    $helpBuilderPath = Join-Path $repositoryRoot "Src/Pscx.Help/bin/$Configuration/net10.0"
    if (-not (Test-Path -LiteralPath (Join-Path $helpBuilderPath 'Pscx.Help.dll'))) {
        throw "Required help builder output is missing. Run the Compile task first."
    }

    try {
        Invoke-NativeCommand pwsh @(
            '-NoLogo',
            '-NoProfile',
            '-NonInteractive',
            '-File',
            (Join-Path $repositoryRoot 'Tools/Generate-PscxHelp.ps1'),
            '-ModulePath',
            $moduleRoot,
            '-HelpBuilderPath',
            $helpBuilderPath,
            '-OutputPath',
            $helpOutputPath,
            '-Configuration',
            $Configuration
        )
    }
    finally {
        Remove-BuildDirectory (Join-Path $artifactsRoot 'help-work')
    }

    Get-ChildItem -LiteralPath $helpOutputPath -File |
        Where-Object Name -NotLike 'Merged*' |
        Copy-Item -Destination $moduleRoot -Force
}

function Invoke-Test {
    param([switch] $All)

    Write-Step $(if ($All) { 'Run full legacy managed test suite' } else { 'Run managed regression tests' })
    if (-not (Test-Path -LiteralPath (Join-Path $moduleRoot 'Pscx.psd1'))) {
        New-ModuleStage
    }

    $testOutput = Join-Path $repositoryRoot "Src/Pscx.UnitTests/bin/$Configuration/net10.0"
    Remove-BuildDirectory (Join-Path $testOutput 'Apps')
    Copy-RequiredItem (Join-Path $moduleRoot 'Apps') (Join-Path $testOutput 'Apps')

    New-Item -ItemType Directory -Path $testResultsPath -Force | Out-Null
    $arguments = @(
        'test',
        $testProjectPath,
        '--configuration',
        $Configuration,
        '--no-build',
        '--no-restore',
        '--nologo',
        '--results-directory',
        $testResultsPath,
        '--logger',
        'trx;LogFileName=Pscx.UnitTests.trx'
    ) + (Get-MSBuildVersionArguments)

    if (-not $All) {
        # Phase 2 will classify/migrate the environment-dependent legacy tests.
        # Until then, CI runs the stable pure-logic regression slice.
        $arguments += @(
            '--filter',
            'FullyQualifiedName~PscxUnitTests.Time.DateTimeArithmeticTests'
        )
    }

    Invoke-NativeCommand dotnet $arguments
}

function Invoke-Package {
    New-ModuleStage
    Invoke-Help

    Write-Step "Create Pscx-$packageVersion.zip"
    Remove-BuildDirectory $packageOutputPath
    New-Item -ItemType Directory -Path $packageOutputPath -Force | Out-Null
    $archivePath = Join-Path $packageOutputPath "Pscx-$packageVersion.zip"
    Compress-Archive -LiteralPath (Join-Path $artifactsRoot 'module/Pscx') -DestinationPath $archivePath
}

function Invoke-Validate {
    Write-Step 'Validate version and package'

    $sourceVersionLocations = @(
        'Src/ConsoleApp/ConsoleApp.csproj',
        'Src/Pscx/Pscx.csproj',
        'Src/Pscx.Core/Pscx.Core.csproj',
        'Src/Pscx.Help/Pscx.Help.csproj',
        'Src/Pscx.UnitTests/Pscx.UnitTests.csproj',
        'Src/Pscx.Win/Pscx.Win.csproj',
        'Src/AssemblyInfo.Shared.cs',
        'Src/Pscx.Core/Properties/PscxAssemblyInfo.cs',
        'Src/Pscx.UnitTests/Properties/AssemblyInfo.cs',
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
    }

    $manifestPath = Join-Path $moduleRoot 'Pscx.psd1'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "The staged package is missing. Run the Package task first."
    }

    $manifest = Test-ModuleManifest -Path $manifestPath
    if ($manifest.Version -ne [version]$moduleVersion) {
        throw "Staged module version '$($manifest.Version)' does not match '$moduleVersion'."
    }

    if ($manifestPrerelease -and $manifest.PrivateData.PSData.Prerelease -ne $manifestPrerelease) {
        throw "Staged module prerelease '$($manifest.PrivateData.PSData.Prerelease)' does not match '$manifestPrerelease'."
    }

    foreach ($assemblyName in 'Pscx.Core.dll', 'Pscx.dll', 'Pscx.Win.dll') {
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

    $archivePath = Join-Path $packageOutputPath "Pscx-$packageVersion.zip"
    if (-not (Test-Path -LiteralPath $archivePath)) {
        throw "Expected package archive is missing: $(Get-RelativePath $archivePath)"
    }

    $changeLogPath = Join-Path $moduleRoot 'CHANGELOG.md'
    $changeLogContent = Get-Content -LiteralPath $changeLogPath -Raw
    if ($changeLogContent -notmatch "(?m)^##\s+$([regex]::Escape($moduleVersion))(?:\s|$)") {
        throw "The packaged changelog has no $moduleVersion release heading."
    }

    Invoke-NativeCommand pwsh @(
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-File',
        (Join-Path $repositoryRoot 'Tools/Test-PscxPackage.ps1'),
        '-ManifestPath',
        $manifestPath
    )
}

function Invoke-Audit {
    Write-Step 'Audit dependencies'
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

function Invoke-PublishPrep {
    param([switch] $AlreadyValidated)

    if (-not $AlreadyValidated) {
        Invoke-Validate
    }
    Write-Step 'Publish preparation complete'
    Write-Host "Prepared package: $(Get-RelativePath (Join-Path $packageOutputPath "Pscx-$packageVersion.zip"))"
    Write-Host 'Publishing and signing are intentionally separate, maintainer-approved release actions.'
}

[xml] $versionDocument = Get-Content -LiteralPath $versionFilePath -Raw
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
    if ($item -eq 'CI') {
        'Clean', 'Restore', 'Compile', 'Test', 'Package', 'Validate'
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

$validated = $false
foreach ($item in $expandedTasks) {
    switch ($item) {
        Clean { Invoke-Clean }
        Restore { Invoke-Restore }
        Compile { Invoke-Compile }
        Help { Invoke-Help }
        Test { Invoke-Test }
        TestAll { Invoke-Test -All }
        Package { Invoke-Package }
        Validate {
            Invoke-Validate
            $validated = $true
        }
        Audit { Invoke-Audit }
        PublishPrep { Invoke-PublishPrep -AlreadyValidated:$validated }
    }
}
