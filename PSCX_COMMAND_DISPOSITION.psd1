@{
    # This is the Phase 5 working inventory, not an approved removal list.
    # A command moves out of Proposed status only after maintainer review.
    SchemaVersion = 1
    Status = 'Proposed'

    Categories = @{
        RetainCore = @(
            'Add-PathVariable'
            'Convert-Xml'
            'ConvertFrom-Base64'
            'ConvertTo-Base64'
            'ConvertTo-Unit'
            'Edit-File'
            'Format-Byte'
            'Format-Xml'
            'Get-EnvironmentBlock'
            'Get-PathVariable'
            'Get-PEHeader'
            'Pop-EnvironmentBlock'
            'Push-EnvironmentBlock'
            'Remove-PathVariable'
            'Resolve-ErrorRecord'
            'Set-FileTime'
            'Set-PathVariable'
            'Set-PscxLocation'
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
            'Get-MountPoint'
            'Get-OleDbData'
            'Get-OleDbDataSet'
            'Get-OpticalDriveInfo'
            'Get-Privilege'
            'Get-PscxADObject'
            'Get-ReparsePoint'
            'Get-RunningObject'
            'Get-ShortPath'
            'Get-SqlData'
            'Get-SqlDataSet'
            'Get-TerminalSession'
            'Import-VisualStudioVars'
            'Invoke-AdoCommand'
            'Invoke-BatchFile'
            'Invoke-OleDbCommand'
            'Invoke-SqlCommand'
            'Mount-PscxVHD'
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

        Review = @(
            'Add-DirectoryLength'
            'AddAccelerator'
            'AddRegex'
            'ConvertTo-UnixLineEnding'
            'ConvertTo-WindowsLineEnding'
            'Edit-HostProfile'
            'Edit-Profile'
            'Get-DriveInfo'
            'Get-ExecutionTime'
            'Get-FileVersionInfo'
            'Get-Parameter'
            'Get-TypeName'
            'Get-ViewDefinition'
            'Invoke-Apartment'
            'Invoke-Method'
            'QuoteList'
            'QuoteString'
            'RemoveAccelerator'
            'Set-FileAttributes'
            'Set-ReadOnly'
            'Set-Writable'
            'Show-Tree'
            'Skip-Object'
        )
    }
}
