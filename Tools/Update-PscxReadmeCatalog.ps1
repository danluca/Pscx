[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string] $ModulePath,

    [string] $ReadmePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'README.md'),

    [switch] $Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

$startMarker = '<!-- BEGIN GENERATED PSCX PUBLIC API -->'
$endMarker = '<!-- END GENERATED PSCX PUBLIC API -->'
$resolvedModulePath = (Resolve-Path -LiteralPath $ModulePath).Path
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$resolvedReadmePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
    $ReadmePath
)
$manifestPath = Join-Path $resolvedModulePath 'Pscx.psd1'
$windowsManifestPath = Join-Path $resolvedModulePath 'PscxWin.psd1'
$preferencesPath = Join-Path $resolvedModulePath 'Pscx.UserPreferences.ps1'

foreach ($requiredPath in $manifestPath, $windowsManifestPath, $preferencesPath) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "The Full packaged module is required; missing '$requiredPath'."
    }
}
if (-not (Test-Path -LiteralPath $resolvedReadmePath -PathType Leaf)) {
    throw "README does not exist: $resolvedReadmePath"
}
if (Get-Module -Name Pscx*) {
    throw 'A PSCX module is already loaded. Run this tool in a fresh pwsh -NoProfile process.'
}

function ConvertTo-MarkdownText {
    param([AllowEmptyString()][string] $Text)

    return (($Text -replace '\s+', ' ').Trim() -replace '\|', '\|')
}

function Get-ManifestExports {
    param([Parameter(Mandatory)][string] $Path)

    $data = Import-PowerShellDataFile -LiteralPath $Path
    return @(
        $data['CmdletsToExport']
        $data['FunctionsToExport']
    ) | Where-Object { $_ -and $_ -ne '*' } | Sort-Object -Unique
}

$rootManifest = Import-PowerShellDataFile -LiteralPath $manifestPath
$publicContractPath = Join-Path $repositoryRoot 'Tests/Pscx.PublicContract.psd1'
$publicContract = Import-PowerShellDataFile -LiteralPath $publicContractPath
$windowsCommandNames = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase
)
foreach ($name in Get-ManifestExports -Path $windowsManifestPath) {
    $windowsCommandNames.Add($name) | Out-Null
}
foreach ($name in $publicContract.Platforms.WindowsOnlyCommands) {
    $windowsCommandNames.Add($name) | Out-Null
}

