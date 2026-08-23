[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'Parameters are Pester container data consumed in BeforeAll.'
)]
param(
    [Parameter(Mandatory)]
    [string] $ModulePath,

    [Parameter(Mandatory)]
    [string] $TimeModulePath,

    [Parameter(Mandatory)]
    [string] $PowerShellPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'Packaged Pscx.Time module' {
    BeforeAll {
        $script:modulePath = (Resolve-Path -LiteralPath $ModulePath).Path
        $script:timeModulePath = (Resolve-Path -LiteralPath $TimeModulePath).Path
        $script:powerShellPath = $PowerShellPath
        $script:timeManifestPath = Join-Path $script:timeModulePath 'Pscx.Time.psd1'
    }

    It 'keeps NodaTime and time types out of the default module payload and import' {
        @(Get-ChildItem -LiteralPath $script:modulePath -Recurse -File |
            Where-Object Name -Match '^(NodaTime|Pscx\.Time)\.') | Should -HaveCount 0

        $output = & $script:powerShellPath -NoLogo -NoProfile -NonInteractive -File `
            (Join-Path $PSScriptRoot 'Invoke-PscxTimeImportProbe.ps1') `
            -ModulePath $script:modulePath -TimeModulePath $script:timeModulePath
        $LASTEXITCODE | Should -Be 0
        $probe = $output | Select-Object -Last 1 | ConvertFrom-Json
        @($probe.BeforeTimeImport) | Should -HaveCount 0
        $probe.NodaAssemblyCountBeforeTimeImport | Should -Be 0
        @($probe.Registered) | Sort-Object | Should -Be @(
            'isodate', 'localtime', 'offsettime', 'tz', 'tzi', 'zonedtime'
        )
        @($probe.AfterRemoval) | Should -HaveCount 0
        $probe.Sample | Should -Match '12:00:01'
        $probe.HelpName | Should -Be 'about_Pscx.Time'
    }

    It 'has a valid accelerator-only manifest and the approved dependency payload' {
        $manifest = Test-ModuleManifest -Path $script:timeManifestPath
        @($manifest.ExportedCommands.Values) | Should -HaveCount 0
        @('Pscx.Time.dll', 'NodaTime.dll', 'NodaTime.xml', 'THIRD-PARTY-NOTICES.md') |
            ForEach-Object { Join-Path $script:timeModulePath $_ | Should -Exist }
        Join-Path $script:timeModulePath 'en-US/about_Pscx.Time.help.txt' | Should -Exist
    }
}
