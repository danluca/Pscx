# Set $gsudoVerbose=$false before importing this module to remove the verbose messages.
if ($null -eq $gsudoVerbose) { $gsudoVerbose = $true; }
# Set $gsudoVerbose=$false before importing this module to remove the gsudo auto-complete functionality.
if ($null -eq $gsudoAutoComplete) { $gsudoAutoComplete = $true; }

$c = @("function Invoke-Gsudo {")
$c += (Get-Content "$PSScriptRoot\Invoke-Gsudo.ps1")
$c += "}"
iex ($c -join "`n" | Out-String)

function gsudo {
    <#
.SYNOPSIS
gsudo is a sudo for windows. It allows to run a command/ScriptBlock with elevated permissions. If no command is specified, it starts an elevated Powershell session.
.DESCRIPTION
# Syntax:
gsudo [options] { ScriptBlock } [ScriptBlock arguments]

gsudo [-n|--new]             # Run command in a new window and dont wait until command exits
      [-w|--wait]            # If --new is specified it wait until it exits.
      [-d 'CMD command']     # To elevate a Win32 CMD command instead of a Powershell script
      [--integrity {i}]      # Run with integrity level [Low, Medium, High, System]
      [-s]                   # Run as `NT AUTHORITY\System` 
      [--ti]                 # Run as Trusted Installer
      [-u|--user {username}] # Run as specific user (prompts for password)
      [--loadProfile]        # Loads the user profile on the elevated Powershell instance before running {ScriptBlock}
      { ScriptBlock }        # Script to elevate
      [-args $argument1[..., $argumentN]] ; # Pass arguments to the ScriptBlock, available as $args[0], $args[1]...

The command to elevate will run in a different process, so it can't access the parent $variables and scope.

More details about gsudo can be found by running: gsudo -h

.EXAMPLE
gsudo { Get-Process }
This run the `Get-Process` command as an administrator.

.EXAMPLE
gsudo { Get-Process $args[0] } -args "WinLogon"
Example case passing parameters to the ScriptBlock.

.INPUTS
You can pipe an input object and will be received as $input in the elevated ScriptBlock.

"WinLogon" | gsudo.exe { Get-Process $input }

.OUTPUTS
The output is determined by the command that is run with gsudo.

.LINK
https://github.com/gerardog/gsudo
#>

    # Note: gsudo is a windows application. 
    # This wrapper only serves the purpose of:
    #  - Adding support for `gsudo !!` on Powershell
    #  - Adding support for `Get-Help gsudo`

    $invocationLine = $MyInvocation.Line -replace "^$($MyInvocation.InvocationName)\s+" # -replace '"','""'

    if ($invocationLine -match "(^| )!!( |$)") { 
        $i = 0;
        do {
            $c = (Get-History | Select-Object -last 1 -skip $i).CommandLine
            $i++;
        } while ($c -eq $MyInvocation.Line -and $c)
        
        if ($c) { 
            if ($gsudoVerbose) { Write-verbose "Elevating Command: '$c'" -Verbose }
            gsudo.exe $c 
        }
        else {
            throw "Failed to find last invoked command in Powershell history."
        }
    }
    elseif ($myinvocation.expectingInput) {
        $input | & gsudo.exe @args 
    } 
    else { 
        & gsudo.exe @args 
    }
}

function Test-IsGsudoCacheAvailable {
    <#
.SYNOPSIS
Tests whether the gsudo credentials cache is available.
.EXAMPLE
Test-IsGsudoCacheAvailable
Returns true when gsudo reports that its credentials cache is available.
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return ('true' -eq (gsudo status CacheAvailable))
}

function Test-IsProcessElevated {
    <#
.Synopsis
    Tests if the user is an administrator *and* the current proces is elevated.
.Description
    Returns true if the current process is elevated.
.Example
    Test-IsProcessElevated
    Returns true when the current process is elevated.
#>	
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($PSVersionTable.Platform -eq 'Unix') {
        return (id -u) -eq 0
    }
    else {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal $identity
        return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    }
}

function Test-IsAdminMember {
    <#
.SYNOPSIS
The function Test-IsAdminMember checks if the currently logged-in user is a member of the local administrators group, regardless of the elevation level of the current process.
.EXAMPLE
Test-IsAdminMember
Returns true when the current user belongs to the local Administrators group.
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $adminGroupSid = "S-1-5-32-544"
    $localAdminGroup = Get-LocalGroup -SID $adminGroupSid
    $isAdmin = (Get-LocalGroupMember -Group $localAdminGroup.Name).Where({ $_.Name -eq $userName }).Count -gt 0
    return $isAdmin
}

Function gsudoPrompt {
    $eol = If (Test-IsProcessElevated) { "$([char]27)[1;31m" + ('#') * ($nestedPromptLevel + 1) + "$([char]27)[0m" } else { '>' * ($nestedPromptLevel + 1) };
    "PS $($executionContext.SessionState.Path.CurrentLocation)$eol ";
}

