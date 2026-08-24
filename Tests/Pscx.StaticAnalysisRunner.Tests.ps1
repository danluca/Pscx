param(
    [string] $PowerShellPath = 'pwsh'
)

BeforeAll {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $repositoryRoot 'Tools/PscxAnalyzerRunner.psm1') -Force
    $powerShellExecutable = $PowerShellPath
    $fakeWorker = Join-Path $TestDrive 'FakeAnalyzerWorker.ps1'
    Set-Content -LiteralPath $fakeWorker -Encoding utf8 -Value @'
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $AnalyzerManifest,

    [Parameter(Mandatory)]
    [string] $Path,

    [string] $IncludeRule
)

switch ([IO.Path]::GetFileName($Path)) {
    'permanent.ps1' {
        [Console]::Out.WriteLine('worker stdout')
        [Console]::Error.WriteLine('worker stderr')
        exit 17
    }
    'transient.ps1' {
        if (-not (Test-Path -LiteralPath $AnalyzerManifest)) {
            Set-Content -LiteralPath $AnalyzerManifest -Value 'attempted' -NoNewline
            [Console]::Out.WriteLine('first-attempt stdout')
            [Console]::Error.WriteLine('first-attempt stderr')
            exit 23
        }
        [Console]::Out.WriteLine('[]')
    }
    'finding.ps1' {
        [ordered]@{
            Severity = 'Warning'
            RuleName = 'FakeRule'
            ScriptPath = $Path
            Line = 7
            Message = 'genuine analyzer finding'
        } | ConvertTo-Json -Compress
    }
}
'@
}

Describe 'PSScriptAnalyzer child-process orchestration' {
    It 'retries a permanent infrastructure failure once and preserves complete context' {
        $result = Invoke-PscxAnalyzerWorkItem `
            -PowerShellExecutable $powerShellExecutable `
            -AnalyzerScript $fakeWorker `
            -AnalyzerManifest (Join-Path $TestDrive 'unused.psd1') `
            -Path (Join-Path $TestDrive 'permanent.ps1') `
            -IncludeRule 'RuleOne,RuleTwo'

        $result.Succeeded | Should -BeFalse
        $result.AttemptCount | Should -Be 2
        $result.InfrastructureFailures.Count | Should -Be 2
        $message = Format-PscxAnalyzerInfrastructureFailure -Failure $result.InfrastructureFailures
        $message | Should -Match 'Attempt: 1'
        $message | Should -Match 'Attempt: 2'
        $message | Should -Match ([regex]::Escape((Join-Path $TestDrive 'permanent.ps1')))
        $message | Should -Match 'Rule batch: RuleOne,RuleTwo'
        $message | Should -Match 'Exit code: 17'
        $message | Should -Match 'worker stdout'
        $message | Should -Match 'worker stderr'
    }

    It 'retries a transient infrastructure failure once and reports the recovered attempt' {
        $statePath = Join-Path $TestDrive 'transient.state'
        $result = Invoke-PscxAnalyzerWorkItem `
            -PowerShellExecutable $powerShellExecutable `
            -AnalyzerScript $fakeWorker `
            -AnalyzerManifest $statePath `
            -Path (Join-Path $TestDrive 'transient.ps1')

        $result.Succeeded | Should -BeTrue
        $result.AttemptCount | Should -Be 2
        $result.InfrastructureFailures.Count | Should -Be 1
        $result.InfrastructureFailures[0].ExitCode | Should -Be 23
        $result.InfrastructureFailures[0].StandardError | Should -Match 'first-attempt stderr'
        $result.Diagnostics.Count | Should -Be 0
    }

    It 'returns genuine analyzer findings without treating them as infrastructure failures' {
        $result = Invoke-PscxAnalyzerWorkItem `
            -PowerShellExecutable $powerShellExecutable `
            -AnalyzerScript $fakeWorker `
            -AnalyzerManifest (Join-Path $TestDrive 'unused.psd1') `
            -Path (Join-Path $TestDrive 'finding.ps1')

        $result.Succeeded | Should -BeTrue
        $result.AttemptCount | Should -Be 1
        $result.InfrastructureFailures.Count | Should -Be 0
        $result.Diagnostics.Count | Should -Be 1
        $result.Diagnostics[0].RuleName | Should -Be 'FakeRule'
        $result.Diagnostics[0].Message | Should -Be 'genuine analyzer finding'
    }
}
