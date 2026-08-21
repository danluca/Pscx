@{
    SchemaVersion = 1
    Status = 'Complete'

    Groups = @(
        @{
            Name = 'Path environment editing'
            Commands = @('Add-PathVariable', 'Get-PathVariable', 'Remove-PathVariable', 'Set-PathVariable')
            Differentiation = 'Treats path-like environment variables as ordered entries across process, user, and machine targets.'
        }
        @{
            Name = 'Environment frames'
            Commands = @('Get-EnvironmentBlock', 'Push-EnvironmentBlock', 'Pop-EnvironmentBlock')
            Differentiation = 'Snapshots and restores the process environment as a stack with descriptions.'
        }
        @{
            Name = 'Assembly and PE inspection'
            Commands = @('Get-PEHeader', 'Test-Assembly')
            Differentiation = 'Provides pipeline-oriented assembly validation and structured portable-executable metadata.'
        }
        @{
            Name = 'XML tooling'
            Commands = @('Convert-Xml', 'Format-Xml', 'Test-Xml')
            Differentiation = 'Combines XSL transformation, readable formatting, and schema-aware validation with pipeline and path input.'
        }
        @{
            Name = 'Units and byte formatting'
            Commands = @('ConvertTo-Unit', 'Format-Byte')
            Differentiation = 'Provides reusable measurement objects and concise human-readable byte formatting.'
        }
        @{
            Name = 'Base64 conversion'
            Commands = @('ConvertFrom-Base64', 'ConvertTo-Base64')
            Differentiation = 'Adds pipeline aggregation, file IO, chunking, encoding choices, and whitespace-tolerant decoding around Base64 conversion.'
        }
        @{
            Name = 'Line-ending conversion'
            Commands = @('ConvertTo-UnixLineEnding', 'ConvertTo-WindowsLineEnding')
            Differentiation = 'Performs in-place, wildcard-aware line-ending conversion with ShouldProcess support.'
        }
        @{
            Name = 'Editors and file times'
            Commands = @('Edit-File', 'Edit-HostProfile', 'Edit-Profile', 'Set-FileTime')
            Differentiation = 'Centralizes configured editor launching and pipeline-friendly timestamp mutation.'
        }
        @{
            Name = 'Filesystem inspection'
            Commands = @('Add-DirectoryLength', 'Get-DriveInfo', 'Get-FileVersionInfo')
            Differentiation = 'Adds directory sizes and exposes drive and executable-version metadata as objects.'
        }
        @{
            Name = 'PowerShell metadata and invocation'
            Commands = @('AddAccelerator', 'AddRegex', 'Get-Parameter', 'Get-TypeName', 'Get-ViewDefinition', 'Invoke-Method', 'RemoveAccelerator')
            Differentiation = 'Surfaces PowerShell metadata and controlled reflection while retaining established accelerator and regex-library conveniences.'
        }
        @{
            Name = 'History and quoting conveniences'
            Commands = @('Get-ExecutionTime', 'QuoteList', 'QuoteString')
            Differentiation = 'Provides typed history timing and concise interactive argument construction.'
        }
        @{
            Name = 'File attributes'
            Commands = @('Set-FileAttributes', 'Set-ReadOnly', 'Set-Writable')
            Differentiation = 'Offers wildcard and literal path support, pipeline binding, ShouldProcess, and optional pass-through objects for attributes.'
        }
        @{
            Name = 'Navigation and tree display'
            Commands = @('Set-PscxLocation', 'Show-Tree')
            Differentiation = 'Adds FIFO location history and provider-aware hierarchical display.'
        }
        @{
            Name = 'Pipeline partitioning'
            Commands = @('Skip-Object')
            Differentiation = 'Supports first, last, and indexed pipeline exclusion in a single streaming command.'
        }
        @{
            Name = 'Error inspection'
            Commands = @('Resolve-ErrorRecord')
            Differentiation = 'Exposes structured invocation and nested-exception details with an explicit text compatibility mode.'
        }
        @{
            Name = 'Script parsing'
            Commands = @('Test-Script')
            Differentiation = 'Wraps the modern PowerShell parser for path and pipeline input with Boolean and structured diagnostic modes.'
        }
        @{
            Name = 'Windows elevation and paging'
            Commands = @('gsudo', 'Invoke-Gsudo', 'PscxLess', 'Test-IsAdminMember', 'Test-IsGsudoCacheAvailable', 'Test-IsProcessElevated')
            Differentiation = 'Bundles established Windows elevation and paging utilities with PowerShell-aware wrappers and status checks.'
        }
        @{
            Name = 'Windows storage integration'
            Commands = @('Get-MountPoint', 'Get-OpticalDriveInfo', 'Get-ReparsePoint', 'Get-ShortPath', 'New-Shortcut', 'Remove-MountPoint', 'Remove-ReparsePoint', 'Set-VolumeLabel')
            Differentiation = 'Exposes Windows mount, reparse-point, optical-media, short-path, shortcut, and volume-label APIs through PowerShell objects.'
        }
        @{
            Name = 'Windows security'
            Commands = @('Get-Privilege', 'Set-Privilege', 'Test-UserGroupMembership')
            Differentiation = 'Provides direct token-privilege inspection and mutation plus explicit identity group checks.'
        }
        @{
            Name = 'Windows desktop and COM'
            Commands = @('Get-RunningObject', 'Invoke-Apartment', 'Set-ForegroundWindow')
            Differentiation = 'Supports COM running-object access, apartment-specific execution, and foreground-window control.'
        }
        @{
            Name = 'Windows sessions and processes'
            Commands = @('Get-TerminalSession', 'Stop-RemoteProcess', 'Stop-TerminalSession')
            Differentiation = 'Provides Terminal Services session objects and targeted remote process/session termination.'
        }
        @{
            Name = 'Windows environment and error decoding'
            Commands = @('Import-VisualStudioVars', 'Resolve-HResult', 'Resolve-WindowsError')
            Differentiation = 'Imports Visual Studio build environments and translates native Windows error identifiers.'
        }
    )

    OutputContracts = @{
        'Add-DirectoryLength' = 'The input DirectoryInfo with a Length note property.'
        'Add-PathVariable' = 'No success output.'
        'AddAccelerator' = 'No success output; conflicts produce a warning.'
        'AddRegex' = 'No success output.'
        'Convert-Xml' = 'System.String containing transformed XML.'
        'ConvertFrom-Base64' = 'System.Byte[] unless writing directly to a file.'
        'ConvertTo-Base64' = 'System.String unless writing directly to a file.'
        'ConvertTo-Unit' = 'Pscx.SimpleUnits.Measurement.'
        'ConvertTo-UnixLineEnding' = 'No success output.'
        'ConvertTo-WindowsLineEnding' = 'No success output.'
        'Edit-File' = 'System.IO.FileInfo only with PassThru.'
        'Edit-HostProfile' = 'No success output from the wrapper.'
        'Edit-Profile' = 'No success output from the wrapper.'
        'Format-Byte' = 'System.String intended for display.'
        'Format-Xml' = 'System.String containing formatted XML.'
        'Get-DriveInfo' = 'System.IO.DriveInfo.'
        'Get-EnvironmentBlock' = 'Pscx.EnvironmentBlock.EnvironmentFrame.'
        'Get-ExecutionTime' = 'Pscx.Commands.Modules.Utility.ExecutionTimeInfo.'
        'Get-FileVersionInfo' = 'System.Diagnostics.FileVersionInfo.'
        'Get-MountPoint' = 'Pscx.Win.Fwk.IO.Ntfs.LinkReparsePointInfo.'
        'Get-OpticalDriveInfo' = 'Pscx.Win.Commands.IO.ImageMastering.OpticalDriveInfo.'
        'Get-Parameter' = 'System.Management.Automation.ParameterMetadataEx.'
        'Get-PathVariable' = 'System.String for each ordered path entry.'
        'Get-PEHeader' = 'Pscx.Reflection.PEHeader.'
        'Get-Privilege' = 'Pscx.Win.Interop.Security.Privileges.TokenPrivilegeCollection.'
        'Get-ReparsePoint' = 'Pscx.Win.Fwk.IO.Ntfs.ReparsePointInfo, or System.Byte[] with Raw.'
        'Get-RunningObject' = 'System.Management.Automation.PSObject wrapping each COM object.'
        'Get-ShortPath' = 'System.String.'
        'Get-TerminalSession' = 'Pscx.Win.Fwk.TerminalServices.TerminalSession.'
        'Get-TypeName' = 'System.Management.Automation.PSObject describing input type names.'
        'Get-ViewDefinition' = 'Pscx.Commands.Modules.Utility.ViewDefinition.'
        'gsudo' = 'Output from the elevated native command; type depends on that command.'
        'Import-VisualStudioVars' = 'Environment mutation plus any text emitted by the selected vendor batch file.'
        'Invoke-Apartment' = 'Objects emitted by the supplied script block.'
        'Invoke-Gsudo' = 'Deserialized objects emitted by the elevated script block.'
        'Invoke-Method' = 'The invoked method return value, whose type depends on the method.'
        'New-Shortcut' = 'System.IO.FileInfo for the created shortcut.'
        'Pop-EnvironmentBlock' = 'No success output.'
        'PscxLess' = 'No output in ConsoleHost; otherwise passes input objects through.'
        'Push-EnvironmentBlock' = 'No success output.'
        'QuoteList' = 'Each supplied argument as an individual pipeline object.'
        'QuoteString' = 'System.String formed using the current output-field separator.'
        'Remove-MountPoint' = 'No success output.'
        'Remove-PathVariable' = 'No success output.'
        'Remove-ReparsePoint' = 'No success output.'
        'RemoveAccelerator' = 'No success output; missing names produce a warning.'
        'Resolve-ErrorRecord' = 'Pscx.ErrorRecordDetail by default, or System.String with AsText.'
        'Resolve-HResult' = 'System.String.'
        'Resolve-WindowsError' = 'System.String.'
        'Set-FileAttributes' = 'System.IO.FileSystemInfo only with PassThru.'
        'Set-FileTime' = 'System.IO.FileInfo only with PassThru.'
        'Set-ForegroundWindow' = 'No success output; failure produces a warning.'
        'Set-PathVariable' = 'No success output.'
        'Set-Privilege' = 'No success output.'
        'Set-PscxLocation' = 'PathInfo with PassThru; stack display is text; preference-enabled listing emits child items.'
        'Set-ReadOnly' = 'System.IO.FileSystemInfo only with PassThru.'
        'Set-VolumeLabel' = 'System.Boolean reporting native API success.'
        'Set-Writable' = 'System.IO.FileSystemInfo only with PassThru.'
        'Show-Tree' = 'System.String display lines.'
        'Skip-Object' = 'The unskipped pipeline objects, preserving their types.'
        'Stop-RemoteProcess' = 'No success output.'
        'Stop-TerminalSession' = 'No success output.'
        'Test-Assembly' = 'System.Boolean.'
        'Test-IsAdminMember' = 'System.Boolean.'
        'Test-IsGsudoCacheAvailable' = 'System.Boolean.'
        'Test-IsProcessElevated' = 'System.Boolean.'
        'Test-Script' = 'System.Boolean by default, or Pscx.Commands.ScriptTestResult with PassThru.'
        'Test-UserGroupMembership' = 'System.Boolean.'
        'Test-Xml' = 'System.Boolean.'
    }

    OutputMetadataExceptions = @{
        'Add-PathVariable' = 'Intentional silent mutator.'
        'AddAccelerator' = 'Intentional silent session mutator.'
        'AddRegex' = 'Intentional silent session mutator.'
        'ConvertTo-UnixLineEnding' = 'Intentional in-place mutator.'
        'ConvertTo-WindowsLineEnding' = 'Intentional in-place mutator.'
        'Edit-HostProfile' = 'Intentional editor-launch wrapper with no success object.'
        'Edit-Profile' = 'Intentional editor-launch wrapper with no success object.'
        'gsudo' = 'Native-style wrapper whose output type is selected by the invoked command.'
        'Import-VisualStudioVars' = 'Environment mutator that may relay vendor batch-file text.'
        'Pop-EnvironmentBlock' = 'Intentional silent environment mutator.'
        'Push-EnvironmentBlock' = 'Intentional silent environment mutator.'
        'QuoteList' = 'Legacy arbitrary-argument helper that preserves each argument type.'
        'QuoteString' = 'Legacy arbitrary-argument helper implemented through automatic args.'
        'Remove-MountPoint' = 'Intentional silent mutator.'
        'Remove-PathVariable' = 'Intentional silent mutator.'
        'Remove-ReparsePoint' = 'Intentional silent mutator.'
        'RemoveAccelerator' = 'Intentional silent session mutator.'
        'Set-ForegroundWindow' = 'Intentional silent desktop mutator.'
        'Set-PathVariable' = 'Intentional silent mutator.'
        'Set-Privilege' = 'Intentional silent security mutator.'
        'Set-PscxLocation' = 'Context-dependent modes intentionally have no single output type.'
        'Stop-RemoteProcess' = 'Intentional silent process mutator.'
        'Stop-TerminalSession' = 'Intentional silent session mutator.'
    }

    NamingExceptions = @{
        'AddAccelerator' = 'Retained legacy public name; a 4.0 rename would add migration cost without improving discoverability enough.'
        'AddRegex' = 'Retained legacy public name paired with the RegexLib session object.'
        'gsudo' = 'Matches the bundled native utility name and syntax.'
        'PscxLess' = 'Matches the established PSCX pager integration name.'
        'QuoteList' = 'Retained interactive compatibility helper.'
        'QuoteString' = 'Retained interactive compatibility helper.'
        'RemoveAccelerator' = 'Retained as the established counterpart to AddAccelerator.'
    }

    CommonParameterExceptions = @{
        'gsudo' = 'Must preserve native-style arbitrary option forwarding without PowerShell consuming common-parameter names.'
        'QuoteList' = 'Must preserve automatic-args behavior for arbitrary interactive tokens.'
        'QuoteString' = 'Must preserve automatic-args behavior for arbitrary interactive tokens.'
    }

    LiteralPathExceptions = @{
        'Set-VolumeLabel' = 'Path identifies a volume root for a native API and is not a wildcard-capable provider path.'
    }

    OptionalCommands = @{
        'Add-DirectoryLength' = 'Modules/FileSystem/Pscx.FileSystem.psd1'
    }
}
