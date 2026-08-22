[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string] $ModulePath,

    [string] $ReadmePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'README.md'),

    [switch] $Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

$startMarker = '<!-- BEGIN GENERATED PSCX PUBLIC API -->'
$endMarker = '<!-- END GENERATED PSCX PUBLIC API -->'
$resolvedModulePath = (Resolve-Path -LiteralPath $ModulePath).Path
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$resolvedReadmePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
    $ReadmePath
)
$manifestPath = Join-Path $resolvedModulePath 'Pscx.psd1'
$windowsManifestPath = Join-Path $resolvedModulePath 'PscxWin.psd1'
$preferencesPath = Join-Path $resolvedModulePath 'Pscx.UserPreferences.ps1'

foreach ($requiredPath in $manifestPath, $windowsManifestPath, $preferencesPath) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "The Full packaged module is required; missing '$requiredPath'."
    }
}
if (-not (Test-Path -LiteralPath $resolvedReadmePath -PathType Leaf)) {
    throw "README does not exist: $resolvedReadmePath"
}
if (Get-Module -Name Pscx*) {
    throw 'A PSCX module is already loaded. Run this tool in a fresh pwsh -NoProfile process.'
}

function ConvertTo-MarkdownText {
    param([AllowEmptyString()][string] $Text)

    return (($Text -replace '\s+', ' ').Trim() -replace '\|', '\|')
}

function Get-ManifestExports {
    param([Parameter(Mandatory)][string] $Path)

    $data = Import-PowerShellDataFile -LiteralPath $Path
    return @(
        $data['CmdletsToExport']
        $data['FunctionsToExport']
    ) | Where-Object { $_ -and $_ -ne '*' } | Sort-Object -Unique
}

$rootManifest = Import-PowerShellDataFile -LiteralPath $manifestPath
$publicContractPath = Join-Path $repositoryRoot 'Tests/Pscx.PublicContract.psd1'
$publicContract = Import-PowerShellDataFile -LiteralPath $publicContractPath
$windowsCommandNames = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase
)
foreach ($name in Get-ManifestExports -Path $windowsManifestPath) {
    $windowsCommandNames.Add($name) | Out-Null
}
foreach ($name in $publicContract.Platforms.WindowsOnlyCommands) {
    $windowsCommandNames.Add($name) | Out-Null
}

