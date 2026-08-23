[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ModulePath,

    [Parameter(Mandatory)]
    [string] $ResultsPath,

    [string] $PowerShellPath = 'pwsh'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$policy = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'Tests/TestPolicy.psd1')
$baseline = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'Tests/StaticAnalysisBaseline.psd1')
$analyzerVersion = [string]$policy.PSScriptAnalyzerVersion
$toolModuleRoot = Join-Path $repositoryRoot '.tools/modules'
$analyzerManifest = Join-Path $toolModuleRoot "PSScriptAnalyzer/$analyzerVersion/PSScriptAnalyzer.psd1"

if (-not (Test-Path -LiteralPath $analyzerManifest)) {
    New-Item -ItemType Directory -Path $toolModuleRoot -Force | Out-Null
    Write-Output "Saving PSScriptAnalyzer $analyzerVersion to $toolModuleRoot"
    Save-PSResource -Name PSScriptAnalyzer -Version $analyzerVersion -Repository PSGallery `
        -Path $toolModuleRoot -TrustRepository
}
if (-not (Test-Path -LiteralPath $analyzerManifest)) {
    throw "PSScriptAnalyzer $analyzerVersion was not saved at the expected path: $analyzerManifest"
}

Import-Module $analyzerManifest -Force -ErrorAction Stop
if ((Get-Module PSScriptAnalyzer).Version -ne [version]$analyzerVersion) {
    throw "Expected PSScriptAnalyzer $analyzerVersion but loaded $((Get-Module PSScriptAnalyzer).Version)."
}

$excludedDirectoryPattern = '[\\/](?:\.git|\.tools|artifacts|Output|bin|obj)[\\/]'
$allFiles = @(
    Get-ChildItem -LiteralPath $repositoryRoot -Recurse -File |
        Where-Object FullName -NotMatch $excludedDirectoryPattern
)
$powerShellFiles = @(
    $allFiles |
        Where-Object Extension -In '.ps1', '.psm1', '.psd1' |
        Sort-Object FullName
)

# Enforce the platform ownership established by the Phase 5.4 source audit.
$windowsAssemblyInfoFiles = @(
    'Src/Pscx.Win/Properties/AssemblyInfo.cs'
    'Src/Pscx.WinAdmin/AssemblyInfo.cs'
)
foreach ($relativePath in $windowsAssemblyInfoFiles) {
    $content = Get-Content -LiteralPath (Join-Path $repositoryRoot $relativePath) -Raw
    if ($content -notmatch 'SupportedOSPlatform\("windows"\)') {
        throw "$relativePath must declare its assembly as Windows-only."
    }
}

$crossPlatformSourceRoots = @(
    'Src/Pscx.Core'
    'Src/Pscx'
    'Src/Pscx.Archive'
)
$crossPlatformCSharpFiles = @(
    foreach ($relativeRoot in $crossPlatformSourceRoots) {
        Get-ChildItem -LiteralPath (Join-Path $repositoryRoot $relativeRoot) -Recurse -Filter *.cs -File |
            Where-Object FullName -NotMatch $excludedDirectoryPattern
    }
)
$nativeInteropFiles = @(
    $crossPlatformCSharpFiles |
        Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match '\b(?:DllImport|LibraryImport)\s*\(' } |
        ForEach-Object { [IO.Path]::GetRelativePath($repositoryRoot, $_.FullName).Replace('\', '/') }
)
$approvedNativeInteropFiles = @(
    'Src/Pscx.Core/EncodingConversion.cs'
    'Src/Pscx/Commands/UIAutomation/SetForegroundWindowCommand.cs'
)
if ($difference = Compare-Object $approvedNativeInteropFiles $nativeInteropFiles) {
    $difference | Format-Table -AutoSize | Out-String | Write-Output
    throw 'Cross-platform native-interop ownership differs from the reviewed Phase 5.4 exceptions.'
}

$encodingConversion = Get-Content -LiteralPath (
    Join-Path $repositoryRoot 'Src/Pscx.Core/EncodingConversion.cs'
) -Raw
if ($encodingConversion -notmatch 'OperatingSystem\.IsWindows\(\)' -or
    $encodingConversion -notmatch "The 'oem' encoding is supported only on Windows") {
    throw 'The native OEM encoding path must remain guarded from non-Windows execution.'
}
$foregroundWindow = Get-Content -LiteralPath (
    Join-Path $repositoryRoot 'Src/Pscx/Commands/UIAutomation/SetForegroundWindowCommand.cs'
) -Raw
if ($foregroundWindow -notmatch 'SupportedOSPlatform\("windows"\)') {
    throw 'Set-ForegroundWindow must retain its explicit Windows platform annotation.'
}

$crossPlatformPowerShellFiles = @(
    foreach ($relativeRoot in $crossPlatformSourceRoots) {
        Get-ChildItem -LiteralPath (Join-Path $repositoryRoot $relativeRoot) -Recurse -File |
            Where-Object Extension -In '.ps1', '.psm1' |
            Where-Object FullName -NotMatch $excludedDirectoryPattern
    }
)
$windowsAutomationReferences = @(
    $crossPlatformPowerShellFiles |
        Where-Object {
            (Get-Content -LiteralPath $_.FullName -Raw) -match
                '\b(?:Get-WmiObject|Get-CimInstance|Invoke-CimMethod|New-CimSession|Win32_)\b'
        } |
        ForEach-Object { [IO.Path]::GetRelativePath($repositoryRoot, $_.FullName).Replace('\', '/') }
)
if ($windowsAutomationReferences.Count -gt 0) {
    throw "Cross-platform PowerShell sources contain Windows automation references: $($windowsAutomationReferences -join ', ')"
}

$resultsPath = [IO.Path]::GetFullPath($ResultsPath)
New-Item -ItemType Directory -Path $resultsPath -Force | Out-Null
$infrastructureResultPath = Join-Path $resultsPath 'Pscx.StaticAnalysis.infrastructure.json'
Remove-Item -LiteralPath $infrastructureResultPath -Force -ErrorAction SilentlyContinue
try {
    $powerShellExecutable = Get-Command -Name $PowerShellPath -CommandType Application -ErrorAction Stop |
        Select-Object -First 1 -ExpandProperty Source
}
catch {
    throw "Could not resolve the PowerShell executable '$PowerShellPath'."
}
$analyzerFileScript = Join-Path $PSScriptRoot 'Invoke-PscxAnalyzerFile.ps1'
$analyzerRunnerPath = Join-Path $PSScriptRoot 'PscxAnalyzerRunner.psm1'
Import-Module $analyzerRunnerPath -Force -ErrorAction Stop
$ruleNames = @(
    Get-ScriptAnalyzerRule |
        Where-Object RuleName -NE 'PSUseToExportFieldsInManifest' |
        Select-Object -ExpandProperty RuleName
)
$ruleMidpoint = [math]::Ceiling($ruleNames.Count / 2)
$ruleBatches = @(
    $ruleNames[0..($ruleMidpoint - 1)] -join ','
    $ruleNames[$ruleMidpoint..($ruleNames.Count - 1)] -join ','
)
$analyzerWorkItemCount = $powerShellFiles.Count * $ruleBatches.Count
$diagnosticList = [Collections.Generic.List[object]]::new()
$infrastructureFailures = [Collections.Generic.List[object]]::new()
$analyzerAttemptCount = 0
foreach ($file in $powerShellFiles) {
    foreach ($ruleBatch in $ruleBatches) {
        $workItem = Invoke-PscxAnalyzerWorkItem `
            -PowerShellExecutable $powerShellExecutable `
            -AnalyzerScript $analyzerFileScript `
            -AnalyzerManifest $analyzerManifest `
            -Path $file.FullName `
            -IncludeRule $ruleBatch
        $analyzerAttemptCount += $workItem.AttemptCount
        foreach ($failure in $workItem.InfrastructureFailures) {
            $infrastructureFailures.Add($failure)
        }

        if (-not $workItem.Succeeded) {
            [ordered]@{
                Status = 'Failed'
                Orchestration = [ordered]@{
                    Mode = 'SequentialChildProcess'
                    WorkItemCount = $analyzerWorkItemCount
                    AttemptCount = $analyzerAttemptCount
                    MaximumAttemptsPerWorkItem = 2
                    RuleBatchCount = $ruleBatches.Count
                }
                InfrastructureFailures = @($infrastructureFailures)
            } | ConvertTo-Json -Depth 8 |
                Set-Content -LiteralPath $infrastructureResultPath -Encoding utf8
            throw (Format-PscxAnalyzerInfrastructureFailure -Failure $workItem.InfrastructureFailures)
        }

        if ($workItem.InfrastructureFailures.Count -gt 0) {
            Write-Warning (Format-PscxAnalyzerInfrastructureFailure `
                    -Failure $workItem.InfrastructureFailures `
                    -Heading 'Transient PSScriptAnalyzer infrastructure failure recovered on retry')
        }
        foreach ($diagnostic in $workItem.Diagnostics) {
            if ($null -ne $diagnostic) {
                $diagnosticList.Add($diagnostic)
            }
        }
    }
}
$diagnostics = @($diagnosticList)
$errors = @($diagnostics | Where-Object Severity -EQ Error)
if ($errors.Count -gt 0) {
    $errors | Format-Table RuleName, ScriptPath, Line, Message -AutoSize | Out-String | Write-Output
    throw "PSScriptAnalyzer reported $($errors.Count) error(s)."
}

