@{
    RootModule = 'Pscx.WinAdmin.psm1'
    ModuleVersion = '0.0.0'
    GUID = 'e0fa4ac2-c919-4453-8d6e-af55e8b70fb4'
    Author = 'PowerShell Core Community Extensions Team'
    CompanyName = 'PowerShell Core Community Extensions'
    Copyright = 'Copyright © 2005-2026 Keith Hill, Oisin Grehan, Dan Luca, and contributors'
    Description = 'Optional Windows administration commands for PSCX.'
    PowerShellVersion = '0.0'
    CompatiblePSEditions = @('Core')
    NestedModules = @('Pscx.WinAdmin.dll')
    FunctionsToExport = @('Add-ShortPath', 'Invoke-BatchFile')
    CmdletsToExport = @(
        'Get-AdoConnection'
        'Get-AdoDataProvider'
        'Get-ForegroundWindow'
        'Get-OleDbData'
        'Get-OleDbDataSet'
        'Invoke-AdoCommand'
        'Invoke-OleDbCommand'
    )
    AliasesToExport = @()
    VariablesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('PSCX', 'Windows', 'Administration', 'ADO', 'OleDb')
            LicenseUri = 'https://github.com/danluca/Pscx/blob/master/LICENSE'
            ProjectUri = 'https://github.com/danluca/Pscx'
            # Prerelease = ''
            ReleaseNotes = "See CHANGELOG.md in the module root."
        }
    }
}
