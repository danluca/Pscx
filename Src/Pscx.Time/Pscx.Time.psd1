@{
    RootModule = 'Pscx.Time.psm1'
    ModuleVersion = '0.0.0'
    GUID = 'd6a39b7e-7b25-47e9-af6b-9b0314575a06'
    Author = 'Dan Luca'
    CompanyName = 'Dan Luca'
    Copyright = 'Copyright © 2026 Dan Luca'
    Description = 'Optional NodaTime-backed types and PowerShell type accelerators for PSCX.'
    PowerShellVersion = '0.0'
    RequiredAssemblies = @('NodaTime.dll', 'Pscx.Time.dll')
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Time', 'DateTime', 'NodaTime', 'Utilities')
            LicenseUri = 'https://github.com/danluca/Pscx/blob/master/LICENSE'
            ProjectUri = 'https://github.com/danluca/Pscx'
            # Prerelease = 'preview'
            ReleaseNotes = "See CHANGELOG.md in the module root."
        }
    }
}
