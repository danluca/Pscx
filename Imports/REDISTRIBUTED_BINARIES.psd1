@{
    SchemaVersion = 1

    Components = @(
        @{
            Name = 'gsudo'
            Version = '2.6.0'
            License = 'MIT'
            LicensePaths = @('Imports/gsudo/LICENSE.txt')
            PackageLicensePaths = @('Pscx/Apps/Win/LICENSE_sudo.txt')
            SourceUri = 'https://github.com/gerardog/gsudo/releases/tag/v2.6.0'
            LatestReleaseApiUri = 'https://api.github.com/repos/gerardog/gsudo/releases/latest'
            ExpectedReleaseTag = 'v2.6.0'
            UpdateOwner = 'PSCX maintainer (@danluca)'
            Purpose = 'Windows elevation support exposed by the bundled gsudo integration.'
            Artifacts = @(
                @{
                    SourcePath = 'Imports/gsudo/win/gsudo.exe'
                    Architecture = 'x64'
                    PackagePaths = @(
                        'Pscx/Apps/Win/gsudo.exe'
                        'Pscx/Apps/Win/sudo.exe'
                    )
                    Size = 4264016
                    Sha256 = '21C470D6DEABFBD398349168E18ED1CF261D6C204D7BD12EEB53C846403A0D1A'
                    SignatureStatus = 'Valid'
                    SignerThumbprint = 'AABEBFAAD120BA5DDBD90BD193C2372635660AC6'
                }
            )
        }
        @{
            Name = 'less'
            Version = '678'
            License = 'less upstream license; Windows-port changes under MIT'
            LicensePaths = @(
                'Imports/Less-678/license'
                'Imports/Less-678/LICENSE_win.txt'
            )
            PackageLicensePaths = @(
                'Pscx/Apps/Win/LICENSE_less_orig.txt'
                'Pscx/Apps/Win/LICENSE_less_win.txt'
            )
            SourceUri = 'https://github.com/jftuga/less-Windows/releases/tag/less-v678'
            LatestReleaseApiUri = 'https://api.github.com/repos/jftuga/less-Windows/releases/latest'
            ExpectedReleaseTag = 'less-v678'
            UpdateOwner = 'PSCX maintainer (@danluca)'
            Purpose = 'Windows pager and companion key-binding compiler used by PscxLess.'
            Artifacts = @(
                @{
                    SourcePath = 'Imports/Less-678/less.exe'
                    Architecture = 'x64'
                    PackagePaths = @('Pscx/Apps/Win/less.exe')
                    Size = 442880
                    Sha256 = '09221B709149F69AF280AB3CDFB375B43FE11B1EFB8F3FBD71F612117F6C336A'
                    SignatureStatus = 'NotSigned'
                    SignerThumbprint = $null
                }
                @{
                    SourcePath = 'Imports/Less-678/lesskey.exe'
                    Architecture = 'x64'
                    PackagePaths = @('Pscx/Apps/Win/lesskey.exe')
                    Size = 174080
                    Sha256 = 'DF4F73AD6140EBCE6CCCA99FB3DBF992B4F7A684BEF277A71374100ACE387302'
                    SignatureStatus = 'NotSigned'
                    SignerThumbprint = $null
                }
            )
        }
    )
}
