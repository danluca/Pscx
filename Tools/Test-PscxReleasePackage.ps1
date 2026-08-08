# Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
# Licensed under MIT license.

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $PackagePath,

    [Parameter(Mandatory)]
    [ValidateSet('Core', 'Full')]
    [string] $ExpectedBuildScope,

    [Parameter(Mandatory)]
    [version] $ExpectedVersion,

    [string] $PowerShellPath = 'pwsh',

    [Parameter(DontShow)]
    [string] $InstalledModuleRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = [Management.Automation.OutputRendering]::PlainText

if ($InstalledModuleRoot) {
    $env:PSModulePath = $InstalledModuleRoot
    $warnings = @()
    Import-Module Pscx -Force -ErrorAction Stop -WarningVariable warnings
    $module = Get-Module Pscx -ErrorAction Stop
    $commands = @(Get-Command -Module Pscx*)
    $aboutHelp = Get-Help about_Pscx -ErrorAction Stop

    if (-not $module.Path.StartsWith($InstalledModuleRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "PowerShell imported PSCX from an unexpected location: $($module.Path)"
    }
    if ($module.Version -ne $ExpectedVersion) {
        throw "Installed PSCX version '$($module.Version)' does not match '$ExpectedVersion'."
    }
    if ($commands.Count -eq 0) {
        throw 'The installed package exported no commands.'
    }
    if (-not $aboutHelp) {
        throw 'The installed package did not expose about_Pscx help.'
    }
    $windowsAssemblyPath = Join-Path (Split-Path -Parent $module.Path) 'Pscx.Win.dll'
    $windowsCommand = Get-Command Get-Privilege -ErrorAction SilentlyContinue
    if ($ExpectedBuildScope -eq 'Full' -and (
        -not (Test-Path -LiteralPath $windowsAssemblyPath) -or -not $windowsCommand
    )) {
        throw 'The installed Full package did not expose its Windows companion payload.'
    }
    if ($ExpectedBuildScope -eq 'Core' -and (
        (Test-Path -LiteralPath $windowsAssemblyPath) -or $windowsCommand
    )) {
        throw 'The installed Core package unexpectedly exposed a Windows companion payload.'
    }

    [ordered]@{
        Version = $module.Version.ToString()
        BuildScope = $ExpectedBuildScope
        CommandCount = $commands.Count
        WarningCount = $warnings.Count
        ModulePath = $module.Path
    } | ConvertTo-Json -Compress
    return
}

$resolvedPackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) (
    'Pscx.ReleaseValidation.{0}' -f [guid]::NewGuid().ToString('N')
)
$modulePath = Join-Path $temporaryRoot 'Modules'
try {
    New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
    Expand-Archive -LiteralPath $resolvedPackagePath -DestinationPath $modulePath

    $manifestPath = Join-Path $modulePath 'Pscx/Pscx.psd1'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw 'The release archive does not contain Pscx/Pscx.psd1 at its installation root.'
    }

    $arguments = @(
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-File',
        $PSCommandPath,
        '-PackagePath',
        $resolvedPackagePath,
        '-ExpectedBuildScope',
        $ExpectedBuildScope,
        '-ExpectedVersion',
        $ExpectedVersion.ToString(),
        '-InstalledModuleRoot',
        $modulePath
    )
    & $PowerShellPath @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Installed-package validation failed with exit code $LASTEXITCODE."
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
