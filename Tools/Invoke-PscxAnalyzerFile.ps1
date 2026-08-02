[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $AnalyzerManifest,

    [Parameter(Mandatory)]
    [string] $Path,

    [string] $IncludeRule
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module $AnalyzerManifest -Force -ErrorAction Stop
$content = [IO.File]::ReadAllText($Path)
$content = [regex]::Replace(
    $content,
    '(?ms)^# SIG # Begin signature block\r?\n.*?# SIG # End signature block\r?\n?',
    ''
)
$analyzerArguments = @{
    ScriptDefinition = $content
    Severity = @('Error', 'Warning', 'Information')
    ExcludeRule = 'PSUseToExportFieldsInManifest'
}
if ($IncludeRule) {
    $analyzerArguments.IncludeRule = @($IncludeRule -split ',')
}
$diagnostics = @(
    Invoke-ScriptAnalyzer @analyzerArguments |
        ForEach-Object {
            [ordered]@{
                Severity = $_.Severity.ToString()
                RuleName = $_.RuleName
                ScriptPath = $Path
                Line = $_.Line
                Message = $_.Message
            }
        }
)
ConvertTo-Json -InputObject $diagnostics -Depth 3 -Compress