$analyzerCounts = @{}
foreach ($severity in 'Warning', 'Information') {
    $count = @($diagnostics | Where-Object Severity -EQ $severity).Count
    $analyzerCounts[$severity] = $count
    $maximum = [int]$baseline.PSScriptAnalyzer[$severity]
    if ($count -gt $maximum) {
        throw "PSScriptAnalyzer $severity count increased from $maximum to $count."
    }
}

$manifestFiles = @(
    Get-ChildItem -LiteralPath $ModulePath -Recurse -Filter *.psd1 -File |
        Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match '(?m)^\s*ModuleVersion\s*=' }
)
foreach ($manifestFile in $manifestFiles) {
    Test-ModuleManifest -Path $manifestFile.FullName -ErrorAction Stop | Out-Null
}

$xmlFiles = @($allFiles | Where-Object Extension -In '.xml', '.ps1xml')
foreach ($xmlFile in $xmlFiles) {
    [xml](Get-Content -LiteralPath $xmlFile.FullName -Raw) | Out-Null
}
foreach ($typeFile in Get-ChildItem -LiteralPath $ModulePath -Recurse -Filter *.Types.ps1xml -File) {
    Update-TypeData -PrependPath $typeFile.FullName -ErrorAction Stop
}
foreach ($formatFile in Get-ChildItem -LiteralPath $ModulePath -Recurse -Filter *.Format.ps1xml -File) {
    Update-FormatData -PrependPath $formatFile.FullName -ErrorAction Stop
}

