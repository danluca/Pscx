[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $ModulePath,

    [Parameter(Mandatory)]
    [string] $OutputPath,

    [string] $PackageLabel
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (Get-Module -Name Pscx) {
    throw 'PSCX is already loaded. Run this script in a fresh pwsh -NoProfile process.'
}

$resolvedModulePath = (Resolve-Path -LiteralPath $ModulePath).Path
$moduleRoot = Split-Path -Parent $resolvedModulePath
$typeAcceleratorsType = [psobject].Assembly.GetType(
    'System.Management.Automation.TypeAccelerators',
    $true
)
$acceleratorsBefore = @($typeAcceleratorsType::Get.Keys)
$commonParameterNames = @(
    'Debug',
    'ErrorAction',
    'ErrorVariable',
    'InformationAction',
    'InformationVariable',
    'OutBuffer',
    'OutVariable',
    'PipelineVariable',
    'ProgressAction',
    'Verbose',
    'WarningAction',
    'WarningVariable',
    'WhatIf',
    'Confirm'
)

Import-Module $resolvedModulePath -ArgumentList @{
    PageHelpUsingLess = $false
} -ErrorAction Stop

$module = Get-Module -Name Pscx -ErrorAction Stop
$acceleratorsAfter = @($typeAcceleratorsType::Get.Keys)

$commandInventory = foreach ($command in $module.ExportedCommands.Values |
        Sort-Object CommandType, Name) {
    $record = [ordered] @{
        Name        = $command.Name
        CommandType = $command.CommandType.ToString()
    }

    if ($command.CommandType -eq [Management.Automation.CommandTypes]::Alias) {
        $record.Definition = $command.Definition
    }
    else {
        $record.SupportsShouldProcess = (
            $command.Parameters.ContainsKey('WhatIf') -and
            $command.Parameters.ContainsKey('Confirm')
        )
        $record.ParameterSets = @(
            foreach ($parameterSet in $command.ParameterSets |
                    Sort-Object Name) {
                [ordered] @{
                    Name      = $parameterSet.Name
                    IsDefault = $parameterSet.IsDefault
                    Parameters = @(
                        foreach ($parameter in $parameterSet.Parameters |
                                Where-Object Name -NotIn $commonParameterNames |
                                Sort-Object Position, Name) {
                            [ordered] @{
                                Name                            = $parameter.Name
                                Type                            = $parameter.ParameterType.FullName
                                IsMandatory                     = $parameter.IsMandatory
                                Position                        = $parameter.Position
                                ValueFromPipeline               = $parameter.ValueFromPipeline
                                ValueFromPipelineByPropertyName = $parameter.ValueFromPipelineByPropertyName
                                ValueFromRemainingArguments     = $parameter.ValueFromRemainingArguments
                                Aliases                         = @($parameter.Aliases)
                            }
                        }
                    )
                }
            }
        )
    }

    [pscustomobject] $record
}

$providerInventory = @(
    Get-PSProvider |
        Where-Object ModuleName -Like 'Pscx*' |
        Sort-Object Name |
        ForEach-Object {
            [ordered] @{
                Name         = $_.Name
                ModuleName   = $_.ModuleName
                Capabilities = $_.Capabilities.ToString()
            }
        }
)

$typeDataFiles = @(
    Get-ChildItem -LiteralPath $moduleRoot -Recurse -File -Filter '*.Type.ps1xml' |
        ForEach-Object {
            [IO.Path]::GetRelativePath($moduleRoot, $_.FullName).Replace('\', '/')
        } |
        Sort-Object
)

$formatDataFiles = @(
    Get-ChildItem -LiteralPath $moduleRoot -Recurse -File -Filter '*.Format.ps1xml' |
        ForEach-Object {
            [IO.Path]::GetRelativePath($moduleRoot, $_.FullName).Replace('\', '/')
        } |
        Sort-Object
)

$inventory = [ordered] @{
    SchemaVersion = 1
    Package       = [ordered] @{
        Label   = $PackageLabel
        Module  = $module.Name
        Version = $module.Version.ToString()
    }
    Environment   = [ordered] @{
        Platform     = if ($IsWindows) {
            'Windows'
        }
        elseif ($IsLinux) {
            'Linux'
        }
        elseif ($IsMacOS) {
            'macOS'
        }
        else {
            $PSVersionTable.Platform
        }
        Architecture = [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
    }
    Api           = [ordered] @{
        CmdletCount   = $module.ExportedCmdlets.Count
        FunctionCount = $module.ExportedFunctions.Count
        AliasCount    = $module.ExportedAliases.Count
        VariableCount = $module.ExportedVariables.Count
        Commands      = @($commandInventory)
        Providers     = $providerInventory
        TypeAcceleratorsAdded = @(
            $acceleratorsAfter |
                Where-Object { $_ -notin $acceleratorsBefore } |
                Sort-Object
        )
        TypeDataFiles   = $typeDataFiles
        FormatDataFiles = $formatDataFiles
    }
}

$resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
    $OutputPath
)
$outputDirectory = Split-Path -Parent $resolvedOutputPath
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$inventory |
    ConvertTo-Json -Depth 12 |
    Set-Content -LiteralPath $resolvedOutputPath -Encoding utf8

Get-Item -LiteralPath $resolvedOutputPath
