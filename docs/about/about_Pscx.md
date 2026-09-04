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

PSCX 4.0 requires PowerShell 7.6 LTS and .NET 10. Windows PowerShell 5.1 is not
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
keeps directory services formatting, filesystem extensions, and transcription
features disabled.

The release ZIP also contains separately imported sibling modules.
`Pscx.Archive` provides cross-platform archive commands, while the Windows-only
`Pscx.WinAdmin` module provides optional ADO/OLE DB, batch-environment,
short-path annotation, and foreground-window commands.

## Help and command discovery

List commands in the default module or discover the explicitly imported
sibling modules:

```powershell
Get-Command -Module Pscx
Get-Module Pscx.Archive, Pscx.Time, Pscx.WinAdmin -ListAvailable
```

Start with a task, then use full command help for details:

```powershell
Get-TextFileInfo -Path ./src/*.cs
Get-PathVariable -Name PATH
Test-Script -Path ./build.ps1 -PassThru
Get-Help ConvertTo-Base64 -Full
```

Import `Pscx.Archive` for cross-platform archive creation, listing, and safe
extraction. Import `Pscx.Time` for the optional NodaTime-backed types. On
Windows, import `Pscx.WinAdmin` for lower-frequency administration commands.

Run the read-only installation diagnostic when behavior differs between
machines:

```powershell
Test-PscxInstallation | Where-Object Status -In Warning, Fail
```

The repository's task-oriented command guide explains when PSCX adds value
over nearby built-in commands. Its generated public API catalog identifies the
platform and availability of every command.

## Migrating to PSCX 4.0

PSCX 4.0 uses explicit exports and collision-aware aliases. Archive commands,
NodaTime types, and lower-frequency Windows administration commands moved to
the `Pscx.Archive`, `Pscx.Time`, and `Pscx.WinAdmin` sibling modules. Commands
superseded by PowerShell, .NET, or maintained Microsoft modules were removed.

Install 4.0 in a versioned module directory beside 3.8 while validating
profiles and automation. See the repository migration guide for the complete
command replacement and behavior-change tables.

## Guided update

The installed `Pscx` module directory contains `Update-Pscx.ps1`. It performs
no work during module import; invoke it explicitly to discover, download,
validate, and optionally install a newer compatible GitHub Release:

```powershell
$updateScript = Join-Path (Get-Module Pscx).ModuleBase 'Update-Pscx.ps1'
& $updateScript -CheckOnly
& $updateScript -WhatIf
& $updateScript
```

Stable releases are selected by default. Use `-IncludePrerelease` to opt into
prerelease versions. The script verifies the release checksum and package before
prompting, installs into versioned module directories, and retains every
existing version for explicit rollback or cleanup.

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
- https://github.com/danluca/Pscx/blob/master/docs/COMMAND_DISCOVERY.md
- https://github.com/danluca/Pscx/blob/master/docs/MIGRATING_TO_4.0.md