$defaultPreferences = & $preferencesPath
$availabilityByName = @{}
$childManifestFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $resolvedModulePath 'Modules') `
        -Recurse -Filter *.psd1 -File |
        Where-Object {
            (Get-Content -LiteralPath $_.FullName -Raw) -match '(?m)^\s*(?:Functions|Cmdlets)ToExport\s*='
        }
)
foreach ($childManifest in $childManifestFiles) {
    $feature = $childManifest.Directory.Name
    $isDefault = [bool]$defaultPreferences.ModulesToImport[$feature]
    foreach ($name in Get-ManifestExports -Path $childManifest.FullName) {
        $availabilityByName[$name] = if ($isDefault) { 'Default' } else { "Optional ($feature)" }
        if ($feature -in 'DirectoryServices', 'Sudo', 'Vhd', 'Wmi') {
            $windowsCommandNames.Add($name) | Out-Null
        }
    }
}

$allFeatures = @{}
foreach ($feature in $defaultPreferences.ModulesToImport.Keys) {
    # TranscribeSession changes profile-adjacent state and does not contribute a
    # command declared by the parent manifest, so catalog generation never loads it.
    $allFeatures[$feature] = $feature -ne 'TranscribeSession'
}
$importWarnings = @()
Import-Module $manifestPath -ArgumentList @{
    PageHelpUsingLess = $false
    ModulesToImport = $allFeatures
} -Force -DisableNameChecking -WarningVariable importWarnings -ErrorAction Stop

if ($importWarnings.Count -gt 0) {
    throw "The packaged module emitted warnings while generating the catalog: $($importWarnings -join ' | ')"
}

$module = Get-Module Pscx -ErrorAction Stop
$declaredNames = @(
    $rootManifest.CmdletsToExport
    $rootManifest.FunctionsToExport
) | Where-Object { $_ -and $_ -ne '*' } | Sort-Object -Unique
$commandsByName = @{}
foreach ($command in $module.ExportedCommands.Values) {
    $commandsByName[$command.Name] = $command
}
$missingNames = @($declaredNames | Where-Object { -not $commandsByName.ContainsKey($_) })
if ($missingNames.Count -gt 0) {
    throw "The Full package does not resolve declared commands: $($missingNames -join ', ')"
}

$catalogCommands = [Collections.Generic.List[object]]::new()
$platformByName = @{}
$availabilityByResolvedName = @{}
foreach ($name in $declaredNames) {
    $command = $commandsByName[$name]
    $platform = if ($windowsCommandNames.Contains($command.Name)) { 'Windows' } else { 'All' }
    if ($command.CommandType -eq [Management.Automation.CommandTypes]::Cmdlet) {
        $supportedPlatforms = @(
            $command.ImplementingType.GetCustomAttributesData() |
                Where-Object AttributeType -EQ ([Runtime.Versioning.SupportedOSPlatformAttribute]) |
                ForEach-Object { [string]$_.ConstructorArguments[0].Value }
        )
        if ($supportedPlatforms | Where-Object { $_ -like 'windows*' }) {
            $platform = 'Windows'
        }
    }
    elseif (
        $command.ScriptBlock.File -and
        [IO.Path]::GetFileName($command.ScriptBlock.File) -eq 'PscxWin.psm1'
    ) {
        $platform = 'Windows'
    }

    $availability = if ($availabilityByName.ContainsKey($command.Name)) {
        $availabilityByName[$command.Name]
    }
    else {
        'Default'
    }
    $description = if ($command.CommandType -eq [Management.Automation.CommandTypes]::Cmdlet) {
        $descriptionAttribute = @(
            $command.ImplementingType.GetCustomAttributes(
                [ComponentModel.DescriptionAttribute],
                $true
            )
        ) | Select-Object -First 1
        ConvertTo-MarkdownText ([string]$descriptionAttribute.Description)
    }
    else {
        $helpContent = $command.ScriptBlock.Ast.GetHelpContent()
        if ($null -ne $helpContent -and $helpContent.Synopsis) {
            ConvertTo-MarkdownText ([string]$helpContent.Synopsis)
        }
        else {
            $help = Get-Help -Name $command.Name -Full -ErrorAction Stop
            ConvertTo-MarkdownText ([string]$help.Synopsis)
        }
    }
    $description = $description -replace '^PSCX Cmdlet:\s*', ''
    if (
        [string]::IsNullOrWhiteSpace($description) -or
        $description -like '*proper help content*'
    ) {
        throw "Public command '$($command.Name)' has no usable help synopsis."
    }

    $platformByName[$command.Name] = $platform
    $availabilityByResolvedName[$command.Name] = $availability
    $catalogCommands.Add([pscustomobject]@{
        Name = $command.Name
        Type = $command.CommandType.ToString()
        Platform = $platform
        Availability = $availability
        Description = $description
    })
}

$coreAliasNames = @($publicContract.Aliases.Core)
$windowsAliasNames = @($publicContract.Aliases.Full)
$catalogAliases = @(
    @($coreAliasNames; $windowsAliasNames) |
        Sort-Object -Unique |
        ForEach-Object {
            $alias = Get-Alias -Name $_ -ErrorAction Stop
            $target = [string]$alias.Definition
            $unqualifiedTarget = ($target -split '\\')[-1]
            $platform = if ($_ -in $windowsAliasNames) {
                'Windows'
            }
            elseif ($platformByName.ContainsKey($unqualifiedTarget)) {
                $platformByName[$unqualifiedTarget]
            }
            else {
                'All'
            }
            $availability = if ($availabilityByResolvedName.ContainsKey($unqualifiedTarget)) {
                $availabilityByResolvedName[$unqualifiedTarget]
            }
            else {
                'Default'
            }
            [pscustomobject]@{
                Name = $alias.Name
                Target = $target
                Platform = $platform
                Availability = $availability
            }
        }
)

$catalogProviders = @(
    Get-PSProvider |
        Where-Object { $_.ImplementingType.Assembly.GetName().Name -Like 'Pscx*' } |
        Sort-Object Name -Unique |
        ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                Platform = if ($_.ImplementingType.Assembly.GetName().Name -eq 'Pscx.Win') {
                    'Windows'
                }
                else {
                    'All'
                }
            }
        }
)

$lines = [Collections.Generic.List[string]]::new()
$lines.Add($startMarker)
$lines.Add('<!-- Generated by Tools/Update-PscxReadmeCatalog.ps1. Do not edit this region manually. -->')
$lines.Add('')
foreach ($commandType in 'Cmdlet', 'Function') {
    $items = @($catalogCommands | Where-Object Type -EQ $commandType | Sort-Object Name)
    $lines.Add("### ${commandType}s ($($items.Count))")
    $lines.Add('')
    $lines.Add('| Command | Platform | Availability | Description |')
    $lines.Add('| --- | --- | --- | --- |')
    foreach ($item in $items) {
        $lines.Add("| ``$($item.Name)`` | $($item.Platform) | $($item.Availability) | $($item.Description) |")
    }
    $lines.Add('')
}

$lines.Add("### Aliases ($($catalogAliases.Count))")
$lines.Add('')
$lines.Add('| Alias | Target | Platform | Availability |')
$lines.Add('| --- | --- | --- | --- |')
foreach ($alias in $catalogAliases) {
    $lines.Add("| ``$($alias.Name)`` | ``$($alias.Target)`` | $($alias.Platform) | $($alias.Availability) |")
}
$lines.Add('')
$lines.Add("### Providers ($($catalogProviders.Count))")
$lines.Add('')
$lines.Add('| Provider | Platform |')
$lines.Add('| --- | --- |')
foreach ($provider in $catalogProviders) {
    $lines.Add("| ``$($provider.Name)`` | $($provider.Platform) |")
}
$lines.Add('')
$lines.Add($endMarker)
$generatedRegion = $lines -join "`n"

$readme = [IO.File]::ReadAllText($resolvedReadmePath)
$normalizedReadme = $readme -replace "`r`n", "`n"
$pattern = '(?ms)' + [regex]::Escape($startMarker) + '.*?' + [regex]::Escape($endMarker)
$matches = [regex]::Matches($normalizedReadme, $pattern)
if ($matches.Count -ne 1) {
    throw "Expected exactly one generated catalog region in '$resolvedReadmePath'; found $($matches.Count)."
}
$expectedReadme = [regex]::Replace($normalizedReadme, $pattern, $generatedRegion)

if ($Check) {
    if ($normalizedReadme -cne $expectedReadme) {
        throw 'README public API catalog is stale. Run ./build.ps1 -Task Catalog after a Full package build.'
    }
    Write-Output 'README public API catalog is current.'
    return
}

if ($normalizedReadme -ceq $expectedReadme) {
    Write-Output 'README public API catalog is already current.'
    return
}

[IO.File]::WriteAllText(
    $resolvedReadmePath,
    $expectedReadme,
    [Text.UTF8Encoding]::new($false)
)
Write-Output "Updated README public API catalog: $resolvedReadmePath"
