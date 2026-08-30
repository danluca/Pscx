<#
.SYNOPSIS
    Generates a self-contained HTML dashboard from PSCX test result files.
.DESCRIPTION
    Reads the authoritative TRX, NUnit XML, Cobertura XML, static-analysis JSON,
    and unified-summary files beneath ResultsPath. The generated HTML is a
    convenience view only and does not replace or modify those source files.

    Failure text is HTML encoded and absolute filesystem paths are redacted.
    The report contains no external scripts, stylesheets, fonts, or images.
.PARAMETER ResultsPath
    Directory containing the PSCX test result files.
.PARAMETER OutputPath
    Destination HTML file. Defaults to Pscx.TestDashboard.html in ResultsPath.
.EXAMPLE
    ./Tools/New-PscxTestDashboard.ps1 -ResultsPath ./artifacts/test-results

    Regenerates the dashboard from an existing local test run.
.OUTPUTS
    System.IO.FileInfo
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ResultsPath,

    [ValidateNotNullOrEmpty()]
    [string] $OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-PscxSafeText {
    param(
        [AllowNull()][string] $Text,
        [Parameter(Mandatory)][string[]] $SensitiveRoot
    )

    if ([string]::IsNullOrEmpty($Text)) {
        return ''
    }

    $safe = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
    foreach ($root in $SensitiveRoot | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object Length -Descending -Unique) {
        $comparison = if ($IsWindows) {
            [StringComparison]::OrdinalIgnoreCase
        }
        else {
            [StringComparison]::Ordinal
        }
        while ($safe.IndexOf($root, $comparison) -ge 0) {
            $index = $safe.IndexOf($root, $comparison)
            $safe = $safe.Remove($index, $root.Length).Insert($index, '[path]')
        }
    }

    $safe = [regex]::Replace(
        $safe,
        '(?i)(?<![A-Za-z0-9+.-])(?:[A-Z]:[\\/]|\\\\)[^\s<>"'']+',
        '[path]'
    )
    $safe = [regex]::Replace(
        $safe,
        '(?<![:A-Za-z0-9])/(?:[^/\s<>"'']+/)*[^/\s<>"'']+',
        '[path]'
    )
    return $safe
}

function ConvertTo-PscxHtml {
    param([AllowNull()][string] $Text)

    return [Net.WebUtility]::HtmlEncode([string]$Text)
}

function ConvertTo-PscxDurationValue {
    param([AllowNull()][string] $Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    $number = 0.0
    if ([double]::TryParse(
            $Value,
            [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$number
        )) {
        return $number
    }
    $duration = [TimeSpan]::Zero
    if ([TimeSpan]::TryParse($Value, [Globalization.CultureInfo]::InvariantCulture, [ref]$duration)) {
        return $duration.TotalSeconds
    }
    return $null
}

function Get-PscxXmlAttribute {
    param(
        [Parameter(Mandatory)][Xml.XmlElement] $Element,
        [Parameter(Mandatory)][string] $Name,
        [string] $Default = '0'
    )

    $attribute = $Element.Attributes[$Name]
    if ($null -eq $attribute) {
        return $Default
    }
    return $attribute.Value
}

function Get-PscxXmlNodeText {
    param([AllowNull()][Xml.XmlNode] $Node)

    if ($null -eq $Node) {
        return ''
    }
    return $Node.InnerText
}

function Get-PscxCoveragePercent {
    param([Parameter(Mandatory)][string] $Path)

    [xml] $coverage = Get-Content -LiteralPath $Path -Raw
    $root = $coverage.DocumentElement
    if ($null -eq $root -or -not $root.HasAttribute('line-rate')) {
        throw "Coverage report has no coverage/line-rate attribute: $Path"
    }
    $rate = [decimal]::Parse(
        $root.GetAttribute('line-rate'),
        [Globalization.CultureInfo]::InvariantCulture
    )
    return [Math]::Round(100 * $rate, 2)
}

function Get-PscxPesterResult {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string[]] $SensitiveRoot
    )

    [xml] $document = Get-Content -LiteralPath $Path -Raw
    $run = $document.DocumentElement
    $failed = [int](Get-PscxXmlAttribute -Element $run -Name failed)
    $failures = @(
        $document.SelectNodes("//*[local-name()='test-case' and @result='Failed']") |
            ForEach-Object {
                $messageNode = $_.SelectSingleNode("./*[local-name()='failure']/*[local-name()='message']")
                $stackNode = $_.SelectSingleNode("./*[local-name()='failure']/*[local-name()='stack-trace']")
                [pscustomobject]@{
                    Name = ConvertTo-PscxSafeText -Text $_.GetAttribute('name') -SensitiveRoot $SensitiveRoot
                    Message = ConvertTo-PscxSafeText `
                        -Text (Get-PscxXmlNodeText $messageNode) -SensitiveRoot $SensitiveRoot
                    Stack = ConvertTo-PscxSafeText `
                        -Text (Get-PscxXmlNodeText $stackNode) -SensitiveRoot $SensitiveRoot
                }
            }
    )
    return [pscustomobject]@{
        Name = 'PowerShell / Pester'
        Key = 'Pester'
        Status = if ($failed -gt 0) { 'Failed' } else { 'Passed' }
        Total = [int](Get-PscxXmlAttribute -Element $run -Name total)
        Passed = [int](Get-PscxXmlAttribute -Element $run -Name passed)
        Failed = $failed
        Skipped = [int](Get-PscxXmlAttribute -Element $run -Name skipped)
        DurationSeconds = ConvertTo-PscxDurationValue -Value (
            Get-PscxXmlAttribute -Element $run -Name duration -Default ''
        )
        SourceAvailable = $true
        Failures = $failures
    }
}

