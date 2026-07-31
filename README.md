# Pscx - PowerShell Community Extensions Light

This PowerShell module provides a broadly useful set of additional cmdlets,
providers, aliases, filters, functions, and scripts for PowerShell.

This repository is a lightweight fork of the
[PowerShell Community Extensions](https://github.com/Pscx/Pscx), based on
upstream commit
[`698efdf0`](https://github.com/Pscx/Pscx/commit/698efdf0ba9cb29b326eb93e4a25ac841cc302dd).

The customizations made in this fork include:

- current development version 3.8.0 targeting .NET 10 and the PowerShell 7.6 SDK;
- a cross-platform core for Windows, macOS, and Linux, with a Windows companion
  module for platform-specific commands;
- modern .NET SDK/Visual Studio 2022-compatible projects;
- packaging and build improvements;
- removal of a number of obsolete or low-value commands;
- a GitHub Actions build.

> [!NOTE]
> The 3.8 development branch requires PowerShell 7.6 LTS and .NET 10. The
> repository currently builds against PowerShell SDK 7.6.4. Published releases
> may have different requirements from the current development branch.

## Release notes

See [CHANGELOG.md](CHANGELOG.md) for detailed release information.

## Roadmap

See the [PSCX modernization plan](PSCX_MODERNIZATION_PLAN.md) for the proposed
stabilization work, unified test strategy, documentation migration, package
boundaries, and PSCX 4.0 direction.

Repository contributors and coding agents should also read
[AGENTS.md](AGENTS.md) for collaboration, review, testing, and commit policy.

## License

PSCX is licensed under the MIT license. This work includes other open-source
projects licensed under their respective licenses. See [LICENSE](LICENSE) and
the [Imports](Imports/) folder for the applicable license files.

## Install Pscx

### Pre-requisites

- Install a PowerShell version compatible with the PSCX release you are using.
  The current development branch targets PowerShell 7.6 and .NET 10.
- A PowerShell profile is optional. Add `Import-Module Pscx` to a profile only
  if PSCX should load in every interactive session.

### Installation

1. Download the package from the
   [latest GitHub release](https://github.com/danluca/Pscx/releases/latest).
2. If the download is a GitHub artifact wrapper, extract it first to obtain
   `Pscx-{version}.zip`.
3. Extract the module into a directory listed in `$env:PSModulePath`. Common
   current-user locations are:
   - Windows: `~/Documents/PowerShell/Modules`
   - macOS/Linux: `~/.local/share/powershell/Modules`
4. Import and verify the module:

   ```powershell
   Import-Module Pscx
   Get-Module Pscx
   ```

## Maintainers

@danluca and other maintainers of this GitHub repository.

## Developer guidance

### Build, test, and package

Use the repository entry point from any working directory:

```powershell
./build.ps1 -Task CI
```

`CI` performs a clean restore, compile, managed regression test, package, help
generation, and package validation. Individual operations can also be run when
their prerequisites already exist:

```powershell
./build.ps1 -Task Restore,Compile
./build.ps1 -Task Test
./build.ps1 -Task Package,Validate
./build.ps1 -Task Audit
```

`-BuildScope Auto` selects a Full build on Windows and a Core build elsewhere.
Use `-BuildScope Full` for the complete Windows package or `-BuildScope Core`
for the cross-platform projects and package. Full builds are intentionally
Windows-only.

Build output is written beneath the ignored `artifacts` directory. Pass
`-ArtifactsPath` to use another directory. `Test` currently runs the reliable
NodaTime arithmetic regression slice. `TestAll` exposes the full legacy NUnit
suite, whose environment-dependent tests remain scheduled for classification
and migration in Phase 2.

The maintainer-controlled semantic version is `PscxVersionPrefix` in
`Directory.Build.props`. Local stable builds use that value directly. CI adds
`ci.<run-number>` to prerelease package and manifest metadata, puts the run
number in `FileVersion`, and adds the run number plus short commit SHA to
informational metadata. Source manifests intentionally contain `0.0.0`; staged
package manifests are stamped without rewriting tracked source files.

The minimum supported PowerShell and build SDK versions are also centralized in
`Directory.Build.props`. CI builds and packages on Windows, Ubuntu, and macOS,
then imports each platform package in fresh jobs using both the minimum and
current PowerShell versions. Each import job publishes command counts, warnings,
and import duration as JSON. NuGet packages are cached; compiled and packaged
output is not.

### Compiled C# cmdlets

Required annotations:

- `Cmdlet`, using the appropriate `PscxVerbs` and `PscxNouns` constants for the
  containing module. Plain strings interfere with the repository tooling.
- `Description`, containing a summary of what the cmdlet accomplishes.
- Optionally, `DetailedDescription` for additional context.

Place a new C# cmdlet in the OS appropriate project - `Pscx` for cross-platform, `Pscx.Win` for Windows specific. `Pscx.Core` is a framework level library that both `Pscx` and `Pscx.Win` projects depend upon; it is not intended to contain exportable cmdlets but their base classes and utilities. 

When this OS based functionality separation is not self evident and a class is not entirely cross-platform nor OS specific, at a minimum do annotate the functions that are OS specific with `SupportedOSPlatform` attribute. Refactoring the design where the OS specific classes extend a basic common functionality is encouraged.

Under the current build, new compiled cmdlets also require a corresponding help
file in `Pscx.Help`. The modernization plan proposes replacing that legacy
generator with Markdown and PlatyPS.


### Tooling

Several conveniences are made available in support of release process:

- `build.ps1` is the local and CI entry point for restoring, compiling, testing,
  packaging, validating, auditing, and preparing release artifacts.
- `Tools/find_cmdlets.ps1` reports cmdlets and functions throughout the solution
  and assists with manifest and documentation maintenance.

## Included cmdlets and functions

The following is the current manually maintained catalog. It may include optional
submodules and is scheduled to become generated/validated as part of the
modernization work. Use `Get-Command -Module Pscx` after import for the
authoritative commands available on the current platform and configuration. Use
`Get-Help <command> -Full` for installed help and examples.

# Cmdlets

## PSCX core module

This assembly is intended to be cross-platform. The foreground-window commands
listed below currently use Windows APIs; moving them into the Windows companion
module is tracked in the modernization plan.

### Set-FileTime
Sets a file or folder's created and last accessed/write times.

### Edit-File
Edit file with configured editor - VSCode, Notepad++/TextMate, default for OS

### Test-Assembly
Tests whether or not the specified file is a .NET assembly.

### Get-EnvironmentBlock
Get the current environment block

### ConvertFrom-Base64
Converts base64 encoded string to byte array.

### Test-Xml
Tests for well formedness and optionally validates against XML Schema.

### ConvertTo-WindowsLineEnding
Converts the line endings in the specified file to Windows line endings \"\\r\\n\".

### Convert-Xml
Converts XML through a XSL

### Get-TypeName
Get type name as conveniently detailed information

### Get-PathVariable
Gets the specified path-like environment variable, defaults to PATH

### Get-LoremIpsum
Generates a lorem-ipsum text of specified length

### Skip-Object
Skips an object - similar with LINQ Skip() method, allows the user to skip the first N and/or last N objects in a sequence

### Get-PEHeader
Get the Portable Executable file header

### Get-PscxHash
Gets the hash value for the specified file or byte array via the pipeline.

### ConvertTo-Unit
Converts a measurement from one unit into another (compatible) unit.

### ConvertTo-UnixLineEnding
Converts the line endings in the specified file to Unix line endings \"\\n\".

### Set-ForegroundWindow
Given an hWnd or window handle, brings that window to the foreground on Windows.
See also `Get-ForegroundWindow`.

### Get-ForegroundWindow
Returns the hWnd or handle of the foreground window on the current Windows
desktop. See also `Set-ForegroundWindow`.

### Test-Script
Test script for validity

### Get-DriveInfo
Get drive information

### Format-Xml
Pretty print for XML files and XmlDocument objects.

### Push-EnvironmentBlock
Pushes the current environment frame onto stack

### Get-FileVersionInfo
Get the file version information

### Pop-EnvironmentBlock
Pops the environment block frame from the stack

### ConvertTo-MacOs9LineEnding
Converts the line endings in the specified file to Mac OS9 and earlier style line endings \"\\r\".

### Format-Byte
Format the byte sizes in human readable forms - progressively increasing the unit based on byte size value

### Get-FileTail
Tails the contents of a file - optionally waiting on new content.

### ConvertTo-Base64
Converts byte array to base64 string.

### Split-PscxString
Splits a single string into an array of strings.

### Add-PathVariable
Adds values to an environment variable of type PATH (default is PATH variable)

### Set-PathVariable
Sets/overrides a path-like variable (defaults to PATH) to the value specified

### Format-Hex
Displays contents of files for byte streams in hex.

### Join-PscxString
Joins an array of strings into a single string.

## PSCX Windows companion module

The Windows companion assembly and its applicable optional submodules are loaded
only on Windows.

### Get-MountPoint
Returns all mount points defined for a specific root path.

### Get-AdoDataProvider
Get ADO data provider

### Set-Privilege
Adjusts privileges held by the session.

### Get-SqlDataSet
Query and retrieve SQL data set

### Get-OpticalDriveInfo
Lists Optical drive information

### Disconnect-TerminalSession
Disconnects a specific remote desktop session on a system running Terminal Services/Remote Desktop

### Invoke-SqlCommand
Invokes sql commands on Sql Server database

### Remove-ReparsePoint
Removes NTFS reparse junctions and symbolic links.

### Write-PscxArchive
Creates Archives using 7zip library - supports all types 7zip does

### New-Junction
Creates NTFS directory junctions.

### Get-Privilege
Lists privileges held by the session and their current status.

### New-Hardlink
Creates filesystem hard links. The hardlink and the target must reside on the same NTFS volume.

### Get-ReparsePoint
Gets NTFS reparse point data.

### Get-DomainController
Finds the domain controller

### Set-VolumeLabel
Modifies the label shown in Windows Explorer for a particular disk volume.

### Get-PscxUptime
Get the amount of time the system was up

### Test-UserGroupMembership
Check group membership for the requested user identity

### Get-RunningObject
Retrieves currently running COM object

### Invoke-AdoCommand
Invokes an ADO command

### Remove-MountPoint
Removes a mount point, dismounting the current media if any. If used against the root of a fixed drive, removes the drive letter assignment.

### Get-PscxADObject
Search for objects in the Active Directory/Global Catalog.

### Get-TerminalSession
Get the terminal session

### Get-ShortPath
Gets the short, 8.3 name for the given path.

### Read-PscxArchive
List the contents of an archive - all types supported by 7zip

### Stop-TerminalSession
Logs off a specific remote desktop session on a system running Terminal Services/Remote Desktop

### Get-OleDbDataSet
Retrieve data set through an OLE-DB connection

### Get-AdoConnection
Get an ADO connection

### Expand-PscxArchive
Extract Archives using 7zip library - supports all types 7zip does

### Invoke-OleDbCommand
Invoke commands on OleDb datasources

### Get-OleDbData
Retrieves DB data through an OLE-DB connection

### Get-SqlData
Query and retrieves SQL data

### Invoke-Apartment
Invokes using apartment threading model

### Get-DhcpServer
Gets a list of authorized DHCP servers.

### New-Symlink
Creates filesystem symbolic links. Requires Microsoft Windows 7 or later.

### New-Shortcut
Creates shell shortcuts.

### ConvertFrom-Yaml
Converts a YAML file or string into object graph; navigate graph with dot notation. Comments are not retained.

### ConvertTo-Yaml
Converts an object graph - suitable for YAML representation - into YAML string or file.

# Functions

Some function submodules are optional. Their defaults are defined in
`Pscx.UserPreferences.ps1` and can be overridden when importing PSCX.

## Cross-platform

### CD submodule

- `Set-PscxLocation`

### FileSystem submodule

Disabled by default:

- `Add-DirectoryLength`
- `Add-ShortPath`

### TranscribeSession submodule

Disabled by default for security and privacy:

- `Search-Transcript`

### Utility submodule

- `AddAccelerator`
- `RemoveAccelerator`
- `PscxHelp`
- `PscxLess`
- `Edit-Profile`
- `Edit-HostProfile`
- `Resolve-ErrorRecord`
- `QuoteList`
- `QuoteString`
- `Invoke-GC`
- `Get-ViewDefinition`
- `Get-ScreenCss`
- `Get-ScreenHtml`
- `Invoke-Method`
- `Set-Writable`
- `Set-FileAttributes`
- `Set-ReadOnly`
- `Show-Tree`
- `Get-Parameter`
- `Get-ExecutionTime`
- `AddRegex`

## Windows only

### Functions loaded by the Windows companion module

- `Resolve-HResult`
- `Resolve-WindowsError`
- `Invoke-BatchFile`
- `Stop-RemoteProcess`
- `Import-VisualStudioVars`

### Sudo submodule

- `gsudo`
- `Invoke-Gsudo`
- `Test-IsGsudoCacheAvailable`
- `Test-IsProcessElevated`
- `Test-IsAdminMember`

### VHD submodule

Disabled by default:

- `Mount-PscxVHD`
- `Dismount-PscxVHD`

### WMI submodule

Disabled by default. This submodule registers type accelerators and does not add
a distinct public function beyond the shared accelerator helpers.
