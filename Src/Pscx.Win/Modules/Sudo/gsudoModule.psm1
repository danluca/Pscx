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
    return ('true' -eq (gsudo status CacheAvailable))
}

function Test-IsProcessElevated {
    <#
.Synopsis
    Tests if the user is an administrator *and* the current proces is elevated.
.Description
    Returns true if the current process is elevated.
.Example
    Test-IsAdmin
#>	
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
#>
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
# MIImXQYJKoZIhvcNAQcCoIImTjCCJkoCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBvKDMtESUKQX/+
# MBoOlyXC9k0D1Y1WPC5TaPlOw864fqCCH30wggWNMIIEdaADAgECAhAOmxiO+dAt
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
# twGpn1eqXijiuZQwggYaMIIEAqADAgECAhBiHW0MUgGeO5B5FSCJIRwKMA0GCSqG
# SIb3DQEBDAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0
# ZWQxLTArBgNVBAMTJFNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBSb290IFI0
# NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5NTlaMFQxCzAJBgNVBAYTAkdC
# MRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMTIlNlY3RpZ28gUHVi
# bGljIENvZGUgU2lnbmluZyBDQSBSMzYwggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAw
# ggGKAoIBgQCbK51T+jU/jmAGQ2rAz/V/9shTUxjIztNsfvxYB5UXeWUzCxEeAEZG
# bEN4QMgCsJLZUKhWThj/yPqy0iSZhXkZ6Pg2A2NVDgFigOMYzB2OKhdqfWGVoYW3
# haT29PSTahYkwmMv0b/83nbeECbiMXhSOtbam+/36F09fy1tsB8je/RV0mIk8XL/
# tfCK6cPuYHE215wzrK0h1SWHTxPbPuYkRdkP05ZwmRmTnAO5/arnY83jeNzhP06S
# hdnRqtZlV59+8yv+KIhE5ILMqgOZYAENHNX9SJDm+qxp4VqpB3MV/h53yl41aHU5
# pledi9lCBbH9JeIkNFICiVHNkRmq4TpxtwfvjsUedyz8rNyfQJy/aOs5b4s+ac7I
# H60B+Ja7TVM+EKv1WuTGwcLmoU3FpOFMbmPj8pz44MPZ1f9+YEQIQty/NQd/2yGg
# W+ufflcZ/ZE9o1M7a5Jnqf2i2/uMSWymR8r2oQBMdlyh2n5HirY4jKnFH/9gRvd+
# QOfdRrJZb1sCAwEAAaOCAWQwggFgMB8GA1UdIwQYMBaAFDLrkpr/NZZILyhAQnAg
# NpFcF4XmMB0GA1UdDgQWBBQPKssghyi47G9IritUpimqF6TNDDAOBgNVHQ8BAf8E
# BAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDAzAb
# BgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEsGA1UdHwREMEIwQKA+oDyGOmh0
# dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nUm9v
# dFI0Ni5jcmwwewYIKwYBBQUHAQEEbzBtMEYGCCsGAQUFBzAChjpodHRwOi8vY3J0
# LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ1Jvb3RSNDYucDdj
# MCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0B
# AQwFAAOCAgEABv+C4XdjNm57oRUgmxP/BP6YdURhw1aVcdGRP4Wh60BAscjW4HL9
# hcpkOTz5jUug2oeunbYAowbFC2AKK+cMcXIBD0ZdOaWTsyNyBBsMLHqafvIhrCym
# laS98+QpoBCyKppP0OcxYEdU0hpsaqBBIZOtBajjcw5+w/KeFvPYfLF/ldYpmlG+
# vd0xqlqd099iChnyIMvY5HexjO2AmtsbpVn0OhNcWbWDRF/3sBp6fWXhz7DcML4i
# TAWS+MVXeNLj1lJziVKEoroGs9Mlizg0bUMbOalOhOfCipnx8CaLZeVme5yELg09
# Jlo8BMe80jO37PU8ejfkP9/uPak7VLwELKxAMcJszkyeiaerlphwoKx1uHRzNyE6
# bxuSKcutisqmKL5OTunAvtONEoteSiabkPVSZ2z76mKnzAfZxCl/3dq3dUNw4rg3
# sTCggkHSRqTqlLMS7gjrhTqBmzu1L90Y1KWN/Y5JKdGvspbOrTfOXyXvmPL6E52z
# 1NZJ6ctuMFBQZH3pwWvqURR8AgQdULUvrxjUYbHHj95Ejza63zdrEcxWLDX6xWls
# /GDnVNueKjWUH3fTv1Y8Wdho698YADR7TNx8X8z2Bev6SivBBOHY+uqiirZtg0y9
# ShQoPzmCcn63Syatatvx157YK9hlcPmVoa1oDE5/L9Uo2bC5a4CH2RwwggZYMIIE
# wKADAgECAhEA1hBezo41z3AItTU5kYK/yTANBgkqhkiG9w0BAQwFADBUMQswCQYD
# VQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0
# aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2MB4XDTIyMTEyMTAwMDAwMFoX
# DTI1MTEyMDIzNTk1OVowbjELMAkGA1UEBhMCQVIxKTAnBgNVBAgMIENpdWRhZCBB
# dXTDs25vbWEgZGUgQnVlbm9zIEFpcmVzMRkwFwYDVQQKDBBHZXJhcmRvIEdyaWdu
# b2xpMRkwFwYDVQQDDBBHZXJhcmRvIEdyaWdub2xpMIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEAt/W5DVIya5ejfBByJc33Y7MWCBQnisri6c5ybt81lPUP
# g3i8jfaOg6YOOFvmhRDgM49sTXWK3rkjRHrCnWKVKDb8i2hiU6dHc4Ra7nosi5ip
# mhJgvhJVLzWxTxEyrjixBIpUm6XKPCArWrancVAWotCi6kyB/+RL0OLlXzQdkx8a
# 4/9Ub27WEvbn6u66/Idv/hipDuHSpM80RuspV7J08RHbIdZBUY1kU9itjs/uBsCS
# SheqvlvIQzfl1CmXv1KtfjBowHYS2o6OQmVyKRPg8K9O3ZwvL8uJMwxfOcT75hn3
# ffEwxnbOvHEBeiE851A+bW1LBc+x++8A3K6ZhHLmmhIsgg+77ujx9Z9EzaNBCStb
# q/SHNfRQjBFWS+jfXofppLREenUjwuDNdgHsbpeNh0YZgUsri8K81EIrnIOwyyQf
# IlGYFLWfNwIQATzZralA/Z3BJAEW0rKGXu8FtBw2QKRcj5kDE3eEoU8wAZEUJolV
# gBXeDV9gygAgPVvi9r/8WPJiyZgAFzF0zd+sIci5aDyKqtc82cZflRi5uzf+emLY
# y7grtkHXbJ9XeSF87JGIHP2ryJiYQbxmBV4XpI4unANAU7RHdXKlWElkQ58O5P4o
# 4RlVGc/bAlREml7Rl5De/T8KpjhxR5VhnTeZNax2G0DVTD7Wsbxj0TmAnAStZNsC
# AwEAAaOCAYkwggGFMB8GA1UdIwQYMBaAFA8qyyCHKLjsb0iuK1SmKaoXpM0MMB0G
# A1UdDgQWBBQUXpGJwKTGIAYQuTTSFpz1f2aFIjAOBgNVHQ8BAf8EBAMCB4AwDAYD
# VR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzBKBgNVHSAEQzBBMDUGDCsG
# AQQBsjEBAgEDAjAlMCMGCCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQ
# UzAIBgZngQwBBAEwSQYDVR0fBEIwQDA+oDygOoY4aHR0cDovL2NybC5zZWN0aWdv
# LmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdDQVIzNi5jcmwweQYIKwYBBQUH
# AQEEbTBrMEQGCCsGAQUFBzAChjhodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3Rp
# Z29QdWJsaWNDb2RlU2lnbmluZ0NBUjM2LmNydDAjBggrBgEFBQcwAYYXaHR0cDov
# L29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQEMBQADggGBABOIZQVhJqkOkoVy
# JKjlc8sMtBWiTWvIZqggyvR1FeOFBYkHOQxd9CWiRhqSbGeE55n1+JfYhhCF0zHK
# 7lMouZKa8rxYW5yOufTX2sJIsNYmfnpyD9SJRgloAPaxjB5pu0ZJ9Yx84wyW/DO2
# t3Vn3myPjW3wPdfS0GfN5BJvtykT/fxyakZ3pi9S8AvwCJSG/qWeOzjjj9BvLTKf
# HE5ivz5Y6Hyqh/LsSjXsijXgNbcvoEPjBYtTdFc8kDS+kZtydmORKGnMebagJTdC
# +Lh+yZdY1F+2XEIQpYHz+x4kJVEQhjV7g0PPdNVcF/zjU2J53SQ66+SW9yvjj2ai
# xrID4czk176IBFQ/1O2+I+rU7OQ+HfTwsH0mE7GOgp33gQSOhJXMHTnIy62JpdJE
# HOnUINPvxcnoOxajDXQ9IjRyQZN1soW2GAPI4/2+Zu1NsxX3sjDNcgy1+zn4MpQe
# 25SrBGo7WpSwfNRk01CuaVbjz9rWP0kzFA+P2Mgsl2GsFSRiITCCBq4wggSWoAMC
# AQICEAc2N7ckVHzYR6z9KGYqXlswDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMC
# VVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0
# LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTIyMDMy
# MzAwMDAwMFoXDTM3MDMyMjIzNTk1OVowYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoT
# DkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJT
# QTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAMaGNQZJs8E9cklRVcclA8TykTepl1Gh1tKD0Z5Mom2gsMyD
# +Vr2EaFEFUJfpIjzaPp985yJC3+dH54PMx9QEwsmc5Zt+FeoAn39Q7SE2hHxc7Gz
# 7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupRPfDWVtTnKC3r07G1decfBmWNlCnT2exp
# 39mQh0YAe9tEQYncfGpXevA3eZ9drMvohGS0UvJ2R/dhgxndX7RUCyFobjchu0Cs
# X7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV5huowWR0QKfAcsW6Th+xtVhNef7Xj3OT
# rCw54qVI1vCwMROpVymWJy71h6aPTnYVVSZwmCZ/oBpHIEPjQ2OAe3VuJyWQmDo4
# EbP29p7mO1vsgd4iFNmCKseSv6De4z6ic/rnH1pslPJSlRErWHRAKKtzQ87fSqEc
# azjFKfPKqpZzQmiftkaznTqj1QPgv/CiPMpC3BhIfxQ0z9JMq++bPf4OuGQq+nUo
# JEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5K6jzRWC8I41Y99xh3pP+OcD5sjClTNfp
# mEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oiqMEmCPkUEBIDfV8ju2TjY+Cm4T72wnSy
# Px4JduyrXUZ14mCjWAkBKAAOhFTuzuldyF4wEr1GnrXTdrnSDmuZDNIztM2xAgMB
# AAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBS6FtltTYUv
# cyl2mi91jGogj57IbzAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qYrhwPTzAO
# BgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEE
# azBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYIKwYB
# BQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0
# ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZMBcwCAYG
# Z4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAfVmOwJO2b5ip
# RCIBfmbW2CFC4bAYLhBNE88wU86/GPvHUF3iSyn7cIoNqilp/GnBzx0H6T5gyNgL
# 5Vxb122H+oQgJTQxZ822EpZvxFBMYh0MCIKoFr2pVs8Vc40BIiXOlWk/R3f7cnQU
# 1/+rT4osequFzUNf7WC2qk+RZp4snuCKrOX9jLxkJodskr2dfNBwCnzvqLx1T7pa
# 96kQsl3p/yhUifDVinF2ZdrM8HKjI/rAJ4JErpknG6skHibBt94q6/aesXmZgaNW
# hqsKRcnfxI2g55j7+6adcq/Ex8HBanHZxhOACcS2n82HhyS7T6NJuXdmkfFynOlL
# AlKnN36TU6w7HQhJD5TNOXrd/yVjmScsPT9rp/Fmw0HNT7ZAmyEhQNC3EyTN3B14
# OuSereU0cZLXJmvkOHOrpgFPvT87eK1MrfvElXvtCl8zOYdBeHo46Zzh3SP9HSjT
# x/no8Zhf+yvYfvJGnXUsHicsJttvFXseGYs2uJPU5vIXmVnKcPA3v5gA3yAWTyf7
# YGcWoWa63VXAOimGsJigK+2VQbc61RWYMbRiCQ8KvYHZE/6/pNHzV9m8BPqC3jLf
# BInwAM1dwvnQI38AC+R2AibZ8GV2QqYphwlHK+Z/GqSFD/yYlvZVVCsfgPrA8g4r
# 5db7qS9EFUrnEw4d2zc4GqEr9u3WfPwwgga8MIIEpKADAgECAhALrma8Wrp/lYfG
# +ekE4zMEMA0GCSqGSIb3DQEBCwUAMGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5E
# aWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0
# MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwHhcNMjQwOTI2MDAwMDAwWhcNMzUx
# MTI1MjM1OTU5WjBCMQswCQYDVQQGEwJVUzERMA8GA1UEChMIRGlnaUNlcnQxIDAe
# BgNVBAMTF0RpZ2lDZXJ0IFRpbWVzdGFtcCAyMDI0MIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEAvmpzn/aVIauWMLpbbeZZo7Xo/ZEfGMSIO2qZ46XB/Qow
# IEMSvgjEdEZ3v4vrrTHleW1JWGErrjOL0J4L0HqVR1czSzvUQ5xF7z4IQmn7dHY7
# yijvoQ7ujm0u6yXF2v1CrzZopykD07/9fpAT4BxpT9vJoJqAsP8YuhRvflJ9YeHj
# es4fduksTHulntq9WelRWY++TFPxzZrbILRYynyEy7rS1lHQKFpXvo2GePfsMRhN
# f1F41nyEg5h7iOXv+vjX0K8RhUisfqw3TTLHj1uhS66YX2LZPxS4oaf33rp9Hlfq
# SBePejlYeEdU740GKQM7SaVSH3TbBL8R6HwX9QVpGnXPlKdE4fBIn5BBFnV+KwPx
# RNUNK6lYk2y1WSKour4hJN0SMkoaNV8hyyADiX1xuTxKaXN12HgR+8WulU2d6zhz
# XomJ2PleI9V2yfmfXSPGYanGgxzqI+ShoOGLomMd3mJt92nm7Mheng/TBeSA2z4I
# 78JpwGpTRHiT7yHqBiV2ngUIyCtd0pZ8zg3S7bk4QC4RrcnKJ3FbjyPAGogmoiZ3
# 3c1HG93Vp6lJ415ERcC7bFQMRbxqrMVANiav1k425zYyFMyLNyE1QulQSgDpW9rt
# vVcIH7WvG9sqYup9j8z9J1XqbBZPJ5XLln8mS8wWmdDLnBHXgYly/p1DhoQo5fkC
# AwEAAaOCAYswggGHMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYGA1Ud
# JQEB/wQMMAoGCCsGAQUFBwMIMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG
# /WwHATAfBgNVHSMEGDAWgBS6FtltTYUvcyl2mi91jGogj57IbzAdBgNVHQ4EFgQU
# n1csA3cOKBWQZqVjXu5Pkh92oFswWgYDVR0fBFMwUTBPoE2gS4ZJaHR0cDovL2Ny
# bDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNIQTI1NlRp
# bWVTdGFtcGluZ0NBLmNybDCBkAYIKwYBBQUHAQEEgYMwgYAwJAYIKwYBBQUHMAGG
# GGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBYBggrBgEFBQcwAoZMaHR0cDovL2Nh
# Y2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNIQTI1
# NlRpbWVTdGFtcGluZ0NBLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAPa0eH3aZW+M4
# hBJH2UOR9hHbm04IHdEoT8/T3HuBSyZeq3jSi5GXeWP7xCKhVireKCnCs+8GZl2u
# VYFvQe+pPTScVJeCZSsMo1JCoZN2mMew/L4tpqVNbSpWO9QGFwfMEy60HofN6V51
# sMLMXNTLfhVqs+e8haupWiArSozyAmGH/6oMQAh078qRh6wvJNU6gnh5OruCP1QU
# AvVSu4kqVOcJVozZR5RRb/zPd++PGE3qF1P3xWvYViUJLsxtvge/mzA75oBfFZSb
# dakHJe2BVDGIGVNVjOp8sNt70+kEoMF+T6tptMUNlehSR7vM+C13v9+9ZOUKzfRU
# AYSyyEmYtsnpltD/GWX8eM70ls1V6QG/ZOB6b6Yum1HvIiulqJ1Elesj5TMHq8CW
# T/xrW7twipXTJ5/i5pkU5E16RSBAdOp12aw8IQhhA/vEbFkEiF2abhuFixUDobZa
# A0VhqAsMHOmaT3XThZDNi5U2zHKhUs5uHHdG6BoQau75KiNbh0c+hatSF+02kULk
# ftARjsyEpHKsF7u5zKRbt5oK5YGwFvgc4pEVUNytmB3BpIiowOIIuDgP5M9WArHY
# SAR16gc0dP2XdkMEP5eBsX7bf/MGN4K3HP50v/01ZHo/Z5lGLvNwQ7XHBx1yomzL
# P8lx4Q1zZKDyHcp4VQJLu2kWTsKsOqQxggY2MIIGMgIBATBpMFQxCzAJBgNVBAYT
# AkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMTIlNlY3RpZ28g
# UHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYCEQDWEF7OjjXPcAi1NTmRgr/JMA0G
# CWCGSAFlAwQCAQUAoHwwEAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZI
# hvcNAQkEMSIEIDB20awi4VDvLxnUqu85zodSTe25K2iqqigLhvrvXjy0MA0GCSqG
# SIb3DQEBAQUABIICAG62faHzded3SkZ1rw8vnyWL/LWk4GsTH9bELN3kPsy3amNT
# 9erXt2yFa2iRWYfhBJBtvrL+uSAeSETVtxP4AsPdoAE37xyZcu5OF1DPTJkZU/yn
# W8KwGkDLs1NBd9hgtRV+4XHsgA77G7dXTP8FWCf7ia7ZPcwNDY+fhFxpIbicvOte
# pdE6tHouraat58p3vML+UNY9l/da7yEkEOPIjTKgF+khjJH2lWlp9nvOS/5lGLzX
# X8z8P9yuDh4QcioxHvwfXL0Z87mH4U74f5hoL4CogUHftwwiWwwJh6vDuB2z5ARk
# wLWE+aMMph2mnw8FgnyEVEeOr3XLw2mFXE8E39CDcyj/dfp0d8S37sMHV7lnkhi8
# L4hzgCGjTeAAFj4dBFzZK6xBRR8UGiDLJPfv1uLyJneb4NqrMYaalkmIbtbxr9/P
# j61WvuXVL2m7yNVIlb//ledYerOIkbre4gCS4JpPjVvABEkMsmB86pPpRnJeb0L4
# /n+om2NTBgWCTtdDClH5FmlPyZQ382Z2cE1qE4zPLJbOFtrcxuckxeQcCp3oGrvY
# 4xhKviZReqsjC0v2Jafam1s5MaSd0AioP4BenpIxxGRMHpazVM9upG6KbgvqWyhp
# ibPYiPTS+EkHagDWqwaSXawvoXwKFV0ydZP/8m5Xah/jqwyOISc9Ro6CS2o4oYID
# IDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMxFzAV
# BgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVk
# IEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQC65mvFq6f5WHxvnp
# BOMzBDANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTI1MDIyODAwMTQ0M1owLwYJKoZIhvcNAQkEMSIEIO6m
# LKfycEigT5IpQjF12HpVe5w3Q37D1YRlEWw7R1pZMA0GCSqGSIb3DQEBAQUABIIC
# ADsfgsolFxswje038K3pLdxDL0nff+v8rnrBuMGtTnWK/ACb0XMOasSYfB7Qi3Mf
# zynTxlK5FeuD8qezybOOeTaBqOjIkwi+LdF6xDDS9vgmjlVUm1QEp7Z2KynstRST
# J43QzMQhrWhMONzEoqsmhniPJ3xfaty1hTMEh6OenTvywCxybzY3BttymRZqgIT1
# PhzykRJOyuWOaRySpsUA4sSS8UO8SA17YXsNDrObQcbVVhkD09hFGXQh0+Jn98ic
# UZX3AnoqzrKal7i/3gC+ViNKcQqre0R9ge8CsasPAw2+EsuENO/NhY1KDGEwaD3R
# qU7bWu10rM1FA+Nm4QdAN6qQTeRY4WUVqh7wWPY92u/8Vht6kLGXEPwCNnAZHrUP
# oJcMX3m1IvmEN3d2QvcotckLG0fANpBqIelDQT7Mv9eiXQeLPriopS5TFrsPT5go
# PqZSF1JX8inmUEJ/u+/ybqNWDrUMnCwnALqa+aorKpjSiTcXUAsD76BsMEmQZ57C
# iEeOOGdzWHfb0dKB9AqWEX5Kcteq1cx+vGU6HGMs8IwcKFfO3AKOKpLTQXdcLdcq
# tpHmZNcCFV9hWvucQfB44+zkD5kjrDngxXDVTluM+o/M2cRheiPR20esw48hHsM2
# vYhTR9NSPAqe/0POC6VwjSsgXNrcvAZ2bOpmKLW97h9w
# SIG # End signature block