function Get-PscxManagedResult {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string[]] $SensitiveRoot
    )

    [xml] $document = Get-Content -LiteralPath $Path -Raw
    $counters = $document.SelectSingleNode(
        "/*[local-name()='TestRun']/*[local-name()='ResultSummary']/*[local-name()='Counters']"
    )
    if ($null -eq $counters) {
        throw "Managed TRX has no ResultSummary/Counters element: $Path"
    }
    $failureCount = 0
    foreach ($name in 'failed', 'error', 'timeout', 'aborted') {
        $attribute = $counters.Attributes[$name]
        if ($null -ne $attribute) {
            $failureCount += [int]$attribute.Value
        }
    }
    $failures = @(
        $document.SelectNodes(
            "//*[local-name()='UnitTestResult' and not(@outcome='Passed') and not(@outcome='NotExecuted')]"
        ) | ForEach-Object {
            $messageNode = $_.SelectSingleNode(
                "./*[local-name()='Output']/*[local-name()='ErrorInfo']/*[local-name()='Message']"
            )
            $stackNode = $_.SelectSingleNode(
                "./*[local-name()='Output']/*[local-name()='ErrorInfo']/*[local-name()='StackTrace']"
            )
            [pscustomobject]@{
                Name = ConvertTo-PscxSafeText -Text $_.GetAttribute('testName') -SensitiveRoot $SensitiveRoot
                Message = ConvertTo-PscxSafeText `
                    -Text (Get-PscxXmlNodeText $messageNode) -SensitiveRoot $SensitiveRoot
                Stack = ConvertTo-PscxSafeText `
                    -Text (Get-PscxXmlNodeText $stackNode) -SensitiveRoot $SensitiveRoot
            }
        }
    )
    $times = $document.SelectSingleNode("/*[local-name()='TestRun']/*[local-name()='Times']")
    $duration = $null
    if ($null -ne $times -and $times.HasAttribute('start') -and $times.HasAttribute('finish')) {
        $start = [DateTimeOffset]::Parse($times.GetAttribute('start'), [Globalization.CultureInfo]::InvariantCulture)
        $finish = [DateTimeOffset]::Parse($times.GetAttribute('finish'), [Globalization.CultureInfo]::InvariantCulture)
        $duration = ($finish - $start).TotalSeconds
    }
    return [pscustomobject]@{
        Name = 'Managed / .NET'
        Key = 'Managed'
        Status = if ($failureCount -gt 0) { 'Failed' } else { 'Passed' }
        Total = [int]$counters.GetAttribute('total')
        Passed = [int]$counters.GetAttribute('passed')
        Failed = $failureCount
        Skipped = [int]$counters.GetAttribute('notExecuted')
        DurationSeconds = $duration
        SourceAvailable = $true
        Failures = $failures
    }
}

function Get-PscxStaticResult {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string[]] $SensitiveRoot
    )

    $summary = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $failures = @(
        $summary.AnalyzerOrchestration.InfrastructureFailures |
            Where-Object { $null -ne $_ } |
            ForEach-Object {
            $detail = $_ | ConvertTo-Json -Depth 8 -Compress
            [pscustomobject]@{
                Name = 'Analyzer infrastructure'
                Message = ConvertTo-PscxSafeText -Text $detail -SensitiveRoot $SensitiveRoot
                Stack = ''
            }
            }
    )
    return [pscustomobject]@{
        Name = 'Static analysis'
        Key = 'Static'
        Status = [string]$summary.Status
        Total = [int]$summary.AnalyzerCounts.Warning + [int]$summary.AnalyzerCounts.Information
        Passed = $null
        Failed = $null
        Skipped = $null
        DurationSeconds = $null
        WarningCount = [int]$summary.AnalyzerCounts.Warning
        InformationCount = [int]$summary.AnalyzerCounts.Information
        SourceAvailable = $true
        Failures = $failures
    }
}

function ConvertTo-PscxMissingResult {
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Key
    )

    return [pscustomobject]@{
        Name = $Name
        Key = $Key
        Status = 'Incomplete'
        Total = $null
        Passed = $null
        Failed = $null
        Skipped = $null
        DurationSeconds = $null
        WarningCount = $null
        InformationCount = $null
        SourceAvailable = $false
        Failures = @()
    }
}

function Get-PscxOrchestrationValue {
    param(
        [AllowNull()][object] $Summary,
        [Parameter(Mandatory)][string] $Suite,
        [Parameter(Mandatory)][string] $Property
    )

    if ($null -eq $Summary -or $null -eq $Summary.Suites) {
        return $null
    }
    $suiteProperty = $Summary.Suites.PSObject.Properties[$Suite]
    if ($null -eq $suiteProperty) {
        return $null
    }
    $valueProperty = $suiteProperty.Value.PSObject.Properties[$Property]
    if ($null -eq $valueProperty) {
        return $null
    }
    return $valueProperty.Value
}

function Format-PscxCount {
    param([AllowNull()][object] $Value)

    if ($null -eq $Value) {
        return '&mdash;'
    }
    return ConvertTo-PscxHtml -Text ([string]$Value)
}

function Format-PscxDuration {
    param([AllowNull()][object] $Seconds)

    if ($null -eq $Seconds) {
        return '&mdash;'
    }
    return ConvertTo-PscxHtml -Text ('{0:N2} s' -f [double]$Seconds)
}

function Format-PscxPercent {
    param([AllowNull()][object] $Value)

    if ($null -eq $Value) {
        return '&mdash;'
    }
    return ConvertTo-PscxHtml -Text ('{0:N2}%' -f [double]$Value)
}

