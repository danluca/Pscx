Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-PscxAnalyzerProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $PowerShellExecutable,

        [Parameter(Mandatory)]
        [string] $AnalyzerScript,

        [Parameter(Mandatory)]
        [string] $AnalyzerManifest,

        [Parameter(Mandatory)]
        [string] $Path,

        [string] $IncludeRule
    )

    $arguments = @(
        '-NoLogo'
        '-NoProfile'
        '-NonInteractive'
        '-File'
        $AnalyzerScript
        '-AnalyzerManifest'
        $AnalyzerManifest
        '-Path'
        $Path
    )
    if ($IncludeRule) {
        $arguments += @('-IncludeRule', $IncludeRule)
    }

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $PowerShellExecutable
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $arguments) {
        $startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw "Could not start analyzer worker '$PowerShellExecutable'."
        }
        $standardOutputTask = $process.StandardOutput.ReadToEndAsync()
        $standardErrorTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()

        [pscustomobject]@{
            ExitCode = $process.ExitCode
            StandardOutput = $standardOutputTask.GetAwaiter().GetResult()
            StandardError = $standardErrorTask.GetAwaiter().GetResult()
        }
    }
    finally {
        $process.Dispose()
    }
}

function Invoke-PscxAnalyzerWorkItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $PowerShellExecutable,

        [Parameter(Mandatory)]
        [string] $AnalyzerScript,

        [Parameter(Mandatory)]
        [string] $AnalyzerManifest,

        [Parameter(Mandatory)]
        [string] $Path,

        [string] $IncludeRule,

        [ValidateRange(1, 2)]
        [int] $MaximumAttempts = 2
    )

    $ruleBatch = if ($IncludeRule) { $IncludeRule } else { 'all reviewed rules' }
    $failures = [Collections.Generic.List[object]]::new()
    for ($attempt = 1; $attempt -le $MaximumAttempts; $attempt++) {
        try {
            $processResult = Invoke-PscxAnalyzerProcess `
                -PowerShellExecutable $PowerShellExecutable `
                -AnalyzerScript $AnalyzerScript `
                -AnalyzerManifest $AnalyzerManifest `
                -Path $Path `
                -IncludeRule $IncludeRule
        }
        catch {
            $processResult = [pscustomobject]@{
                ExitCode = $null
                StandardOutput = ''
                StandardError = $_.Exception.ToString()
            }
        }

        $reason = $null
        $diagnostics = @()
        if ($processResult.ExitCode -ne 0) {
            $reason = "Analyzer worker exited with code $($processResult.ExitCode)."
        }
        else {
            try {
                $diagnostics = @($processResult.StandardOutput | ConvertFrom-Json -ErrorAction Stop)
            }
            catch {
                $reason = "Analyzer worker returned invalid JSON: $($_.Exception.Message)"
            }
        }

        if (-not $reason) {
            return [pscustomobject]@{
                Succeeded = $true
                Path = $Path
                RuleBatch = $ruleBatch
                AttemptCount = $attempt
                Diagnostics = $diagnostics
                InfrastructureFailures = @($failures)
            }
        }

        $failures.Add([pscustomobject]@{
                Path = $Path
                RuleBatch = $ruleBatch
                Attempt = $attempt
                ExitCode = $processResult.ExitCode
                StandardOutput = $processResult.StandardOutput
                StandardError = $processResult.StandardError
                Reason = $reason
            })
    }

    [pscustomobject]@{
        Succeeded = $false
        Path = $Path
        RuleBatch = $ruleBatch
        AttemptCount = $MaximumAttempts
        Diagnostics = @()
        InfrastructureFailures = @($failures)
    }
}

function Format-PscxAnalyzerInfrastructureFailure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]] $Failure,

        [string] $Heading = 'PSScriptAnalyzer infrastructure failure'
    )

    $sections = [Collections.Generic.List[string]]::new()
    $sections.Add("$Heading after $($Failure.Count) attempt(s).")
    foreach ($item in $Failure) {
        $exitCode = if ($null -eq $item.ExitCode) { '<not available>' } else { $item.ExitCode }
        $standardOutput = if ([string]::IsNullOrWhiteSpace($item.StandardOutput)) {
            '<empty>'
        }
        else {
            $item.StandardOutput.TrimEnd()
        }
        $standardError = if ([string]::IsNullOrWhiteSpace($item.StandardError)) {
            '<empty>'
        }
        else {
            $item.StandardError.TrimEnd()
        }
        $sections.Add(@"
Attempt: $($item.Attempt)
File: $($item.Path)
Rule batch: $($item.RuleBatch)
Exit code: $exitCode
Reason: $($item.Reason)
Standard output:
$standardOutput
Standard error:
$standardError
"@.Trim())
    }

    $sections -join [Environment]::NewLine
}

Export-ModuleMember -Function `
    Invoke-PscxAnalyzerWorkItem, `
    Format-PscxAnalyzerInfrastructureFailure
