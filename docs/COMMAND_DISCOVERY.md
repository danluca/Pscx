# Find PSCX commands by task

PSCX spans several small command-line productivity areas. Start with the task
you need to perform, then use PowerShell's standard discovery commands for the
details.

## Discover what is installed

The default import exposes the cross-platform core and, on Windows, the
Windows companion commands:

```powershell
Import-Module Pscx
Get-Command -Module Pscx | Sort-Object Noun, Verb
```

The release also contains sibling modules that are imported explicitly. Only
`Pscx.WinAdmin` is Windows-only:

```powershell
Get-Module Pscx.Archive, Pscx.Time, Pscx.WinAdmin -ListAvailable |
    Select-Object Name, Version, Path

Import-Module Pscx.Archive
Get-Command -Module Pscx.Archive
```

Use normal PowerShell help for syntax and examples:

```powershell
Get-Help Get-TextFileInfo -Full
Get-Help about_Pscx
```

Run `Test-PscxInstallation` when a command or optional module behaves
differently between machines.

## Files, text, and line endings

Inspect text encoding and line endings before changing a file:

```powershell
Get-TextFileInfo -Path ./src/*.cs |
    Select-Object Path, Encoding, LineEnding, HasMixedLineEndings, HasFinalNewline

ConvertTo-UnixLineEnding -Path ./src/*.cs -Check |
    Where-Object NeedsConversion
```

Use `ConvertTo-UnixLineEnding` or `ConvertTo-WindowsLineEnding` without
`-Check` to perform a conversion. Other file-oriented commands include
`Set-FileTime`, `Set-FileAttributes`, `Set-ReadOnly`, `Set-Writable`,
`Get-FileVersionInfo`, and `Get-PEHeader`.

For log following, `Get-FileTail` is a convenience wrapper over the modern
`Get-Content -Tail` and `-Wait` behavior:

```powershell
Get-FileTail -Path ./application.log -Count 50 -Wait
```

## PATH and environment management

Treat a path-oriented environment variable as an ordered collection instead
of manually splitting and joining a string:

```powershell
Get-PathVariable -Name PATH
Add-PathVariable -Name PATH -Value "$HOME/.local/bin" -Normalize -PassThru -WhatIf
Remove-PathVariable -Name PATH -Value ./obsolete-tools -Normalize -PassThru
```

Process-scoped operations work on every supported platform. Persistent `User`
and `Machine` targets are Windows-only. Comparison is case-sensitive on Linux
and macOS by default; use `-CaseInsensitive` when that is the intended policy.

Use `Push-EnvironmentBlock` and `Pop-EnvironmentBlock` to preserve and restore
a process environment around a temporary operation.

## Navigation and filesystem structure

Enable the CD submodule to use `Set-PscxLocation` and its FIFO location stack.
When enabled, PSCX deliberately replaces PowerShell's `cd` alias; disable that
submodule if the built-in behavior is preferred.

```powershell
Import-Module Pscx -ArgumentList @{ ModulesToImport = @{ CD = $true } }
Get-Help Set-PscxLocation -Full
```

Use `Show-Tree` and `Add-DirectoryLength` to explore directory structure.
`New-Hardlink`, `New-Symlink`, and Windows-only `New-Junction` provide familiar
named wrappers over `New-Item -ItemType`.

## Data conversion and inspection

PSCX provides pipeline-friendly conversions for common CLI data formats:

```powershell
$encoded = 'PSCX' | ConvertTo-Base64
$encoded | ConvertFrom-Base64

$data = [ordered]@{ name = 'Pscx'; version = 4 }
$data | ConvertTo-Yaml
```

Use `Convert-Xml` to parse XML text and `Format-Xml` to produce readable XML.
`ConvertTo-Unit`, `Format-Byte`, and `Get-TypeName` help inspect values at the
prompt.

## Validation, diagnostics, and errors

Validate scripts without executing them and request structured parser results:

```powershell
Test-Script -Path ./build.ps1 -PassThru |
    Where-Object IsValid -EQ $false

Test-PscxInstallation |
    Where-Object Status -In Warning, Fail
```

