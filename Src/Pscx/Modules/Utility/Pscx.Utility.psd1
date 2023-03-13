@{
    ModuleVersion    = '3.6.4'
    ModuleToProcess  = 'Pscx.Utility.psm1'
    FormatsToProcess = 'Pscx.Utility.Format.ps1xml'
    AliasesToExport = '*'
    FunctionsToExport = @(
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
        'AddRegex'
    )
}