if ($gsudoAutoComplete) {
    #Create an auto-completer for gsudo.

    $verbs = @('status', 'cache', 'config', 'help', '!!')
    $options = @('-d', '--loadProfile', '--system', '--ti', '-k', '--new', '--wait', '--keepShell', '--keepWindow', '--help', '--debug', '--copyNS', '--integrity', '--user')

    $integrityOptions = @("Low", "Medium", "MediumPlus", "High", "System")
    $TrueFalseReset = @('true', 'false', '--reset')

    $suggestions = @{ 
        '--integrity'                 = $integrityOptions;
        '-i'                          = $integrityOptions;
        'cache'                       = @('on', 'off', 'help');
        'config'                      = @('--reset-all', 'CacheMode', 'CacheDuration', 'LogLevel', 'NewWindow.Force', 'NewWindow.CloseBehaviour', 'Prompt', 'PipedPrompt', 'PathPrecedence', 'ForceAttachedConsole', 'ForcePipedConsole', 'ForceVTConsole', 'CopyEnvironmentVariables', 'CopyNetworkShares', 'PowerShellLoadProfile', 'SecurityEnforceUacIsolation', 'ExceptionList');
        'cachemode'                   = @('Auto', 'Disabled', 'Explicit', '--reset');
        'loglevel'                    = @('All', 'Debug', 'Info', 'Warning', 'Error', 'None', '--reset');
        'NewWindow.CloseBehaviour'    = @('KeepShellOpen', 'PressKeyToClose', 'OsDefault', '--reset');
        'NewWindow.Force'             = $TrueFalseReset;
        'ForceAttachedConsole'        = $TrueFalseReset;
        'ForcePipedConsole'           = $TrueFalseReset;
        'ForceVTConsole'              = $TrueFalseReset;
        'CopyEnvironmentVariables'    = $TrueFalseReset;
        'CopyNetworkShares'           = $TrueFalseReset;
        'PowerShellLoadProfile'       = $TrueFalseReset;
        'SecurityEnforceUacIsolation' = $TrueFalseReset;
        'PathPrecedence'              = $TrueFalseReset;		
		'Status'                      = @('--json', 'CallerPi 	d', 'UserName', 'UserSid', 'IsElevated', 'IsAdminMember', 'IntegrityLevelNumeric', 'IntegrityLevel', 'CacheMode', 'CacheAvailable', 'CacheSessionsCount', 'CacheSessions', 'IsRedirected', '--no-output')
        '--user'                      = @("$env:USERDOMAIN\$env:USERNAME");
        '-u'                          = @("$env:USERDOMAIN\$env:USERNAME")
    }

    $autoCompleter = {
        param($wordToComplete, $commandAst, $cursorPosition)
    
        # gsudo powershell syntax is:
        # gsudo [gsudo options] [optional-gsudo-verb] [gsudo-verb-options | command-to-elevate] [commant-to-elevate-args]
        
        # Will use $phase variable to signal which part of the command is being auto-completed.
        # Phase 1 means autocomplete for [options]
        # Phase 2 means autocomplete for [gsudo-verb]
        # Phase 3 means autocomplete for [verb-options]
        # Phase 4 means [command] is already written.

        $commands = $commandAst.ToString().Substring(0, $cursorPosition - 1).Split(' ') | select -Skip 1;
        if ($wordToComplete) {
            $lastWord = ($commands | select -Last 1 -skip 1)
        }
        else {
            $lastWord = ($commands | select -Last 1)
        }

<# Debugging aids
        # Save the current cursor position
        $originalX = $host.ui.RawUI.CursorPosition.X
        $originalY = $host.ui.RawUI.CursorPosition.Y
        
        # Set the cursor position to (0,0)
        $host.ui.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 0, 0
        
        Write-Debug -Debug "wordToComplete = ""$wordToComplete""         "
        Write-Debug -Debug "commandAst = ""$commandAst""         "
        Write-Debug -Debug "cursorPosition = ""$cursorPosition""         "
        Write-Debug -Debug "commands = ""$commands""     ";
        Write-Debug -Debug "lastWord = ""$lastWord""     ";
#>    
        $phase = 1;
    
        foreach ($c in $commands) {
            if ($phase -le 2) {
                if ($verbs -contains $c) { $phase = 3 }
                if ($c -like '{*') { $phase = 4 }
            }
        }

        $filter = "$wordToComplete*"
    
        if ($lastWord -and $suggestions[$lastWord]) {
            $suggestions[$lastWord] -like $filter | % { $_ }
        }
        else {
            if ($phase -lt 3) { 
                if ($wordToComplete -eq '') {
                    # Suggest last 3 executed commands.
                    $lastCommands = Get-History | Select-Object -last 3 | % { "{ $($_.CommandLine) }" }
                
                    if ($lastCommands -is [System.Array]) {
                        # Last one first.
                        $lastCommands[($lastCommands.Length - 1)..0] | % { $_ };
                    }
                    elseif ($lastCommands) {
                        # Only one command.
                        $lastCommands;
                    }
                }
            }
            if ($phase -le 2) { $verbs -like $filter; }	
            if ($phase -le 1) { $options -like $filter; }
            if ($phase -ge 4) { '-args' }

        }
<# Debugging aids
        Write-Debug -Debug "----";

        # Return the cursor position to its original location
        $host.ui.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $originalX, $originalY 
#>
    }

    Register-ArgumentCompleter -Native -CommandName 'gsudo' -ScriptBlock $autoCompleter
    Register-ArgumentCompleter -Native -CommandName 'sudo' -ScriptBlock $autoCompleter
}

