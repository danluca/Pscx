[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ModulePath,

    [Parameter(Mandatory)]
    [string] $HelpBuilderPath,

    [Parameter(Mandatory)]
    [string] $OutputPath,

    [Parameter(Mandatory)]
    [string] $Configuration
)

$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

$modulePath = (Resolve-Path -LiteralPath $ModulePath).Path
$helpBuilderPath = (Resolve-Path -LiteralPath $HelpBuilderPath).Path
$destinationPath = [System.IO.Path]::GetFullPath($OutputPath)
$workspacePath = Join-Path (Split-Path -Parent $destinationPath) 'help-work'
$outputPath = Join-Path $workspacePath 'Output'

if (Test-Path -LiteralPath $workspacePath) {
    Remove-Item -LiteralPath $workspacePath -Recurse -Force
}

New-Item -ItemType Directory -Path $workspacePath -Force | Out-Null
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
Get-ChildItem -LiteralPath $modulePath |
    Copy-Item -Destination $workspacePath -Recurse -Force
Get-ChildItem -LiteralPath $helpBuilderPath |
    Copy-Item -Destination $workspacePath -Recurse -Force

try {
    Import-Module (Join-Path $workspacePath 'Pscx.psd1') -Force
    Import-Module (Join-Path $workspacePath 'PscxHelp.psd1') -Force

    & (Join-Path $workspacePath 'Scripts/GeneratePscxHelpXml.ps1') `
        $outputPath `
        (Join-Path $workspacePath 'Help') `
        -Configuration $Configuration

    & (Join-Path $workspacePath 'Scripts/GenerateAboutPsxcHelpTxt.ps1') `
        $outputPath `
        -Configuration $Configuration

    Get-ChildItem -LiteralPath $outputPath -File |
        Where-Object Name -NotLike 'Merged*' |
        Copy-Item -Destination $destinationPath -Force
}
finally {
    Remove-Module PscxHelp, Pscx -Force -ErrorAction SilentlyContinue
}
