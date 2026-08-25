# Pscx - PowerShell Community Extensions Light

This PowerShell module provides a broadly useful set of additional cmdlets,
providers, aliases, filters, functions, and scripts for PowerShell.

This repository is a lightweight fork of the
[PowerShell Community Extensions](https://github.com/Pscx/Pscx), based on
upstream commit
[`698efdf0`](https://github.com/Pscx/Pscx/commit/698efdf0ba9cb29b326eb93e4a25ac841cc302dd).

The customizations made in this fork include:

- current development version 4.0.0-preview.1 targeting .NET 10 and the
  PowerShell 7.6 SDK;
- a cross-platform core for Windows, macOS, and Linux, with a Windows companion
  module for platform-specific commands;
- modern .NET SDK/Visual Studio 2022-compatible projects;
- packaging and build improvements;
- removal of a number of obsolete or low-value commands;
- a GitHub Actions build.

> [!NOTE]
> PSCX 4.0 development currently retains the PSCX 3.8 runtime baseline: a
> PowerShell 7.6 LTS release (`7.6.x`) and .NET 10. The build accepts PowerShell
> 7.6.0 as its minimum and currently compiles against PowerShell SDK 7.6.4.
> PowerShell 7.7 and later remain outside the support contract until they are
> validated explicitly. Published PSCX releases may have different requirements
> from the current development branch.

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

- Install PowerShell 7.6 LTS (`7.6.x`) for the current PSCX 4.0 development
  branch. It targets .NET 10 and does not support Windows PowerShell 5.1.
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

The cross-platform release ZIP includes `Pscx`, `Pscx.Archive`, and
`Pscx.Time` as sibling module roots. The Full Windows ZIP also includes
`Pscx.WinAdmin`. Install
the desired roots using a versioned layout (`<module-name>/<version>/...`), then import
the optional modules only when needed:

```powershell
Import-Module Pscx.Archive
Get-Command -Module Pscx.Archive

# Optional NodaTime-backed types and accelerators
Import-Module Pscx.Time
[localtime]::now()

# Windows only
Import-Module Pscx.WinAdmin
Get-Command -Module Pscx.WinAdmin
```

The optional archive module is managed-only and cross-platform. PSCX 4.0 uses
SharpCompress 0.50.4 and deliberately does not support encrypted extraction.
`Pscx.Time` provides the NodaTime-backed `isodate`, `zonedtime`,
`offsettime`, `localtime`, `tz`, and `tzi` accelerators without adding
NodaTime to the default module payload.
`Pscx.WinAdmin` contains nine lower-frequency Windows commands for generic
ADO/OLE DB access, foreground-window inspection, short-path annotation, and
retaining environment changes from arbitrary batch files. Importing `Pscx`
does not load any optional sibling module.

The [redistributed binary inventory](docs/security/REDISTRIBUTED_BINARIES.md)
documents the exact retained Windows executables, provenance, checksums,
ownership, package-size reporting, and release security checks. Each build
writes its exact module file counts and uncompressed sizes to
`artifacts/test-results/Pscx.PackageContents.json`.

The release ZIP includes local offline help. PSCX does not configure
`Update-Help` or publish separate online help packages.

### Replacements for removed Windows administration commands

PSCX 4.0 removes command groups that are superseded by maintained Microsoft
modules. Install only the Windows capabilities or module needed by the machine:

```powershell
# Run the Windows capability/feature commands from an elevated session.
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
Add-WindowsCapability -Online -Name Rsat.DHCP.Tools~~~~0.0.1.0
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell

# SQL tooling can be installed for the current user.
Install-PSResource -Name SqlServer -Repository PSGallery -Scope CurrentUser -TrustRepository
```

| Removed PSCX commands | Maintained replacement |
| --- | --- |
| `Get-PscxADObject`, `Get-DomainController` | ActiveDirectory module: `Get-ADObject`, `Get-ADDomainController` |
| `Get-DhcpServer` | DhcpServer module: `Get-DhcpServerInDC` |
| `Get-SqlData`, `Get-SqlDataSet`, `Invoke-SqlCommand` | SqlServer module: `Invoke-Sqlcmd` and its structured-output commands |
| `Mount-PscxVHD`, `Dismount-PscxVHD` | Hyper-V module: `Mount-VHD`, `Dismount-VHD` |

PSCX 4.0 also removes low-value duplicates from the default command surface:

| Removed PSCX command or feature | Replacement |
| --- | --- |
| `ConvertTo-MacOs9LineEnding` | Use an editor or targeted text conversion when this legacy format is genuinely required. |
| `Format-Hex` | Built-in `Format-Hex` |
| `Get-LoremIpsum` | Use a dedicated test-data or text-generation module. |
| `Get-PscxUptime` | Built-in `Get-Uptime` |
| `Join-PscxString` | Built-in `Join-String` |
| `Split-PscxString` | The `-split` operator or .NET string APIs |
| `Invoke-GC` | Allow .NET garbage collection to run automatically. |
| `PscxHelp` | Built-in `Get-Help` or `help`; use `PscxLess` explicitly when paging is desired. |
| `Get-ScreenCss`, `Get-ScreenHtml` | `ConvertTo-Html`, terminal capture, or a dedicated reporting tool |
| Optional `Pscx.Wmi` module (`GetDhcpServer`, `GetWin32Processes`, and WMI accelerators) | DhcpServer module commands, `Get-CimInstance -ClassName Win32_Process`, and native `DateTime`/`TimeSpan` values |

`Get-FileTail`, `New-Hardlink`, `New-Symlink`, and Windows-only
`New-Junction` remain as thin convenience functions. They delegate to
`Get-Content -Tail`/`-Wait` and `New-Item -ItemType` respectively. The former
custom `Get-FileTail -LineTerminator` behavior is not retained; use
`Get-Content -Raw` and explicit string processing for nonstandard delimiters.

See Microsoft's installation guidance for
[RSAT](https://learn.microsoft.com/en-us/windows-server/administration/install-remote-server-administration-tools),
[the SqlServer module](https://learn.microsoft.com/en-us/powershell/sql-server/download-sql-server-ps-module),
and [Hyper-V management tools](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/get-started/install-hyper-v).

### PATH management

`Get-PathVariable`, `Add-PathVariable`, `Set-PathVariable`, and
`Remove-PathVariable` manage `PATH` and other path-oriented environment
variables without treating the value as an opaque string. Mutations preserve
entry order and remove duplicates. Use `-Normalize` for canonical absolute
paths and `-Validate` to remove entries that do not currently resolve to a file
or directory; add `-RetainUnavailable` when disconnected or optional paths
must remain.

Path comparison follows the operating system: case-insensitive on Windows and
case-sensitive on Linux and macOS. Specify `-CaseInsensitive` to opt into
case-insensitive comparison on Unix systems. Process-scoped variables work on
all supported platforms; persistent `User` and `Machine` targets are Windows
only.

Mutation commands support `-WhatIf` and `-PassThru`. The returned
`PathVariableChange` object describes the before and after values and the
added, removed, retained, invalid, and duplicate entries:

```powershell
$change = Add-PathVariable -Value "$HOME/.local/bin" -Normalize -PassThru -WhatIf
$change | Select-Object Name, Target, Changed, Applied, Added, Invalid, Duplicate
```

### Alias collision policy

PSCX creates its convenience aliases when their names do not already resolve
to an alias, function, cmdlet, or native application. This preserves native
Unix commands such as `tail` and `touch`, along with any aliases or functions
defined by the user. Prefer full, module-qualified command names in scripts:

```powershell
Pscx\Get-FileTail -Path ./application.log -Count 20
Pscx\Set-FileTime -Path ./output.txt -Time (Get-Date)
Pscx\New-Hardlink -Path ./copy.txt -Target ./original.txt
```

To deliberately give PSCX aliases precedence over existing commands, enable
the override preference during import:

```powershell
Import-Module Pscx -ArgumentList @{ OverrideExistingAliases = $true }
```

`cd` is the deliberate exception. Enabling the CD submodule always replaces
PowerShell's `cd` alias with `Set-PscxLocation`, which adds PSCX's enhanced
FIFO location-stack navigation. Disable the CD submodule to retain the
built-in behavior. The built-in `help` command is never replaced. The complete
alias-to-command mapping appears in the generated catalog below.

### Platform support

PSCX 4.0 supports Windows, Linux, and macOS. The default package selects its
platform-aware payload during import:

- The PSCX core assembly and the functions under **Cross-platform** below are
  supported on all three operating systems, except for the foreground-window
  commands called out in the catalog.
- The PSCX Windows companion assembly, commands under **Windows only**, and
  gsudo integration are available only on Windows.
- YAML commands and the `yaml`/`yml` type accelerators are part of the
  cross-platform core.
- The separately imported `Pscx.Archive` module provides archive creation,
  listing, and safe extraction on all three operating systems.
- The separately imported `Pscx.Time` module provides the optional
  NodaTime-backed date/time types and accelerators on all three operating
  systems.
- The separately imported `Pscx.WinAdmin` module provides the optional
  Windows administration commands described above.
- Optional submodules are controlled through `ModulesToImport` in
  `Pscx.UserPreferences.ps1` or an import argument. Their default state is
  shown in the catalog.

### Text-file diagnostics and line endings

`Get-TextFileInfo` reports a file's detected encoding, byte-order mark (BOM),
line-ending style and counts, mixed-line-ending state, and final-newline state.
Detection is intentionally conservative: BOM-less ASCII and valid UTF-8 are
recognized, while ambiguous encodings are reported as `Unknown`.

The explicit `ConvertTo-UnixLineEnding` and
`ConvertTo-WindowsLineEnding` commands preserve the source encoding, BOM, and
final-newline state by default. Use `-FinalNewline Add` or
`-FinalNewline Remove` to choose a final-newline policy. For CI checks, use
`-Check` without a destination; it writes nothing and returns structured
results with `NeedsConversion`:

```powershell
ConvertTo-UnixLineEnding -Path ./src/*.cs -Check |
    Where-Object NeedsConversion
```

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

The build requires a stable .NET 10 SDK. `global.json` accepts installed
10.0.x feature bands and rejects preview or later-major SDKs.

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

Place a new C# cmdlet in the project matching its package boundary: `Pscx` for
cross-platform commands, `Pscx.Win` for default Windows commands, and
`Pscx.WinAdmin` for the separately imported Windows administration surface.
`Pscx.Time` owns optional NodaTime-backed types but intentionally exports no
commands.
`Pscx.Core` is a framework-level library shared by these projects; it contains
base classes and utilities rather than exportable cmdlets.

When this OS based functionality separation is not self evident and a class is not entirely cross-platform nor OS specific, at a minimum do annotate the functions that are OS specific with `SupportedOSPlatform` attribute. Refactoring the design where the OS specific classes extend a basic common functionality is encouraged.

Add or update compiled-command help under `docs/commands/Pscx`,
`docs/commands/Pscx.Win`, `docs/commands/Pscx.Archive`, or
`docs/commands/Pscx.WinAdmin`. The build pins `Microsoft.PowerShell.PlatyPS`,
validates the Markdown against the packaged command metadata, and generates
offline MAML beneath the package's `en-US` directory. Public script functions
continue to use their single authoritative comment-based help source.
`docs/about/about_Pscx.Time.md` is the authoritative source for the optional
accelerator module's offline about topic.


### Tooling

Several conveniences are made available in support of release process:

- `build.ps1` is the local and CI entry point for restoring, compiling, testing,
  packaging, validating, auditing, and preparing release artifacts.
- `Tools/Update-PscxReadmeCatalog.ps1` generates the public API tables from a
  Full packaged module. Use `./build.ps1 -Task Catalog` after packaging; the
  Windows static CI gate fails when the committed catalog is stale.

### Release artifacts and local signing

`./build.ps1 -Task CI,PublishPrep` validates every bundled module from the
completed ZIP in isolated module paths, generates an SPDX 2.2 SBOM with the pinned
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

### Cmdlets (46)

| Command | Platform | Availability | Description |
| --- | --- | --- | --- |
| `Add-PathVariable` | All | Default | Adds values to an environment variable of type PATH (default is PATH variable) |
| `Convert-Xml` | All | Default | Converts XML through a XSL |
| `ConvertFrom-Base64` | All | Default | Converts base64 encoded string to byte array. |
| `ConvertFrom-Yaml` | All | Default | Converts YAML string/file to PowerShell structured objects (leverages YamlDotNet library). |
| `ConvertTo-Base64` | All | Default | Converts byte array to base64 string. |
| `ConvertTo-Unit` | All | Default | Converts units into different compatible units - e.g. metric to non-metric, different multiplier, etc. |
| `ConvertTo-UnixLineEnding` | All | Default | Converts the line endings in the specified file to Unix line endings "\n". |
| `ConvertTo-WindowsLineEnding` | All | Default | Converts the line endings in the specified file to Windows line endings "\r\n". |
| `ConvertTo-Yaml` | All | Default | Converts YAML document or PowerShell structured objects into YAML file (leverages YamlDotNet library). |
| `Disconnect-TerminalSession` | Windows | Default | Disconnects a remote desktop session while preserving its programs for later reconnection |
| `Edit-File` | All | Default | Edit file with configured editor - VSCode, Notepad++/TextMate, default for OS |
| `Format-Byte` | All | Default | Format the byte sizes in human readable forms - progressively increasing the unit based on byte size value |
| `Format-Xml` | All | Default | Pretty print for XML files and XmlDocument objects. |
| `Get-DriveInfo` | All | Default | Get drive information |
| `Get-EnvironmentBlock` | All | Default | Get the current environment block |
| `Get-FileVersionInfo` | All | Default | Get the file version information |
| `Get-MountPoint` | Windows | Default | Returns all mount points defined for a specific root path. |
| `Get-OpticalDriveInfo` | Windows | Default | Lists Optical drive information |
| `Get-PathVariable` | All | Default | Gets the specified path-like environment variable, defaults to PATH |
| `Get-PEHeader` | All | Default | Get the Portable Executable file header |
| `Get-Privilege` | Windows | Default | Lists privileges held by the session and their current status. |
| `Get-PscxHash` | All | Default | Gets the hash value for the specified file or byte array via the pipeline. |
| `Get-ReparsePoint` | Windows | Default | Gets NTFS reparse point data. |
| `Get-RunningObject` | Windows | Default | Retrieves currently running COM object |
| `Get-ShortPath` | Windows | Default | Gets the short, 8.3 name for the given path. |
| `Get-TerminalSession` | Windows | Default | Get the terminal session |
| `Get-TextFileInfo` | All | Default | Reports a text file's encoding, byte-order mark, line endings, and final-newline state. |
| `Get-TypeName` | All | Default | Get type name as conveniently detailed information |
| `Invoke-Apartment` | Windows | Default | Invokes using apartment threading model |
| `New-Shortcut` | Windows | Default | Creates shell shortcuts. |
| `Pop-EnvironmentBlock` | All | Default | Pops the environment block frame from the stack |
| `Push-EnvironmentBlock` | All | Default | Pushes the current environment frame onto stack |
| `Remove-MountPoint` | Windows | Default | Removes a mount point, dismounting the current media if any. If used against the root of a fixed drive, removes the drive letter assignment. |
| `Remove-PathVariable` | All | Default | Removes values from an environment variable of type PATH (default is PATH variable) |
| `Remove-ReparsePoint` | Windows | Default | Removes NTFS reparse junctions and symbolic links. |
| `Set-FileTime` | All | Default | Sets a file or folder's created and last accessed/write times. |
| `Set-ForegroundWindow` | Windows | Default | Given an hWnd or window handle, brings that window to the foreground. Useful for restoring a window to uppermost after an application which seizes the foreground is invoked. See also Get-ForegroundWindow in Pscx.WinAdmin |
| `Set-PathVariable` | All | Default | Sets/overrides a path-like variable (defaults to PATH) to the value specified |
| `Set-Privilege` | Windows | Default | Adjusts privileges held by the session. |
| `Set-VolumeLabel` | Windows | Default | Modifies the label shown in Windows Explorer for a particular disk volume. |
| `Skip-Object` | All | Default | Skips an object - similar with LINQ Skip() method, allows the user to skip the first N and/or last N objects in a sequence |
| `Stop-TerminalSession` | Windows | Default | Logs off a remote desktop session and closes the programs running in it |
| `Test-Assembly` | All | Default | Tests whether or not the specified file is a .NET assembly. |
| `Test-Script` | All | Default | Test script for validity |
| `Test-UserGroupMembership` | Windows | Default | Check group membership for the requested user identity |
| `Test-Xml` | All | Default | Tests for well formedness and optionally validates against XML Schema. |

### Functions (32)

| Command | Platform | Availability | Description |
| --- | --- | --- | --- |
| `Add-DirectoryLength` | All | Optional (FileSystem) | Calculates the sizes of the specified directory and adds that size as a "Length" NoteProperty to the input DirectoryInfo object. |
| `AddAccelerator` | All | Default | Adds a PowerShell type accelerator without replacing an existing accelerator. |
| `AddRegex` | All | Default | Adds a named regular-expression pattern to the PSCX RegexLib object. |
| `Edit-HostProfile` | All | Default | Opens the current user's profile for the current host in a text editor. |
| `Edit-Profile` | All | Default | Opens the current user's "all hosts" profile in a text editor. |
| `Get-ExecutionTime` | All | Default | Gets the execution time for the specified Id of a command in the current session history. |
| `Get-FileTail` | All | Default | Returns the last lines of a file and can continue waiting for appended content. |
| `Get-Parameter` | All | Default | Enumerates the parameters of one or more commands. |
| `Get-ViewDefinition` | All | Default | Gets the possible alternate views for the specified object. |
| `gsudo` | Windows | Default | gsudo is a sudo for windows. It allows to run a command/ScriptBlock with elevated permissions. If no command is specified, it starts an elevated Powershell session. |
| `Import-VisualStudioVars` | Windows | Default | Imports environment variables for the specified version of Visual Studio. |
| `Invoke-Gsudo` | Windows | Default | Executes a ScriptBlock in a new elevated instance of powershell, using `gsudo`. |
| `Invoke-Method` | All | Default | Calls a single method on an incoming stream of piped objects. |
| `New-Hardlink` | All | Default | Creates a filesystem hard link. |
| `New-Junction` | Windows | Default | Creates a Windows directory junction. |
| `New-Symlink` | All | Default | Creates a filesystem symbolic link. |
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
| `Stop-RemoteProcess` | Windows | Default | Stops a process on a remote Windows machine. |
| `Test-IsAdminMember` | Windows | Default | The function Test-IsAdminMember checks if the currently logged-in user is a member of the local administrators group, regardless of the elevation level of the current process. |
| `Test-IsGsudoCacheAvailable` | Windows | Default | Tests whether the gsudo credentials cache is available. |
| `Test-IsProcessElevated` | Windows | Default | Tests if the user is an administrator *and* the current proces is elevated. |

### Aliases (20)

| Alias | Target | Platform | Availability |
| --- | --- | --- | --- |
| `call` | `Invoke-Method` | All | Default unless collision (`OverrideExistingAliases`) |
| `cd` | `Pscx\Set-PscxLocation` | All | When CD module is enabled |
| `cvxml` | `Pscx\Convert-Xml` | All | Default unless collision (`OverrideExistingAliases`) |
| `e` | `Pscx\Edit-File` | All | Default unless collision (`OverrideExistingAliases`) |
| `ehp` | `Edit-HostProfile` | All | Default unless collision (`OverrideExistingAliases`) |
| `ep` | `Edit-Profile` | All | Default unless collision (`OverrideExistingAliases`) |
| `fxml` | `Pscx\Format-Xml` | All | Default unless collision (`OverrideExistingAliases`) |
| `gpar` | `Get-Parameter` | All | Default unless collision (`OverrideExistingAliases`) |
| `gtn` | `Pscx\Get-TypeName` | All | Default unless collision (`OverrideExistingAliases`) |
| `ln` | `New-HardLink` | Windows | Default unless collision (`OverrideExistingAliases`) |
| `ql` | `QuoteList` | All | Default unless collision (`OverrideExistingAliases`) |
| `qs` | `QuoteString` | All | Default unless collision (`OverrideExistingAliases`) |
| `rver` | `Resolve-ErrorRecord` | All | Default unless collision (`OverrideExistingAliases`) |
| `rvhr` | `Resolve-HResult` | Windows | Default unless collision (`OverrideExistingAliases`) |
| `rvwer` | `Resolve-WindowsError` | Windows | Default unless collision (`OverrideExistingAliases`) |
| `skip` | `Pscx\Skip-Object` | All | Default unless collision (`OverrideExistingAliases`) |
| `sro` | `Set-ReadOnly` | All | Default unless collision (`OverrideExistingAliases`) |
| `swr` | `Set-Writable` | All | Default unless collision (`OverrideExistingAliases`) |
| `tail` | `Pscx\Get-FileTail` | All | Default unless collision (`OverrideExistingAliases`) |
| `touch` | `Pscx\Set-FileTime` | All | Default unless collision (`OverrideExistingAliases`) |

### Providers (3)

| Provider | Platform |
| --- | --- |
| `AssemblyCache` | Windows |
| `DirectoryServices` | Windows |
| `PscxSettings` | All |

<!-- END GENERATED PSCX PUBLIC API -->

## Type accelerators

Importing the default Utility submodule registers the entries marked
**default**; importing an optional module registers its listed entries. Type
accelerators are session-global. The default registrations currently remain
after PSCX is removed, while `Pscx.Time` tracks and removes the accelerators
it owns when that sibling module is removed.

| Accelerator | Backing type or purpose | Platform/default |
| --- | --- | --- |
| `[accelerators]` | PowerShell's internal type-accelerator registry | All; default |
| `[json]` | Serialize a value as indented JSON | All; default |
| `[hex]` | Convert supported scalar, string, array, or object values to hexadecimal | All; default |
| `[base64]`, `[b64]` | Convert supported values to Base64 | All; default |
| `[isodate]` | Format and parse ISO-oriented date/time values | All; optional `Pscx.Time` import |
| `[zonedtime]` | `Pscx.Time.ZonedDateTime` | All; optional `Pscx.Time` import |
| `[offsettime]` | `Pscx.Time.OffsetDateTime` | All; optional `Pscx.Time` import |
| `[localtime]` | `Pscx.Time.LocalDateTime` | All; optional `Pscx.Time` import |
| `[tz]` | `NodaTime.DateTimeZone` | All; optional `Pscx.Time` import |
| `[tzi]` | `System.TimeZoneInfo` | All; optional `Pscx.Time` import |
| `[yaml]`, `[yml]` | Serialize a value as YAML | All; default |