Use `Test-Xml` for well-formedness and optional schema validation,
`Test-Assembly` for managed assembly inspection, and `Resolve-ErrorRecord` for
structured exception details. Add `-AsText` to `Resolve-ErrorRecord` only when
preformatted diagnostic text is required.

## Hashing pipeline values

Use PowerShell's built-in `Get-FileHash` for ordinary files. Use
`Get-PscxHash` when data arrives through the pipeline as strings or aggregated
byte arrays:

```powershell
'content from the pipeline' |
    Get-PscxHash -Algorithm SHA256 -StringEncoding UTF8
```

## Archives

Import the optional cross-platform archive module when ZIP alone is not enough:

```powershell
Import-Module Pscx.Archive
Write-PscxArchive -Path ./logs -OutputPath ./logs.tar.gz
Read-PscxArchive -Path ./logs.tar.gz
Expand-PscxArchive -Path ./logs.tar.gz -OutputPath ./restored-logs
```

`Pscx.Archive` supports ZIP, 7z, TAR, TAR.GZ/TGZ, and TAR.BZ2/TBZ2 creation,
and detects additional SharpCompress read formats. Extraction rejects rooted
paths, parent traversal, symbolic-link entries, and encrypted archives.

## Optional date/time types

Import `Pscx.Time` only when its NodaTime-backed types and accelerators are
needed:

```powershell
Import-Module Pscx.Time
[localtime]::now()
```

The default `Pscx` import does not load NodaTime.

## Windows administration and shell integration

The default Windows payload includes Terminal Services, reparse-point, mount
point, privilege, shortcut, Visual Studio environment, elevation, and paging
commands. Discover them with the platform column in the
[README command catalog](../README.md#public-api-catalog).

Import `Pscx.WinAdmin` for the lower-frequency ADO/OLE DB, arbitrary batch-file
environment, short-path annotation, and foreground-window commands:

```powershell
Import-Module Pscx.WinAdmin
Get-Command -Module Pscx.WinAdmin
```

## Why PSCX instead of the built-in?

Use PSCX where it adds a pipeline contract, safer composition, broader format
support, or an intentional interactive convenience. Prefer the built-in when
the PSCX wrapper adds nothing needed by the task.

| PSCX command | Nearby built-in | What PSCX adds |
| --- | --- | --- |
| `Get-PathVariable`, `Add-PathVariable`, `Set-PathVariable`, `Remove-PathVariable` | `$env:PATH` and .NET environment APIs | Ordered entry handling, normalization, validation, duplicate removal, `ShouldProcess`, and structured changes. |
| `Get-TextFileInfo`, `ConvertTo-*LineEnding` | `Get-Content`, `Set-Content`, and string replacement | Conservative encoding/BOM detection, mixed-ending diagnostics, final-newline policy, encoding preservation, and a non-writing CI check. |
| `Get-PscxHash` | `Get-FileHash` | Hashes pipeline strings and byte arrays as well as files. |
| `Skip-Object` | `Select-Object -Skip` | Can omit leading, trailing, and indexed items in one pipeline operation. |
| `Set-PscxLocation` | `Set-Location` | Adds PSCX's FIFO location-stack navigation for interactive use. |
| `Get-FileTail` | `Get-Content -Tail -Wait` | A short compatibility/convenience name; use the built-in directly when preferred. |
| `New-Hardlink`, `New-Symlink`, `New-Junction` | `New-Item -ItemType` | Familiar named wrappers; their filesystem behavior comes from the built-in. |
| `Pscx.Archive` commands | `Compress-Archive`, `Expand-Archive` | Additional archive formats, entry listing, and explicit safe-extraction checks. |
| `Test-Script` | PowerShell parser APIs | A command-line Boolean result or structured parser diagnostics without executing the script. |

The complete alphabetical inventory remains in the
[README public API catalog](../README.md#public-api-catalog), and each exported
function or cmdlet has local `Get-Help` content.
