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
# MIInmgYJKoZIhvcNAQcCoIInizCCJ4cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAEGVuhMA7c8ZiN
# V4AHMFE2TS/bg21iQ38fwOljPoovv6CCIHEwggWNMIIEdaADAgECAhAOmxiO+dAt
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
# MQ4wDAYKKwYBBAGCNwIBFjAvBgkqhkiG9w0BCQQxIgQghisyJiFjUE6lBJbzxYDw
# I4dpk+Ekoh8kbcAXojGefiEwDQYJKoZIhvcNAQEBBQAEggIAN3zZTfyTNeUlN9My
# IW1bvFF4SqoGC3JTU/jl33NCYKZSfZsAWMNqwVpN4bxrkgJFowchRqdklf5XtoX7
# 6aOZrmQe/gvpOnl0UqaeZlEeBx24CLllBvxNCNnXqXsI6utsQDLKDvOXCDKIOLXs
# xW+f1nwj8SmzGcfsi8BwTq1pDsG6ogXFmxrgJNvdyRkQZ5w+0YP5asTzE+daY8o9
# drYZN2zBBMDg4zxDgKTLN6S/lt4XuZshYLVjvwwoy4nkQpIzH0P4zC3Oha9w7Pzf
# Roe982Ehvz4bzGzNVzy280ZGCFdetvPxeR9bo52ckCGnsk0KXEwpenQyk5ksUhtP
# 3grO1Xc5icIuuw9fOC5kFaOyEUQKls+iyCAk6x5GZ/VgI2J7i1oKxmqbG9vRFnNU
# HLZebUNsdFeCoI3i1XJr3harRgooMnwW2awpoGLKEzmC3mJmnSPlK1Ndh5/+Sb/G
# Q6yhC2utzNLzGQkQUS7gf+iWhrfU9g+yaH2BgQqS0C1sXTe8RoQUED70KQcD1obp
# nGscfYANTQRZ7P6H2u9DoKE0rxaJYKf5z70KmtvcslsLdzpJLzlKZr5E+asjPiiP
# CNfWs7Z8F9nrd0wpkdnv1Sdf1uyG/8rYRxEaGfeiWr2cJhrIfvYmtcR5ipwHFtck
# uJcbr6oHstM9ecivjItC67QqzQihggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8C
# AQEwfTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/
# BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYg
# U0hBMjU2IDIwMjUgQ0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUA
# oGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYw
# ODA4MDQ0ODQxWjAvBgkqhkiG9w0BCQQxIgQgAOwfviiQd4ScC2NhEiJUh4r9ou9v
# UAjfuwVV6sVs5c0wDQYJKoZIhvcNAQEBBQAEggIAvtC2Dr22GzjSnrEBourqMitr
# Cz7ZtnKr/niXx30qV7yWbJ9HOWMa8Hy/AfvB3fnn8fG0g/8FoOoMBQgnAuYpS3va
# WulyBzMVyri1hIjPgxUXm4642Tq/jKNuNCoRE+3fFoUBvczxhBmkc1myq/q5Rn4+
# WfLDQDI9GXYDtTSw1tdKgBWKgeb2ZcxklQR9YbgKe7S8NqJ1vpo9klO4QSUJ8owD
# HLI9ylAH8Buq7KtmakxdyYJpweQA94M4bfBGOuYK6Yu7Qew/Tc7F2yNYUitfKTCt
# in7Ds0HIryE3p829escM4yMz3whOldVEvrAolj16Vz24+v9prpTrnJSFAOgDAosH
# B+HQ2lXSpbuuTNyg9M3QdVmLalPd7sTjZhPBoYvxFIQQpb5CpsbpqvFGb1vvjR/M
# aXiTJYTuL6f04X8G4yQHXYiRG5ncilUvJO90XRqBngAIqPxaRi9fV1UjKc0K0Wsx
# 9eEKs7CXXkEfYDjlQlEdIwa9C6cjfOL7wHJ4p09gOmH94gl26dIfN6qy9K3kld0i
# j+W5BhBBOKZXsdw6JS7Vyl/EtSBz3Ns0Gb+MLOAwOvJrCBKz/BCsr6IfQnWhQQHk
# DygUvBJrBjIWak7V9xbm1CqSNH0yBsekgW3cOJuBD0ppiR199Uo/M7WnFCeieMzN
# mtRchGppzmQvunVFyjg=
# SIG # End signature block
