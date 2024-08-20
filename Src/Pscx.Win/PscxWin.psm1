# -----------------------------------------------------------------------
# Desc: This is the PscxWin initialization module script. This module is 
# not meant to be used standalone, only as a companion module for PSCX 
# when running on Windows OS
# -----------------------------------------------------------------------
Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Resolves the hresult error code to a textual description of the error.
.DESCRIPTION
    Resolves the hresult error code to a textual description of the error.
.PARAMETER HResult
    The hresult error code to resolve.
.EXAMPLE
    C:\PS> Resolve-HResult -2147023293
    Fatal error during installation. (Exception from HRESULT: 0x80070643)
.NOTES
    Aliases:  rvhr
#>
function Resolve-HResult {
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [long[]]
        $HResult
    )

    Process {
        foreach ($hr in $HResult) {
            $comEx = [System.Runtime.InteropServices.Marshal]::GetExceptionForHR($hr)
            if ($comEx) {
                $comEx.Message
            }
            else {
                Write-Error "$hr doesn't correspond to a known HResult"
            }
        }
    }
}

<#
.SYNOPSIS
    Resolves a Windows error number a textual description of the error.
.DESCRIPTION
    Resolves a Windows error number a textual description of the error. The Windows
    error number is typically retrieved via the Win32 API GetLastError() but it is
    typically displayed in messages to the end user.
.PARAMETER ErrorNumber
    The Windows error code number to resolve.
.EXAMPLE
    C:\PS> Resolve-WindowsError 5
    Access is denied
.NOTES
    Aliases:  rvwer
#>
function Resolve-WindowsError {
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [int[]]
        $ErrorNumber
    )

    Process {
        foreach ($num in $ErrorNumber) {
            $win32Ex = new-object ComponentModel.Win32Exception $num
            if ($win32Ex) {
                $win32Ex.Message
            }
            else {
                Write-Error "$num does not correspond to a known Windows error code"
            }
        }
    }
}

<#
.SYNOPSIS
    Imports environment variables for the specified version of Visual Studio.
.DESCRIPTION
    Imports environment variables for the specified version of Visual Studio.
    This function requires the PowerShell Community Extensions. To find out
    the most recent set of Visual Studio environment variables imported use
    the cmdlet Get-EnvironmentBlock.  If you want to revert back to a previous
    Visul Studio environment variable configuration use the cmdlet
    Pop-EnvironmentBlock.
.PARAMETER VisualStudioVersion
    The version of Visual Studio to import environment variables for. Valid
    values are 2008, 2010, 2012, 2013, 2015, 2017 and 2019.
.PARAMETER Architecture
    Selects the desired architecture to configure the environment for.
    If this parameter isn't specified, the command will attempt to locate and
    use VsDevCmd.bat.  If VsDevCmd.bat can't be found (not installed) then the
    command will use vcvarsall.bat with either the argument x86 if running in
    32-bit PowerShell or amd64 if running in 64-bit PowerShell. Other valid
    values are: arm, x86_arm, x86_amd64, amd64_x86.
.PARAMETER RequireWorkload
    This parameter applies to Visual Studio 2017 and higher.  It allows you
    to specify which workloads are required for the environment you desire to
    import.  This can be used when you have multiple versions of Visual Studio
    2017 installed and different versions support different workloads e.g.
    perhaps only the "Preview" version supports the
    Microsoft.VisualStudio.Component.VC.Tools.x86.x64 workload.
.EXAMPLE
    C:\PS> Import-VisualStudioVars 2015

    Sets up the environment variables to use the VS 2015 tools. If
    VsDevCmd.bat is found then it will use that. Otherwise, vcvarsall.bat will
    be used with an architecture of either x86 for 32-bit Powershell, or amd64
    for 64-bit Powershell.
.EXAMPLE
    C:\PS> Import-VisualStudioVars 2013 arm

    Sets up the environment variables for the VS 2013 ARM tools.
.EXAMPLE
    C:\PS> Import-VisualStudioVars 2017 -Architecture amd64 -RequireWorkload Microsoft.VisualStudio.Component.VC.Tools.x86.x64

    Finds an instance of VS 2017 that has the required workload and sets up
    the environment variables to use that instance of the VS 2017 tools.
    To see a full list of available workloads, execute:
    Get-VSSetupInstance | Foreach-Object Packages | Foreach-Object Id | Sort-Object
