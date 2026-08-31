[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'UpdateModulePath is Pester container data consumed in BeforeAll.'
)]
param(
    [Parameter(Mandatory)]
    [string] $UpdateModulePath
)

BeforeAll {
    $script:updateModulePath = (Resolve-Path -LiteralPath $UpdateModulePath).Path
    $script:updateModule = Import-Module $script:updateModulePath -Force -PassThru

    function Get-PscxUpdateTestPackage {
        param(
            [Parameter(Mandatory)][string] $Root,
            [string] $Version = '4.1.0',
            [string] $Prerelease,
            [string] $RequiredPowerShellVersion = '7.6.0',
            [string[]] $ModuleName = @('Pscx', 'Pscx.Archive', 'Pscx.Time')
        )

        foreach ($name in $ModuleName) {
            $moduleRoot = Join-Path $Root "$name/$Version"
            New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
            $guid = if ($name -eq 'Pscx') {
                '0fab0d39-2f29-4e79-ab9a-fd750c66e6c5'
            }
            else {
                [guid]::NewGuid().ToString()
            }
            $prereleaseLine = if ($Prerelease) {
                "Prerelease = '$Prerelease'"
            }
            else {
                "Prerelease = ''"
            }
            @"
@{
    RootModule = '$name.psm1'
    ModuleVersion = '$Version'
    GUID = '$guid'
    PowerShellVersion = '$RequiredPowerShellVersion'
    PrivateData = @{ PSData = @{ $prereleaseLine } }
}
"@ | Set-Content -LiteralPath (Join-Path $moduleRoot "$name.psd1") -Encoding utf8
            "# $name test payload" |
                Set-Content -LiteralPath (Join-Path $moduleRoot "$name.psm1") -Encoding utf8
        }
    }

    function Get-PscxUpdateTestRelease {
        param(
            [string] $Version,
            [bool] $Prerelease = $false,
            [bool] $Draft = $false,
            [bool] $IncludeAssets = $true
        )

        $assets = if ($IncludeAssets) {
            @(
                [pscustomobject]@{
                    name = "Pscx-$Version.zip"
                    browser_download_url = "https://example.invalid/Pscx-$Version.zip"
                }
                [pscustomobject]@{
                    name = "Pscx-$Version.sha256"
                    browser_download_url = "https://example.invalid/Pscx-$Version.sha256"
                }
            )
        }
        else {
            @()
        }
        [pscustomobject]@{
            tag_name = "v$Version"
            draft = $Draft
            prerelease = $Prerelease
            html_url = "https://example.invalid/releases/v$Version"
            assets = $assets
        }
    }
}

AfterAll {
    Remove-Module $script:updateModule -Force -ErrorAction SilentlyContinue
}

Describe 'PSCX updater semantic version and release selection' {
    It 'implements Semantic Version prerelease precedence' {
        $ordered = @(
            '1.0.0-alpha'
            '1.0.0-alpha.1'
            '1.0.0-alpha.beta'
            '1.0.0-beta'
            '1.0.0-beta.2'
            '1.0.0-beta.11'
            '1.0.0-rc.1'
            '1.0.0'
        )
        for ($index = 0; $index -lt $ordered.Count - 1; $index++) {
            $comparison = & $script:updateModule {
                param($Left, $Right)
                Compare-PscxSemanticVersion -Left $Left -Right $Right
            } $ordered[$index] $ordered[$index + 1]
            $comparison | Should -BeLessThan 0
        }

        $largeNumericComparison = & $script:updateModule {
            Compare-PscxSemanticVersion `
                -Left '1.0.0-999999999999999999999999999999' `
                -Right '1.0.0-1000000000000000000000000000000'
        }
        $largeNumericComparison | Should -BeLessThan 0
    }

    It 'ignores drafts and prereleases by default and sorts stable releases newest first' {
        $releases = @(
            Get-PscxUpdateTestRelease -Version '4.1.0'
            Get-PscxUpdateTestRelease -Version '4.2.0-preview.1' -Prerelease $true
            Get-PscxUpdateTestRelease -Version '5.0.0' -Draft $true
            Get-PscxUpdateTestRelease -Version '4.0.0'
            Get-PscxUpdateTestRelease -Version '4.3.0' -IncludeAssets $false
        )

        $selected = @(& $script:updateModule {
                param($Release)
                Select-PscxRelease -Release $Release
            } $releases)

        $selected.Version.Text | Should -Be @('4.1.0', '4.0.0')
    }

    It 'includes prereleases only through explicit opt-in' {
        $releases = @(
            Get-PscxUpdateTestRelease -Version '4.1.0'
            Get-PscxUpdateTestRelease -Version '4.2.0-preview.2' -Prerelease $true
        )

        $selected = @(& $script:updateModule {
                param($Release)
                Select-PscxRelease -Release $Release -IncludePrerelease
            } $releases)

        $selected.Version.Text | Should -Be @('4.2.0-preview.2', '4.1.0')
    }

    It 'reads installed prerelease metadata from manifest hashtables' {
        Mock -ModuleName Pscx.Update Get-Module {
            @([pscustomobject]@{
                    Name = 'Pscx'
                    Version = [version]'4.0.0'
                    Path = '/modules/Pscx/4.0.0/Pscx.psd1'
                    PrivateData = @{
                        PSData = @{ Prerelease = 'preview.1' }
                    }
                })
        }

        $installed = @(& $script:updateModule { Get-PscxInstalledVersion })

        $installed | Should -HaveCount 1
        $installed[0].Version.Text | Should -Be '4.0.0-preview.1'
        $installed[0].Version.IsPrerelease | Should -BeTrue
    }
}

