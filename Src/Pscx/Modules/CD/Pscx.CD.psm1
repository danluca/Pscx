#---------------------------------------------------------------------------
# Author: Keith Hill, Dan Luca
# Desc:   Module that replaces the regular CD function with one that handles
#         history and backward/forward navigation using - and +.
#         as ..[.]*.
# Date:   Nov 18, 2006; Dec 22, 2021
# Site:   https://www.github.com/danluca/Pscx
#---------------------------------------------------------------------------
#requires -Version 6
Set-StrictMode -Version Latest

$backwardStack = new-object System.Collections.ArrayList
$forewardStack = new-object System.Collections.ArrayList

# When the module removed, set the cd alias back to something reasonable.
# We could use the original cd alias but most of the time it's going to be set to Set-Location.
# And you may have loaded another module in between stashing the "original" cd alias that
# modifies the cd alias.  So setting it back to the "original" may not be the right thing to
# do anyway.
$ExecutionContext.SessionState.Module.OnRemove = {
    Set-Alias cd Set-Location -Scope Global -Option AllScope -Force
}.GetNewClosure()

# We are going to replace the PowerShell default "cd" alias with the CD function defined below.
Set-Alias cd Pscx\Set-PscxLocation -Force -Scope Global -Option AllScope -Description "PSCX: Enhanced set-location cmdlet with history stack"

<#
.SYNOPSIS
    Set-PscxLocation function that tracks location history allowing easy navigation to previous locations.
.DESCRIPTION
    Set-PscxLocation function that tracks location history allowing easy navigation to previous locations.
    Set-PscxLocation maintains a backward and forward stack mechanism that can be navigated using "Set-PscxLocation -"
    to go backwards in the stack and "Set-PscxLocation +" to go forwards in the stack.  Executing "Set-PscxLocation"
    without any parameters will display the current stack history. 
    
    By default, the new location is echo'd to the host.  If you want to suppress this set the preference 
    variable in your profile e.g. $Pscx:Preferences['CD_EchoNewLocation'] = $false. 
    
    If you want to change your cd alias to use Set-PscxLocation, execute:
    Set-Alias cd Set-PscxLocation -Option AllScope
.PARAMETER Path
    The path to change location to.
.PARAMETER LiteralPath
    The literal path to change location to.  This path can contain wildcard characters that
    do not need to be escaped.
.PARAMETER PassThru
    If the PassThru switch is specified the object passed into the Set-PscxLocation function is also output
    from the function.  This allows the next pipeline stage to also operate on the object.
.PARAMETER UnboundArguments
    This parameter accumulates all the additional arguments and concatenates them to the Path
    or LiteralPath parameter using a space separator.  This allows you to cd to some paths containing
    spaces without having to quote the path e.g. 'cd c:\program files'.  Note that this doesn't always
    work.  For example, this following won't work: 'cd c:\program files (x86)'.  This fails because
    PowerShell tries to evaluate the contents of the expression '(x86)' which isn't a valid command name.
.PARAMETER UseTransaction
    Includes the command in the active transaction. This parameter is valid only when a transaction
    is in progress. For more information, see about_Transactions.  This parameter is not supported
    in PowerShell Core.
.EXAMPLE
    C:\PS> set-alias cd Set-PscxLocation -Option AllScope; cd $pshome; cd -; cd +
    This example changes location to the PowerShell install dir, then back to the original
    location, than forward again to the PowerShell install dir.
.EXAMPLE
    C:\PS> set-alias cd Set-PscxLocation -Option AllScope; cd ....
    This example changes location up two levels from the current path.  You can use an arbitrary
    number of periods to indicate how many levels you want to go up.  A single period "." indicates
    the current location.  Two periods ".." indicate the current location's parent.  Three periods "..."
    indicates the current location's parent's parent and so on.
.EXAMPLE
    C:\PS> set-alias cd Set-PscxLocation -Option AllScope; cd
    Executing CD without any parameters will cause it to display the current stack contents.
.EXAMPLE
    C:\PS> set-alias cd Set-PscxLocation -Option AllScope; cd =0 OR cd *0
    Changes location to the very first (0th index) location in the stack. Execute CD without any parameters
    to see all the paths, then execute CD =<number> or CD *<number> to change location to that path.