#>
function Import-VisualStudioVars {
    param
    (
        [Parameter(Position = 0)]
        [ValidateSet('90','2008','100','2010','110','2012','120','2013','140','2015','150','2017','160','2019','170','2022')]
        [string]
        $VisualStudioVersion,

        [Parameter(Position = 1)]
        [string]
        $Architecture,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $RequireWorkload
    )

    begin {
        $ArchSpecified = $true
        if (!$Architecture) {
            $ArchSpecified = $false
            $Architecture = $(if ($Pscx:Is64BitProcess) {'amd64'} else {'x86'})
        }

        function GetSpecifiedVSSetupInstance($Version, [switch]$Latest, [switch]$FailOnMissingVSSetup) {
            if ($null -eq (Get-Module -Name VSSetup -ListAvailable)) {
                Write-Warning "You must install the VSSetup module to import Visual Studio variables for Visual Studio 2017 or higher."
                Write-Warning "Install the VSSetup module with the command: Install-Module VSSetup -Scope CurrentUser"

                if ($FailOnMissingVSSetup) {
                    throw "VSSetup module is not installed, unable to import Visual Studio 2017 (or higher) environment variables."
                }
                else {
                    # For the default (no VS version specified) case, we can look for earlier versions of VS.
                    return $null
                }
            }

            Import-Module VSSetup -ErrorAction Stop

            $selectArgs = @{
                Product = '*'
            }

            if ($Latest) {
                $selectArgs['Latest'] = $true
            }
            elseif ($Version) {
                $selectArgs['Version'] = $Version
            }

            if ($RequireWorkload -or $ArchSpecified) {
                if (!$RequireWorkload) {
                    # We get here when the architecture was specified but no worload, most likely these users want the C++ workload
                    $RequireWorkload = 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
                }

                $selectArgs['Require'] = $RequireWorkload
            }

            Write-Verbose "$($MyInvocation.MyCommand.Name) Select-VSSetupInstance args:"
            Write-Verbose "$(($selectArgs | Out-String) -split "`n")"
            $vsInstance = Get-VSSetupInstance | Select-VSSetupInstance @selectArgs | Select-Object -First 1
            $vsInstance
        }

        function FindAndLoadBatchFile($ComnTools, $ArchSpecified, [switch]$IsAppxInstall) {
            $batchFilePath = Join-Path $ComnTools VsDevCmd.bat
            if (!$ArchSpecified -and (Test-Path -LiteralPath $batchFilePath)) {
                if ($IsAppxInstall) {
                    # The newer batch files spit out a header that tells you which environment was loaded
                    # so only write out the below message when -Verbose is specified.
                    Write-Verbose "Invoking '$batchFilePath'"
                }
                else {
                    "Invoking '$batchFilePath'"
                }

                Invoke-BatchFile $batchFilePath
            }
            else {
                if ($IsAppxInstall) {
                    $batchFilePath = Join-Path $ComnTools ..\..\VC\Auxiliary\Build\vcvarsall.bat

                    # The newer batch files spit out a header that tells you which environment was loaded
                    # so only write out the below message when -Verbose is specified.
                    Write-Verbose "Invoking '$batchFilePath' $Architecture"
                }
                else {
                    $batchFilePath = Join-Path $ComnTools ..\..\VC\vcvarsall.bat
                    "Invoking '$batchFilePath' $Architecture"
                }

                Invoke-BatchFile $batchFilePath $Architecture
            }
        }
    }

    end {
        switch -regex ($VisualStudioVersion) {
            '90|2008' {
                Push-EnvironmentBlock -Description "Before importing VS 2008 $Architecture environment variables"
                Write-Verbose "Invoking ${env:VS90COMNTOOLS}..\..\VC\vcvarsall.bat $Architecture"
                Invoke-BatchFile "${env:VS90COMNTOOLS}..\..\VC\vcvarsall.bat" $Architecture
            }

            '100|2010' {
                Push-EnvironmentBlock -Description "Before importing VS 2010 $Architecture environment variables"
                Write-Verbose "Invoking ${env:VS100COMNTOOLS}..\..\VC\vcvarsall.bat $Architecture"
                Invoke-BatchFile "${env:VS100COMNTOOLS}..\..\VC\vcvarsall.bat" $Architecture
            }

            '110|2012' {
                Push-EnvironmentBlock -Description "Before importing VS 2012 $Architecture environment variables"
                FindAndLoadBatchFile $env:VS110COMNTOOLS $ArchSpecified
            }

            '120|2013' {
                Push-EnvironmentBlock -Description "Before importing VS 2013 $Architecture environment variables"
                FindAndLoadBatchFile $env:VS120COMNTOOLS $ArchSpecified
            }

            '140|2015' {
                Push-EnvironmentBlock -Description "Before importing VS 2015 $Architecture environment variables"
                FindAndLoadBatchFile $env:VS140COMNTOOLS $ArchSpecified
            }

            '150|2017' {
                $vsInstance = GetSpecifiedVSSetupInstance -Version '[15.0,16.0)' -FailOnMissingVSSetup
                if (!$vsInstance) {
                    throw "No instances of Visual Studio 2017 found$(if ($RequireWorkload) {" for the required workload: $RequireWorkload"})."
                }

                Push-EnvironmentBlock -Description "Before importing VS 2017 $Architecture environment variables"
                $installPath = $vsInstance.InstallationPath
                FindAndLoadBatchFile "$installPath/Common7/Tools" $ArchSpecified -IsAppxInstall
            }

            '160|2019' {
                $vsInstance = GetSpecifiedVSSetupInstance -Version '[16.0,17.0)' -FailOnMissingVSSetup
                if (!$vsInstance) {
                    throw "No instances of Visual Studio 2019 found$(if ($RequireWorkload) {" for the required workload: $RequireWorkload"})."
                }

                Push-EnvironmentBlock -Description "Before importing VS 2019 $Architecture environment variables"
                $installPath = $vsInstance.InstallationPath
                FindAndLoadBatchFile "$installPath/Common7/Tools" $ArchSpecified -IsAppxInstall
            }

            '170|2022' {
                $vsInstance = GetSpecifiedVSSetupInstance -Version '[17.0,18.0)' -FailOnMissingVSSetup
                if (!$vsInstance) {
                    throw "No instances of Visual Studio 2022 found$(if ($RequireWorkload) {" for the required workload: $RequireWorkload"})."
                }

                Push-EnvironmentBlock -Description "Before importing VS 2022 $Architecture environment variables"
                $installPath = $vsInstance.InstallationPath
                FindAndLoadBatchFile "$installPath/Common7/Tools" $ArchSpecified -IsAppxInstall
            }

            default {
                $vsInstance = GetSpecifiedVSSetupInstance -Latest
                if ($vsInstance) {
                    Push-EnvironmentBlock -Description "Before importing $($vsInstance.DisplayName) $Architecture environment variables"
                    $installPath = $vsInstance.InstallationPath
                    FindAndLoadBatchFile "$installPath/Common7/Tools" $ArchSpecified -IsAppxInstall
                }
                else {
                    $envvar = @(Get-Item Env:\vs*comntools | Sort-Object { $_.Name -replace '(?<=VS)(\d)(0)','0$1$2'} -Descending)[0]
                    if (!$envvar) {
                        throw "No versions of Visual Studio found."
                    }

                    Push-EnvironmentBlock -Description "Before importing $($envvar.Name) $Architecture environment variables"
                    FindAndLoadBatchFile ($envvar.Value) $ArchSpecified
                }
            }
        }
    }
}


# set the 7zip library path
[SevenZip.SevenZipBase]::SetLibraryPath([System.IO.Path]::Join([Pscx.Core.PscxContext]::Instance.AppsDir, "7z.dll"))

# aliases
Set-Alias rvhr  Pscx\Resolve-HResult        -Description "PSCX alias"
Set-Alias rvwer Pscx\Resolve-WindowsError   -Description "PSCX alias"
Set-Alias ln    Pscx\New-HardLink           -Description "PSCX alias"


# -----------------------------------------------------------------------
# Cmdlet aliases
# -----------------------------------------------------------------------

Export-ModuleMember -Alias * -Function * -Cmdlet *
# SIG # Begin signature block
# MIInYwYJKoZIhvcNAQcCoIInVDCCJ1ACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCWM75PzQhJKAXT
# ynoHgHNOpXDne+hf2YhzLZImF0LywKCCIEAwggWNMIIEdaADAgECAhAOmxiO+dAt
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
# EebBYhHzbPbXhSUfdKFro6bVrzSp+a3MY+E0GlDUeLf6rjCCBq4wggSWoAMCAQIC
# EAc2N7ckVHzYR6z9KGYqXlswDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMx
# FTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNv
# bTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTIyMDMyMzAw
# MDAwMFoXDTM3MDMyMjIzNTk1OVowYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRp
# Z2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQw
# OTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIP
# ADCCAgoCggIBAMaGNQZJs8E9cklRVcclA8TykTepl1Gh1tKD0Z5Mom2gsMyD+Vr2
# EaFEFUJfpIjzaPp985yJC3+dH54PMx9QEwsmc5Zt+FeoAn39Q7SE2hHxc7Gz7iuA
# hIoiGN/r2j3EF3+rGSs+QtxnjupRPfDWVtTnKC3r07G1decfBmWNlCnT2exp39mQ
# h0YAe9tEQYncfGpXevA3eZ9drMvohGS0UvJ2R/dhgxndX7RUCyFobjchu0CsX7Le
# Sn3O9TkSZ+8OpWNs5KbFHc02DVzV5huowWR0QKfAcsW6Th+xtVhNef7Xj3OTrCw5
# 4qVI1vCwMROpVymWJy71h6aPTnYVVSZwmCZ/oBpHIEPjQ2OAe3VuJyWQmDo4EbP2
# 9p7mO1vsgd4iFNmCKseSv6De4z6ic/rnH1pslPJSlRErWHRAKKtzQ87fSqEcazjF
# KfPKqpZzQmiftkaznTqj1QPgv/CiPMpC3BhIfxQ0z9JMq++bPf4OuGQq+nUoJEHt
# Qr8FnGZJUlD0UfM2SU2LINIsVzV5K6jzRWC8I41Y99xh3pP+OcD5sjClTNfpmEpY
# PtMDiP6zj9NeS3YSUZPJjAw7W4oiqMEmCPkUEBIDfV8ju2TjY+Cm4T72wnSyPx4J
# duyrXUZ14mCjWAkBKAAOhFTuzuldyF4wEr1GnrXTdrnSDmuZDNIztM2xAgMBAAGj
# ggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBS6FtltTYUvcyl2
# mi91jGogj57IbzAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qYrhwPTzAOBgNV
# HQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEEazBp
# MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYIKwYBBQUH
# MAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRS
# b290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZMBcwCAYGZ4EM
# AQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAfVmOwJO2b5ipRCIB
# fmbW2CFC4bAYLhBNE88wU86/GPvHUF3iSyn7cIoNqilp/GnBzx0H6T5gyNgL5Vxb
# 122H+oQgJTQxZ822EpZvxFBMYh0MCIKoFr2pVs8Vc40BIiXOlWk/R3f7cnQU1/+r
# T4osequFzUNf7WC2qk+RZp4snuCKrOX9jLxkJodskr2dfNBwCnzvqLx1T7pa96kQ
# sl3p/yhUifDVinF2ZdrM8HKjI/rAJ4JErpknG6skHibBt94q6/aesXmZgaNWhqsK
# RcnfxI2g55j7+6adcq/Ex8HBanHZxhOACcS2n82HhyS7T6NJuXdmkfFynOlLAlKn
# N36TU6w7HQhJD5TNOXrd/yVjmScsPT9rp/Fmw0HNT7ZAmyEhQNC3EyTN3B14OuSe
# reU0cZLXJmvkOHOrpgFPvT87eK1MrfvElXvtCl8zOYdBeHo46Zzh3SP9HSjTx/no
# 8Zhf+yvYfvJGnXUsHicsJttvFXseGYs2uJPU5vIXmVnKcPA3v5gA3yAWTyf7YGcW
# oWa63VXAOimGsJigK+2VQbc61RWYMbRiCQ8KvYHZE/6/pNHzV9m8BPqC3jLfBInw
# AM1dwvnQI38AC+R2AibZ8GV2QqYphwlHK+Z/GqSFD/yYlvZVVCsfgPrA8g4r5db7
# qS9EFUrnEw4d2zc4GqEr9u3WfPwwggbCMIIEqqADAgECAhAFRK/zlJ0IOaa/2z9f
# 5WEWMA0GCSqGSIb3DQEBCwUAMGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdp
# Q2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2
# IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwHhcNMjMwNzE0MDAwMDAwWhcNMzQxMDEz
# MjM1OTU5WjBIMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4x
# IDAeBgNVBAMTF0RpZ2lDZXJ0IFRpbWVzdGFtcCAyMDIzMIICIjANBgkqhkiG9w0B
# AQEFAAOCAg8AMIICCgKCAgEAo1NFhx2DjlusPlSzI+DPn9fl0uddoQ4J3C9Io5d6
# OyqcZ9xiFVjBqZMRp82qsmrdECmKHmJjadNYnDVxvzqX65RQjxwg6seaOy+WZuNp
# 52n+W8PWKyAcwZeUtKVQgfLPywemMGjKg0La/H8JJJSkghraarrYO8pd3hkYhftF
# 6g1hbJ3+cV7EBpo88MUueQ8bZlLjyNY+X9pD04T10Mf2SC1eRXWWdf7dEKEbg8G4
# 5lKVtUfXeCk5a+B4WZfjRCtK1ZXO7wgX6oJkTf8j48qG7rSkIWRw69XloNpjsy7p
# Be6q9iT1HbybHLK3X9/w7nZ9MZllR1WdSiQvrCuXvp/k/XtzPjLuUjT71Lvr1KAs
# NJvj3m5kGQc3AZEPHLVRzapMZoOIaGK7vEEbeBlt5NkP4FhB+9ixLOFRr7StFQYU
# 6mIIE9NpHnxkTZ0P387RXoyqq1AVybPKvNfEO2hEo6U7Qv1zfe7dCv95NBB+plwK
# WEwAPoVpdceDZNZ1zY8SdlalJPrXxGshuugfNJgvOuprAbD3+yqG7HtSOKmYCaFx
# smxxrz64b5bV4RAT/mFHCoz+8LbH1cfebCTwv0KCyqBxPZySkwS0aXAnDU+3tTbR
# yV8IpHCj7ArxES5k4MsiK8rxKBMhSVF+BmbTO77665E42FEHypS34lCh8zrTioPL
# QHsCAwEAAaOCAYswggGHMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYG
# A1UdJQEB/wQMMAoGCCsGAQUFBwMIMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCG
# SAGG/WwHATAfBgNVHSMEGDAWgBS6FtltTYUvcyl2mi91jGogj57IbzAdBgNVHQ4E
# FgQUpbbvE+fvzdBkodVWqWUxo97V40kwWgYDVR0fBFMwUTBPoE2gS4ZJaHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNIQTI1
# NlRpbWVTdGFtcGluZ0NBLmNybDCBkAYIKwYBBQUHAQEEgYMwgYAwJAYIKwYBBQUH
# MAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBYBggrBgEFBQcwAoZMaHR0cDov
# L2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNI
# QTI1NlRpbWVTdGFtcGluZ0NBLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAgRrW3qCp
# tZgXvHCNT4o8aJzYJf/LLOTN6l0ikuyMIgKpuM+AqNnn48XtJoKKcS8Y3U623mzX
# 4WCcK+3tPUiOuGu6fF29wmE3aEl3o+uQqhLXJ4Xzjh6S2sJAOJ9dyKAuJXglnSoF
# eoQpmLZXeY/bJlYrsPOnvTcM2Jh2T1a5UsK2nTipgedtQVyMadG5K8TGe8+c+nji
# kxp2oml101DkRBK+IA2eqUTQ+OVJdwhaIcW0z5iVGlS6ubzBaRm6zxbygzc0brBB
# Jt3eWpdPM43UjXd9dUWhpVgmagNF3tlQtVCMr1a9TMXhRsUo063nQwBw3syYnhmJ
# A+rUkTfvTVLzyWAhxFZH7doRS4wyw4jmWOK22z75X7BC1o/jF5HRqsBV44a/rCcs
# QdCaM0qoNtS5cpZ+l3k4SF/Kwtw9Mt911jZnWon49qfH5U81PAC9vpwqbHkB3NpE
# 5jreODsHXjlY9HxzMVWggBHLFAx+rrz+pOt5Zapo1iLKO+uagjVXKBbLafIymrLS
# 2Dq4sUaGa7oX/cR3bBVsrquvczroSUa31X/MtjjA2Owc9bahuEMs305MfR5ocMB3
# CtQC4Fxguyj/OOVSWtasFyIjTvTs0xf7UGv/B3cfcZdEQcm4RtNsMnxYL2dHZeUb
# c7aZ+WssBkbvQR7w8F/g29mtkIBEr4AQQYoxggZ5MIIGdQIBATCBojCBlTELMAkG
# A1UEBhMCVVMxCzAJBgNVBAgTAk1OMRQwEgYDVQQHEwtNaW5uZWFwb2xpczESMBAG
# A1UEChMJTHVjYSBIb21lMQ8wDQYDVQQLEwZPZmZpY2UxGjAYBgNVBAMTEUx1Y2Fz
# IENvZGUgUlNBIENBMSIwIAYJKoZIhvcNAQkBFhNkYW5sdWNhQGNvbWNhc3QubmV0
# AggG1+WHsDPlNjANBglghkgBZQMEAgEFAKCBhDAYBgorBgEEAYI3AgEMMQowCKAC
# gAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsx
# DjAMBgorBgEEAYI3AgEWMC8GCSqGSIb3DQEJBDEiBCAJtP3O9tpMGM26af1JxbQV
# p6HwElMYq1XXMHXqnJd5CjANBgkqhkiG9w0BAQEFAASCAgCy8l/cHdfruWg6f+7l
# xgyZ+krr1gdzMDUWKHXpJ7cFPVFQXHS8MF4gsKUepmz9GALcU5i2SaAVcezJKKNK
# uxXs1CxxrZBw6k/kEw74s1SVBBOIWzlwjaju+8h3KvhKxa6fSSUanoALvHvKy7KN
# x3S9egCfX/Eop8qLzEh3SA6Q0p2L7T9xxrlXjDb5FVdZ93slS+YJclCKA1sc9XGw
# rb3kgwrFoaD6o8S8mnsNqg30/i2CZzyUFjzDMV5BmrRGnfGFchGggS7MAjITPmYN
# //ZUBMtJCmHLmd+Ofs3V4gSOHB3dDepDVtfGg69UQezrc2a5y+HJ6xAYuW4cqwsR
# +dKvjLduGsHVYPMhiD7fm3+zROpBlDV1wQ8VZJ02OiTxOtm55fV6fMWyh4iOk7cR
# kb9ypzrHVSrNPrNhHeGkE4XdrW/4FDk2kMjOliGUp4n52KBk4jvnqeqSyjw5nV7s
# Ia634V+xH5CZ4bF2gnAnzC0zp6qyHOPS53grhxeAT0stK7LsleLGNDmHKQy8bNEH
# eswrxGlzP7PJIjfyaynWVKSU1esp2Oe8hk7J/387gPAXrQeKJOrlZKL70XvtZyjZ
# Au4BWJ34PRmwghSbCQMCjCdh2upXN0RCkbGCaVNZmPhEUVhfJqoBaN4zhxWoQJhD
# k9+lrXZVkzX/8YJbAc/w7LtFa6GCAyAwggMcBgkqhkiG9w0BCQYxggMNMIIDCQIB
# ATB3MGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkG
# A1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3Rh
# bXBpbmcgQ0ECEAVEr/OUnQg5pr/bP1/lYRYwDQYJYIZIAWUDBAIBBQCgaTAYBgkq
# hkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yNDA4MjAwMDU3
# NDlaMC8GCSqGSIb3DQEJBDEiBCBOG73dDe3k6Ov9BVkWJ0pghW9fO5GmCV1RZak7
# EQ+vHDANBgkqhkiG9w0BAQEFAASCAgA6bNiK0H+JLgu9YEJeS/KZFc2cwcgVCfmG
# JBdRiyO2EYueJnbNYIUtMXxTF+/nLiPTZCRy6sH+ubGJJpcKTfzO0nsNPKpH2ADH
# tzr5HVhwLfkc7bF3kyB71nN+RpyK8XiW0vj8Jt2eisqluWTr7T8ndG72XPabtyAs
# DYnc36ypuzrXEi1wTo4fVAbMkXgFdoWiNRjRQM5wbTt71cwxSi1vomJ7af4fnbEG
# WO1Tb5mtTqmpWByyOtMKm3JTyPg37LNDlRqKmXD5gMDPrMdtwfePHNHaS9yCAt+g
# aQfu5wP2VX0Z2p5v2TGE+iWBvZq5lgNq7CTgBMERdBsnbu+aXQ03Q4ZMd9VmOTMH
# IJOQor3TnkQb+PIYwNb6ohGCIcTWPMXCEBlLQMyNiyFnclGfFtYlfg2/4rwT8aNp
# QUmbeZnajM7dv3yEqZbb7i4X/dpUAoIe5cMh3mpqa1/2ufzL/dwqQaaie0uO2zfx
# PoV8oX5bV+DlCbnO2FWgTooWPzHitIiMBi/uhUVD0PVpdy9k/+qLKk6mDlfKS4BJ
# r219rLAYcwpijEQmeA1lYpkEd/gUY+URv6fBpKX1/OMnn2d8zFFuA53YNr7TwQ39
# DMN3wUEOyOE/1+DZ0EOAeonLVWD+QvzEARSE6eCeNc0ToECwg1h2ShZKFpgYul1I
# FQFW1y5CPQ==
# SIG # End signature block
