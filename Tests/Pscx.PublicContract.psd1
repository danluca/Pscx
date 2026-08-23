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
            'fxml',
            'gpar',
            'gtn',
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
        # Windows-only commands now live in platform-specific modules or carry
        # SupportedOSPlatformAttribute metadata, so no catalog exception remains.
        WindowsOnlyCommands = @()
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
            @{ Name = 'Sudo'; ModuleName = 'Pscx.Sudo' }
        )
    }
}