Export-ModuleMember -function Invoke-Gsudo, gsudo, Test-IsGsudoCacheAvailable, Test-IsProcessElevated, Test-IsAdminMember, gsudoPrompt -Variable gsudoVerbose, gsudoAutoComplete



# SIG # Begin signature block
# MIInmgYJKoZIhvcNAQcCoIInizCCJ4cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDyHUfWchYInU6x
# 5Xn7G48z2pPKOALPA97X8ZiaQ2/xAKCCIHEwggWNMIIEdaADAgECAhAOmxiO+dAt
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
# MQ4wDAYKKwYBBAGCNwIBFjAvBgkqhkiG9w0BCQQxIgQgvTW5kd/OpYPMyGio1tY8
# IcFjvLkPgmz8fPHWmoVU7GkwDQYJKoZIhvcNAQEBBQAEggIAi+Sy8B9ELIVLrHEn
# m4HxBocWDl24/+nPZXHmDekHGczQK8FqsiAI0Opvnj6LONkRShmkMBb7wu4C1Xre
# AFFs35do6oq+O5STprIKkBADJJNQzvxqQiDWdOsCoaEFVh8jlw+QllYOXIfe/a0B
# N/4k7ZtpNbIsh/Bp8CPBLqc0nPgRj2NUDnbYtWdMBA+oIk8MySe3cW614hOsll/O
# cln+mdsxREGMT03WQEw9jTWPlh9lIdu8idOC3v/tDAZkqWQU+5cKvfNxfhYEs4rm
# rLFs3ZEWZt9fNh1lsxlPbry85yUI1sD9mqfbxSY0PCATGvcitpCJIBxBU/L6kj8k
# O21w8g2g3g8G9gaeOHSCw4B1sLdazO9GMm3I7aC+dOTQtumzKpLobMa/lRkY0vlY
# txzIP9CHET5HPfQXiaO/BfVFXinCtnmAevvcDExcAJTiLUjSZFsXhxqmzlnMs7RK
# c+YVyAVeaHmqAEB7NJcofEygmXvgHwp/Pdo8tRpCG6YplKqG2cXXwNELOmV6FDeB
# PKIkjFaYVJnG/BVrGqG4rNSipvjTg4ZMPLxNCYrsqH0fz86CO2eYXSjxVbdOhdBz
# nsqbepTGL6jSxbqa6c9Dgpf5ODr2Pergh1cHYK8LBtv92XGzh+4kaZ5pJ1e9t3GG
# YPuaHkinbXqxPPRY1kU1NWeeDPihggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8C
# AQEwfTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/
# BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYg
# U0hBMjU2IDIwMjUgQ0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUA
# oGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYw
# ODMxMTY0MTAwWjAvBgkqhkiG9w0BCQQxIgQgrEjcFsSZ3Iq6b3OmZJvE17TYn2/6
# qavGn/9YNpfDE5swDQYJKoZIhvcNAQEBBQAEggIAJ8Q0oJP8hkf09prEqUI08FXS
# wENOMbcm6sXAEY5qzY0qUZfgO19src8NRM8TYSUfbjh6uV7j2MEO7w6wAtN2a6ou
# uLqyiMKn4usswOLp2FJonk9w/6dFmuEDuwA7VfHcUwqoESEIWSB5FdsEUaFj3+sa
# ++8DRstZ79uLiRQHbgT007pL9S//4NEszXUuwqElOkt800xI1/xlxfwCAzLLsNbP
# CwwMPbRUo+6Cznrfa/EHoo2hCGNqiG8qVODnPxcr6AWKGlRIedVDXPv8P887dTI8
# iLg/S/7reRfqhcLzorGL4nIfApPBevdF2c+AmDCkWQe/UlE3m1tue1myJaD6dslq
# O5XTm34JWVd/baVd23w9fGklUTv6+2npUk/QNoO0QJNse8gfSLFuT+l1jUB7M+m8
# 1YX53cim/NliHTIvWndq38KbUq1z2snqSHp+L+fFPoZWgem5aAnRI6brgjz1MJEa
# mX6ttG7KCARbn1XybDHOqt8rj2XYRghknB4NGtQzxQ54DMbnogPCQSqZkahxWkAc
# KA7d+5AEkg51Q5+0VVZu15vJEYJ/XsuaqZV6p3NQJikWTG8S+jA56sY+PUNUUpt/
# MzzT3JOk0tza0oIhV140dgqIh+NQKXjQ6O0tXKbXcy2I4u62XhIDfdnghe3EGTtP
# jETbvEe4qZFQ4NFxGDM=
# SIG # End signature block