$resolvedResultsPath = (Resolve-Path -LiteralPath $ResultsPath).Path
if (-not $PSBoundParameters.ContainsKey('OutputPath')) {
    $OutputPath = Join-Path $resolvedResultsPath 'Pscx.TestDashboard.html'
}
$resolvedOutputPath = [IO.Path]::GetFullPath($OutputPath)
$outputParent = Split-Path -Parent $resolvedOutputPath
New-Item -ItemType Directory -Path $outputParent -Force | Out-Null

$paths = [ordered]@{
    Pester = Join-Path $resolvedResultsPath 'Pscx.Pester.xml'
    Managed = Join-Path $resolvedResultsPath 'managed/Pscx.InternalTests.trx'
    PowerShellCoverage = Join-Path $resolvedResultsPath 'Pscx.PowerShell.coverage.xml'
    ManagedCoverage = Join-Path $resolvedResultsPath 'Pscx.Managed.coverage.xml'
    Static = Join-Path $resolvedResultsPath 'Pscx.StaticAnalysis.summary.json'
    Unified = Join-Path $resolvedResultsPath 'Pscx.TestSummary.json'
}
if (-not (Test-Path -LiteralPath $paths.Unified -PathType Leaf)) {
    throw 'Cannot generate the dashboard; the required Unified result file is missing.'
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sensitiveRoots = @(
    $repositoryRoot
    $resolvedResultsPath
    [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    [IO.Path]::GetTempPath().TrimEnd([IO.Path]::DirectorySeparatorChar)
    $env:HOME
    $env:USERPROFILE
    $env:TEMP
    $env:TMP
)
$sensitiveRoots = @(
    $sensitiveRoots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)
$unified = Get-Content -LiteralPath $paths.Unified -Raw | ConvertFrom-Json
$suites = @(
    if (Test-Path -LiteralPath $paths.Managed -PathType Leaf) {
        Get-PscxManagedResult -Path $paths.Managed -SensitiveRoot $sensitiveRoots
    }
    else {
        ConvertTo-PscxMissingResult -Name 'Managed / .NET' -Key Managed
    }
    if (Test-Path -LiteralPath $paths.Pester -PathType Leaf) {
        Get-PscxPesterResult -Path $paths.Pester -SensitiveRoot $sensitiveRoots
    }
    else {
        ConvertTo-PscxMissingResult -Name 'PowerShell / Pester' -Key Pester
    }
    if (Test-Path -LiteralPath $paths.Static -PathType Leaf) {
        Get-PscxStaticResult -Path $paths.Static -SensitiveRoot $sensitiveRoots
    }
    else {
        ConvertTo-PscxMissingResult -Name 'Static analysis' -Key Static
    }
)
foreach ($suite in $suites) {
    $orchestratedStatus = Get-PscxOrchestrationValue -Summary $unified -Suite $suite.Key -Property Status
    if (-not [string]::IsNullOrWhiteSpace([string]$orchestratedStatus)) {
        $suite.Status = [string]$orchestratedStatus
    }
    $orchestratedDuration = Get-PscxOrchestrationValue `
        -Summary $unified -Suite $suite.Key -Property DurationSeconds
    if ($null -ne $orchestratedDuration) {
        $suite.DurationSeconds = [double]$orchestratedDuration
    }
    $orchestratedError = Get-PscxOrchestrationValue -Summary $unified -Suite $suite.Key -Property Error
    if (-not [string]::IsNullOrWhiteSpace([string]$orchestratedError) -and $suite.Failures.Count -eq 0) {
        $suite.Failures = @([pscustomobject]@{
                Name = "$($suite.Name) suite"
                Message = ConvertTo-PscxSafeText -Text $orchestratedError -SensitiveRoot $sensitiveRoots
                Stack = ''
            })
    }
    if (-not $suite.SourceAvailable -and $suite.Failures.Count -eq 0) {
        $suite.Failures = @([pscustomobject]@{
                Name = "$($suite.Name) result unavailable"
                Message = 'The suite did not produce its machine-readable result file.'
                Stack = ''
            })
    }
}

$powerShellCoverage = if (Test-Path -LiteralPath $paths.PowerShellCoverage -PathType Leaf) {
    Get-PscxCoveragePercent -Path $paths.PowerShellCoverage
}
else {
    $null
}
$managedCoverage = if (Test-Path -LiteralPath $paths.ManagedCoverage -PathType Leaf) {
    Get-PscxCoveragePercent -Path $paths.ManagedCoverage
}
else {
    $null
}
$overallStatus = [string]$unified.Status
$testSuites = @($suites | Where-Object Key -In Managed, Pester)
$total = ($testSuites | Measure-Object Total -Sum).Sum
$passed = ($testSuites | Measure-Object Passed -Sum).Sum
$failed = ($testSuites | Measure-Object Failed -Sum).Sum
$skipped = ($testSuites | Measure-Object Skipped -Sum).Sum
$overallDuration = ($suites | Measure-Object DurationSeconds -Sum).Sum

$suiteRows = foreach ($suite in $suites) {
    $detail = if ($suite.Key -eq 'Static') {
        "Warnings: $($suite.WarningCount); information: $($suite.InformationCount)"
    }
    else {
        ''
    }
    @"
          <tr>
            <th scope="row">$(ConvertTo-PscxHtml $suite.Name)</th>
            <td><span class="status $($suite.Status.ToLowerInvariant())">$(ConvertTo-PscxHtml $suite.Status)</span></td>
            <td>$(Format-PscxCount $suite.Total)</td>
            <td>$(Format-PscxCount $suite.Passed)</td>
            <td>$(Format-PscxCount $suite.Failed)</td>
            <td>$(Format-PscxCount $suite.Skipped)</td>
            <td>$(Format-PscxDuration $suite.DurationSeconds)</td>
            <td>$(ConvertTo-PscxHtml $detail)</td>
          </tr>
"@
}

$allFailures = @($suites | ForEach-Object { $_.Failures })
$failureMarkup = if ($allFailures.Count -eq 0) {
    '        <p class="empty">No test or suite failures were reported.</p>'
}
else {
    @($allFailures | ForEach-Object {
            $body = @($_.Message, $_.Stack | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n`n"
            @"
        <details>
          <summary>$(ConvertTo-PscxHtml $_.Name)</summary>
          <pre>$(ConvertTo-PscxHtml $body)</pre>
        </details>
"@
        }) -join "`n"
}