.EXAMPLE
    C:\PS> cd +2; cd -3
    Changes location forward two entries incrementally in the stack (if the new stack position is valid). Then changes location
    backwards three entries incrementally in the stack.
.EXAMPLE
    C:\PS> cd %; cd *-; cd -*
    Changes location to the very first (0th index) location in the stack.
.EXAMPLE
    C:\PS> cd !; cd *+; cd +*
    Changes location to the very last location in the stack.
.EXAMPLE
    C:\PS> set-alias cd Set-PscxLocation -Option AllScope; $profile | cd
    This example will change location to the parent location of $profile.
.NOTES
    This is a PSCX function.
#>
function Set-PscxLocation {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'Path', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]
        $Path,

        [Parameter(Position = 0, ParameterSetName = 'LiteralPath', ValueFromPipelineByPropertyName = $true)]
        [Alias("PSPath")]
        [string]
        $LiteralPath,

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]
        $UnboundArguments,

        [Parameter()]
        [switch]
        $PassThru,

        [Parameter()]
        [switch]
        $UseTransaction
    )

    Begin {
        Set-StrictMode -Version Latest

        # String resources
        Import-LocalizedData -BindingVariable msgTbl -FileName Messages

        $ExtraArgs = @{}
        if (($PSVersionTable.PSVersion.Major -lt 6) -or ($PSVersionTable.PSEdition -eq 'Desktop')) {
            $ExtraArgs['UseTransaction'] = $UseTransaction
        }

        function SetLocationImpl($path, [switch]$IsLiteralPath) {
            if ($pscmdlet.ParameterSetName -eq 'LiteralPath' -or $IsLiteralPath) {
                Write-Debug "Setting location to literal path: '$path'"
                Set-Location -LiteralPath $path @ExtraArgs
            }
            else {
                Write-Debug "Setting location to path: '$path'"
                Set-Location $path @ExtraArgs
            }

            if ($PassThru) {
                Write-Output $ExecutionContext.SessionState.Path.CurrentLocation
            }
            else {
                # If not passing thru, then check for user options of other info to display.
                if ($Pscx:Preferences['CD_GetChildItem']) {
                    Get-ChildItem
                }
                elseif ($Pscx:Preferences['CD_EchoNewLocation']) {
                    Write-Host $ExecutionContext.SessionState.Path.CurrentLocation
                }
            }
        }

        $lnHorz = "`u{2594}"
        $lnSpace = "`u{2579}"
        #$lnHorz = "`u{2501}"
        #$marker = "`u{00bb}"
        $marker = "`u{276f}"
        $clrBold = "`e[1m"
        $clrNoBold = "`e[22m"
        $clrItalic = "`e[3m"
        $clrNoItalic = "`e[23m"
        $clrHeader = "`e[38;5;244m`e[48;5;236m"
        $clrCurrent = "`e[38;5;220m"
        $clrDefault = "`e[39m`e[49m"
        $clrReset = "`e[0m"
    }

    Process {
        if ($pscmdlet.ParameterSetName -eq 'Path') {
            Write-Debug "Path parameter received: '$Path'"
            $aPath = $Path
        }
        else {
            Write-Debug "LiteralPath parameter received: '$LiteralPath'"
            $aPath = $LiteralPath
        }

        if ($UnboundArguments -and $UnboundArguments.Count -gt 0) {
            $OFS = ','
            Write-Debug "Appending unbound arguments to path: '$UnboundArguments'"
            $aPath = $aPath + " " + ($UnboundArguments -join ' ')
        }

        # If no input, dump contents of backward and foreward stacks
        if (!$aPath) {
            [int]$i = 0
            # Command to dump the backward & foreward stacks
            "$clrReset"
            Write-Information " $clrHeader$clrBold   # Directory Stack:$(' '*17)$clrNoBold$clrDefault" -InformationAction Continue
            Write-Information " $clrHeader $($lnHorz * 3)$lnSpace$($lnHorz * 16)$(' '*17)$clrDefault" -InformationAction Continue
            if ($backwardStack.Count -ge 0) {
                for ($i = 0; $i -lt $backwardStack.Count; $i++) {
                    "   {0,3} {1}" -f $i, $backwardStack[$i]
                }
            }

            "$clrCurrent $marker{0,3} {1}$clrDefault" -f $i++, $ExecutionContext.SessionState.Path.CurrentLocation

            if ($forewardStack.Count -ge 0) {
                $ndx = $i
                for ($i = 0; $i -lt $forewardStack.Count; $i++) {
                    "   {0,3} {1}" -f ($ndx + $i), $forewardStack[$i]
                }
            }
            "$clrReset"
            return
        }

        Write-Debug "Processing arg: '$aPath'"

        $currentPathInfo = $ExecutionContext.SessionState.Path.CurrentLocation

        # Expand ..[.]+ out to ..\..[\..]+
        if ($aPath -like "*...*") {
            $regex = [regex]"\.\.\."
            while ($regex.IsMatch($aPath)) {
                $aPath = $regex.Replace($aPath, "..$([System.IO.Path]::DirectorySeparatorChar)..")
            }
        }

        switch ($aPath) {
            "-" {
                if ($backwardStack.Count -eq 0) {
                    Write-Warning $msgTbl.BackStackEmpty
                }
                else {
                    $lastNdx = $backwardStack.Count - 1
                    $prevPath = $backwardStack[$lastNdx]
                    SetLocationImpl $prevPath -IsLiteralPath
                    [void]$forewardStack.Insert(0, $currentPathInfo.Path)
                    $backwardStack.RemoveAt($lastNdx)
                }
                break
            }
            "+" {
                if ($forewardStack.Count -eq 0) {
                    Write-Warning $msgTbl.ForeStackEmpty
                }
                else {
                    $nextPath = $forewardStack[0]
                    SetLocationImpl $nextPath -IsLiteralPath
                    [void]$backwardStack.Add($currentPathInfo.Path)
                    $forewardStack.RemoveAt(0)
                }
                break
            }
            { $_ -in "*-", "%", "-*" } {
                [int]$num = 0
                $backstackSize = $backwardStack.Count
                $forestackSize = $forewardStack.Count
                if ($num -eq $backstackSize) {
                    Write-Host "`n$($msgTbl.GoingToTheSameDir)`n"
                }
                else {
                    $selectedPath = $backwardStack[$num]
                    SetLocationImpl $selectedPath -IsLiteralPath
                    [void]$forewardStack.Insert(0, $currentPathInfo.Path)
                    $backwardStack.RemoveAt($num)

                    if ($backwardStack.Count -gt 0) {
                        $forewardStack.InsertRange(0, $backwardStack)
                        $backwardStack.Clear()
                    }
                }
                break
            }
            { $_ -in "*+", "!", "+*" } {
                $backstackSize = $backwardStack.Count
                $forestackSize = $forewardStack.Count
                [int]$num = $backstackSize + $forestackSize
                if ($num -eq $backstackSize) {
                    Write-Host "`n$($msgTbl.GoingToTheSameDir)`n"
                }
                else {
                    [int]$ndx = $forestackSize - 1
                    $selectedPath = $forewardStack[$ndx]
                    SetLocationImpl $selectedPath -IsLiteralPath
                    [void]$backwardStack.Add($currentPathInfo.Path)
                    $forewardStack.RemoveAt($ndx)

                    if ($ndx -gt 0) {
                        $backwardStack.InsertRange(($backwardStack.Count), $forewardStack)
                        $forewardStack.Clear()
                    }
                }
                break
            }
            default {
                switch -Wildcard ($aPath) {
                    "[=*][0-9]*" {
                        [int]$num = $aPath.Substring(1)
                        $backstackSize = $backwardStack.Count
                        $forestackSize = $forewardStack.Count
                        if ($num -eq $backstackSize) {
                            Write-Host "`n$($msgTbl.GoingToTheSameDir)`n"
                        }
                        elseif ($num -lt $backstackSize) {
                            $selectedPath = $backwardStack[$num]
                            SetLocationImpl $selectedPath -IsLiteralPath
                            [void]$forewardStack.Insert(0, $currentPathInfo.Path)
                            $backwardStack.RemoveAt($num)

                            [int]$ndx = $num
                            [int]$count = $backwardStack.Count - $ndx
                            if ($count -gt 0) {
                                $itemsToMove = $backwardStack.GetRange($ndx, $count)
                                $forewardStack.InsertRange(0, $itemsToMove)
                                $backwardStack.RemoveRange($ndx, $count)
                            }
                        }
                        elseif (($num -gt $backstackSize) -and ($num -lt ($backstackSize + 1 + $forestackSize))) {
                            [int]$ndx = $num - ($backstackSize + 1)
                            $selectedPath = $forewardStack[$ndx]
                            SetLocationImpl $selectedPath -IsLiteralPath
                            [void]$backwardStack.Add($currentPathInfo.Path)
                            $forewardStack.RemoveAt($ndx)

                            [int]$count = $ndx
                            if ($count -gt 0) {
                                $itemsToMove = $forewardStack.GetRange(0, $count)
                                $backwardStack.InsertRange(($backwardStack.Count), $itemsToMove)
                                $forewardStack.RemoveRange(0, $count)
                            }
                        }
                        else {
                            Write-Warning ($msgTbl.NumOutOfRangeF1 -f $num)
                        }
                        break
                    }
                    "-[0-9]*" {
                        [int]$num = $aPath.Substring(1)
                        $backstackSize = $backwardStack.Count
                        if ($num -eq 0) {
                            Write-Host "`n$($msgTbl.GoingToTheSameDir)`n"
                        }
                        elseif ($num -le $backstackSize) {
                            [int]$ndx = $backstackSize - $num
                            $selectedPath = $backwardStack[$ndx]
                            SetLocationImpl $selectedPath -IsLiteralPath
                            [void]$forewardStack.Insert(0, $currentPathInfo.Path)
                            $backwardStack.RemoveAt($ndx)

                            [int]$count = $num - 1
                            if ($count -gt 0) {
                                $itemsToMove = $backwardStack.GetRange($ndx, $count)
                                $forewardStack.InsertRange(0, $itemsToMove)
                                $backwardStack.RemoveRange($ndx, $count)
                            }
                        }
                        else {
                            Write-Warning ($msgTbl.NumOutOfRangeF1 -f $num)
                        }
                        break
                    }
                    "+[0-9]*" {
                        [int]$num = $aPath.Substring(1)
                        $forestackSize = $forewardStack.Count
                        if ($num -eq 0) {
                            Write-Host "`n$($msgTbl.GoingToTheSameDir)`n"
                        }
                        elseif ($num -le $forestackSize) {
                            [int]$ndx = $num - 1
                            $selectedPath = $forewardStack[$ndx]
                            SetLocationImpl $selectedPath -IsLiteralPath
                            [void]$backwardStack.Add($currentPathInfo.Path)
                            $forewardStack.RemoveAt($ndx)

                            if ($ndx -gt 0) {
                                $itemsToMove = $forewardStack.GetRange(0, $ndx)
                                $backwardStack.AddRange($itemsToMove)
                                $forewardStack.RemoveRange(0, $ndx)
                            }
                        }
                        else {
                            Write-Warning ($msgTbl.NumOutOfRangeF1 -f $num)
                        }
                        break
                    }
                    default {
                        $driveName = ''
                        if ($ExecutionContext.SessionState.Path.IsPSAbsolute($aPath, [ref]$driveName) -and !(Test-Path -LiteralPath $aPath -PathType Container)) {
                            # File or a non-existant path - handle the case of "cd $profile" when the profile script doesn't exist
                            $aPath = Split-Path $aPath -Parent
                            Write-Debug "Path is not a container, attempting to set location to parent: '$aPath'"
                        }

                        SetLocationImpl $aPath

                        $forewardStack.Clear()

                        # Don't add the same path twice in a row
                        $newPathInfo = $ExecutionContext.SessionState.Path.CurrentLocation
                        if (($currentPathInfo.Provider -eq $newPathInfo.Provider) -and ($currentPathInfo.ProviderPath -eq $newPathInfo.ProviderPath)) {
                            break
                        }
                        [void]$backwardStack.Add($currentPathInfo.Path)
                        break
                    }
                }
            }
        }
    }
}

