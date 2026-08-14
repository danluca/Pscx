@{
    # PSCX aliases are created when their names are available. Existing commands
    # are preserved unless OverrideExistingAliases is enabled; Pscx.CD always
    # replaces cd when that submodule is selected.
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
