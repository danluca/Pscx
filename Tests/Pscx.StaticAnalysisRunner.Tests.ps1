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
    'timeout.ps1' {
        Start-Sleep -Seconds 10
        [Console]::Out.WriteLine('[]')
    }
    'batch-sensitive.ps1' {
        if ($IncludeRule -match ',') {
            [Console]::Error.WriteLine('combined rule batch failed')
            exit 29
        }
        [ordered]@{
            Severity = 'Information'
            RuleName = $IncludeRule
            ScriptPath = $Path
            Line = 11
            Message = "finding from $IncludeRule"
        } | ConvertTo-Json -Compress
    }
    'single-rule-failure.ps1' {
        if (($IncludeRule -split ',') -contains 'RuleBroken') {
            [Console]::Error.WriteLine('individual rule failed')
            exit 31
        }
        [ordered]@{
            Severity = 'Information'
            RuleName = $IncludeRule
            ScriptPath = $Path
            Line = 13
            Message = "finding from $IncludeRule"
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

    It 'bounds a hung analyzer worker and preserves timeout context' {
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        $result = Invoke-PscxAnalyzerWorkItem `
            -PowerShellExecutable $powerShellExecutable `
            -AnalyzerScript $fakeWorker `
            -AnalyzerManifest (Join-Path $TestDrive 'unused.psd1') `
            -Path (Join-Path $TestDrive 'timeout.ps1') `
            -MaximumAttempts 1 `
            -TimeoutSeconds 1
        $stopwatch.Stop()

        $result.Succeeded | Should -BeFalse
        $result.AttemptCount | Should -Be 1
        $result.InfrastructureFailures | Should -HaveCount 1
        $result.InfrastructureFailures[0].TimedOut | Should -BeTrue
        $result.InfrastructureFailures[0].TimeoutSeconds | Should -Be 1
        $result.InfrastructureFailures[0].Reason | Should -Match 'exceeded the 1-second timeout'
        $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 5
    }

    It 'subdivides a repeatedly failing batch and preserves findings from every rule' {
        $result = Invoke-PscxAnalyzerRuleBatch `
            -PowerShellExecutable $powerShellExecutable `
            -AnalyzerScript $fakeWorker `
            -AnalyzerManifest (Join-Path $TestDrive 'unused.psd1') `
            -Path (Join-Path $TestDrive 'batch-sensitive.ps1') `
            -RuleName RuleOne, RuleTwo

        $result.Succeeded | Should -BeTrue
        $result.AttemptCount | Should -Be 4
        $result.WorkItemCount | Should -Be 3
        $result.SubdivisionCount | Should -Be 1
        $result.InfrastructureFailures.Count | Should -Be 2
        $result.Diagnostics.RuleName | Should -Be @('RuleOne', 'RuleTwo')
    }

    It 'fails with exact context when subdivision isolates a broken rule' {
        $result = Invoke-PscxAnalyzerRuleBatch `
            -PowerShellExecutable $powerShellExecutable `
            -AnalyzerScript $fakeWorker `
            -AnalyzerManifest (Join-Path $TestDrive 'unused.psd1') `
            -Path (Join-Path $TestDrive 'single-rule-failure.ps1') `
            -RuleName RuleGood, RuleBroken

        $result.Succeeded | Should -BeFalse
        $result.AttemptCount | Should -Be 5
        $result.WorkItemCount | Should -Be 3
        $result.SubdivisionCount | Should -Be 1
        $result.Diagnostics.RuleName | Should -Be 'RuleGood'
        $result.InfrastructureFailures.Count | Should -Be 4
        $result.InfrastructureFailures[-1].RuleBatch | Should -Be 'RuleBroken'
        $result.InfrastructureFailures[-1].StandardError | Should -Match 'individual rule failed'
    }

    It 'canonicalizes paths and removes only exact duplicate diagnostics' {
        $diagnostics = @(
            [pscustomobject]@{
                Severity = 'Warning'
                RuleName = 'FakeRule'
                ScriptPath = Join-Path $repositoryRoot 'Src/Pscx/Pscx.psm1'
                Line = 12
                Message = 'same finding'
            }
            [pscustomobject]@{
                Severity = 'Warning'
                RuleName = 'FakeRule'
                ScriptPath = Join-Path $repositoryRoot 'Src/Pscx/Pscx.psm1'
                Line = 12
                Message = 'same finding'
            }
            [pscustomobject]@{
                Severity = 'Warning'
                RuleName = 'FakeRule'
                ScriptPath = Join-Path $repositoryRoot 'Src/Pscx/Pscx.psm1'
                Line = 13
                Message = 'same finding'
            }
        )

        $result = @(Get-PscxCanonicalAnalyzerDiagnostic `
                -Diagnostic $diagnostics `
                -RepositoryRoot $repositoryRoot)

        $result | Should -HaveCount 2
        $result.RelativePath | Should -Be @('Src/Pscx/Pscx.psm1', 'Src/Pscx/Pscx.psm1')
        $result.Line | Should -Be @(12, 13)
    }
}

# SIG # Begin signature block
# MIInmgYJKoZIhvcNAQcCoIInizCCJ4cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA2BCl+hw2LgAhz
# oljdX6tZClx/IK9yBUOdxydDrUGdRKCCIHEwggWNMIIEdaADAgECAhAOmxiO+dAt
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
# MQ4wDAYKKwYBBAGCNwIBFjAvBgkqhkiG9w0BCQQxIgQgD4crrHUiZz1S6X1lTfT+
# t0dsqQzlilZ9nhIOgmEE3gowDQYJKoZIhvcNAQEBBQAEggIAL67xxf3BZDUXLenF
# 9YwnTBFtulDW0F+Pw30YfZSRR8GdtIkC6+FAiT8ysDVs+sA+eWKTvoSi84CiRs1y
# np9trvF5v+WHHLdPDsIpBj3qbna52IkYQacdv5sO1LYYBDfjliE9oSo4037fk491
# ug33/x7gqPoJ3Pomr/MxWO3wl08fSUSEgPwJ54AkJrV2WK2csqOBwLWmkhI0e46S
# weOcFv4qJiFZKKEwKtNA31QnS0ukC0CN4BEa4LMaCA+CKAOgeGrFyuNMSqB7h9I1
# dFNyfreJujBBFxNXp5VR+Aaznxv8TnXeNS4jdGNBIuKO/QfU9IYTTvy6iivRbQAS
# yhVpdQF7pH5QEACMi5pJT0DYvAvMMuvOJSXgRbpZ/qepaGvQwOZIu+xPWSTD++2w
# PtzK9+DLCzo6KK1wTVomjYU+A/LgEiW1K5B8kfaC6M69PkLMb48ezGGMCuNwYwNC
# eMcbLiKNYUePSG5gRK5dNJWvlH/Oy3OeLcfA2ps6mFTwuCknYMWFDl8Ki37Wzzfx
# nKc+3SEdJhPlMPcseIOYyNjpVWDq9t9u4CcmC5NDvHilt5nEVI3WjjxiBHNnbA5x
# QmF8IH32muZFvMdoSji9WQtN/tkB1f0QRAZBN7Aedq9XC7/JSn6UYp8xSZd4uwBs
# SKr2KsEo9TWOJziOH3QtrBqzTmehggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8C
# AQEwfTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/
# BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYg
# U0hBMjU2IDIwMjUgQ0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUA
# oGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYw
# ODI5MTcwNTM5WjAvBgkqhkiG9w0BCQQxIgQgGXeXLd8yr5lr3+2RAOwKSs8Ayl4A
# 8UL7CsWnEY67pUcwDQYJKoZIhvcNAQEBBQAEggIAqeUQHQOzY3yxZBfeX/7fgEFl
# dVWpG82O2pvOR4UpwaQYEMDat11wAUStldzz/KZM14UlxvgVMgOXMJCbGo9QKY3x
# WHyns7VjZT8MilD+TP3Ky1LgHWjuCJYZ4iFc+mqx6cPn+Bo8MbUgre+a6KQrTWkE
# RpNyaXA+mocDmT9Bow9nPWu7+/YYHhFIPsHrm/RPArmygZyUe6AdPIbz0U8o5vBE
# fvmDZSXuZtKF9BM1OH/qaQSEHIygQefuKI+GhSOW7BR2N79SQ4UWRxwxnpiEiseS
# 1Zheqp1iABzVeX6tIotN6ZgDb3Ji0VztS0kzsMfEFvqhSPLr7I4MgabFP7W4uDOM
# 1UqGwKb2jRZ3hS/6FxucO/UKoq8nOLDMAw+1/osYokiNSgQi8Cb5hHHfWDA4yVQF
# L448nYfHCrfXPreibX/0crnYr8///7FWjiO61ZWGhBnkSxowZ3FXbvdvermOm3AE
# xiIgwz+EaXd9lkzFzxxoHpWK4aQco5TlaPqbN4sX32ZYlKpCGcFKnzAy/voZUkGW
# 1ag4qO6jbzQdOVVXZTR3psZ/iL3CnEqOh5JHEfFi/wp4SX2bugi7UZ+GOUE6A9pL
# lxiC8D27qZ24Z22Fo/bHjAKUQmXBE/fAI51oo5Md1ZBMnyPL14l1qTCY8p6uhEg6
# 0jAF3xVw+5NuS6cStyI=
# SIG # End signature block
