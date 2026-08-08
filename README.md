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
> PSCX 3.8 requires a PowerShell 7.6 LTS release (`7.6.x`) and .NET 10. The
> build accepts PowerShell 7.6.0 as its minimum and currently compiles against
> PowerShell SDK 7.6.4. PowerShell 7.7 and later are outside the 3.8 support
> contract until they are validated explicitly. Published PSCX releases may
> have different requirements from the current development branch.

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

- Install PowerShell 7.6 LTS (`7.6.x`) for the current PSCX 3.8 development
  branch. PSCX 3.8 targets .NET 10 and does not support Windows PowerShell 5.1.
- A PowerShell profile is optional. Add `Import-Module Pscx` to a profile only
  if PSCX should load in every interactive session.

### Installation

1. Download the package from the
   [latest GitHub release](https://github.com/danluca/Pscx/releases/latest),
   together with its `.sha256` checksum file. GitHub Releases are the supported
   distribution channel; PSCX is not published to PowerShell Gallery.
2. Verify the ZIP against the matching entry in the checksum file:

   ```powershell
   Get-FileHash ./Pscx-3.8.0.zip -Algorithm SHA256
   Get-Content ./Pscx-3.8.0.sha256
   ```

3. Extract the ZIP into a directory listed in `$env:PSModulePath`. Common
   current-user locations are:
   - Windows: `~/Documents/PowerShell/Modules`
   - macOS/Linux: `~/.local/share/powershell/Modules`
4. Import and verify the module:

   ```powershell
   Import-Module Pscx
   Get-Module Pscx
   ```

The release ZIP includes local offline help. PSCX does not configure
`Update-Help` or publish separate online help packages.

### Platform support

PSCX 3.8 supports Windows, Linux, and macOS. The default package selects its
platform-aware payload during import:

- The PSCX core assembly and the functions under **Cross-platform** below are
  supported on all three operating systems, except for the foreground-window
  commands called out in the catalog.
- The PSCX Windows companion assembly, commands under **Windows only**, YAML
  commands and accelerators, gsudo integration, and optional VHD/WMI modules
  are available only on Windows.
- Optional submodules are controlled through `ModulesToImport` in
  `Pscx.UserPreferences.ps1` or an import argument. Their default state is
  shown in the catalog.

## Maintainers

@danluca and other maintainers of this GitHub repository.

## Developer guidance

### Build, test, and package

Use the repository entry point from any working directory:

```powershell
./build.ps1 -Task CI
```

`CI` performs a clean restore, compile, package/help generation, the unified
managed and Pester test suites, coverage collection, and package validation.
`TestPipeline` runs the same release-blocking path explicitly. Individual
operations can also be run when their prerequisites already exist:

```powershell
./build.ps1 -Task TestPipeline
./build.ps1 -Task Restore,Compile
./build.ps1 -Task Test
./build.ps1 -Task Pester
./build.ps1 -Task Package,Catalog,Validate -BuildScope Full
./build.ps1 -Task Package,Validate -BuildScope Core
./build.ps1 -Task Audit
```

`-BuildScope Auto` selects a Full build on Windows and a Core build elsewhere.
Use `-BuildScope Full` for the complete Windows package or `-BuildScope Core`
for the cross-platform projects and package. Full builds are intentionally
Windows-only.

Build output is written beneath the ignored `artifacts` directory. Pass
`-ArtifactsPath` to use another directory. `Test` runs the cross-platform,
pure-logic `Pscx.InternalTests` project. `Pester` starts a clean PowerShell
process and tests the staged package. Their TRX, NUnit, Cobertura, framework
summaries, and combined status are written beneath `artifacts/test-results`.
The pinned Pester version and separate coverage gates are defined in
`Tests/TestPolicy.psd1`; Pester is saved beneath ignored `.tools` output and is
not redistributed. `TestAll` exposes the non-release-blocking
`Pscx.LegacyTests` suite while its remaining fixtures are migrated or removed.
See `Tests/MANAGED_TEST_INVENTORY.md` for their classifications.

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

Place a new C# cmdlet in the OS-appropriate project: `Pscx` for cross-platform
commands and `Pscx.Win` for Windows-specific commands. `Pscx.Core` is a
framework-level library shared by both projects; it contains base classes and
utilities rather than exportable cmdlets.

When this OS based functionality separation is not self evident and a class is not entirely cross-platform nor OS specific, at a minimum do annotate the functions that are OS specific with `SupportedOSPlatform` attribute. Refactoring the design where the OS specific classes extend a basic common functionality is encouraged.

Add or update compiled-command help under `docs/commands/Pscx` or
`docs/commands/Pscx.Win`. The build pins `Microsoft.PowerShell.PlatyPS`,
validates the Markdown against the packaged command metadata, and generates
offline MAML beneath the package's `en-US` directory. Public script functions
continue to use their single authoritative comment-based help source.


### Tooling

Several conveniences are made available in support of release process:

- `build.ps1` is the local and CI entry point for restoring, compiling, testing,
  packaging, validating, auditing, and preparing release artifacts.
- `Tools/Update-PscxReadmeCatalog.ps1` generates the public API tables from a
  Full packaged module. Use `./build.ps1 -Task Catalog` after packaging; the
  Windows static CI gate fails when the committed catalog is stale.

### Release artifacts and local signing

`./build.ps1 -Task CI,PublishPrep` validates installation from the completed
ZIP in an isolated module path, generates an SPDX 2.2 SBOM with the pinned
Microsoft SBOM Tool, and creates SHA-256 checksums. A tagged release workflow
attaches these three files directly to a draft GitHub Release for maintainer
review and publication:

- `Pscx-{version}.zip`;
- `Pscx-{version}.spdx.json`;
- `Pscx-{version}.sha256`.

The CI workflow has no signing credentials and PSCX-built DLLs in its release
artifacts are intentionally Authenticode-unsigned. Maintainers may sign
selected PowerShell source or locally staged files from a Windows workstation:

```powershell
./Tools/SignScripts.ps1 `
    -Path ./Src/Pscx/Modules/Utility `
    -Recurse `
    -CertificateThumbprint '<certificate-thumbprint>' `
    -WhatIf
```

Remove `-WhatIf` only after reviewing the exact file set. The signing tool
requires an explicit certificate thumbprint, validates the code-signing
certificate and timestamp result, excludes `Pscx.UserPreferences.ps1` by
default, and is never invoked by the build or GitHub Actions.

## Public API catalog

The tables between the generated markers come from the Full packaged module's
manifests, runtime exports, command metadata, and installed function help. Run
`./build.ps1 -Task Package,Catalog -BuildScope Full` to update them. CI rejects
stale catalog content.
Commands marked **All** are supported on Windows, Linux, and macOS; commands
marked **Windows** require the Windows companion payload. Use
`Get-Help <command> -Full` for complete installed help and examples.

<!-- BEGIN GENERATED PSCX PUBLIC API -->
<!-- Generated by Tools/Update-PscxReadmeCatalog.ps1. Do not edit this region manually. -->

### Cmdlets (70)

| Command | Platform | Availability | Description |
| --- | --- | --- | --- |
| `Add-PathVariable` | All | Default | Adds values to an environment variable of type PATH (default is PATH variable) |
| `Convert-Xml` | All | Default | Converts XML through a XSL |
| `ConvertFrom-Base64` | All | Default | Converts base64 encoded string to byte array. |
| `ConvertFrom-Yaml` | Windows | Default | Converts YAML string/file to PowerShell structured objects (leverages YamlDotNet library). |
| `ConvertTo-Base64` | All | Default | Converts byte array to base64 string. |
| `ConvertTo-MacOs9LineEnding` | All | Default | Converts the line endings in the specified file to Mac OS9 and earlier style line endings "\r". |
| `ConvertTo-Unit` | All | Default | Converts units into different compatible units - e.g. metric to non-metric, different multiplier, etc. |
| `ConvertTo-UnixLineEnding` | All | Default | Converts the line endings in the specified file to Unix line endings "\n". |
| `ConvertTo-WindowsLineEnding` | All | Default | Converts the line endings in the specified file to Windows line endings "\r\n". |
| `ConvertTo-Yaml` | Windows | Default | Converts YAML document or PowerShell structured objects into YAML file (leverages YamlDotNet library). |
| `Disconnect-TerminalSession` | Windows | Default | Disconnects a specific remote desktop session on a system running Terminal Services/Remote Desktop |
| `Edit-File` | All | Default | Edit file with configured editor - VSCode, Notepad++/TextMate, default for OS |
| `Expand-PscxArchive` | Windows | Default | Extract Archives using 7zip library - supports all types 7zip does |
| `Format-Byte` | All | Default | Format the byte sizes in human readable forms - progressively increasing the unit based on byte size value |
| `Format-Hex` | All | Default | Displays contents of files for byte streams in hex. |
| `Format-Xml` | All | Default | Pretty print for XML files and XmlDocument objects. |
| `Get-AdoConnection` | Windows | Default | Get an ADO connection |
| `Get-AdoDataProvider` | Windows | Default | Get ADO data provider |
| `Get-DhcpServer` | Windows | Default | Gets a list of authorized DHCP servers. |
| `Get-DomainController` | Windows | Default | Finds the domain controller |
| `Get-DriveInfo` | All | Default | Get drive information |
| `Get-EnvironmentBlock` | All | Default | Get the current environment block |
| `Get-FileTail` | All | Default | Tails the contents of a file - optionally waiting on new content. |
| `Get-FileVersionInfo` | All | Default | Get the file version information |
| `Get-ForegroundWindow` | Windows | Default | Returns the hWnd or handle of the window in the foreground on the current desktop. See also Set-ForegroundWindow. |
| `Get-LoremIpsum` | All | Default | Generates a lorem-ipsum text of specified length |
| `Get-MountPoint` | Windows | Default | Returns all mount points defined for a specific root path. |
| `Get-OleDbData` | Windows | Default | Retrieves DB data through an OLE-DB connection |
| `Get-OleDbDataSet` | Windows | Default | Retrieve data set through an OLE-DB connection |
| `Get-OpticalDriveInfo` | Windows | Default | Lists Optical drive information |
| `Get-PathVariable` | All | Default | Gets the specified path-like environment variable, defaults to PATH |
| `Get-PEHeader` | All | Default | Get the Portable Executable file header |
| `Get-Privilege` | Windows | Default | Lists privileges held by the session and their current status. |
| `Get-PscxADObject` | Windows | Default | Search for objects in the Active Directory/Global Catalog. |
| `Get-PscxHash` | All | Default | Gets the hash value for the specified file or byte array via the pipeline. |
| `Get-PscxUptime` | Windows | Default | Get the amount of time the system was up |
| `Get-ReparsePoint` | Windows | Default | Gets NTFS reparse point data. |
| `Get-RunningObject` | Windows | Default | Retrieves currently running COM object |
| `Get-ShortPath` | Windows | Default | Gets the short, 8.3 name for the given path. |
| `Get-SqlData` | Windows | Default | Query and retrieves SQL data |
| `Get-SqlDataSet` | Windows | Default | Query and retrieve SQL data set |
| `Get-TerminalSession` | Windows | Default | Get the terminal session |
| `Get-TypeName` | All | Default | Get type name as conveniently detailed information |
| `Invoke-AdoCommand` | Windows | Default | Invokes an ADO command |
| `Invoke-Apartment` | Windows | Default | Invokes using apartment threading model |
| `Invoke-OleDbCommand` | Windows | Default | Invoke commands on OleDb datasources |
| `Invoke-SqlCommand` | Windows | Default | Invokes sql commands on Sql Server database |
| `Join-PscxString` | All | Default | Joins an array of strings into a single string. |
| `New-Hardlink` | Windows | Default | Creates filesystem hard links. The hardlink and the target must reside on the same NTFS volume. |
| `New-Junction` | Windows | Default | Creates NTFS directory junctions. |
| `New-Shortcut` | Windows | Default | Creates shell shortcuts. |
| `New-Symlink` | Windows | Default | Creates filesystem symbolic links. Requires Microsoft Windows 7 or later. |
| `Pop-EnvironmentBlock` | All | Default | Pops the environment block frame from the stack |
| `Push-EnvironmentBlock` | All | Default | Pushes the current environment frame onto stack |
| `Read-PscxArchive` | Windows | Default | List the contents of an archive - all types supported by 7zip |
| `Remove-MountPoint` | Windows | Default | Removes a mount point, dismounting the current media if any. If used against the root of a fixed drive, removes the drive letter assignment. |
| `Remove-ReparsePoint` | Windows | Default | Removes NTFS reparse junctions and symbolic links. |
| `Set-FileTime` | All | Default | Sets a file or folder's created and last accessed/write times. |
| `Set-ForegroundWindow` | Windows | Default | Given an hWnd or window handle, brings that window to the foreground. Useful for restoring a window to uppermost after an application which seizes the foreground is invoked. See also Get-ForegroundWindow |
| `Set-PathVariable` | All | Default | Sets/overrides a path-like variable (defaults to PATH) to the value specified |
| `Set-Privilege` | Windows | Default | Adjusts privileges held by the session. |
| `Set-VolumeLabel` | Windows | Default | Modifies the label shown in Windows Explorer for a particular disk volume. |
| `Skip-Object` | All | Default | Skips an object - similar with LINQ Skip() method, allows the user to skip the first N and/or last N objects in a sequence |
| `Split-PscxString` | All | Default | Splits a single string into an array of strings. |
| `Stop-TerminalSession` | Windows | Default | Logs off a specific remote desktop session on a system running Terminal Services/Remote Desktop |
| `Test-Assembly` | All | Default | Tests whether or not the specified file is a .NET assembly. |
| `Test-Script` | All | Default | Test script for validity |
| `Test-UserGroupMembership` | Windows | Default | Check group membership for the requested user identity |
| `Test-Xml` | All | Default | Tests for well formedness and optionally validates against XML Schema. |
| `Write-PscxArchive` | Windows | Default | Creates Archives using 7zip library - supports all types 7zip does |

### Functions (36)

| Command | Platform | Availability | Description |
| --- | --- | --- | --- |
| `Add-DirectoryLength` | All | Optional (FileSystem) | Calculates the sizes of the specified directory and adds that size as a "Length" NoteProperty to the input DirectoryInfo object. |
| `Add-ShortPath` | All | Optional (FileSystem) | Adds the file or directory's short path as a "ShortPath" NoteProperty to each input object. |
| `AddAccelerator` | All | Default | Adds a PowerShell type accelerator without replacing an existing accelerator. |
| `AddRegex` | All | Default | Adds a named regular-expression pattern to the PSCX RegexLib object. |
| `Dismount-PscxVHD` | Windows | Optional (Vhd) | Dismounts a Virtual Hard Drive (VHD) file. |
| `Edit-HostProfile` | All | Default | Opens the current user's profile for the current host in a text editor. |
| `Edit-Profile` | All | Default | Opens the current user's "all hosts" profile in a text editor. |
| `Get-ExecutionTime` | All | Default | Gets the execution time for the specified Id of a command in the current session history. |
| `Get-Parameter` | All | Default | Enumerates the parameters of one or more commands. |
| `Get-ScreenCss` | All | Default | Generate CSS header for HTML "screen shot" of the host buffer. |
| `Get-ScreenHtml` | All | Default | Functions to generate HTML "screen shot" of the host buffer. |
| `Get-ViewDefinition` | All | Default | Gets the possible alternate views for the specified object. |
| `gsudo` | Windows | Default | gsudo is a sudo for windows. It allows to run a command/ScriptBlock with elevated permissions. If no command is specified, it starts an elevated Powershell session. |
| `Import-VisualStudioVars` | Windows | Default | Imports environment variables for the specified version of Visual Studio. |
| `Invoke-BatchFile` | Windows | Default | Invokes the specified batch file and retains any environment variable changes it makes. |
| `Invoke-GC` | All | Default | Invokes the .NET garbage collector to clean up garbage objects. |
| `Invoke-Gsudo` | Windows | Default | Executes a ScriptBlock in a new elevated instance of powershell, using `gsudo`. |
| `Invoke-Method` | All | Default | Calls a single method on an incoming stream of piped objects. |
| `Mount-PscxVHD` | Windows | Optional (Vhd) | Mounts a Virtual Hard Drive (VHD) file. |
| `PscxHelp` | All | Default | Displays PowerShell help using PSCX pager behavior. |
| `PscxLess` | All | Default | PscxLess provides better paging of output from cmdlets. |
| `QuoteList` | All | Default | Convenience function for creating an array of strings without requiring quotes or commas. |
| `QuoteString` | All | Default | Creates a string from each parameter by concatenating each item using $OFS as the separator. |
| `RemoveAccelerator` | All | Default | Removes a PowerShell type accelerator when it exists. |
| `Resolve-ErrorRecord` | All | Default | Resolves the PowerShell error code to a textual description of the error. |
| `Resolve-HResult` | Windows | Default | Resolves the hresult error code to a textual description of the error. |
| `Resolve-WindowsError` | Windows | Default | Resolves a Windows error number a textual description of the error. |
| `Set-FileAttributes` | All | Default | Updates file or folder attributes. |
| `Set-PscxLocation` | All | Default | Set-PscxLocation function that tracks location history allowing easy navigation to previous locations. |
| `Set-ReadOnly` | All | Default | Sets a file's read only status to true making it read only. |
| `Set-Writable` | All | Default | Sets a file's read only status to false making it writable. |
| `Show-Tree` | All | Default | Shows the specified path as a tree. |
| `Stop-RemoteProcess` | Windows | Default | Stops a process on a remote machine. |
| `Test-IsAdminMember` | Windows | Default | The function Test-IsAdminMember checks if the currently logged-in user is a member of the local administrators group, regardless of the elevation level of the current process. |
| `Test-IsGsudoCacheAvailable` | Windows | Default | Tests whether the gsudo credentials cache is available. |
| `Test-IsProcessElevated` | Windows | Default | Tests if the user is an administrator *and* the current proces is elevated. |

### Aliases (23)

| Alias | Target | Platform | Availability |
| --- | --- | --- | --- |
| `call` | `Pscx\Invoke-Method` | All | Default |
| `cd` | `Pscx\Set-PscxLocation` | All | Default |
| `cvxml` | `Pscx\Convert-Xml` | All | Default |
| `e` | `Pscx\Edit-File` | All | Default |
| `ehp` | `Pscx\Edit-HostProfile` | All | Default |
| `ep` | `Pscx\Edit-Profile` | All | Default |
| `fhex` | `Pscx\Format-Hex` | All | Default |
| `fxml` | `Pscx\Format-Xml` | All | Default |
| `gpar` | `Pscx\Get-Parameter` | All | Default |
| `gtn` | `Pscx\Get-TypeName` | All | Default |
| `igc` | `Pscx\Invoke-GC` | All | Default |
| `ln` | `Pscx\New-HardLink` | Windows | Default |
| `lorem` | `Pscx\Get-LoremIpsum` | All | Default |
| `ql` | `Pscx\QuoteList` | All | Default |
| `qs` | `Pscx\QuoteString` | All | Default |
| `rver` | `Pscx\Resolve-ErrorRecord` | All | Default |
| `rvhr` | `Pscx\Resolve-HResult` | Windows | Default |
| `rvwer` | `Pscx\Resolve-WindowsError` | Windows | Default |
| `skip` | `Pscx\Skip-Object` | All | Default |
| `sro` | `Pscx\Set-ReadOnly` | All | Default |
| `swr` | `Pscx\Set-Writable` | All | Default |
| `tail` | `Pscx\Get-FileTail` | All | Default |
| `touch` | `Pscx\Set-FileTime` | All | Default |

### Providers (3)

| Provider | Platform |
| --- | --- |
| `AssemblyCache` | Windows |
| `DirectoryServices` | Windows |
| `PscxSettings` | All |

<!-- END GENERATED PSCX PUBLIC API -->

## Type accelerators

Importing the default Utility submodule registers the following accelerators
in the PowerShell session. As with all PowerShell type accelerators, these are
session-global registrations and currently remain registered after PSCX is
removed from the session.

| Accelerator | Backing type or purpose | Platform/default |
| --- | --- | --- |
| `[accelerators]` | PowerShell's internal type-accelerator registry | All; default |
| `[json]` | Serialize a value as indented JSON | All; default |
| `[hex]` | Convert supported scalar, string, array, or object values to hexadecimal | All; default |
| `[base64]`, `[b64]` | Convert supported values to Base64 | All; default |
| `[isodate]` | Format and parse ISO-oriented date/time values | All; default |
| `[zonedtime]` | `Pscx.Time.ZonedDateTime` | All; default |
| `[offsettime]` | `Pscx.Time.OffsetDateTime` | All; default |
| `[localtime]` | `Pscx.Time.LocalDateTime` | All; default |
| `[tz]` | `NodaTime.DateTimeZone` | All; default |
| `[tzi]` | `System.TimeZoneInfo` | All; default |
| `[yaml]`, `[yml]` | Serialize a value as YAML | Windows; default Windows companion import |
| `[wmidatetime]` | Convert WMI date/time values | Windows; optional WMI submodule |
| `[wmitimespan]` | Convert WMI time-span values | Windows; optional WMI submodule |