# Only the Full Windows package can enumerate the complete cross-platform and
# Windows public surface. One matrix leg is sufficient to enforce the shared
# committed README; Core legs still run all other static checks.
if (Test-Path -LiteralPath (Join-Path $ModulePath 'PscxWin.psd1')) {
    & $powerShellExecutable -NoLogo -NoProfile -NonInteractive -File `
        (Join-Path $repositoryRoot 'Tools/Update-PscxReadmeCatalog.ps1') `
        -ModulePath $ModulePath -ReadmePath (Join-Path $repositoryRoot 'README.md') -Check
    if ($LASTEXITCODE -ne 0) {
        throw "README public API catalog validation failed with exit code $LASTEXITCODE."
    }
}

$formatExtensions = @('.cs', '.ps1', '.psm1', '.psd1', '.md', '.xml', '.ps1xml', '.yml', '.yaml')
$formatCounts = @{}
foreach ($extension in $formatExtensions) {
    $counts = @{ TrailingWhitespace = 0; MissingFinalNewline = 0; LeadingTab = 0 }
    foreach ($file in $allFiles | Where-Object Extension -EQ $extension) {
        $content = [IO.File]::ReadAllText($file.FullName)
        $counts.TrailingWhitespace += [regex]::Matches($content, '(?m)[ \t]+$').Count
        $counts.LeadingTab += [regex]::Matches($content, '(?m)^\t+').Count
        if ($content.Length -gt 0 -and -not $content.EndsWith("`n")) {
            $counts.MissingFinalNewline++
        }
    }
    $formatCounts[$extension] = $counts
    foreach ($rule in $counts.Keys) {
        $maximum = [int]$baseline.Formatting[$extension][$rule]
        if ($counts[$rule] -gt $maximum) {
            throw "Formatting violation $rule for $extension increased from $maximum to $($counts[$rule])."
        }
    }
}

[ordered]@{
    Status = 'Passed'
    PSScriptAnalyzerVersion = $analyzerVersion
    PowerShellFileCount = $powerShellFiles.Count
    AnalyzerCounts = $analyzerCounts
    AnalyzerOrchestration = [ordered]@{
        Mode = 'SequentialChildProcess'
        WorkItemCount = $analyzerWorkItemCount
        AttemptCount = $analyzerAttemptCount
        MaximumAttemptsPerWorkItem = 2
        RuleBatchCount = $ruleBatches.Count
        InfrastructureFailures = @($infrastructureFailures)
    }
    ModuleManifestCount = $manifestFiles.Count
    XmlFileCount = $xmlFiles.Count
    PlatformAudit = [ordered]@{
        CrossPlatformCSharpFileCount = $crossPlatformCSharpFiles.Count
        CrossPlatformPowerShellFileCount = $crossPlatformPowerShellFiles.Count
        ApprovedNativeInteropFiles = $approvedNativeInteropFiles
        WindowsAssemblyCount = $windowsAssemblyInfoFiles.Count
    }
    FormattingCounts = $formatCounts
} | ConvertTo-Json -Depth 8 |
    Set-Content -LiteralPath (Join-Path $resultsPath 'Pscx.StaticAnalysis.summary.json') -Encoding utf8

