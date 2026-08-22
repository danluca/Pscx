@{
    GUID = '62c9101a-b87e-4a4e-a60f-2dbf2d8ec313'
    Author = 'PowerShell Core Community Extensions Team'
    CompanyName = 'PowerShell Core Community Extensions'
    Copyright = 'Copyright PowerShell Core Community Extensions Team 2006 - 2026.'
    Description = 'Optional cross-platform archive commands for PowerShell Core Community Extensions.'
    # Stamped from Directory.Build.props when the package is assembled.
    PowerShellVersion = '0.0'
    # Stamped from Directory.Build.props when the package is assembled.
    ModuleVersion = '0.0.0'
    CompatiblePSEditions = @('Core')
    RootModule = 'Pscx.Archive.dll'
    RequiredAssemblies = @('SharpCompress.dll')
    CmdletsToExport = @(
        'Expand-PscxArchive'
        'Read-PscxArchive'
        'Write-PscxArchive'
    )
    FunctionsToExport = @()
    AliasesToExport = @()
    VariablesToExport = @()
    FormatsToProcess = @('FormatData/Pscx.Archive.Format.ps1xml')
    TypesToProcess = @('TypeData/Pscx.Archive.Type.ps1xml')
    PrivateData = @{
        PSData = @{
            Tags = @('Utilities', 'Archive', 'CrossPlatform', 'PSCX')
            LicenseUri = 'https://github.com/danluca/Pscx/blob/master/LICENSE'
            ProjectUri = 'https://github.com/danluca/Pscx'
            IconUri = 'https://github.com/danluca/Pscx/blob/master/PscxIcon.png?raw=true'
            # Prerelease = 'preview'
            ReleaseNotes = "See CHANGELOG.md in the module root."
        }
    }
}
