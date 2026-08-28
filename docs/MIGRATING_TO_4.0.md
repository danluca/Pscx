# Migrating to PSCX 4.0

PSCX 4.0 is the intentional breaking boundary after PSCX Light 3.8. It keeps a
smaller cross-platform core, moves dependency-heavy and lower-frequency
features into explicit sibling modules, and removes commands superseded by
PowerShell, .NET, or maintained Microsoft modules.

This guide covers both PSCX Light 3.x and older full/upstream PSCX
installations. It is also useful when auditing scripts before replacing an
existing PSCX installation.

## Runtime and installation changes

PSCX 4.0 requires PowerShell 7.6 LTS and .NET 10. Windows PowerShell 5.1 is not
supported. Install the GitHub Release ZIP into versioned module directories so
3.8 and 4.0 can remain side by side during migration:

```text
Modules/
  Pscx/4.0.0/Pscx.psd1
  Pscx.Archive/4.0.0/Pscx.Archive.psd1
  Pscx.Time/4.0.0/Pscx.Time.psd1
  Pscx.WinAdmin/4.0.0/Pscx.WinAdmin.psd1   # Windows package only
```

Import a specific version while validating existing profiles and scripts:

```powershell
Import-Module Pscx -RequiredVersion 4.0.0
Test-PscxInstallation
```

PSCX is distributed through GitHub Releases rather than PowerShell Gallery.
The release ZIP and matching SHA-256 file are the supported installation
inputs.

## Package boundaries

| PSCX 4.0 module | Import | Platforms | Migration action |
| --- | --- | --- | --- |
| `Pscx` | `Import-Module Pscx` | Windows, Linux, macOS | Default core. On Windows it loads the packaged Windows companion commands. |
| `Pscx.Archive` | `Import-Module Pscx.Archive` | Windows, Linux, macOS | Add an explicit import before using `Read-PscxArchive`, `Write-PscxArchive`, or `Expand-PscxArchive`. |
| `Pscx.Time` | `Import-Module Pscx.Time` | Windows, Linux, macOS | Add an explicit import before using the NodaTime-backed types and accelerators. |
| `Pscx.WinAdmin` | `Import-Module Pscx.WinAdmin` | Windows only | Add an explicit import for the moved lower-frequency administration commands. |

The default `Pscx` import no longer loads SharpCompress or NodaTime. Importing
the core also does not load any sibling module.

### Commands moved to explicit sibling modules

| Command or feature | PSCX 4.0 module |
| --- | --- |
| `Read-PscxArchive`, `Write-PscxArchive`, `Expand-PscxArchive` | `Pscx.Archive` |
| `isodate`, `zonedtime`, `offsettime`, `localtime`, `tz`, and `tzi` accelerators | `Pscx.Time` |
| `Add-ShortPath`, `Get-AdoConnection`, `Get-AdoDataProvider`, `Get-ForegroundWindow`, `Get-OleDbData`, `Get-OleDbDataSet`, `Invoke-AdoCommand`, `Invoke-BatchFile`, `Invoke-OleDbCommand` | `Pscx.WinAdmin` |

## Commands replaced by maintained modules

These commands are not shipped in PSCX 4.0. Install the required Windows
capability or Microsoft module and update scripts to use its command.

| Removed PSCX command | Replacement |
| --- | --- |
| `Get-PscxADObject` | ActiveDirectory module: `Get-ADObject` |
| `Get-DomainController` | ActiveDirectory module: `Get-ADDomainController` |
| `Get-DhcpServer` | DhcpServer module: `Get-DhcpServerInDC` |
| `Get-SqlData`, `Get-SqlDataSet`, `Invoke-SqlCommand` | SqlServer module: `Invoke-Sqlcmd` and structured-output commands |
| `Mount-PscxVHD`, `Dismount-PscxVHD` | Hyper-V module: `Mount-VHD`, `Dismount-VHD` |

