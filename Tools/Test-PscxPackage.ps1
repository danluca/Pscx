[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ManifestPath
)

$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

Import-Module $ManifestPath -Force -ErrorAction Stop
$commands = @(Get-Command -Module Pscx*)
if ($commands.Count -eq 0) {
    throw 'Packaged module exported no commands.'
}

Write-Host "Validated $($commands.Count) packaged commands."