$defaultPreferences = & $preferencesPath
$availabilityByName = @{}
$childManifestFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $resolvedModulePath 'Modules') `
        -Recurse -Filter *.psd1 -File |
        Where-Object {
            (Get-Content -LiteralPath $_.FullName -Raw) -match '(?m)^\s*(?:Functions|Cmdlets)ToExport\s*='
        }
)
foreach ($childManifest in $childManifestFiles) {
    $feature = $childManifest.Directory.Name
    $isDefault = [bool]$defaultPreferences.ModulesToImport[$feature]
    foreach ($name in Get-ManifestExports -Path $childManifest.FullName) {
        $availabilityByName[$name] = if ($isDefault) { 'Default' } else { "Optional ($feature)" }
        if ($feature -in 'DirectoryServices', 'Sudo', 'Wmi') {
            $windowsCommandNames.Add($name) | Out-Null
        }
    }
}

$allFeatures = @{}
foreach ($feature in $defaultPreferences.ModulesToImport.Keys) {
    # TranscribeSession changes profile-adjacent state and does not contribute a
    # command declared by the parent manifest, so catalog generation never loads it.
    $allFeatures[$feature] = $feature -ne 'TranscribeSession'
}
$importWarnings = @()
Import-Module $manifestPath -ArgumentList @{
    PageHelpUsingLess = $false
    OverrideExistingAliases = $true
    ModulesToImport = $allFeatures
} -Force -DisableNameChecking -WarningVariable importWarnings -ErrorAction Stop

if ($importWarnings.Count -gt 0) {
    throw "The packaged module emitted warnings while generating the catalog: $($importWarnings -join ' | ')"
}

$module = Get-Module Pscx -ErrorAction Stop
$declaredNames = @(
    $rootManifest.CmdletsToExport
    $rootManifest.FunctionsToExport
) | Where-Object { $_ -and $_ -ne '*' } | Sort-Object -Unique
$commandsByName = @{}
foreach ($command in $module.ExportedCommands.Values) {
    $commandsByName[$command.Name] = $command
}
$missingNames = @($declaredNames | Where-Object { -not $commandsByName.ContainsKey($_) })
if ($missingNames.Count -gt 0) {
    throw "The Full package does not resolve declared commands: $($missingNames -join ', ')"
}

$catalogCommands = [Collections.Generic.List[object]]::new()
$platformByName = @{}
$availabilityByResolvedName = @{}
foreach ($name in $declaredNames) {
    $command = $commandsByName[$name]
    $platform = if ($windowsCommandNames.Contains($command.Name)) { 'Windows' } else { 'All' }
    if ($command.CommandType -eq [Management.Automation.CommandTypes]::Cmdlet) {
        $supportedPlatforms = @(
            $command.ImplementingType.GetCustomAttributesData() |
                Where-Object AttributeType -EQ ([Runtime.Versioning.SupportedOSPlatformAttribute]) |
                ForEach-Object { [string]$_.ConstructorArguments[0].Value }
        )
        if ($supportedPlatforms | Where-Object { $_ -like 'windows*' }) {
            $platform = 'Windows'
        }
    }
    elseif (
        $command.ScriptBlock.File -and
        [IO.Path]::GetFileName($command.ScriptBlock.File) -eq 'PscxWin.psm1'
    ) {
        $platform = 'Windows'
    }

    $availability = if ($availabilityByName.ContainsKey($command.Name)) {
        $availabilityByName[$command.Name]
    }
    else {
        'Default'
    }
    $description = if ($command.CommandType -eq [Management.Automation.CommandTypes]::Cmdlet) {
        $descriptionAttribute = @(
            $command.ImplementingType.GetCustomAttributes(
                [ComponentModel.DescriptionAttribute],
                $true
            )
        ) | Select-Object -First 1
        ConvertTo-MarkdownText ([string]$descriptionAttribute.Description)
    }
    else {
        $helpContent = $command.ScriptBlock.Ast.GetHelpContent()
        if ($null -ne $helpContent -and $helpContent.Synopsis) {
            ConvertTo-MarkdownText ([string]$helpContent.Synopsis)
        }
        else {
            $help = Get-Help -Name $command.Name -Full -ErrorAction Stop
            ConvertTo-MarkdownText ([string]$help.Synopsis)
        }
    }
    $description = $description -replace '^PSCX Cmdlet:\s*', ''
    if (
        [string]::IsNullOrWhiteSpace($description) -or
        $description -like '*proper help content*'
    ) {
        throw "Public command '$($command.Name)' has no usable help synopsis."
    }

    $platformByName[$command.Name] = $platform
    $availabilityByResolvedName[$command.Name] = $availability
    $catalogCommands.Add([pscustomobject]@{
        Name = $command.Name
        Type = $command.CommandType.ToString()
        Platform = $platform
        Availability = $availability
        Description = $description
    })
}

$coreAliasNames = @($publicContract.Aliases.Core)
$windowsAliasNames = @($publicContract.Aliases.Full)
$catalogAliases = @(
    @($coreAliasNames; $windowsAliasNames) |
        Sort-Object -Unique |
        ForEach-Object {
            $alias = Get-Alias -Name $_ -ErrorAction Stop
            $target = [string]$alias.Definition
            $unqualifiedTarget = ($target -split '\\')[-1]
            $platform = if ($_ -in $windowsAliasNames) {
                'Windows'
            }
            elseif ($platformByName.ContainsKey($unqualifiedTarget)) {
                $platformByName[$unqualifiedTarget]
            }
            else {
                'All'
            }
            $availability = if ($alias.Name -eq 'cd') {
                'When CD module is enabled'
            }
            else {
                'Default unless collision (`OverrideExistingAliases`)'
            }
            [pscustomobject]@{
                Name = $alias.Name
                Target = $target
                Platform = $platform
                Availability = $availability
            }
        }
)

$catalogProviders = @(
    Get-PSProvider |
        Where-Object { $_.ImplementingType.Assembly.GetName().Name -Like 'Pscx*' } |
        Sort-Object Name -Unique |
        ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                Platform = if ($_.ImplementingType.Assembly.GetName().Name -eq 'Pscx.Win') {
                    'Windows'
                }
                else {
                    'All'
                }
            }
        }
)

$lines = [Collections.Generic.List[string]]::new()
$lines.Add($startMarker)
$lines.Add('<!-- Generated by Tools/Update-PscxReadmeCatalog.ps1. Do not edit this region manually. -->')
$lines.Add('')
foreach ($commandType in 'Cmdlet', 'Function') {
    $items = @($catalogCommands | Where-Object Type -EQ $commandType | Sort-Object Name)
    $lines.Add("### ${commandType}s ($($items.Count))")
    $lines.Add('')
    $lines.Add('| Command | Platform | Availability | Description |')
    $lines.Add('| --- | --- | --- | --- |')
    foreach ($item in $items) {
        $lines.Add("| ``$($item.Name)`` | $($item.Platform) | $($item.Availability) | $($item.Description) |")
    }
    $lines.Add('')
}

$lines.Add("### Aliases ($($catalogAliases.Count))")
$lines.Add('')
$lines.Add('| Alias | Target | Platform | Availability |')
$lines.Add('| --- | --- | --- | --- |')
foreach ($alias in $catalogAliases) {
    $lines.Add("| ``$($alias.Name)`` | ``$($alias.Target)`` | $($alias.Platform) | $($alias.Availability) |")
}
$lines.Add('')
$lines.Add("### Providers ($($catalogProviders.Count))")
$lines.Add('')
$lines.Add('| Provider | Platform |')
$lines.Add('| --- | --- |')
foreach ($provider in $catalogProviders) {
    $lines.Add("| ``$($provider.Name)`` | $($provider.Platform) |")
}
$lines.Add('')
$lines.Add($endMarker)
$generatedRegion = $lines -join "`n"