For installation examples, see
[Replacements for removed Windows administration commands](../README.md#replacements-for-removed-windows-administration-commands).

Provider-neutral ADO and OLE DB commands remain available in
`Pscx.WinAdmin`; only the SQL Server-specific wrappers were removed.

## Low-value and obsolete commands removed

| Removed command or feature | Migration |
| --- | --- |
| `ConvertTo-MacOs9LineEnding` | Use targeted string/byte conversion if this legacy format is genuinely required. |
| `Format-Hex` | Use PowerShell's built-in `Format-Hex`. |
| `Get-LoremIpsum` | Use a dedicated test-data or text-generation module. |
| `Get-PscxUptime` | Use the built-in `Get-Uptime`. |
| `Get-ScreenCss`, `Get-ScreenHtml` | Use `ConvertTo-Html`, terminal capture, or a dedicated reporting tool. |
| `Invoke-GC` | Allow .NET garbage collection to run automatically. |
| `Join-PscxString` | Use the built-in `Join-String`. |
| `Split-PscxString` | Use the `-split` operator or .NET string APIs. |
| `PscxHelp` | Use built-in `Get-Help` or `help`; invoke `PscxLess` explicitly on Windows when paging is desired. |
| `Pscx.Wmi` optional module and WMI accelerators | Use `Get-CimInstance` and native `DateTime`/`TimeSpan` values. |

There is no PSCX 4.0 compatibility module for these removals.

## Retained convenience commands

`Get-FileTail`, `New-Hardlink`, `New-Symlink`, and Windows-only `New-Junction`
remain supported names, but now delegate to modern built-in behavior.

- `Get-FileTail` uses `Get-Content -Tail` and optional `-Wait`. Its former
  nonstandard `-LineTerminator` behavior is not retained.
- The link functions use `New-Item -ItemType HardLink`, `SymbolicLink`, or
  `Junction` and support `ShouldProcess`.
- `Get-PscxHash` remains because it hashes pipeline strings and byte arrays in
  addition to files; use `Get-FileHash` when only ordinary file hashing is
  required.

## Import and alias behavior

PSCX 4.0 exports commands explicitly. Scripts should not depend on helper
functions that happened to leak from older module versions.

Convenience aliases are created only when their names do not already resolve
to an alias, function, cmdlet, or native application. This prevents PSCX from
silently replacing native Unix commands such as `tail` and `touch`. To request
the old precedence deliberately:

```powershell
Import-Module Pscx -ArgumentList @{ OverrideExistingAliases = $true }
```

The CD submodule is the deliberate exception: enabling it always replaces
PowerShell's `cd` alias with `Set-PscxLocation`. PowerShell's built-in `help`
command is never replaced. Prefer module-qualified command names in scripts
when an alias could be ambiguous.

## Output and automation changes

Review scripts that parse display text or rely on host output:

- `Resolve-ErrorRecord` now returns structured objects by default. Add
  `-AsText` for the legacy preformatted representation.
- Base64 conversion writes pipeline output instead of writing directly to the
  host.
- `Set-PscxLocation -PassThru` returns `PathInfo`.
- PATH mutation commands support `ShouldProcess` and return a structured
  `PathVariableChange` with `-PassThru`.
- Persistent PATH `User` and `Machine` targets are Windows-only. Unix path
  comparison is case-sensitive unless `-CaseInsensitive` is specified.

## Archive behavior changes

The 4.0 archive commands use managed SharpCompress instead of SevenZipSharp
and bundled 7-Zip executables. The module creates ZIP, 7z, TAR, TAR.GZ/TGZ, and
TAR.BZ2/TBZ2 archives and detects supported read formats.

Encrypted extraction is not supported. Extraction rejects rooted paths,
parent traversal, and symbolic-link entries. File timestamps are preserved
when available; portable ACL and Unix-mode preservation are not part of the
4.0 contract.

## Migrating from older full/upstream PSCX

This lightweight fork is not a drop-in replacement for the historical full
PSCX command surface. Before changing the version used by a profile or script:

1. Run the old environment and capture the commands actually referenced by
   the profile or automation.
2. Compare them with `Get-Command -Module Pscx` and the
   [PSCX 4.0 public API catalog](../README.md#public-api-catalog).
3. Replace missing commands with current PowerShell/.NET functionality or a
   maintained specialist module.
4. Remove assumptions about Windows PowerShell, snap-ins, global alias
   replacement, and implicit loading of optional dependencies.
5. Test on PowerShell 7.6 in every operating system used by the automation.

The historical repository contains substantially more commands than the PSCX
Light 3.x baseline. A command absent from both this guide and the 4.0 catalog
should be treated as unsupported rather than as an accidental omission.

## Suggested migration check

Use a clean PowerShell 7.6 process with only the intended PSCX version on
`PSModulePath`:

```powershell
Import-Module Pscx -RequiredVersion 4.0.0 -Force

Test-PscxInstallation |
    Format-Table Status, Category, Name, Message -AutoSize

Get-Command -Module Pscx | Sort-Object Name
Get-Module Pscx.Archive, Pscx.Time, Pscx.WinAdmin -ListAvailable
```

Then run the consuming project's tests without relying on convenience aliases.
Import only the sibling modules the project actually needs. Retain PSCX 3.8 in
its versioned directory until the migrated automation has been validated and a
rollback is no longer required.
