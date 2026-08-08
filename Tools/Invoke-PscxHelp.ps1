[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ModulePath,

    [Parameter(Mandatory)]
    [string] $OutputPath,

    [Parameter(Mandatory)]
    [ValidateSet('Core', 'Full')]
    [string] $BuildScope
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$policy = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'Tests/TestPolicy.psd1')
$platyPSVersion = [string]$policy.PlatyPSVersion
$toolModuleRoot = Join-Path $repositoryRoot '.tools/modules'
$platyPSManifest = Join-Path $toolModuleRoot "Microsoft.PowerShell.PlatyPS/$platyPSVersion/Microsoft.PowerShell.PlatyPS.psd1"

if (-not (Test-Path -LiteralPath $platyPSManifest)) {
    New-Item -ItemType Directory -Path $toolModuleRoot -Force | Out-Null
    Write-Host "Saving Microsoft.PowerShell.PlatyPS $platyPSVersion to $toolModuleRoot"
    Save-PSResource -Name Microsoft.PowerShell.PlatyPS -Version $platyPSVersion -Repository PSGallery `
        -Path $toolModuleRoot -TrustRepository
}
if (-not (Test-Path -LiteralPath $platyPSManifest)) {
    throw "Microsoft.PowerShell.PlatyPS $platyPSVersion was not saved at the expected path: $platyPSManifest"
}

Import-Module $platyPSManifest -Force -ErrorAction Stop
if ((Get-Module Microsoft.PowerShell.PlatyPS).Version -ne [version]$platyPSVersion) {
    throw "Expected Microsoft.PowerShell.PlatyPS $platyPSVersion but loaded $((Get-Module Microsoft.PowerShell.PlatyPS).Version)."
}

$modulePath = (Resolve-Path -LiteralPath $ModulePath).Path
$outputPath = [IO.Path]::GetFullPath($OutputPath)
$commandDocsRoot = Join-Path $repositoryRoot 'docs/commands'
$packageNames = @('Pscx')
if ($BuildScope -eq 'Full') {
    $packageNames += 'Pscx.Win'
}

$markdownFiles = @(
    foreach ($packageName in $packageNames) {
        $packageDocsPath = Join-Path $commandDocsRoot $packageName
        if (-not (Test-Path -LiteralPath $packageDocsPath -PathType Container)) {
            throw "Command help directory is missing: $packageDocsPath"
        }
        Get-ChildItem -LiteralPath $packageDocsPath -Filter *.md -File
    }
)
if ($markdownFiles.Count -eq 0) {
    throw 'No Markdown command help files were found.'
}

$placeholderMatches = @($markdownFiles | Select-String -Pattern '\{\{.+\}\}')
if ($placeholderMatches.Count -gt 0) {
    throw "Markdown help contains $($placeholderMatches.Count) unresolved template placeholder(s)."
}

$commandHelp = @(
    foreach ($file in $markdownFiles) {
        # Run PlatyPS's schema validator for every topic. Its Boolean result is
        # also false for non-fatal authoring warnings (for example, an empty
        # optional NOTES section), so errors are enforced from Diagnostics.
        Test-MarkdownCommandHelp -LiteralPath $file.FullName | Out-Null

        $help = Import-MarkdownCommandHelp -LiteralPath $file.FullName
        $errors = @($help.Diagnostics.Messages | Where-Object Severity -EQ Error)
        if ($errors.Count -gt 0) {
            throw "PlatyPS reported $($errors.Count) error(s) for $($file.FullName): $($errors.Message -join '; ')"
        }
        $help
    }
)

try {
    Import-Module (Join-Path $modulePath 'Pscx.psd1') -Force -ErrorAction Stop
    $commands = @(Get-Command -Module Pscx -CommandType Cmdlet | Sort-Object Name)
    $documentedNames = @($commandHelp.Title | Sort-Object)
    $commandNames = @($commands.Name | Sort-Object)
    $missingTopics = @($commandNames | Where-Object { $_ -notin $documentedNames })
    $extraTopics = @($documentedNames | Where-Object { $_ -notin $commandNames })
    if ($missingTopics.Count -gt 0 -or $extraTopics.Count -gt 0) {
        throw "Compiled help topic mismatch. Missing: $($missingTopics -join ', '); extra: $($extraTopics -join ', ')."
    }

    $commonParameterNames = @(
        'Debug', 'ErrorAction', 'ErrorVariable', 'InformationAction',
        'InformationVariable', 'OutBuffer', 'OutVariable', 'PipelineVariable',
        'ProgressAction', 'Verbose', 'WarningAction', 'WarningVariable'
    )
    foreach ($help in $commandHelp) {
        $command = Get-Command -Name $help.Title -Module Pscx
        $actualParameters = @(
            $command.Parameters.Keys |
                Where-Object { $_ -notin $commonParameterNames } |
                Sort-Object
        )
        $documentedParameters = @(
            $help.Parameters | ForEach-Object Name | Sort-Object
        )
        if (Compare-Object $actualParameters $documentedParameters) {
            throw "Documented parameters do not match Get-Command for $($help.Title)."
        }

        foreach ($parameterSet in $command.ParameterSets) {
            $documentedSet = @($help.Syntax | Where-Object ParameterSetName -EQ $parameterSet.Name)
            if ($documentedSet.Count -ne 1) {
                throw "Documented syntax is missing parameter set '$($parameterSet.Name)' for $($help.Title)."
            }
            $runtimeSetParameters = @(
                $parameterSet.Parameters |
                    ForEach-Object Name |
                    Where-Object { $_ -notin $commonParameterNames } |
                    Sort-Object
            )
            $documentedSetParameters = @($documentedSet[0].ParameterNames | Sort-Object)
            if (Compare-Object $runtimeSetParameters $documentedSetParameters) {
                throw "Documented syntax does not match parameter set '$($parameterSet.Name)' for $($help.Title)."
            }
        }
    }
}
finally {
    Remove-Module Pscx -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
foreach ($packageName in $packageNames) {
    $packageHelp = @($commandHelp | Where-Object ModuleName -EQ $packageName)
    if ($packageHelp.Count -eq 0) {
        throw "No command help was found for package $packageName."
    }
    $generatedMaml = @(
        $packageHelp | Export-MamlCommandHelp -OutputFolder $outputPath -Encoding utf8 -Force
    )
    foreach ($file in $generatedMaml) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $outputPath $file.Name) -Force
    }
    $nestedOutputPath = Join-Path $outputPath $packageName
    if (Test-Path -LiteralPath $nestedOutputPath) {
        Remove-Item -LiteralPath $nestedOutputPath -Recurse -Force
    }
}

$aboutMarkdownPath = Join-Path $repositoryRoot 'docs/about/about_Pscx.md'
$aboutOutputPath = Join-Path $outputPath 'about_Pscx.help.txt'
$manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $modulePath 'Pscx.psd1')
$aboutLines = [Collections.Generic.List[string]]::new()
$aboutLines.Add('TOPIC')
$aboutLines.Add("    about_Pscx (version $($manifest.ModuleVersion))")
$inCodeBlock = $false
foreach ($line in Get-Content -LiteralPath $aboutMarkdownPath) {
    if ($line -match '^# about_Pscx\s*$') {
        continue
    }
    if ($line -match '^## (?<heading>.+)$') {
        $aboutLines.Add('')
        $aboutLines.Add($Matches.heading.ToUpperInvariant())
        continue
    }
    if ($line -match '^```') {
        $inCodeBlock = -not $inCodeBlock
        continue
    }

    $plainLine = $line -replace '`([^`]+)`', '$1' -replace '\*\*([^*]+)\*\*', '$1'
    $indent = if ($inCodeBlock) { '        ' } else { '    ' }
    $aboutLines.Add("$indent$plainLine".TrimEnd())
}
$aboutLines | Set-Content -LiteralPath $aboutOutputPath -Encoding utf8

$expectedFiles = @($packageNames | ForEach-Object { "$_.dll-Help.xml" }) + 'about_Pscx.help.txt'
$missingOutputs = @($expectedFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $outputPath $_)) })
if ($missingOutputs.Count -gt 0) {
    throw "Generated help output is missing: $($missingOutputs -join ', ')."
}

Write-Host "Validated $($commandHelp.Count) Markdown command topics and generated help in $outputPath."
