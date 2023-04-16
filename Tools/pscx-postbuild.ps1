#######################################
## Globals                           ##
#######################################
[CmdletBinding()]
param([string]$outDir, [string]$configuration)

# Disable ANSI colors - same as $env:TERM = xterm-mono
$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

Write-Host "In $PWD running script $($MyInvocation.MyCommand) from $PSScriptRoot with params outdir as $outDir and config $configuration"

$solDir = $PWD
$pscxDll = Join-Path $outDir "Pscx.dll"
$signTool = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22000.0\x86\signtool.exe"
$version = (Import-PowerShellDataFile (Join-Path $outDir "Pscx.psd1")).ModuleVersion

# copy release notes
Copy-Item ../CHANGELOG.md $outDir

# copy the Apps
Push-Location $outDir
if (!(Test-Path "Apps" -PathType Container)) {
    New-Item "Apps/Win" -ItemType Directory -Force
    New-Item "Apps/macOS" -ItemType Directory -Force
    New-Item "Apps/Linux" -ItemType Directory -Force
}
Copy-Item $solDir/../Imports/Less-608/less*.* ./Apps/Win/
Copy-Item $solDir/../Imports/Less-608/license ./Apps/Win/LICENSE_less_orig.txt
Copy-Item $solDir/../Imports/Less-608/LICENSE_win.txt ./Apps/Win/LICENSE_less_win.txt
Copy-Item $solDir/../Imports/gsudo/win/gsudo.exe ./Apps/Win/gsudo.exe
Copy-Item $solDir/../Imports/gsudo/win/gsudo.exe ./Apps/Win/sudo.exe
Copy-Item $solDir/../Imports/gsudo/LICENSE.txt ./Apps/Win/LICENSE_sudo.txt
Copy-Item $solDir/../Imports/7zip/win/x64/7z.* ./Apps/Win/
Copy-Item $solDir/../Imports/7zip/macOS/7zz ./Apps/macOS/
Copy-Item $solDir/../Imports/7zip/linux/x64/7zz ./Apps/Linux/
Copy-Item $solDir/../Imports/7zip/License.txt ./Apps/Win/LICENSE_7zip.txt
Copy-Item $solDir/../Imports/7zip/License.txt ./Apps/macOS/LICENSE_7zip.txt
Copy-Item $solDir/../Imports/7zip/License.txt ./Apps/Linux/LICENSE_7zip.txt
Copy-Item $solDir/../LICENSE ./LICENSE.txt
Pop-Location

#sign if enabled
if ($configuration -eq "Release-Signed") {
    Write-host "$signTool sign /t http://timestamp.digicert.com /sha1 BB25149CDAF879A29DB6A011F6FC874AF32CBF51 $pscxDll"
    & $signTool sign /t http://timestamp.digicert.com /sha1 BB25149CDAF879A29DB6A011F6FC874AF32CBF51 "$pscxDll"
    Write-Host "./SignScripts.ps1" 
    ./SignScripts.ps1
}

#package the output - the packDir is created by the pscxwin-postbuild script that runs before this one
$packDir = Join-Path $solDir "../Output/Pscx/$version/"
if (!(Test-Path $packDir)) {
    New-Item $packDir -ItemType Directory -Force
}

Push-Location $outDir
Copy-Item Pscx.Core.dll,Pscx.dll,NodaTime.*,Pscx.psd1,Pscx.psm1,Pscx.UserPreferences.ps1,Pscx.ico,LICENSE.txt $packDir -Force
Copy-Item $solDir/../CHANGELOG.md $packDir -Force
Copy-Item Apps $packDir -Recurse -Force
Copy-Item FormatData $packDir -Recurse -Force
Copy-Item Modules $packDir -Recurse -Force
Copy-Item TypeData $packDir -Recurse -Force
Pop-Location

