[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Build', 'Import')]
    [string] $Kind
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
[xml] $versionDocument = Get-Content -LiteralPath (Join-Path $repositoryRoot 'Directory.Build.props') -Raw
$properties = $versionDocument.Project.PropertyGroup
$minimumVersion = [string]$properties.PowerShellMinimumVersion
$currentVersion = [string]$properties.PowerShellSdkVersion
foreach ($version in @($minimumVersion, $currentVersion)) {
    $parsedVersion = $null
    if (-not [version]::TryParse($version, [ref]$parsedVersion)) {
        throw "Directory.Build.props contains an invalid PowerShell version '$version'."
    }
}

$platforms = @(
    [ordered]@{
        os = 'windows-latest'
        platform = 'windows'
        buildScope = 'Full'
        powerShellExecutable = '.tools/powershell/pwsh.exe'
    },
    [ordered]@{
        os = 'ubuntu-latest'
        platform = 'linux'
        buildScope = 'Core'
        powerShellExecutable = '.tools/powershell/pwsh'
    },
    [ordered]@{
        os = 'macos-latest'
        platform = 'macos'
        buildScope = 'Core'
        powerShellExecutable = '.tools/powershell/pwsh'
    }
)

$include = if ($Kind -eq 'Build') {
    foreach ($platform in $platforms) {
        [ordered]@{
            os = $platform.os
            platform = $platform.platform
            buildScope = $platform.buildScope
            powerShellExecutable = $platform.powerShellExecutable
            powerShellVersion = $currentVersion
        }
    }
}
else {
    $versions = @(
        [ordered]@{ label = 'minimum'; version = $minimumVersion },
        [ordered]@{ label = 'current'; version = $currentVersion }
    )

    foreach ($platform in $platforms) {
        foreach ($version in $versions) {
            [ordered]@{
                os = $platform.os
                platform = $platform.platform
                buildScope = $platform.buildScope
                powerShellExecutable = $platform.powerShellExecutable
                powerShellLabel = $version.label
                powerShellVersion = $version.version
            }
        }
    }
}

[ordered]@{ include = @($include) } | ConvertTo-Json -Depth 5 -Compress