# SIG # Begin signature block
# MIInmgYJKoZIhvcNAQcCoIInizCCJ4cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAJpmObuXolrqFb
# zMJZctAvrjevTUE3wB9L4hI0C8tvUqCCIHEwggWNMIIEdaADAgECAhAOmxiO+dAt
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
# MQ4wDAYKKwYBBAGCNwIBFjAvBgkqhkiG9w0BCQQxIgQgLWMsTJ11GUr7PICT1G0X
# bKlABOL8U1r+6TZqhftd3VAwDQYJKoZIhvcNAQEBBQAEggIAqiATxEXtnmbmJaup
# 0Sv6tddEfr4qEhew07kxwQ0KzHaZusTHrZbEqxGnryhCSeXaqzaWzM8OU1Vq69LR
# raCo1IVWDFk7FFtVsZcLP/EBy5QSBjZ6NQpqQ1uCMj2MJpC46HEoea15WuISRGYK
# 1MqAS2ooCzya1oEUZx2TLQlDE9VOtLtPdqYWw/tLfE8TlVigZqttwe+iGVU8WzKU
# 8DE6JJgRNC5v63cI0Ndgk3a0i5EL1FybuNi/J0b4bgt4Ncd/OcO+LU0Dsg3yX6QO
# e9Jx5Y5l/3A+bXPg8h4DvgddzqmbIS/PV935C1NGeFTmyYy17jeQx/wrPE0MQ5ok
# ipiTnsoBne5kEp9oRUjjjk2c0FhbFQvzk0P+hdsLjb5nnKe7YUn+U5E1J8bGL8Uq
# gfJSdKTAuAo9+PI+SkUHvW/tP+J+GM2lCAnTpjl9gnuYZFX3azib8EunpYEpSSwq
# vjQCcfPvH44PE/myOOwcz1ViRrzK8FnDLGQMJiX09K2P38MkZsTTacz8RlULqk37
# KPDF1LRJ7UtCOLCr5nFoBHgzx4YpGJNaEWy8p32b3/i03sB8bqHNy2TrC+d0u4Se
# uthFOXJfWrG/NwHVoXsZ5QmMFg7MetnKRxtMjJBUQUeGqmXlDiUkmYjgMT2TplQt
# XCkjYGUiVOFxxqowu0aYQD/2d4qhggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8C
# AQEwfTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/
# BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYg
# U0hBMjU2IDIwMjUgQ0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUA
# oGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYw
# ODA4MDUwNTM4WjAvBgkqhkiG9w0BCQQxIgQgm0uWGVH3uTBN3pht8SVB5IlrtRON
# khZvLqfVL8RYFmkwDQYJKoZIhvcNAQEBBQAEggIAUZ7hAGoF4ViS2KrOC16JXQnb
# U2vWKQuDvcY7cL2GXe8VFWcRGDAC15owCn9nLW0/kh4p8SlJxX+ko1+HMWCscXWn
# oNYMqayeuoW35/cytsoXQt/8kj98vU/W2gJv26w6Ox5InRoSXZuy6SJeHVZNqDpy
# T9BfLFR/kgNTglcNVgJXNAiyw/h1uJB0K5WZJS1WmZWfae3c0U5OLEzCnMxIhUM4
# /J1sE4P2M14mADnbrpP1nG3T72Z68Q2f3UuNEy5QrJ9jXyFVPscRwD6tGJIns/01
# DVdEiVFRyfScKEh7cH+L7PksHcol9F4PieRxKtbocgwnnHyiJ/VbrtLWHomYlUVI
# zB7K38lqAHR95dN5XZfQIb5ibwL1ECx1agtuEKKcl18zCjjwsJ/gjTiZTbcCAL77
# q8FjrU7KWShel5NsrDw7srcvmZ1tCtNPin+Qp6PBJjYXxrHYAsEXOvEmjQ5k7oVf
# hboAtKdpdXJp5iYNwRYFuJQcainyc4wJlfC7hlfjZgit5evnkYsHqOe9tVspg5PG
# +B7ggoMhEGRGu+fXnbdZAzdvFDo/HfLMKnvteVu6E/ZGPukLHI+xYTliBnvtO68y
# kQUODxOIhmNcKRoJPsoIZq+J5gEWC4Mr++c+f5XYYGmWyx7Hoci4GCjRzBrKpdMo
# jwV+MFDQPxBbbodkhi0=
# SIG # End signature block