$readme = [IO.File]::ReadAllText($resolvedReadmePath)
$normalizedReadme = $readme -replace "`r`n", "`n"
$pattern = '(?ms)' + [regex]::Escape($startMarker) + '.*?' + [regex]::Escape($endMarker)
$matches = [regex]::Matches($normalizedReadme, $pattern)
if ($matches.Count -ne 1) {
    throw "Expected exactly one generated catalog region in '$resolvedReadmePath'; found $($matches.Count)."
}
$expectedReadme = [regex]::Replace($normalizedReadme, $pattern, $generatedRegion)

if ($Check) {
    if ($normalizedReadme -cne $expectedReadme) {
        throw 'README public API catalog is stale. Run ./build.ps1 -Task Catalog after a Full package build.'
    }
    Write-Output 'README public API catalog is current.'
    return
}

if ($normalizedReadme -ceq $expectedReadme) {
    Write-Output 'README public API catalog is already current.'
    return
}

[IO.File]::WriteAllText(
    $resolvedReadmePath,
    $expectedReadme,
    [Text.UTF8Encoding]::new($false)
)
Write-Output "Updated README public API catalog: $resolvedReadmePath"

# SIG # Begin signature block
# MIInmgYJKoZIhvcNAQcCoIInizCCJ4cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBihiG3btyKQr/1
# +CB6i5L1rMqX6dxCTTy40A6+dQ4ASaCCIHEwggWNMIIEdaADAgECAhAOmxiO+dAt
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
# MQ4wDAYKKwYBBAGCNwIBFjAvBgkqhkiG9w0BCQQxIgQgNf9yCydRrrPuoV5Uv2jD
# LFVn1kCnu4IJ97WvbvqlARMwDQYJKoZIhvcNAQEBBQAEggIAWJWuES/iEUAAKG69
# 0Jzog7aNlmWYSefeWEEnrJWKWNIG0lSrcTIK+We07IbEE5dkTE4F7GnJzJ/wfdeX
# yBwHBFYznvDMS/wC7W2j28BWpI28VHbZdMuxTbHQmKgmva66/apTU2OVi4sjAduW
# mJ4nUSQvJuT9dbqqyd5ntuxRLPmBn+in3fMVab0r/Ce5rJUwN4AekctFgBVIkevP
# I0xQ02ocnV7hIi9tm51b9qJ52yXAnLZV+XXPsuH3NCa1VIIy0+3UQRAx+FNY5rMr
# bXz2AOT46yj3R9lyDK0WUsyScleUF6JcKL+BMbKYdA1bPDeIfMS8hz1qXWa9foFn
# CF2d7nW2oNw8J1qUCcnwGRoS37K0Kqw0C4cZDHEP8Nn8HWRIzSHKOmmCdPXkJEfc
# HzWvvTV/9stpiYFUEwYaFqHSCOIqJEU46+02PB9gFSmueyOxxJSkbkCzP0bq+rLe
# mFItTSoyRVb2n/sBncy9HaOoJNNX57NH0IUyM2uXTvd2fpi++nM5EH74ytA3GKso
# +u7QQYqH5aODuMaEVdzbidvo7YkZpn1/+1dwQn3u21IsLaX0L7d6A+7am8pFDhcs
# j71rcwpvQnnxdgl+iwudV97D+iqiUE148ki9TOp7IfwVjqaXKQymTCnuCXKcPMEU
# 4x/Zz7gPj02kUohSHXcAgvb8uXGhggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8C
# AQEwfTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/
# BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYg
# U0hBMjU2IDIwMjUgQ0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUA
# oGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYw
# ODA4MDUwNTM4WjAvBgkqhkiG9w0BCQQxIgQgrJthwzXqH0qRGbe9gFcnlv1vLJtb
# CBn4rmBGcvjjtFQwDQYJKoZIhvcNAQEBBQAEggIAySXf4+kd92rBVL7HeLVNlYAf
# 5Ji9pqTFljV5WZkJwJCuOc2tKERP706KoltuNPkqWBMWKoW3+Azxxxmx3bddoDyI
# /U5xomkKLP8739LmoLzutT/aAKkSlHRMTE11DlYTLybvgFUrJZYCJCzqSp/X3KAT
# UeColkyd6aVXiyIkAqbkUHLGlUYUx4EayAGbjq5ZNb+nI8s89rAYOyn0KNRGWRaG
# bOuS2h6Rrv+Hi222mBX16+8jzDg4ww17SVuZZ6UXL6xjZSTT2lGv99Itl1Zvk/NG
# O6Ybq4jcCzWS3i+OI4DyIV/zh8G7SI1N+wzNo8bfMcLN1oENoHdEaiPc9fRx20j4
# apMBa5YgMlYDJOQ5N2hcpUk+gsuIQ0ihCz5YCVpkdwxa3C4zx0YNmb02ZwMxKHXW
# RSJBXqBHjlJjqdrRTMDBjQWExxhT03Hq1Obsg8+uFMeUMEQ3a6gXJ9vtXTWSxHvP
# uXcCMmsYbAb7lVzD82Ul7Yo6SXhFgnsRfkXJzz/B5UNMPzbUsnEmLDo/oVseGjDt
# OjcQsNkN9X4PHrzdkN3hlXwPp6PQSer6eQOtjs2wIybul8SiE7a5/jx9FdS81/rP
# 139g82nUQ2kqholyZKpXaw5S3yfQ+gN+auHdKP9tXj5O0uO5i/EcbDsRPVbWzqCh
# oFgwzsKdjmucgyzflUk=
# SIG # End signature block
