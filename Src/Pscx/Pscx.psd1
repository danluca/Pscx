@{
    GUID               = '0fab0d39-2f29-4e79-ab9a-fd750c66e6c5'
    Author             = 'PowerShell Core Community Extensions Team'
    CompanyName        = 'PowerShell Core Community Extensions'
    Copyright          = 'Copyright PowerShell Core Community Extensions Team 2006 - 2023.'
    Description        = 'PowerShell Core Community Extensions (PSCX) base module which implements a general purpose set of Cmdlets.'
    PowerShellVersion  = '7.2'
    CLRVersion         = '6.0'
    ModuleVersion      = "3.6.4"
    RequiredAssemblies = 'Pscx.dll' # needed for [pscxmodules] type (does not import cmdlets/providers)
    RootModule         = 'Pscx.psm1'
    NestedModules      = @('Pscx.dll', 'NodaTime.dll')
    AliasesToExport    = '*'
    CmdletsToExport    = @(
        # PSCX main module
        'Join-PscxString',
        'Get-DriveInfo',
        'Format-Byte',
        'ConvertTo-Base64',
        'Format-Xml',
        'Set-ForegroundWindow',
        'Get-ForegroundWindow',
        'Get-LoremIpsum',
        'Format-Hex',
        'Get-PEHeader',
        'Test-Script',
        'Test-Xml',
        'Get-EnvironmentBlock',
        'Get-TypeName',
        'ConvertTo-WindowsLineEnding',
        'Get-FileTail',
        'Get-PathVariable',
        'Pop-EnvironmentBlock',
        'Get-FileVersionInfo',
        'Convert-Xml',
        'ConvertTo-Unit',
        'Set-FileTime',
        'Split-PscxString',
        'ConvertTo-UnixLineEnding',
        'Get-PscxHash',
        'Edit-File',
        'Test-Assembly',
        'Set-PathVariable',
        'Push-EnvironmentBlock',
        'Add-PathVariable',
        'ConvertFrom-Base64',
        'Skip-Object',
        'ConvertTo-MacOs9LineEnding',
        #PSCXWin module
        'Invoke-OleDbCommand',
        'Remove-ReparsePoint',
        'Get-RunningObject',
        'Get-SqlData',
        'Test-UserGroupMembership',
        'Get-DomainController',
        'Get-AdoDataProvider',
        'Get-OleDbData',
        'Write-PscxArchive',
        'Read-PscxArchive',
        'Get-ShortPath',
        'Expand-PscxArchive',
        'Get-AdoConnection',
        'Get-PscxADObject',
        'Get-Privilege',
        'Remove-MountPoint',
        'Get-MountPoint',
        'Invoke-AdoCommand',
        'New-Shortcut',
        'Get-OleDbDataSet',
        'Set-VolumeLabel',
        'New-Hardlink',
        'Get-OpticalDriveInfo',
        'Get-ReparsePoint',
        'Set-Privilege',
        'Invoke-SqlCommand',
        'New-Symlink',
        'New-Junction',
        'Get-PscxUptime',
        'Get-SqlDataSet',
        'Invoke-Apartment',
        'Disconnect-TerminalSession',
        'Stop-TerminalSession',
        'Get-TerminalSession',
        'Get-DhcpServer'    
    )
    FunctionsToExport = @(
        #PSCX.CD
        'Set-PscxLocation',
        #PSCX.FileSystem
        'Add-DirectoryLength',
        'Add-ShortPath',
        #PSCX.Utility
        'AddAccelerator',
        'RemoveAccelerator',
        'PscxHelp',
        'PscxLess',
        'Edit-Profile',
        'Edit-HostProfile',
        'Resolve-ErrorRecord',
        'QuoteList',
        'QuoteString',
        'Invoke-GC',
        'Invoke-BatchFile',
        'Get-ViewDefinition',
        'Stop-RemoteProcess',
        'Get-ScreenCss',
        'Get-ScreenHtml',
        'Invoke-Method',
        'Set-Writable',
        'Set-FileAttributes',
        'Set-ReadOnly',
        'Show-Tree',
        'Get-Parameter',
        'Get-ExecutionTime',
        'AddRegex',
        #PSCX.Vhd
        'Mount-PscxVHD',
        'Dismount-PscxVHD',    
        #PSCXWin
        'Resolve-HResult',
        'Resolve-WindowsError',
        'Import-VisualStudioVars',
        #PSCXWin.Sudo
        'sudo', 
        'invoke-sudo'
    )
    FormatsToProcess   = @(
        'FormatData\Pscx.Environment.Format.ps1xml',
        'FormatData\Pscx.Format.ps1xml',
        'FormatData\Pscx.SIUnits.Format.ps1xml'
    )
    TypesToProcess     = @(
        'TypeData\Pscx.Reflection.Type.ps1xml',
        'TypeData\Pscx.SIUnits.Type.ps1xml'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Utilities','Xml','Base64','PEHeader','CD')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/danluca/Pscx/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/danluca/Pscx'

            # A URL to an icon representing this module.
            IconUri = 'https://github.com/danluca/Pscx/blob/master/PscxIcon.png?raw=true'

            #Prerelease = 'beta4'

            # Release notes
            ReleaseNotes = "See CHANGELOG.md file in PSCX module's root folder"
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}
