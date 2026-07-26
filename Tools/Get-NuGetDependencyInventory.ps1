# Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
# Licensed under MIT license.

[CmdletBinding()]
param(
    [string] $SourcePath = (Join-Path $PSScriptRoot '..\Src'),

    [string] $OutputPath = (Join-Path $PSScriptRoot '..\docs\security\NUGET_DEPENDENCIES.md')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-MarkdownCell {
    param([AllowEmptyString()][string] $Value)

    return $Value.Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}

function Get-NuspecMetadata {
    param(
        [Parameter(Mandatory)]
        [string[]] $PackageFolders,

        [Parameter(Mandatory)]
        [string] $PackageId,

        [Parameter(Mandatory)]
        [string] $PackageVersion
    )

    $packageDirectory = $null
    foreach ($folder in $PackageFolders) {
        $candidate = Join-Path $folder $PackageId.ToLowerInvariant()
        $candidate = Join-Path $candidate $PackageVersion.ToLowerInvariant()
        if (Test-Path -LiteralPath $candidate) {
            $packageDirectory = $candidate
            break
        }
    }

    if (-not $packageDirectory) {
        throw "The restored package directory was not found for $PackageId $PackageVersion."
    }

    $nuspecPath = Get-ChildItem -LiteralPath $packageDirectory -Filter '*.nuspec' -File |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $nuspecPath) {
        throw "The NuSpec file was not found for $PackageId $PackageVersion."
    }

    [xml] $nuspec = Get-Content -LiteralPath $nuspecPath -Raw
    $metadata = $nuspec.SelectSingleNode(
        "/*[local-name()='package']/*[local-name()='metadata']"
    )
    $licenseNode = $metadata.SelectSingleNode("*[local-name()='license']")
    $licenseUrlNode = $metadata.SelectSingleNode("*[local-name()='licenseUrl']")

    $license = 'Unspecified'
    if ($licenseNode) {
        if ($licenseNode.type -eq 'expression') {
            $license = $licenseNode.InnerText
        }
        else {
            $license = "file: $($licenseNode.InnerText)"
        }
    }
    elseif ($licenseUrlNode) {
        $license = $licenseUrlNode.InnerText
    }

    return @{
        License = $license
    }
}

$resolvedSourcePath = (Resolve-Path $SourcePath).Path
$projects = Get-ChildItem -LiteralPath $resolvedSourcePath -Recurse -Filter '*.csproj' -File |
    Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' } |
    Sort-Object FullName

if (-not $projects) {
    throw "No projects were found under $resolvedSourcePath."
}

$packages = @{}
foreach ($project in $projects) {
    $assetsPath = Join-Path $project.DirectoryName 'obj\project.assets.json'
    if (-not (Test-Path -LiteralPath $assetsPath)) {
        throw "Restore $($project.FullName) before generating the dependency inventory."
    }

    $assets = Get-Content -LiteralPath $assetsPath -Raw | ConvertFrom-Json -AsHashtable
    $packageFolders = @($assets.packageFolders.Keys)
    $directDependencies = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )

    foreach ($framework in $assets.project.frameworks.Values) {
        if ($framework.ContainsKey('dependencies')) {
            foreach ($dependency in $framework.dependencies.Keys) {
                $null = $directDependencies.Add($dependency)
            }
        }
    }

    foreach ($library in $assets.libraries.GetEnumerator()) {
        if ($library.Value.type -ne 'package') {
            continue
        }

        $separatorIndex = $library.Key.LastIndexOf('/')
        $packageId = $library.Key.Substring(0, $separatorIndex)
        $packageVersion = $library.Key.Substring($separatorIndex + 1)
        $packageKey = "$($packageId.ToLowerInvariant())/$($packageVersion.ToLowerInvariant())"

        if (-not $packages.ContainsKey($packageKey)) {
            $metadata = Get-NuspecMetadata `
                -PackageFolders $packageFolders `
                -PackageId $packageId `
                -PackageVersion $packageVersion

            $packages[$packageKey] = @{
                Id         = $packageId
                Version    = $packageVersion
                Direct     = $false
                License    = $metadata.License
                Projects   = [Collections.Generic.HashSet[string]]::new(
                    [StringComparer]::OrdinalIgnoreCase
                )
            }
        }

        $record = $packages[$packageKey]
        $record.Direct = $record.Direct -or $directDependencies.Contains($packageId)
        $null = $record.Projects.Add($project.BaseName)
    }
}

$lines = [Collections.Generic.List[string]]::new()
$lines.Add('# NuGet Dependency Inventory')
$lines.Add('')
$lines.Add(
    'This generated inventory contains every direct and transitive NuGet package ' +
    'resolved by the projects under `Src`.'
)
$lines.Add('')
$lines.Add(
    'Regenerate it after `dotnet restore ./Src/Pscx.sln` by running ' +
    '`./Tools/Get-NuGetDependencyInventory.ps1`.'
)
$lines.Add('')
$lines.Add("Resolved packages: **$($packages.Count)**.")
$lines.Add('')
$lines.Add('| Package | Version | Relationship | License | Projects |')
$lines.Add('| --- | --- | --- | --- | --- |')

foreach ($record in $packages.Values | Sort-Object Id, Version) {
    $packageUrl = "https://www.nuget.org/packages/$($record.Id)/$($record.Version)"
    $relationship = if ($record.Direct) { 'Direct or transitive' } else { 'Transitive' }
    $projectsText = (@($record.Projects) | Sort-Object) -join ', '
    $license = ConvertTo-MarkdownCell $record.License
    $projectsText = ConvertTo-MarkdownCell $projectsText

    $lines.Add(
        "| [$($record.Id)]($packageUrl) | $($record.Version) | " +
        "$relationship | $license | $projectsText |"
    )
}

$resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
    $OutputPath
)
$outputDirectory = Split-Path -Parent $resolvedOutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$output = ($lines -join "`n") + "`n"
[IO.File]::WriteAllText(
    $resolvedOutputPath,
    $output,
    [Text.UTF8Encoding]::new($false)
)
Get-Item -LiteralPath $resolvedOutputPath
