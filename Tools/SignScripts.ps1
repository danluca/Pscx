# Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
# Licensed under MIT license.

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory, Position = 0)]
    [string[]] $Path,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9A-Fa-f]{40}$')]
    [string] $CertificateThumbprint,

    [string[]] $Include = @('*.ps1', '*.psm1', '*.psd1', '*.ps1xml'),

    [string[]] $Exclude = @('Pscx.UserPreferences.ps1'),

    [switch] $Recurse,

    [uri] $TimestampServer = 'http://timestamp.digicert.com'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    throw 'Authenticode signing is supported only from a Windows maintainer workstation.'
}

$certificatePath = "Cert:\CurrentUser\My\$CertificateThumbprint"
$certificate = Get-Item -LiteralPath $certificatePath -ErrorAction Stop
if (-not $certificate.HasPrivateKey) {
    throw "Certificate $CertificateThumbprint does not have an accessible private key."
}
if ($certificate.NotBefore -gt [datetime]::Now -or $certificate.NotAfter -lt [datetime]::Now) {
    throw "Certificate $CertificateThumbprint is not currently valid."
}

$codeSigningOid = '1.3.6.1.5.5.7.3.3'
if ($certificate.EnhancedKeyUsageList.ObjectId -notcontains $codeSigningOid) {
    throw "Certificate $CertificateThumbprint is not valid for code signing."
}

$files = [Collections.Generic.Dictionary[string, IO.FileInfo]]::new(
    [StringComparer]::OrdinalIgnoreCase
)
foreach ($inputPath in $Path) {
    $item = Get-Item -LiteralPath $inputPath -ErrorAction Stop
    $candidates = if ($item.PSIsContainer) {
        Get-ChildItem -LiteralPath $item.FullName -File -Recurse:$Recurse
    }
    else {
        @($item)
    }

    foreach ($candidate in $candidates) {
        $included = @($Include | Where-Object { $candidate.Name -like $_ }).Count -gt 0
        $excluded = @($Exclude | Where-Object {
            $candidate.Name -like $_ -or $candidate.FullName -like $_
        }).Count -gt 0
        if ($included -and -not $excluded) {
            $files[$candidate.FullName] = $candidate
        }
    }
}

if ($files.Count -eq 0) {
    throw 'No PowerShell files matched the requested paths and filters.'
}

foreach ($file in $files.Values | Sort-Object FullName) {
    if (-not $PSCmdlet.ShouldProcess($file.FullName, 'Apply an Authenticode signature')) {
        continue
    }

    $signature = Set-AuthenticodeSignature -FilePath $file.FullName `
        -Certificate $certificate -TimestampServer $TimestampServer.AbsoluteUri
    if ($signature.Status -ne [Management.Automation.SignatureStatus]::Valid) {
        throw "Signing $($file.FullName) returned status '$($signature.Status)': $($signature.StatusMessage)"
    }

    [pscustomobject]@{
        Path = $file.FullName
        Status = $signature.Status.ToString()
        SignerThumbprint = $signature.SignerCertificate.Thumbprint
        TimeStamperThumbprint = if ($signature.TimeStamperCertificate) {
            $signature.TimeStamperCertificate.Thumbprint
        }
        else {
            $null
        }
    }
}