# SIG # Begin signature block
# MIInYwYJKoZIhvcNAQcCoIInVDCCJ1ACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAEGVuhMA7c8ZiN
# V4AHMFE2TS/bg21iQ38fwOljPoovv6CCIEAwggWNMIIEdaADAgECAhAOmxiO+dAt
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
# DjAMBgorBgEEAYI3AgEWMC8GCSqGSIb3DQEJBDEiBCCGKzImIWNQTqUElvPFgPAj
# h2mT4SSiHyRtwBeiMZ5+ITANBgkqhkiG9w0BAQEFAASCAgA3fNlN/JM15SU30zIh
# bVu8UXhKqgYLclNT+OXfc0JgplJ9mwBYw2rBWk3hvGuSAkWjByFGp2SV/le2hfvp
# o5muZB7+C+k6eXRSpp5mUR4HHbgIuWUG/E0I2depewjq62xAMsoO85cIMog4tezF
# b5/WfCPxKbMZx+yLwHBOrWkOwbqiBcWbGuAk293JGRBnnD7Rg/lqxPMT51pjyj12
# thk3bMEEwODjPEOApMs3pL+W3he5myFgtWO/DCjLieRCkjMfQ/jMLc6Fr3Ds/N9G
# h73zYSG/PhvMbM1XPLbzRkYIV1628/F5H1ujnZyQIaeyTQpcTCl6dDKTmSxSG0/e
# Cs7VdzmJwi67D184LmQVo7IRRAqWz6LIICTrHkZn9WAjYnuLWgrGapsb29EWc1Qc
# tl5tQ2x0V4KgjeLVcmveFqtGCigyfBbZrCmgYsoTOYLeYmadI+UrU12Hn/5Jv8ZD
# rKELa63M0vMZCRBRLuB/6JaGt9T2D7JofYGBCpLQLWxdN7xGhBQQPvQpBwPWhumc
# axx9gA1NBFns/ofa70OgoTSvFolgp/nPvQqa29yyWwt3OkkvOUpmvkT5qyM+KI8I
# 19aztnwX2et3TCmR2e/VJ1/W7Ib/ythHERoZ96JavZwmGsh+9ia1xHmKnAcW1yS4
# lxuvqgey0z15yK+Mi0LrtCrNCKGCAyAwggMcBgkqhkiG9w0BCQYxggMNMIIDCQIB
# ATB3MGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkG
# A1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3Rh
# bXBpbmcgQ0ECEAVEr/OUnQg5pr/bP1/lYRYwDQYJYIZIAWUDBAIBBQCgaTAYBgkq
# hkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yNDA4MjAwMDIw
# MzhaMC8GCSqGSIb3DQEJBDEiBCAA7B++KJB3hJwLY2ESIlSHiv2i729QCN+7BVXq
# xWzlzTANBgkqhkiG9w0BAQEFAASCAgAJjlLIH0tCuMvQSEJjgSh/OhdPgtJTNo2Q
# gT3lNEUxyEPnkBRCIMkclodUdnZ1VnUpMnUsmWN7xh5Jl28BJ3orsPLP5/fTlWBG
# NCNZsFhYdvABcpu0lC0HoWSsVBnLjqzpUw61hNCO77Sf3JFY9Pt3cWG532z49ymg
# WboGypWBxQlJFpt2FqYvIukHedRvtgC6JLCqng/6ZFDVsSI8wJTcdkxXjtC/eGxK
# biwkK3ZsuTYyyIJkOjRBQrGO2EkqcSVoGp02wlbjDzmer9byjPB5qhbUV2/5hbbZ
# 6kJakYBEKYiU297uNwm67MARzCB1jddhU0nmbi0CCcVwuxhMBI0ykPsz8T7ICOWX
# fpkMzHX+Kz6sE6kXO4+rO1Yr+fbZWlG5etU41y8gRjaczAfLX4lIrzTYq3rj0WSO
# kyC07MFJnpV18Z4dd7SlIuwFFEAYynUq14zjAnWPvgpQ+mPh3KK/Nwnz6uZB5yOo
# 81gzsoudZyho/+CX382h1xaTW8osbMTh4NPfovGZlMsWRVWEKLdG8D/3daAN2TFo
# xRXvIsj8mRTQsii+vJlBJEGlc5simVyi6p7eSHFjk5QZIAimU4ZDj+s7yP5wLo1X
# 6HvMdmz1Nvm5vRPt9sVcLVl7g/wlvlFogrMU11AWwyq+Z2CqS5891zHAiO119hbp
# Zt4yqQMvbw==
# SIG # End signature block
