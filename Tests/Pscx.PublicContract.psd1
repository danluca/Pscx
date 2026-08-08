@{
    # The root and Utility manifests still use wildcard alias exports. Keep the
    # small alias/provider baseline here until Phase 4 makes those exports explicit.
    Aliases = @{
        Core = @(
            'call',
            'cd',
            'cvxml',
            'e',
            'ehp',
            'ep',
            'fhex',
            'fxml',
            'gpar',
            'gtn',
            'igc',
            'lorem',
            'ql',
            'qs',
            'rver',
            'skip',
            'sro',
            'swr',
            'tail',
            'touch'
        )
        Full = @('ln', 'rvhr', 'rvwer')
    }
    Providers = @{
        Core = @('PscxSettings')
        Full = @('AssemblyCache', 'DirectoryServices')
    }
    Platforms = @{
        # Script functions cannot carry SupportedOSPlatformAttribute metadata.
        # Keep the exceptional Windows-only functions here until their module
        # placement makes the platform boundary self-describing.
        WindowsOnlyCommands = @(
            'Invoke-BatchFile',
            'Stop-RemoteProcess'
        )
    }
    OptionalFeatures = @{
        Core = @(
            @{ Name = 'CD'; ModuleName = 'Pscx.CD' },
            @{ Name = 'FileSystem'; ModuleName = 'Pscx.FileSystem' },
            @{ Name = 'Net'; ModuleName = 'Pscx.Net' },
            @{ Name = 'TranscribeSession'; ModuleName = 'Pscx.TranscribeSession' },
            @{ Name = 'Utility'; ModuleName = 'Pscx.Utility' }
        )
        Full = @(
            @{ Name = 'DirectoryServices'; ModuleName = 'Pscx.DirectoryServices' },
            @{ Name = 'Sudo'; ModuleName = 'Pscx.Sudo' },
            @{ Name = 'Vhd'; ModuleName = 'Pscx.Vhd' },
            @{ Name = 'Wmi'; ModuleName = 'Pscx.Wmi' }
        )
    }
}