Describe 'PSCX updater package security' {
    It 'rejects a checksum mismatch' {
        $archivePath = Join-Path $TestDrive 'Pscx-4.1.0.zip'
        $checksumPath = Join-Path $TestDrive 'Pscx-4.1.0.sha256'
        'archive' | Set-Content -LiteralPath $archivePath -Encoding utf8
        "$('0' * 64)  Pscx-4.1.0.zip" | Set-Content -LiteralPath $checksumPath -Encoding utf8

        {
            & $script:updateModule {
                param($ArchivePath, $ChecksumPath)
                Test-PscxReleaseChecksum -ArchivePath $ArchivePath -ChecksumPath $ChecksumPath
            } $archivePath $checksumPath
        } | Should -Throw '*SHA-256 verification failed*'
    }

    It 'rejects archive paths that escape the extraction root' {
        $archivePath = Join-Path $TestDrive 'unsafe.zip'
        $destination = Join-Path $TestDrive 'expanded'
        $archive = [IO.Compression.ZipFile]::Open($archivePath, [IO.Compression.ZipArchiveMode]::Create)
        try {
            $entry = $archive.CreateEntry('../escape.txt')
            $writer = [IO.StreamWriter]::new($entry.Open())
            try { $writer.Write('unsafe') } finally { $writer.Dispose() }
        }
        finally {
            $archive.Dispose()
        }

        {
            & $script:updateModule {
                param($ArchivePath, $Destination)
                Expand-PscxSafeArchive -ArchivePath $ArchivePath -DestinationPath $Destination
            } $archivePath $destination
        } | Should -Throw '*unsafe path*'
        Test-Path -LiteralPath (Join-Path $TestDrive 'escape.txt') | Should -BeFalse
    }

    It 'validates package identity, version, roots, and runtime compatibility without importing it' {
        $packageRoot = Join-Path $TestDrive 'package'
        Get-PscxUpdateTestPackage -Root $packageRoot
        $expectedVersion = & $script:updateModule {
            ConvertFrom-PscxSemanticVersion -Version '4.1.0'
        }

        $package = & $script:updateModule {
            param($Root, $ExpectedVersion)
            Test-PscxPackageCandidate -PackageRoot $Root -ExpectedVersion $ExpectedVersion
        } $packageRoot $expectedVersion

        $package.Compatible | Should -BeTrue
        $package.ModuleVersion | Should -Be '4.1.0'
        $package.Modules.Name | Should -Be @('Pscx', 'Pscx.Archive', 'Pscx.Time')
        $package.Modules.SourcePath | Should -Match '[\\/]4\.1\.0$'
        Get-Module Pscx.Archive, Pscx.Time | Should -BeNullOrEmpty
    }

    It 'rejects the legacy unversioned release archive layout' {
        $packageRoot = Join-Path $TestDrive 'unversioned'
        Get-PscxUpdateTestPackage -Root $packageRoot
        foreach ($name in 'Pscx', 'Pscx.Archive', 'Pscx.Time') {
            $versionRoot = Join-Path $packageRoot "$name/4.1.0"
            Get-ChildItem -LiteralPath $versionRoot -Force |
                Move-Item -Destination (Split-Path -Parent $versionRoot)
            Remove-Item -LiteralPath $versionRoot -Force
        }
        $expectedVersion = & $script:updateModule {
            ConvertFrom-PscxSemanticVersion -Version '4.1.0'
        }

        {
            & $script:updateModule {
                param($Root, $ExpectedVersion)
                Test-PscxPackageCandidate -PackageRoot $Root -ExpectedVersion $ExpectedVersion
            } $packageRoot $expectedVersion
        } | Should -Throw '*outside its version directory*'
    }

    It 'reports an incompatible PowerShell baseline without importing the package' {
        $packageRoot = Join-Path $TestDrive 'incompatible'
        Get-PscxUpdateTestPackage -Root $packageRoot -RequiredPowerShellVersion '99.0'
        $expectedVersion = & $script:updateModule {
            ConvertFrom-PscxSemanticVersion -Version '4.1.0'
        }

        $package = & $script:updateModule {
            param($Root, $ExpectedVersion)
            Test-PscxPackageCandidate -PackageRoot $Root -ExpectedVersion $ExpectedVersion
        } $packageRoot $expectedVersion

        $package.Compatible | Should -BeFalse
        $package.IncompatibilityReason | Should -Match 'requires PowerShell 99.0'
    }
}

