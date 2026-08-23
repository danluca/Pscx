[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ModulePath,

    [Parameter(Mandatory)]
    [ValidateSet('Core', 'Full')]
    [string] $BuildScope,

    [string] $Feature,

    [switch] $DisableOptionalFeatures,

    [switch] $EnableAllOptionalFeatures,

    [switch] $OverrideExistingAliases,

    [string] $CollisionAliasName,

    [string] $PowerShellPath = 'pwsh',

    [Parameter(DontShow)]
    [string] $ProbeOutputPath
)

$probePath = Join-Path ([IO.Path]::GetTempPath()) ('Pscx.ImportProbe.{0}.json' -f [guid]::NewGuid().ToString('N'))
try {
    $pwshPath = Get-Command -Name $PowerShellPath -CommandType Application -ErrorAction Stop |
        Select-Object -First 1 -ExpandProperty Source
}
catch {
    throw "Could not resolve the PowerShell executable '$PowerShellPath'."
}

$arguments = @(
    '-NoLogo',
    '-NoProfile',
    '-NonInteractive',
    '-File',
    $PSCommandPath,
    '-ModulePath',
    $ModulePath,
    '-BuildScope',
    $BuildScope,
    '-PowerShellPath',
    $pwshPath,
    '-ProbeOutputPath',
    $probePath
)
if ($Feature) {
    $arguments += @('-Feature', $Feature)
}
if ($DisableOptionalFeatures) {
    $arguments += '-DisableOptionalFeatures'
}
if ($EnableAllOptionalFeatures) {
    $arguments += '-EnableAllOptionalFeatures'
}
if ($OverrideExistingAliases) {
    $arguments += '-OverrideExistingAliases'
}
if ($CollisionAliasName) {
    $arguments += @('-CollisionAliasName', $CollisionAliasName)
}

if (-not $env:PSCX_IMPORT_PROBE_CHILD) {
    $env:PSCX_IMPORT_PROBE_CHILD = '1'
    try {
        & $pwshPath @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "PSCX import probe exited with code $LASTEXITCODE."
        }
        Get-Content -LiteralPath $probePath -Raw | ConvertFrom-Json
    }
    finally {
        Remove-Item Env:PSCX_IMPORT_PROBE_CHILD -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $probePath -Force -ErrorAction SilentlyContinue
    }
    return
}

$manifestPath = Join-Path $ModulePath 'Pscx.psd1'
$preferences = $null
if ($DisableOptionalFeatures) {
    $preferences = @{
        ModulesToImport = @{
            CD = $false
            DirectoryServices = $false
            FileSystem = $false
            Net = $false
            TranscribeSession = $false
            Utility = $false
            Sudo = $false
        }
    }
}
elseif ($EnableAllOptionalFeatures) {
    $preferences = @{
        ModulesToImport = @{
            CD = $true
            DirectoryServices = $true
            FileSystem = $true
            Net = $true
            TranscribeSession = $true
            Utility = $true
            Sudo = $true
        }
    }
}
elseif ($Feature) {
    $preferences = @{ ModulesToImport = @{ $Feature = $true } }
}
if ($OverrideExistingAliases) {
    if ($null -eq $preferences) {
        $preferences = @{}
    }
    $preferences.OverrideExistingAliases = $true
}

$warnings = @()
if ($CollisionAliasName) {
    Set-Alias -Name $CollisionAliasName -Value Get-Date -Scope Global -Force
}
$aliasesBefore = @{}
Get-Alias | ForEach-Object { $aliasesBefore[$_.Name] = $_.Definition }
$contract = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'Pscx.PublicContract.psd1')
$documentedAliases = @($contract.Aliases.Core)
if ($BuildScope -eq 'Full') {
    $documentedAliases += $contract.Aliases.Full
}
$commandsBeforeImport = @()
if ($CollisionAliasName -or $DisableOptionalFeatures) {
    $commandsBeforeImport = @(
        Get-Command -Name $documentedAliases -ErrorAction SilentlyContinue |
            ForEach-Object Name |
            Sort-Object -Unique
    )
}
try {
    if ($null -eq $preferences) {
        Import-Module $manifestPath -Force -ErrorAction Stop -WarningVariable warnings
    }
    else {
        Import-Module $manifestPath -ArgumentList $preferences -Force -ErrorAction Stop `
            -WarningVariable warnings
    }
    $result = [ordered]@{
        Imported = $null -ne (Get-Module Pscx)
        LoadedModules = @(Get-Module Pscx* -All | ForEach-Object Name | Sort-Object -Unique)
        ExportedCommands = @(
            (Get-Module Pscx).ExportedCommands.Values |
                Where-Object CommandType -In Function, Cmdlet |
                ForEach-Object Name |
                Sort-Object -Unique
        )
        ExportedAliases = @(
            (Get-Module Pscx).ExportedAliases.Keys | Sort-Object -Unique
        )
        ChangedAliases = @(
            Get-Alias | Where-Object {
                -not $aliasesBefore.ContainsKey($_.Name) -or
                $aliasesBefore[$_.Name] -ne $_.Definition
            } | ForEach-Object Name | Sort-Object -Unique
        )
        PreexistingCommandNames = $commandsBeforeImport
        CdAliasDefinition = (Get-Alias -Name cd -ErrorAction SilentlyContinue).Definition
        CollisionAliasDefinition = if ($CollisionAliasName) {
            (Get-Alias -Name $CollisionAliasName -ErrorAction SilentlyContinue).Definition
        }
        Warnings = @($warnings | ForEach-Object ToString)
    }
    Remove-Module Pscx -Force -ErrorAction Stop
    $result['ChangedAliasesAfterRemoval'] = @(
        Get-Alias | Where-Object {
            -not $aliasesBefore.ContainsKey($_.Name) -or
            $aliasesBefore[$_.Name] -ne $_.Definition
        } | ForEach-Object Name | Sort-Object -Unique
    )
}
catch {
    $result = [ordered]@{
        Imported = $false
        LoadedModules = @()
        ExportedCommands = @()
        ExportedAliases = @()
        ChangedAliases = @()
        ChangedAliasesAfterRemoval = @()
        PreexistingCommandNames = $commandsBeforeImport
        CdAliasDefinition = $null
        CollisionAliasDefinition = $null
        Warnings = @($warnings | ForEach-Object ToString)
        Error = $_.ToString()
    }
}

$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ProbeOutputPath -Encoding utf8
if (-not $result.Imported) {
    exit 1
}
