<#
.SYNOPSIS
Builds and installs the current PSCX source for local testing.

.DESCRIPTION
Runs the incremental restore, compile, and package tasks, then installs the
staged PSCX modules into versioned user-module directories. Existing content
for the same module version is replaced through a same-parent staging and
backup transaction; other installed versions are retained.

On Windows, the default destination honors Documents folder redirection,
including OneDrive, and falls back to the local user profile. On macOS and
Linux, the default follows XDG_DATA_HOME or the normal per-user PowerShell
module location.

.PARAMETER DestinationRoot
One or more PowerShell module roots. When omitted, selects the platform-native
current-user module root.

.PARAMETER Configuration
The managed build configuration. The default is Release.

.PARAMETER BuildScope
Auto selects Full on Windows and Core elsewhere. Full is Windows-only.

.PARAMETER ArtifactsPath
Overrides the repository artifacts directory used for staging.

.PARAMETER SkipBuild
Installs an existing staged package without restoring, compiling, or packaging.

.EXAMPLE
./Tools/Local-Install.ps1

Builds and installs the appropriate package scope for the current platform.

.EXAMPLE
./Tools/Local-Install.ps1 -SkipBuild -WhatIf

Previews replacement of the currently staged modules without changing the
module directory.

.EXAMPLE
./Tools/Local-Install.ps1 -BuildScope Core -DestinationRoot /tmp/psmodules

Builds the cross-platform module set and installs it into an explicit root.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [string[]] $DestinationRoot,

    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release',

    [ValidateSet('Auto', 'Core', 'Full')]
    [string] $BuildScope = 'Auto',

    [string] $ArtifactsPath,

    [switch] $SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PscxDefaultModuleRoot {
    [OutputType([string])]
    param()

    if ($IsWindows) {
        $documents = [Environment]::GetFolderPath(
            [Environment+SpecialFolder]::MyDocuments
        )
        if ([string]::IsNullOrWhiteSpace($documents)) {
            $userProfile = [Environment]::GetFolderPath(
                [Environment+SpecialFolder]::UserProfile
            )
            if ([string]::IsNullOrWhiteSpace($userProfile)) {
                $userProfile = $HOME
            }
            if ([string]::IsNullOrWhiteSpace($userProfile)) {
                throw 'Could not determine the current Windows user profile directory.'
            }
            $documents = Join-Path $userProfile 'Documents'
        }
        return Join-Path $documents 'PowerShell/Modules'
    }

    if (-not [string]::IsNullOrWhiteSpace($env:XDG_DATA_HOME) -and
        [IO.Path]::IsPathRooted($env:XDG_DATA_HOME)) {
        return Join-Path $env:XDG_DATA_HOME 'powershell/Modules'
    }
    if ([string]::IsNullOrWhiteSpace($HOME)) {
        throw 'Could not determine the current user home directory.'
    }
    return Join-Path $HOME '.local/share/powershell/Modules'
}

function Test-PscxChildPath {
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][string] $Candidate
    )

    $comparison = if ($IsWindows) {
        [StringComparison]::OrdinalIgnoreCase
    }
    else {
        [StringComparison]::Ordinal
    }
    $separator = [IO.Path]::DirectorySeparatorChar
    $rootPrefix = $Root.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ) + $separator
    return $Candidate.StartsWith($rootPrefix, $comparison)
}