Describe 'PSCX updater side-by-side transaction behavior' {
    It 'installs all applicable module roots into versioned directories and retains older versions' {
        $packageRoot = Join-Path $TestDrive 'install-package'
        $destination = Join-Path $TestDrive 'Modules'
        Get-PscxUpdateTestPackage -Root $packageRoot
        New-Item -ItemType Directory -Path (Join-Path $destination 'Pscx/3.8.0') -Force | Out-Null
        'old' | Set-Content -LiteralPath (Join-Path $destination 'Pscx/3.8.0/marker.txt')
        $expectedVersion = & $script:updateModule {
            ConvertFrom-PscxSemanticVersion -Version '4.1.0'
        }
        $package = & $script:updateModule {
            param($Root, $ExpectedVersion)
            Test-PscxPackageCandidate -PackageRoot $Root -ExpectedVersion $ExpectedVersion
        } $packageRoot $expectedVersion

        $installed = @(& $script:updateModule {
                param($Package, $Destination)
                Install-PscxPackage -Package $Package -DestinationRoot $Destination
            } $package $destination)

        $installed | Should -HaveCount 3
        Test-Path -LiteralPath (Join-Path $destination 'Pscx/3.8.0/marker.txt') | Should -BeTrue
        foreach ($name in 'Pscx', 'Pscx.Archive', 'Pscx.Time') {
            Test-Path -LiteralPath (Join-Path $destination "$name/4.1.0/$name.psd1") |
                Should -BeTrue
        }
    }

    It 'recovers an interrupted committing transaction without removing older versions' {
        $destination = Join-Path $TestDrive 'RecoveryModules'
        $oldPath = Join-Path $destination 'Pscx/3.8.0'
        $partialPath = Join-Path $destination 'Pscx/4.1.0'
        $transaction = Join-Path $destination ('.pscx-install-' + ('a' * 32))
        New-Item -ItemType Directory -Path $oldPath, $partialPath, $transaction -Force | Out-Null
        'old' | Set-Content -LiteralPath (Join-Path $oldPath 'marker.txt')
        @{ State = 'Committing'; Targets = @('Pscx/4.1.0') } | ConvertTo-Json |
            Set-Content -LiteralPath (Join-Path $transaction 'transaction.json') -Encoding utf8
        if ($IsWindows) {
            $transactionItem = Get-Item -LiteralPath $transaction
            $transactionItem.Attributes = $transactionItem.Attributes -bor [IO.FileAttributes]::Hidden
        }

        & $script:updateModule {
            param($Destination)
            Repair-PscxInterruptedInstall -DestinationRoot $Destination
        } $destination

        Test-Path -LiteralPath $partialPath | Should -BeFalse
        Test-Path -LiteralPath $transaction | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $oldPath 'marker.txt') | Should -BeTrue
    }

    It 'refuses to overwrite an existing version directory' {
        $packageRoot = Join-Path $TestDrive 'collision-package'
        $destination = Join-Path $TestDrive 'CollisionModules'
        Get-PscxUpdateTestPackage -Root $packageRoot
        New-Item -ItemType Directory -Path (Join-Path $destination 'Pscx/4.1.0') -Force | Out-Null
        $expectedVersion = & $script:updateModule {
            ConvertFrom-PscxSemanticVersion -Version '4.1.0'
        }
        $package = & $script:updateModule {
            param($Root, $ExpectedVersion)
            Test-PscxPackageCandidate -PackageRoot $Root -ExpectedVersion $ExpectedVersion
        } $packageRoot $expectedVersion

        {
            & $script:updateModule {
                param($Package, $Destination)
                Install-PscxPackage -Package $Package -DestinationRoot $Destination
            } $package $destination
        } | Should -Throw '*will not overwrite*'
        Test-Path -LiteralPath (Join-Path $destination 'Pscx.Archive/4.1.0') | Should -BeFalse
    }
}

