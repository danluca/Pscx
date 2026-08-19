@{
    # This is the maintainer-approved Phase 5 command disposition. Module moves
    # and removals remain implementation work and must follow the roadmap.
    SchemaVersion = 1
    Status = 'Approved'

    Categories = @{
        RetainCore = @(
            'Add-DirectoryLength'
            'Add-PathVariable'
            'AddAccelerator'
            'AddRegex'
            'Convert-Xml'
            'ConvertFrom-Base64'
            'ConvertTo-Base64'
            'ConvertTo-Unit'
            'ConvertTo-UnixLineEnding'
            'ConvertTo-WindowsLineEnding'
            'Edit-File'
            'Edit-HostProfile'
            'Edit-Profile'
            'Format-Byte'
            'Format-Xml'
            'Get-DriveInfo'
            'Get-EnvironmentBlock'
            'Get-ExecutionTime'
            'Get-FileVersionInfo'
            'Get-Parameter'
            'Get-PathVariable'
            'Get-PEHeader'
            'Get-TypeName'
            'Get-ViewDefinition'
            'Invoke-Method'
            'Pop-EnvironmentBlock'
            'Push-EnvironmentBlock'
            'QuoteList'
            'QuoteString'
            'Remove-PathVariable'
            'RemoveAccelerator'
            'Resolve-ErrorRecord'
            'Set-FileAttributes'
            'Set-FileTime'
            'Set-PathVariable'
            'Set-PscxLocation'
            'Set-ReadOnly'
            'Set-Writable'
            'Show-Tree'
            'Skip-Object'
            'Test-Assembly'
            'Test-Script'
            'Test-Xml'
        )

        RetainWindowsCore = @(
            'gsudo'
            'Invoke-Gsudo'
            'PscxLess'
            'Test-IsAdminMember'
            'Test-IsGsudoCacheAvailable'
            'Test-IsProcessElevated'
            'Get-MountPoint'
            'Get-OpticalDriveInfo'
            'Get-Privilege'
            'Get-ReparsePoint'
            'Get-RunningObject'
            'Get-ShortPath'
            'Get-TerminalSession'
            'Import-VisualStudioVars'
            'Invoke-Apartment'
            'New-Shortcut'
            'Remove-MountPoint'
            'Remove-ReparsePoint'
            'Resolve-HResult'
            'Resolve-WindowsError'
            'Set-ForegroundWindow'
            'Set-Privilege'
            'Set-VolumeLabel'
            'Stop-RemoteProcess'
            'Stop-TerminalSession'
            'Test-UserGroupMembership'
        )

        MoveToArchive = @(
            'Expand-PscxArchive'
            'Read-PscxArchive'
            'Write-PscxArchive'
        )

        MoveToWindowsAdmin = @(
            'Add-ShortPath'
            'Disconnect-TerminalSession'
            'Dismount-PscxVHD'
            'Get-AdoConnection'
            'Get-AdoDataProvider'
            'Get-DhcpServer'
            'Get-DomainController'
            'Get-ForegroundWindow'
            'Get-OleDbData'
            'Get-OleDbDataSet'
            'Get-PscxADObject'
            'Get-SqlData'
            'Get-SqlDataSet'
            'Invoke-AdoCommand'
            'Invoke-BatchFile'
            'Invoke-OleDbCommand'
            'Invoke-SqlCommand'
            'Mount-PscxVHD'
        )

        MoveToCrossPlatformCore = @(
            'ConvertFrom-Yaml'
            'ConvertTo-Yaml'
        )

        DeprecationCandidate = @(
            'ConvertTo-MacOs9LineEnding'
            'Format-Hex'
            'Get-FileTail'
            'Get-LoremIpsum'
            'Get-PscxHash'
            'Get-PscxUptime'
            'Get-ScreenCss'
            'Get-ScreenHtml'
            'Invoke-GC'
            'Join-PscxString'
            'New-Hardlink'
            'New-Junction'
            'New-Symlink'
            'PscxHelp'
            'Split-PscxString'
        )

    }
}