function Invoke-PscxLocalModuleInstall {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][string] $ModuleName,
        [Parameter(Mandatory)][string] $SourcePath,
        [Parameter(Mandatory)][string] $ModuleRoot
    )

    $manifestPath = Join-Path $SourcePath "$ModuleName.psd1"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "The staged $ModuleName module has no manifest at '$manifestPath'."
    }
    $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
    $moduleVersion = ([version]$manifest.ModuleVersion).ToString(3)
    $prerelease = [string]$manifest.PrivateData.PSData.Prerelease
    $displayVersion = if ([string]::IsNullOrWhiteSpace($prerelease)) {
        $moduleVersion
    }
    else {
        "$moduleVersion-$prerelease"
    }

    $moduleParent = [IO.Path]::GetFullPath((Join-Path $ModuleRoot $ModuleName))
    $installPath = [IO.Path]::GetFullPath((Join-Path $moduleParent $moduleVersion))
    if (-not (Test-PscxChildPath -Root $ModuleRoot -Candidate $installPath)) {
        throw "Refusing to install outside destination root '$ModuleRoot': '$installPath'."
    }
    if (-not $PSCmdlet.ShouldProcess(
            $installPath,
            "Install local $ModuleName $displayVersion"
        )) {
        return [pscustomobject]@{
            Module = $ModuleName
            Version = $displayVersion
            Path = $installPath
            Status = 'WouldInstall'
        }
    }

    $loadedModules = @(Get-Module -Name $ModuleName)
    if ($loadedModules.Count -gt 0) {
        Write-Information "Unloading $ModuleName from the current PowerShell session." `
            -InformationAction Continue
        $loadedModules | Remove-Module -Force -ErrorAction Stop
    }

    New-Item -ItemType Directory -Path $moduleParent -Force | Out-Null
    if (Test-Path -LiteralPath $installPath) {
        $existingItem = Get-Item -LiteralPath $installPath -Force
        if (-not $existingItem.PSIsContainer) {
            throw "The install target exists but is not a directory: '$installPath'."
        }
        if ($existingItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Refusing to replace reparse-point install directory '$installPath'."
        }
    }

    $transactionId = [guid]::NewGuid().ToString('N')
    $stagingPath = Join-Path $moduleParent ".pscx-local-stage-$transactionId"
    $backupPath = Join-Path $moduleParent ".pscx-local-backup-$transactionId"
    $existingMoved = $false
    $newInstalled = $false
    try {
        New-Item -ItemType Directory -Path $stagingPath | Out-Null
        Get-ChildItem -LiteralPath $SourcePath -Force |
            Copy-Item -Destination $stagingPath -Recurse -Force
        if (-not (Test-Path -LiteralPath (Join-Path $stagingPath "$ModuleName.psd1") -PathType Leaf)) {
            throw "The staged copy of $ModuleName is incomplete."
        }

        if (Test-Path -LiteralPath $installPath) {
            Move-Item -LiteralPath $installPath -Destination $backupPath
            $existingMoved = $true
        }
        Move-Item -LiteralPath $stagingPath -Destination $installPath
        $newInstalled = $true
    }
    catch {
        $installError = $_
        if ($newInstalled -and (Test-Path -LiteralPath $installPath)) {
            Remove-Item -LiteralPath $installPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        if ($existingMoved -and (Test-Path -LiteralPath $backupPath) -and
            -not (Test-Path -LiteralPath $installPath)) {
            Move-Item -LiteralPath $backupPath -Destination $installPath -ErrorAction SilentlyContinue
        }
        throw $installError
    }
    finally {
        if (Test-Path -LiteralPath $stagingPath) {
            Remove-Item -LiteralPath $stagingPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if ($existingMoved -and (Test-Path -LiteralPath $backupPath)) {
        try {
            Remove-Item -LiteralPath $backupPath -Recurse -Force
        }
        catch {
            Write-Warning "Installed $ModuleName, but could not remove backup '$backupPath': $($_.Exception.Message)"
        }
    }

    Write-Information "Installed $ModuleName $displayVersion at '$installPath'." `
        -InformationAction Continue
    return [pscustomobject]@{
        Module = $ModuleName
        Version = $displayVersion
        Path = $installPath
        Status = 'Installed'
    }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$buildScript = Join-Path $repositoryRoot 'build.ps1'
$artifactsRoot = if ([string]::IsNullOrWhiteSpace($ArtifactsPath)) {
    Join-Path $repositoryRoot 'artifacts'
}
else {
    [IO.Path]::GetFullPath($ArtifactsPath)
}
$resolvedBuildScope = if ($BuildScope -eq 'Auto') {
    if ($IsWindows) { 'Full' } else { 'Core' }
}
else {
    $BuildScope
}
if ($resolvedBuildScope -eq 'Full' -and -not $IsWindows) {
    throw 'Full local installs are supported only on Windows. Use -BuildScope Core.'
}

if (-not $SkipBuild) {
    Write-Information "Building a $resolvedBuildScope PSCX package for local installation." `
        -InformationAction Continue
    $powerShellPath = Get-Command -Name pwsh -CommandType Application -ErrorAction Stop |
        Select-Object -First 1 -ExpandProperty Source
    foreach ($buildTask in 'Restore', 'Compile', 'Package') {
        & $powerShellPath -NoLogo -NoProfile -NonInteractive -File $buildScript `
            -Task $buildTask `
            -Configuration $Configuration `
            -BuildScope $resolvedBuildScope `
            -ArtifactsPath $artifactsRoot
        if ($LASTEXITCODE -ne 0) {
            throw "Local PSCX $buildTask task failed with exit code $LASTEXITCODE."
        }
    }
}

$moduleStageRoot = Join-Path $artifactsRoot 'module'
$moduleNames = @('Pscx', 'Pscx.Archive', 'Pscx.Time')
if ($resolvedBuildScope -eq 'Full') {
    $moduleNames += 'Pscx.WinAdmin'
}
foreach ($moduleName in $moduleNames) {
    $sourcePath = Join-Path $moduleStageRoot $moduleName
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) {
        $buildHint = if ($SkipBuild) { ' Remove -SkipBuild or stage the package first.' } else { '' }
        throw "The staged $moduleName module is missing at '$sourcePath'.$buildHint"
    }
}

$requestedRoots = if ($null -ne $DestinationRoot -and $DestinationRoot.Count -gt 0) {
    $DestinationRoot
}
else {
    @(Get-PscxDefaultModuleRoot)
}
$pathComparer = if ($IsWindows) {
    [StringComparer]::OrdinalIgnoreCase
}
else {
    [StringComparer]::Ordinal
}
$uniqueRoots = [Collections.Generic.HashSet[string]]::new($pathComparer)
$moduleRoots = @(
    foreach ($root in $requestedRoots) {
        if ([string]::IsNullOrWhiteSpace($root)) {
            throw 'DestinationRoot cannot contain an empty path.'
        }
        $fullRoot = [IO.Path]::GetFullPath($root)
        if ($uniqueRoots.Add($fullRoot)) {
            $fullRoot
        }
    }
)

Write-Information 'Close other PowerShell sessions that have PSCX loaded before replacing a local build.' `
    -InformationAction Continue
$results = foreach ($moduleRoot in $moduleRoots) {
    foreach ($moduleName in $moduleNames) {
        Invoke-PscxLocalModuleInstall `
            -ModuleName $moduleName `
            -SourcePath (Join-Path $moduleStageRoot $moduleName) `
            -ModuleRoot $moduleRoot
    }
}

$results
if (-not $WhatIfPreference) {
    Write-Information 'Local installation complete. Start a new PowerShell session before testing it.' `
        -InformationAction Continue
}

# SIG # Begin signature block
# MIInmgYJKoZIhvcNAQcCoIInizCCJ4cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD+qbKoWnIwNdQY
# cWiH4EtXAw6CVnUVbG9D53OzS+wEyaCCIHEwggWNMIIEdaADAgECAhAOmxiO+dAt
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
# EA+8hcpSM9LHJmyrxaFtoza2zNaQ9k+5t1wwggbtMIIE1aADAgECAhAIT9wzT35F
# TtvDD4/5khg1MA0GCSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQK
# Ew5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBU
# aW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwHhcNMjYwODA1MDAw
# MDAwWhcNMzcxMTA0MjM1OTU5WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGln
# aUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFNIQTI1NiBSU0E0MDk2IFRp
# bWVzdGFtcCBSZXNwb25kZXIgMjAyNiAxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAtnum8sn+zUr41JtMZbP9OMYw+HwJDpG5xkIu/lqcfNYmMX81YmsU
# iHLbh9ykpeWBGKTLhYBrAN9Tdg/QEzG32XcObmgIblnr0CoQ3WSAeDZ6nH6X6VkF
# yYkJw3QBJREwvm4UhLzSxmwPA7cFKRTEOMsmEEj6qJk/dqLEAL+oQYuOwE2UuiX1
# Vnul8YReIyWd4kgLn9gq6LNXM0UplkR6jL/QHxmb6fMoGBJYbnaUI7XD6cKDpekK
# 2SVMld4iDbzeHDtOaaxldH5IxuNusQ69nd8/ZXEiB5Hbxj3RlK13cX1W4DlFXKdv
# /CEhM8Cj1vvlmvhNroyPdRGbbpBlgyf8Wdu5N6ByhFwURn0U6ozlPoxN22v+fviU
# hP+6DR547OZnpBMWDfei1f5sVGwiiW/KQTWOK97g+4RJpPzPNV4VYMAwO2jM2Aty
# 2QYPVmOQTJm0msuXnJrSbl2gf9JylpkJlWXqk1Q4LJsxz+TELoQCZIljbgvTJgoP
# U2R12ydv8i1UqL/adelA0y7U9Pmmtbze9Xx3rtajC5SzQd1jgfwAwsa90v9YcSPd
# meoyoBBA/27cCL237l5DTYYPDLQ4ON3OLTGWnvRb6jDrf/T75gMRfUzSLCBQfBus
# m9+mSWRlC/Df6S/e9Q8i13CuhzOT2Jx+V/nlbXM4QoBwlUAhelwwJT0CAwEAAaOC
# AZUwggGRMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFBTJY4owLtRK+26U8+bjQH71
# 7M3iMB8GA1UdIwQYMBaAFO9vU0rp5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB/wQE
# AwIHgDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgwgYUw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEFBQcw
# AoZRaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0
# VGltZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRYMFYw
# VKBSoFCGTmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRH
# NFRpbWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAEGTAX
# MAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBAI3FOmEe
# nVIK35msCYB+fShAsWvSYvLBItoNdAgQ2jIqrGsVsluXMJU/+mRebBc52s6lbKAv
# OVPXaizmKkMLLflEEKDZQx4CkS2t8aHPjkXha3hYZ010htFa3dhNgmalH5vuWvh3
# tTCf4frTS7gPtGc4Z/xaPhQ2AB1mR8eEe/WbH0RWHvVIl6VwQ3+g5FKNfN2N/DWJ
# kf13w2H+2GfqEfbd35Ww8CvoYBjLNIDTadcPWdgsjsiOaK/7EsKJgLjUNIVgvcaF
# OLLQ/GlrA+0ZHJoFUbOr5SJN8zykPspXIXlpDJY/gqFUZRROeab9GVgmhbdOJcD/
# 63RhxPahFUGbckRONqMe6DYAv6/mOG0pWd3cPStsdcS7buj5DyniwRY8yooMH6pt
# x5vpP/pZzBPBeZD2U4IsthyxB5Jaa8qrOkB5z160TXiM5ADMspZ0TfD9MJoq0tFp
# FPssKRFhWeEDYPvcUuN7U7lvcdHl4ezQ3NT/7Ffs1sR1yh/LRbdZ3B3Vc6q2WmD8
# mDC0p9kzl2o73iVtS946IkEj7FkRsZGww1teYxERROC745xrtjvcw9ZyyUjHZWGR
# IpJeMNsPquCDf0fkyHtB+J4AiNZqCQk23rxh+KbpyMTNVKItJ5l92Svl20U9NbqM
# BOVYl1h54NEYLJq1/xHWFKPNK903zJZA9P2DMYIGfzCCBnsCAQEwgaIwgZUxCzAJ
# BgNVBAYTAlVTMQswCQYDVQQIEwJNTjEUMBIGA1UEBxMLTWlubmVhcG9saXMxEjAQ
# BgNVBAoTCUx1Y2EgSG9tZTEPMA0GA1UECxMGT2ZmaWNlMRowGAYDVQQDExFMdWNh
# cyBDb2RlIFJTQSBDQTEiMCAGCSqGSIb3DQEJARYTZGFubHVjYUBjb21jYXN0Lm5l
# dAIIBtflh7Az5TYwDQYJYIZIAWUDBAIBBQCggYQwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFjAvBgkqhkiG9w0BCQQxIgQgdSocnIEyoN2uYPTCCvx0
# Ay/SEyYHzIbug8Rgq6eivk8wDQYJKoZIhvcNAQEBBQAEggIAQvvyRlzNFabzS9WW
# 1i9fVn8gqdqfYGQHOOiOxMTvUARI5wq3A6TKAbUJ4XcdBRw8XhGeLnYITQwcAKQn
# WBz444UAQ+d1cbG0gMfPY+anTlV5ka8oWtdXVbiu4zX6LUV+JqQzEA0XzrPdNl3r
# 7RBFUN//zQSeIrwtOPuZybSASo4gPvAZLbmCgNEbowBBzSd6xPnEzs0+b7es1OZp
# xOg3w7YxWhmCyDc7k3M51nTUwFB3gDxTI0QUT/kgC+oF+ZainmKpgf6nihKDJ5Mj
# JAIfy2cL3H4MEJIl5ODYANtJICooMArSsR/kHImuccblCPFuVVaanpfveDwl0Vj9
# CIjXVngtiTzd11YMn0pBNeXvFymYTkhzF6ijuzoo2YStuflmSURKH+G5VegoLeMB
# FD6Ry+G/H2OaJfaCZZEocpdb2+krfKE8vH7jS22QgqQrGIIt3AUbKiN+EbwQMyci
# LytzPjREH45GGxEyG4/GWgn0i9Eh+rxX3mUfEOmEXsHJb5qxFDYbORiW5l8D31RK
# 56iJzzUGnO9gvLflOGer9lDdK8TK7g8eLaC9m9cqHJqQUXT1DYtNx/ufp2su2e+s
# b/kBg28lGdawK+EjmtRy9KgUPIzACJcFvlfxIiT6NXSp28VxvkfOS1xE3F+0wDOd
# kziJOhKTiNbHdN77quROJVFcUNChggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8C
# AQEwfTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/
# BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYg
# U0hBMjU2IDIwMjUgQ0ExAhAIT9wzT35FTtvDD4/5khg1MA0GCWCGSAFlAwQCAQUA
# oGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYw
# OTA0MDM1NTA2WjAvBgkqhkiG9w0BCQQxIgQg4172nsvsdTjWvPk4gfA8HWMi9B0m
# lTe/xLSdI6RkvPkwDQYJKoZIhvcNAQEBBQAEggIAtlOJsAiHsfSNoSIroBVUM7n2
# FL9SuGdqoRZLpLsorT5yvZ7PDSTAKnMi4/w05/7UgLyKQAdoxagy11Hg1sSZ6syU
# i7Ho839n7UgEkB6UapuslhsSGtUiVL0tC0tRV44Bc29tQ4VpmS2Z2zt+4h6PhWH5
# lVMtO9RPF0RxY3yRMht1QthpHHme0rHVzQ6JDFsxmP5Rp0+XStUwnuvDFxQfuWV9
# fuWHPjnwLDlSWP0a3Ao/JTWvKnOCX297xZzqdCCjVYD39RYl7DdCgGhEbdsS9jAY
# VckYWkLnaWRn+mu3Eh6nq27jvr8+NTcFQoxM//o0VDrlR36NMMwrY15nSCxthGCp
# qiduQONjeVxVItjAPLqSD9DjvWmOAWLAeagdU2HS8w96q+oR1pfwPriO8VT6oee1
# FXaGyIfrEC9CzekFyxcLJ1k84NyBsjP3jiNMPs6eTahJ+rCzQp4RVTnDhOMbc1VW
# Hlhnvehiv7/is2r7rwy/mrrExC1tMebx6H2F9il5KSQAd7fBbUK5RejnqE2nQ8t3
# 5w8lklkcWt7+tEY8lEZalv4vnE7k8+KUhSp1/FBUC0JBJEyfS+bu47mL/IpXaFmB
# xPZV/kwq3mXuJnLCKtBhvx7IpgrqRY8mIxl5dQNKh8pVFi+98rYqc/XT6SQN1Giz
# cfi7vNdEPF5Yk0n6Fe8=
# SIG # End signature block