Describe 'PSCX updater confirmation and WhatIf contract' {
    BeforeEach {
        Mock -ModuleName Pscx.Update Get-PscxInstalledVersion {
            @([pscustomobject]@{
                    Version = [pscustomobject]@{
                        Text = '4.0.0'
                        Core = [version]'4.0.0'
                        Prerelease = [string[]] @()
                        BuildMetadata = $null
                        IsPrerelease = $false
                    }
                    Path = '/installed/Pscx.psd1'
                })
        }
        Mock -ModuleName Pscx.Update Get-PscxGitHubRelease {
            @([pscustomobject]@{
                    tag_name = 'v4.1.0'
                    draft = $false
                    prerelease = $false
                    html_url = 'https://example.invalid/releases/v4.1.0'
                    assets = @(
                        [pscustomobject]@{
                            name = 'Pscx-4.1.0.zip'
                            browser_download_url = 'https://example.invalid/Pscx-4.1.0.zip'
                        }
                        [pscustomobject]@{
                            name = 'Pscx-4.1.0.sha256'
                            browser_download_url = 'https://example.invalid/Pscx-4.1.0.sha256'
                        }
                    )
                })
        }
        Mock -ModuleName Pscx.Update Save-PscxReleaseAsset {
            if (-not (Test-Path -LiteralPath $Destination -PathType Container)) {
                throw "Updater did not create validation directory '$Destination'."
            }
            [pscustomobject]@{ ArchivePath = 'test.zip'; ChecksumPath = 'test.sha256' }
        }
        Mock -ModuleName Pscx.Update Test-PscxReleaseChecksum { $true }
        Mock -ModuleName Pscx.Update Expand-PscxSafeArchive {}
        Mock -ModuleName Pscx.Update Test-PscxPackageCandidate {
            [pscustomobject]@{
                Compatible = $true
                IncompatibilityReason = $null
                ModuleVersion = '4.1.0'
                Modules = @()
            }
        }
        Mock -ModuleName Pscx.Update Install-PscxPackage { @('/modules/Pscx/4.1.0') }
    }

    It 'declares high-impact ShouldProcess confirmation' {
        $attribute = (Get-Command Invoke-PscxUpdate).ScriptBlock.Attributes |
            Where-Object { $_ -is [Management.Automation.CmdletBindingAttribute] }
        $attribute.SupportsShouldProcess | Should -BeTrue
        $attribute.ConfirmImpact | Should -Be ([Management.Automation.ConfirmImpact]::High)
    }

    It 'validates and reports WhatIf without invoking installation' {
        $result = Invoke-PscxUpdate -DestinationRoot (Join-Path $TestDrive 'WhatIfModules') -WhatIf

        $result.Status | Should -Be 'WouldInstall'
        $result.AvailableVersion | Should -Be '4.1.0'
        Should -Invoke -ModuleName Pscx.Update Install-PscxPackage -Times 0
    }

    It 'supports check-only discovery without confirmation or installation' {
        $result = Invoke-PscxUpdate -DestinationRoot (Join-Path $TestDrive 'CheckModules') -CheckOnly

        $result.Status | Should -Be 'UpdateAvailable'
        Should -Invoke -ModuleName Pscx.Update Install-PscxPackage -Times 0
    }

    It 'installs after confirmation is explicitly accepted' {
        $result = Invoke-PscxUpdate -DestinationRoot (Join-Path $TestDrive 'InstallModules') -Confirm:$false

        $result.Status | Should -Be 'Installed'
        $result.ImportCommand | Should -Be 'Import-Module Pscx -RequiredVersion 4.1.0 -Force'
        Should -Invoke -ModuleName Pscx.Update Install-PscxPackage -Times 1
    }
}

