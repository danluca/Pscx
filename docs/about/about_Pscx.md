# about_Pscx

## Short description

PowerShell Community Extensions (PSCX) adds broadly useful commands, providers,
aliases, functions, and scripts to PowerShell.

## Long description

PSCX is a community-maintained PowerShell module. This lightweight fork keeps a
cross-platform core and loads a Windows companion payload when running on
Windows. It is not affiliated with Microsoft or the PowerShell team.

Use `Get-Command -Module Pscx` to inspect the commands available in the current
session. Use `Get-Help <command> -Full` for detailed offline command help. The
repository README contains the generated command catalog and indicates platform
and optional-feature availability.

## Compatibility

PSCX 3.8 requires PowerShell 7.6 LTS and .NET 10. Windows PowerShell 5.1 is not
supported. The core payload supports Windows, Linux, and macOS; Windows-only
commands and integrations are loaded only on Windows.

## Import and preferences

Import PSCX with the default preferences:

```powershell
Import-Module Pscx
```

Override individual preferences by passing a hashtable as the import argument:

```powershell
Import-Module Pscx -ArgumentList @{ ModulesToImport = @{ FileSystem = $true } }
```

For a larger set of customizations, copy `Pscx.UserPreferences.ps1`, edit the
copy, and pass its path as the import argument. Unspecified values continue to
use the defaults built into PSCX.

The `ModulesToImport` preference controls optional feature modules. Some
optional modules are unavailable outside Windows. The default configuration
keeps directory services, filesystem extensions, transcription, VHD, and WMI
features disabled.

## Help and command discovery

List commands available in the current session:

```powershell
Get-Command -Module Pscx
```

Show full help for a command:

```powershell
Get-Help ConvertTo-Base64 -Full
```

Show this topic again:

```powershell
Get-Help about_Pscx
```

## Feedback

Report defects and enhancement requests at
https://github.com/danluca/Pscx/issues.

## Related links

- https://github.com/danluca/Pscx
- https://github.com/danluca/Pscx/blob/master/README.md
