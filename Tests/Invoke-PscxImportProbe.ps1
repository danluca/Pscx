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

    [Parameter(DontShow)]
    [string] $ProbeOutputPath
)

$probePath = Join-Path ([IO.Path]::GetTempPath()) ('Pscx.ImportProbe.{0}.json' -f [guid]::NewGuid().ToString('N'))
$pwshPath = Join-Path $PSHOME 'pwsh.exe'
if (-not (Test-Path -LiteralPath $pwshPath)) {
    $pwshPath = Join-Path $PSHOME 'pwsh'
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
            Vhd = $false
            Wmi = $false
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
            Vhd = $true
            Wmi = $true
        }
    }
}
elseif ($Feature) {
    $preferences = @{ ModulesToImport = @{ $Feature = $true } }
}

$warnings = @()
$cdAliasBefore = (Get-Alias cd -ErrorAction SilentlyContinue).Definition
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
        Warnings = @($warnings | ForEach-Object ToString)
        CdAliasBefore = $cdAliasBefore
        CdAliasAfter = (Get-Alias cd -ErrorAction SilentlyContinue).Definition
    }
}
catch {
    $result = [ordered]@{
        Imported = $false
        LoadedModules = @()
        ExportedCommands = @()
        Warnings = @($warnings | ForEach-Object ToString)
        CdAliasBefore = $cdAliasBefore
        CdAliasAfter = (Get-Alias cd -ErrorAction SilentlyContinue).Definition
        Error = $_.ToString()
    }
}

$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ProbeOutputPath -Encoding utf8
if (-not $result.Imported) {
    exit 1
}