# SIG # Begin signature block
# MIInmgYJKoZIhvcNAQcCoIInizCCJ4cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDZvUrIkfZ6AY0S
# +H9ZL+HoHtYeyE67HihdaMKZ3G8OxKCCIHEwggWNMIIEdaADAgECAhAOmxiO+dAt
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
# MQ4wDAYKKwYBBAGCNwIBFjAvBgkqhkiG9w0BCQQxIgQgWeqAn4e97/1ntd8hBcNB
# t1ceiLzAMz1Iu+5Yexl7umMwDQYJKoZIhvcNAQEBBQAEggIAP6N2TZWHJMWWvTBJ
# 2PkMuOi03w9fWX0qKBBKKD3dJlmAWJvUqd5fy/yc24hCJewVZfeacGsBXKsInssi
# cyOflF/9EdmNUrfwyx7aqpsSK1ERHWeIbDO7IPfsEOI4PoWf9a/3owedKEq5Z6ns
# W0j9cIx1bU7O/rFS5+Vay7fa9ASVpdYWscN0rnJiMCADJbBvT+5S/wZT8obWhxKO
# ki0VU03ZNWCPdr6P1LRUX6n3XKD8Ay4pvqIm6zoWmwp4AQzo/y7fJBtuo9iYNlQA
# Bo3GAj61IFBH8Bk7Wuxcq2atXZiWJNl0zvCGUot0FLaVYfkH5kKZWAZJ/qaHQdN5
# tgVws/L3+fYvgA0n1fano+Siq/uBAptNVxhqWHCfNxMK3sjZGV3Lhiqw+OilNJ3O
# 1kk+2kP2E7jURXI2ZK6F0XgQfht+Q0rYQqdjFm8pARoRi4n6Kr43u3PC6cXodcMH
# cBfqmUSTcxOJVGsQflSjAwNPd/tqlaSrzeSpzuwjZsNNQlafrQBDgBLHZtc6mQRr
# X9hhMOdkGJ/u2fz5iEUoFR6O9NnyI3ljxtQN154lSWO0WoPo4g/wJiwlDEwNHD9r
# TzvDgDgEi5lILH0f2iONzvFMLp+BFlWKnmaCMNYuL6CGxqJoXwax0CESQWV9xNlI
# UhDfchgY4ei8FxASn8SOi7vOmVahggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8C
# AQEwfTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/
# BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYg
# U0hBMjU2IDIwMjUgQ0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUA
# oGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYw
# ODI4MjEwNTIzWjAvBgkqhkiG9w0BCQQxIgQg7CyMunL4HCXQQlQloellfhRF5KUY
# uKbX4xsGGLeydy4wDQYJKoZIhvcNAQEBBQAEggIAJuVnmz/kILdQjtLMYgxKHujY
# xvctHwZx2izmWrcT09ebIlipyk+y7qmrc2P2qqBvr7avbekTFzE0czhW5dmPizhI
# Zl3JgG4oz/oC2jO3Sx2/zoRdQvqML+RKZdaaVckKcxB7+4hZ4+kSkwCH9UDKUBZF
# ipW0Ox4ll0XAdxXm1xha8e3N5g8zH22ETdyDIWIwTWwgeic2M/pFt55CdMUT9eUa
# a/mJ3Yn9nQqcDOMXWFfm5aAcoh0y7Xh/Kys4btlB0x0LXpPpRKC/o1VeaV5cJhcY
# 1IBQMho4eAvtM7omFfqm9ylTEZnUxiVbpz+Q1GfthSaWAIg1F4hnxx1LDmaBmGk7
# ErfCeZmbwbG3deDPx4qstndZY3mU8XlCiyAZ6cXQBU1pVsdHBAWNyc9kQkSHpnJS
# UVkjGG4W9apcSixrsNI2uJoYl0fcwgg2I5WtnPCDkjcUh/JTtSA37hM9+0hriPDU
# o+hAPryYbxluZPkSNNS5xI+wWT9jE++zjy5Ad1cf9uyfQLuesHH10GJ0FbXeopDT
# MVJc05Nx0N8MuwQePg4CRh5p57ePFPAq2aRERjgM/DjxP7v66slkDT8dX6Qd12IV
# 8MNpX7TUm+SgIAKrMxtnUkRRcKuPLJXp2zysCCAvwGszr6kw19+96RS/zFGGlsaa
# oW4714JmThw9yqLuBu4=
# SIG # End signature block