$html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'">
  <title>PSCX test dashboard</title>
  <style>
    :root { color-scheme: light dark; font-family: system-ui, sans-serif; }
    body { max-width: 78rem; margin: 0 auto; padding: 2rem; line-height: 1.45; }
    h1, h2 { line-height: 1.15; }
    .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(9rem, 1fr)); gap: 1rem; }
    .card { border: 1px solid #8887; border-radius: .6rem; padding: 1rem; }
    .card strong { display: block; font-size: 1.5rem; }
    table { width: 100%; border-collapse: collapse; margin-block: 1rem 2rem; }
    th, td { border-bottom: 1px solid #8887; padding: .65rem; text-align: right; vertical-align: top; }
    th:first-child, td:first-child, td:last-child { text-align: left; }
    .status { border-radius: 999px; display: inline-block; font-weight: 700; padding: .2rem .65rem; }
    .passed { background: #198754; color: white; }
    .failed { background: #b42318; color: white; }
    .unknown, .incomplete { background: #8a6100; color: white; }
    details { border: 1px solid #8887; border-radius: .4rem; margin-block: .75rem; padding: .75rem; }
    summary { cursor: pointer; font-weight: 650; }
    pre { overflow-wrap: anywhere; white-space: pre-wrap; }
    .muted, .empty { opacity: .75; }
  </style>
</head>
<body>
  <main>
    <h1>PSCX test dashboard</h1>
    <p>Build scope: <strong>$(ConvertTo-PscxHtml $unified.BuildScope)</strong>; PowerShell: <strong>$(ConvertTo-PscxHtml $unified.PowerShellVersion)</strong></p>
    <section aria-labelledby="overall-heading">
      <h2 id="overall-heading">Overall status: <span class="status $($overallStatus.ToLowerInvariant())">$(ConvertTo-PscxHtml $overallStatus)</span></h2>
      <div class="summary">
        <div class="card"><span>Total tests</span><strong>$total</strong></div>
        <div class="card"><span>Passed</span><strong>$passed</strong></div>
        <div class="card"><span>Failed</span><strong>$failed</strong></div>
        <div class="card"><span>Skipped</span><strong>$skipped</strong></div>
        <div class="card"><span>Suite duration</span><strong>$(Format-PscxDuration $overallDuration)</strong></div>
      </div>
    </section>
    <section aria-labelledby="suites-heading">
      <h2 id="suites-heading">Suites</h2>
      <table>
        <thead><tr><th scope="col">Suite</th><th scope="col">Status</th><th scope="col">Total</th><th scope="col">Passed</th><th scope="col">Failed</th><th scope="col">Skipped</th><th scope="col">Duration</th><th scope="col">Details</th></tr></thead>
        <tbody>
$($suiteRows -join "`n")
        </tbody>
      </table>
    </section>
    <section aria-labelledby="coverage-heading">
      <h2 id="coverage-heading">Line coverage</h2>
      <div class="summary">
        <div class="card"><span>PowerShell</span><strong>$(Format-PscxPercent $powerShellCoverage)</strong></div>
        <div class="card"><span>Managed code</span><strong>$(Format-PscxPercent $managedCoverage)</strong></div>
      </div>
    </section>
    <section aria-labelledby="failures-heading">
      <h2 id="failures-heading">Failure details</h2>
$failureMarkup
    </section>
    <p class="muted">Generated from the machine-readable files beside this dashboard. Those files remain authoritative.</p>
  </main>
</body>
</html>
"@

[IO.File]::WriteAllText($resolvedOutputPath, $html, [Text.UTF8Encoding]::new($false))
Get-Item -LiteralPath $resolvedOutputPath

# SIG # Begin signature block
# MIInmgYJKoZIhvcNAQcCoIInizCCJ4cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAA0DoFtrOhJ9fl
# 60V1+kLYS4nMDKibwqmfvCtnAXa8R6CCIHEwggWNMIIEdaADAgECAhAOmxiO+dAt
# 5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBa
# Fw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lD
# ZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3E
# MB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKy
# unWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsF
# xl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU1
# 5zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJB
# MtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObUR
# WBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6
# nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxB
# YKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5S
# UUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+x
# q4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIB
# NjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwP
# TzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMC
# AYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0Nc
# Vec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnov
# Lbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65Zy
# oUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFW
# juyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPF
# mCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9z
# twGpn1eqXijiuZQwggaUMIIEfKADAgECAgh1RsL97PvpATANBgkqhkiG9w0BAQsF
# ADCBljELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAk1OMRQwEgYDVQQHEwtNaW5uZWFw
# b2xpczESMBAGA1UEChMJTHVjYSBIb21lMQ8wDQYDVQQLEwZPZmZpY2UxGzAZBgNV
# BAMTEkx1Y2FzIENvZGUgUm9vdCBDQTEiMCAGCSqGSIb3DQEJARYTZGFubHVjYUBj
# b21jYXN0Lm5ldDAeFw0yMjAzMjYwMDAwMDBaFw00OTAzMjUyMzU5NTlaMIGVMQsw
# CQYDVQQGEwJVUzELMAkGA1UECBMCTU4xFDASBgNVBAcTC01pbm5lYXBvbGlzMRIw
# EAYDVQQKEwlMdWNhIEhvbWUxDzANBgNVBAsTBk9mZmljZTEaMBgGA1UEAxMRTHVj
# YXMgQ29kZSBSU0EgQ0ExIjAgBgkqhkiG9w0BCQEWE2Rhbmx1Y2FAY29tY2FzdC5u
# ZXQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDNxe4oUxTG+YdtMgDm
# PStZVzsgBoBPBD/2Y9Zsxaaj26ZknpP22kONwySOjVcqMolJwWAOyJtKyzxCCT2c
# bOdwS1ZoAZKpUjmB3HJeMmdhwlTth4irqmK5C/8lxB0Va+jelxEMXTceCd7I6YkW
# w4l23Yq1+Y1Qv+dIifsm7BOYidWzR9aSuGrSdizNk1giewDAYo8l5RhOEoRgWFHx
# vuM0lHcTmT+6U1IgBE+06I7FS/uQ8g/ajQJVm6QAXlCkNeFg3EbEtEyQbdUEKcDS
# a7O88OpnA5j3/UAfEXZfizr9d2GY86gMjE3QDiGr51I4uWcA2gmecZxXUpc2XWFu
# UBu3ikOAJTOTMq9Pi5tN7ZQwKzJQLESdJ8So73dJcI/hW6Bf2k2x17ldY/GO3KEf
# t8KtxSr9kLQ4fYiIhLdHDtje0Zm8QSQFabrE94ci8kB0tFM+7FuQ51E8YiU9fhk3
# eh1sHLwEXg1m7uea6YPFdlpSbx17EpfSnBeeWiH/LNkttTg2Mb7oogVDlecv31Ng
# TqbZzQ7MPRdjrW3L9HxU6YvKo7/cxzGRltmG1daA4pKc0KVUQ6RXL9WRKLQyEbdg
# uTfkXKS9jMtr0h52Zvw7fW3qCGyqI8BhANjPYiCsftckkx0KPefmsQNT/w+m4Qu/
# 97qycOhyLKfpndb9IJkEOcAu0wIDAQABo4HkMIHhMA8GA1UdEwEB/wQFMAMBAf8w
# HQYDVR0OBBYEFIBmtZ8QfiC4XB0vz9YiGsofRq8hMA4GA1UdDwEB/wQEAwIBxjAz
# BgNVHSUELDAqBggrBgEFBQcDAwYIKwYBBQUHAwgGCisGAQQBgjcCARUGCCsGAQUF
# BwMJMDEGA1UdEQQqMCiBEXNsdWNhQGNvbWNhc3QubmV0gRNkYW5sdWNhQGNvbWNh
# c3QubmV0MBEGCWCGSAGG+EIBAQQEAwIAATAkBglghkgBhvhCAQ0EFxYVTHVjYXMg
# Q29kZSBTaWduaW5nIENBMA0GCSqGSIb3DQEBCwUAA4ICAQByKgofmdGXu4v40lYW
# DUL7otFJstfYcp0S7SQpSMIGwNj89kdWENU9ciYYq70qy781kLLIDwyGSwwAju3w
# MqtbiAWhjKGuEXKQROHTs/HtPBEZ9NL99IVdhc+/DT9UzP/fpPk6N/TOaTGQQsmw
# vWovGtnprAxWcGwyDS/jtRrWv1MaiYjtoOFOIAwcsOdkd3sNl5P+VJLTRlQAnrgi
# 55vkFyibH5cgbXvcYg3SLOw9HEi5hUpQ76DdzqCa/CX4sqPstWNlKjQ8ehfi6AGa
# guFC25HcOhhoNZjjlgOP7a5i8KG/Gh2JuYmu8SkWivHJwMswLy3M6Vpd9euNXNSr
# 46EQ4iafNlij5rRxRQuPsjT/q4A4g3HCJZUBCN0HlXmJwiG/yRNJSvjsKGabW2qQ
# NilU2blO9JVRZKPnLGaKai6aRRHQ225kopalRPK4oTtkBjnJzbnXfECHNh0C3qIl
# 0MmgJ7Yf1HrGfj425zC56bH8jCJv3H3G3B4DdDDpRAQbW3/vsypPSce7YoB0JCYt
# UU95KI09G5Dl9GuGtupIaMfs05ECAQTGXvF6Olq6sRTyf7JROTmKBpiJO62a8xEg
# kTmJ9ZLrzBHNqVNzoljx+Zaa+5I3K5a1y6nccG26Th2+m/42kGm1XqfEyUbZybXB
# E5FC/7m39/hu0d703lrl32FtozCCBpswggSDoAMCAQICCAbX5YewM+U2MA0GCSqG
# SIb3DQEBCwUAMIGVMQswCQYDVQQGEwJVUzELMAkGA1UECBMCTU4xFDASBgNVBAcT
# C01pbm5lYXBvbGlzMRIwEAYDVQQKEwlMdWNhIEhvbWUxDzANBgNVBAsTBk9mZmlj
# ZTEaMBgGA1UEAxMRTHVjYXMgQ29kZSBSU0EgQ0ExIjAgBgkqhkiG9w0BCQEWE2Rh
# bmx1Y2FAY29tY2FzdC5uZXQwHhcNMjIwMzI2MDAwMDAwWhcNNDcwMzI1MjM1OTU5
# WjCBjDELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAk1OMRQwEgYDVQQHEwtNaW5uZWFw
# b2xpczESMBAGA1UEChMJTHVjYSBIb21lMQ8wDQYDVQQLEwZPZmZpY2UxETAPBgNV
# BAMTCERhbiBMdWNhMSIwIAYJKoZIhvcNAQkBFhNkYW5sdWNhQGNvbWNhc3QubmV0
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAt5i4r1HEGsNrSWsxNzkV
# A/opuBv3Xisr1Km43wuCW9BKaM73FlgPbPrOo1ynxsWAmvrOv2RKctcxqaEdhvY1
# aioK9HYu/OhCOwIbINnJFUDp3ecdJOFloUC7bE1eccGHRv40fUjLTNT7wcFaYjv7
# G+7jUhvL88BGSneBjyS2RXCn1EpFU0MmJ055tNyAL3zCBfGdtGqilMttfE63Nxf4
# uQfvT5Nloub5V2z07lx/uwA1ZE7pKXiHkZh4auLsb74d+nRKZhwUfKB9c42qfJMU
# iA9wlBbxMZ2Yxb9r+COJsB/TOGGyC1kdDgJ1M1XbxERgsf0FnUJOFCy/n5aozgW6
# hwM/UXxzAQKwLaRkjrk06G7MyYegL6XvHN0EFTFVg1VDFlFOvQ4OCNEtuEcMEfsN
# LFPxiVrfJf3NxcuX3VNMoJwXT716H4cVmvl3z8zWdWikRfUpkDuk17/lN+61KLss
# DMGaj3uGC8xxOWiUCR5Lg9P5dUIIjgGqNhFKiHJE7LvXZ7H63/yh1967P/C1h7mf
# u+3/vZ98H4nXfLCJ4jmAigUYG6jVZffeeogbcfgGR8v9c15binUdD3lWMQ3/PpdI
# GLsENA8MHqXVC/SAnvKm5pqVpFWOXqyBX3u2BJ9utF27Nsb2RoJqCFt7bB2engxM
# adPGGdJc2GbnuSMtdSV5chECAwEAAaOB9TCB8jAMBgNVHRMBAf8EAjAAMB0GA1Ud
# DgQWBBQZJ4PIxOjVfCmSYMBKp3+E/s/h4zAOBgNVHQ8BAf8EBAMCBsAwNQYDVR0l
# BC4wLAYIKwYBBQUHAwMGCCsGAQUFBwMIBgorBgEEAYI3AgEVBgorBgEEAYI3AgEW
# MDMGA1UdEQQsMCqBE2Rhbmx1Y2FAY29tY2FzdC5uZXSBE2Rhbmx1Y2EyMkBnbWFp
# bC5jb20wEQYJYIZIAYb4QgEBBAQDAgQQMDQGCWCGSAGG+EIBDQQnFiVEYW4gTHVj
# YSBjZXJ0aWZpY2F0ZSBmb3IgY29kZSBzaWduaW5nMA0GCSqGSIb3DQEBCwUAA4IC
# AQBIoCyjFppNigfzbRKb48zLEm3Imhuui2cJzAjYdex2WxWgcMbnklGvFuMwP6+K
# HtCMg2Q/vkEh3vM2iyh/fmKlYMGcJtTjzeE3bkStHl6AuYwBEC7xofNAg1SQBWGK
# iOeANeGJj88J8vLpMtKFMTAwf824EJzItZPpxLybdpv14XIeo9Gku6yd/hWticee
# xHbH5cXmBNkMlUPhaP8XpgnF4mF1QKRFNi3OmM36o/r2uVg2M5GXMRb9/FRTjeOz
# ApCmLhee0xF+42iAeYCYpkveMZra0CIcYnViyWeJi+xyx1OP7ZL8cVuIwDXvv3tk
# luAVwobgmwFz6tAMLzblQfUlE9WTdQrA0pzEg1jniWt2O95I+7JDieTP1CM1KxRw
# s2u8vJoxzls47ZmdiIoHcRO9exVUrfUF8rKIORaanY4fUwIiUQiie8GrUMTKrQCk
# Ly8/qN/YJyKxQmlKJxCqyfjoH7FvmaDqtdHaOhweiqF18HhymnHMblrIgctoEPqh
# 3/GURELo9yAhgZRTorw3jS8+uY2b2JRC7+EIbf4GS6rOYvgbdUBpGHRiaA0AeY7F
# 7J0DZncUy1yL1jj1/UzngrC7FIZXVF0WT3b59T5wm7fBo2642lRgD2eVXyj5Ygn4
# EebBYhHzbPbXhSUfdKFro6bVrzSp+a3MY+E0GlDUeLf6rjCCBrQwggScoAMCAQIC
# EA3HrFcF/yGZLkBDIgw6SYYwDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMx
# FTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNv
# bTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTI1MDUwNzAw
# MDAwMFoXDTM4MDExNDIzNTk1OVowaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRp
# Z2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVT
# dGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBALR4MdMKmEFyvjxGwBysddujRmh0tFEXnU2tjQ2UtZmW
# gyxU7UNqEY81FzJsQqr5G7A6c+Gh/qm8Xi4aPCOo2N8S9SLrC6Kbltqn7SWCWgzb
# NfiR+2fkHUiljNOqnIVD/gG3SYDEAd4dg2dDGpeZGKe+42DFUF0mR/vtLa4+gKPs
# YfwEu7EEbkC9+0F2w4QJLVSTEG8yAR2CQWIM1iI5PHg62IVwxKSpO0XaF9DPfNBK
# S7Zazch8NF5vp7eaZ2CVNxpqumzTCNSOxm+SAWSuIr21Qomb+zzQWKhxKTVVgtmU
# PAW35xUUFREmDrMxSNlr/NsJyUXzdtFUUt4aS4CEeIY8y9IaaGBpPNXKFifinT7z
# L2gdFpBP9qh8SdLnEut/GcalNeJQ55IuwnKCgs+nrpuQNfVmUB5KlCX3ZA4x5HHK
# S+rqBvKWxdCyQEEGcbLe1b8Aw4wJkhU1JrPsFfxW1gaou30yZ46t4Y9F20HHfIY4
# /6vHespYMQmUiote8ladjS/nJ0+k6MvqzfpzPDOy5y6gqztiT96Fv/9bH7mQyogx
# G9QEPHrPV6/7umw052AkyiLA6tQbZl1KhBtTasySkuJDpsZGKdlsjg4u70EwgWbV
# RSX1Wd4+zoFpp4Ra+MlKM2baoD6x0VR4RjSpWM8o5a6D8bpfm4CLKczsG7ZrIGNT
# AgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBTvb1NK
# 6eQGfHrK4pBW9i/USezLTjAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qYrhwP
# TzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYBBQUH
# AQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYI
# KwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRy
# dXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZMBcw
# CAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAF877FoAc
# /gc9EXZxML2+C8i1NKZ/zdCHxYgaMH9Pw5tcBnPw6O6FTGNpoV2V4wzSUGvI9NAz
# aoQk97frPBtIj+ZLzdp+yXdhOP4hCFATuNT+ReOPK0mCefSG+tXqGpYZ3essBS3q
# 8nL2UwM+NMvEuBd/2vmdYxDCvwzJv2sRUoKEfJ+nN57mQfQXwcAEGCvRR2qKtntu
# jB71WPYAgwPyWLKu6RnaID/B0ba2H3LUiwDRAXx1Neq9ydOal95CHfmTnM4I+ZI2
# rVQfjXQA1WSjjf4J2a7jLzWGNqNX+DF0SQzHU0pTi4dBwp9nEC8EAqoxW6q17r0z
# 0noDjs6+BFo+z7bKSBwZXTRNivYuve3L2oiKNqetRHdqfMTCW/NmKLJ9M+MtucVG
# yOxiDf06VXxyKkOirv6o02OoXN4bFzK0vlNMsvhlqgF2puE6FndlENSmE+9JGYxO
# GLS/D284NHNboDGcmWXfwXRy4kbu4QFhOm0xJuF2EZAOk5eCkhSxZON3rGlHqhpB
# /8MluDezooIs8CVnrpHMiD2wL40mm53+/j7tFaxYKIqL0Q4ssd8xHZnIn/7GELH3
# IdvG2XlM9q7WP/UwgOkw/HQtyRN62JK4S1C8uw3PdBunvAZapsiI5YKdvlarEvf8
# EA+8hcpSM9LHJmyrxaFtoza2zNaQ9k+5t1wwggbtMIIE1aADAgECAhAKgO8YS43x
# BYLRxHanlXRoMA0GCSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQK
# Ew5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBU
# aW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwHhcNMjUwNjA0MDAw
# MDAwWhcNMzYwOTAzMjM1OTU5WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGln
# aUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFNIQTI1NiBSU0E0MDk2IFRp
# bWVzdGFtcCBSZXNwb25kZXIgMjAyNSAxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEA0EasLRLGntDqrmBWsytXum9R/4ZwCgHfyjfMGUIwYzKomd8U1nH7
# C8Dr0cVMF3BsfAFI54um8+dnxk36+jx0Tb+k+87H9WPxNyFPJIDZHhAqlUPt281m
# HrBbZHqRK71Em3/hCGC5KyyneqiZ7syvFXJ9A72wzHpkBaMUNg7MOLxI6E9RaUue
# HTQKWXymOtRwJXcrcTTPPT2V1D/+cFllESviH8YjoPFvZSjKs3SKO1QNUdFd2adw
# 44wDcKgH+JRJE5Qg0NP3yiSyi5MxgU6cehGHr7zou1znOM8odbkqoK+lJ25LCHBS
# ai25CFyD23DZgPfDrJJJK77epTwMP6eKA0kWa3osAe8fcpK40uhktzUd/Yk0xUvh
# DU6lvJukx7jphx40DQt82yepyekl4i0r8OEps/FNO4ahfvAk12hE5FVs9HVVWcO5
# J4dVmVzix4A77p3awLbr89A90/nWGjXMGn7FQhmSlIUDy9Z2hSgctaepZTd0ILIU
# bWuhKuAeNIeWrzHKYueMJtItnj2Q+aTyLLKLM0MheP/9w6CtjuuVHJOVoIJ/DtpJ
# RE7Ce7vMRHoRon4CWIvuiNN1Lk9Y+xZ66lazs2kKFSTnnkrT3pXWETTJkhd76CID
# BbTRofOsNyEhzZtCGmnQigpFHti58CSmvEyJcAlDVcKacJ+A9/z7eacCAwEAAaOC
# AZUwggGRMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFOQ7/PIx7f391/ORcWMZUEPP
# YYzoMB8GA1UdIwQYMBaAFO9vU0rp5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB/wQE
# AwIHgDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgwgYUw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEFBQcw
# AoZRaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0
# VGltZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRYMFYw
# VKBSoFCGTmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRH
# NFRpbWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAEGTAX
# MAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBAGUqrfEc
# JwS5rmBB7NEIRJ5jQHIh+OT2Ik/bNYulCrVvhREafBYF0RkP2AGr181o2YWPoSHz
# 9iZEN/FPsLSTwVQWo2H62yGBvg7ouCODwrx6ULj6hYKqdT8wv2UV+Kbz/3ImZlJ7
# YXwBD9R0oU62PtgxOao872bOySCILdBghQ/ZLcdC8cbUUO75ZSpbh1oipOhcUT8l
# D8QAGB9lctZTTOJM3pHfKBAEcxQFoHlt2s9sXoxFizTeHihsQyfFg5fxUFEp7W42
# fNBVN4ueLaceRf9Cq9ec1v5iQMWTFQa0xNqItH3CPFTG7aEQJmmrJTV3Qhtfparz
# +BW60OiMEgV5GWoBy4RVPRwqxv7Mk0Sy4QHs7v9y69NBqycz0BZwhB9WOfOu/CIJ
# nzkQTwtSSpGGhLdjnQ4eBpjtP+XB3pQCtv4E5UCSDag6+iX8MmB10nfldPF9SVD7
# weCC3yXZi/uuhqdwkgVxuiMFzGVFwYbQsiGnoa9F5AaAyBjFBtXVLcKtapnMG3VH
# 3EmAp/jsJ3FVF3+d1SVDTmjFjLbNFZUWMXuZyvgLfgyPehwJVxwC+UpX2MSey2ue
# Iu9THFVkT+um1vshETaWyQo8gmBto/m3acaP9QsuLj3FNwFlTxq25+T4QwX9xa6I
# Ls84ZPvmpovq90K8eWyG2N01c4IhSOxqt81nMYIGfzCCBnsCAQEwgaIwgZUxCzAJ
# BgNVBAYTAlVTMQswCQYDVQQIEwJNTjEUMBIGA1UEBxMLTWlubmVhcG9saXMxEjAQ
# BgNVBAoTCUx1Y2EgSG9tZTEPMA0GA1UECxMGT2ZmaWNlMRowGAYDVQQDExFMdWNh
# cyBDb2RlIFJTQSBDQTEiMCAGCSqGSIb3DQEJARYTZGFubHVjYUBjb21jYXN0Lm5l
# dAIIBtflh7Az5TYwDQYJYIZIAWUDBAIBBQCggYQwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFjAvBgkqhkiG9w0BCQQxIgQgQx5dKNJIVRmXpgzCreRF
# L8ISEtfoXn6vetKKx4h9/mcwDQYJKoZIhvcNAQEBBQAEggIAPG15iIbC9KGCRY4L
# BAbPBZt5t0TZW1a0K5HcPRaEeyhhpDdM/0WItuTO3jLw3CQDccwXYum+sg64JU4h
# UKWH03Lvn8pe7kGXRviSNY0ywoeIl69d/2qO5EdejainDh0yniuxOWikY+hM0pY0
# YK3cuAS47N1wFRdBvJu4cTexYHcXb8Y6lXGlMsHpoVcJZHKp32gFwKISLm5caEXn
# 4XlSxvfb4Pu2GQUc+ewwCTqvt45jX/b09s3Cs8C26PrPbOj9KtuvbQPdNPEL1D7G
# nTjGIPlvy5dNykgNhrkCI/cg5wMeTfwjgaDRMSgCUOEevc0cAwouW92RiYn5vQP7
# oXy9FH+IWXat/CwOoY4LjnJKmL3dIJKsnbw6kiqbE32jeUE5NKmoCgLb8Zzf6DIR
# HuXRGqmgq0UHy3J3HbdBfIpoNtbwpdbThz+O8l8tODISA+dF7lHalYsfSnQ9qbxC
# MaNEilZJYEAEPKftT4Z2tJmU6qB6aYu6/WLZE4VGC1y7KGbxry8omUMOqIJ5jITm
# FqqNezwqJtn2sEjXOEd3W7fW3ArxeZjuy4gE/ZyVjQ93rha83BgIem5DedH0xCER
# xgybSXN1uTPFziuiNc4t+Z6Fj3PN55VWwZVi1zhZ7LvvXu3KOTnpp3LFu8AQZpbI
# srwgAQlm5d1iPEjt66M6xVePO5KhggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8C
# AQEwfTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/
# BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYg
# U0hBMjU2IDIwMjUgQ0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUA
# oGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYw
# ODI4MTkyNjIxWjAvBgkqhkiG9w0BCQQxIgQg4pN3kpyFhZG89h3k4lBOQy5XUm1c
# lj4YSNr9Alh14LswDQYJKoZIhvcNAQEBBQAEggIAomP5xDfPSERu3ICvhJVvOBvS
# S2KDEku6geWdCmscya3LDKlNIQ2fGzjUO1o/4it6m4vC4P6L7cZkxR6ZM+uIVYkS
# clEms7fbwBeYCWi7nVuFMRq19Vxs3vdXiVrRtLSK0i8SUO5oGixZQCB4vyYzrV8L
# f/CH1ZjBSWRNrBC0q17u53CTqOmukFM9n1Y3QzuKGMhgi7E5yyXKX0NeRH7JOd5T
# 9jlb6NAwGRglJA5AhRkC7mvf4Mk/Xdz5u3u1xpMGrCBjdN8zaJmZMknoXtTy5Mtb
# wmuiYsIGWsgkxlRKyxWamjwRchyVNhHkFnZF2PeM2WaV2muY3Uk9h0NhXdtNbjwx
# Nslt5K2MHBYMxdqPmO/o5GThS37JrV/3sxjBlllDP6FKvn3grNj9JP4h6nEnhciQ
# zioyYI825pRmS5Ut5CsAJ4Yxpd6Bg2glejM4m6oOf/p1HkP1aAcXaMzJEpvCIvMc
# /gbiBeLBgI9ur0jr2lhVDxzY+9Dj8lkTwVgqUoaJthCQJCRcw7myJm1zSycdlIFf
# LAlyOj2zhnyscjPAX4e9x5Eiwlg0Lz/g/i17bOPrz5QgBsKJA38Yz2XJjv7H6pYL
# X3IZdX+91ticKMQvgnEhM6oslTZ8GM08pDIvWUZDR1Pn4r+WdwFnKZQ0Bzg7RIN1
# v0n1mQVQjn7KACrtpeE=
# SIG # End signature block
