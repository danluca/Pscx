# PSCX 4.0 command disposition review

This document records the evidence and open decisions for Phase 5 of the
[modernization plan](PSCX_MODERNIZATION_PLAN.md). The machine-readable inventory
is [`PSCX_COMMAND_DISPOSITION.psd1`](PSCX_COMMAND_DISPOSITION.psd1).

The inventory records the maintainer-approved destination for every PSCX 4.0
public command. Approval establishes direction; the module moves, deprecations,
and removals remain implementation work governed by the modernization plan.
Every public command must appear exactly once, and the packaged-module tests
compare the inventory with the root manifest so additions, omissions, and
duplicates fail CI.

## Disposition buckets

| Bucket | Meaning |
| --- | --- |
| `RetainCore` | Retain in the cross-platform core. |
| `RetainWindowsCore` | Retain in the default Windows payload. Commands may require elevation when their purpose demands it. |
| `MoveToArchive` | Move to the optional `Pscx.Archive` module. |
| `MoveToWinAdmin` | Move to the optional `Pscx.WinAdmin` module. |
| `MoveToCrossPlatformCore` | Platform-neutral command approved for relocation from a Windows assembly; the Phase 5.4 move is complete. |
| `DeprecationCandidate` | Deprecate or remove after applying the documented compatibility process. |

Commands listed under `RemovedCommands.ModernMicrosoftAlternative` are removed
from PSCX 4.0 in favor of maintained Microsoft modules. The README maps each
removed command group to its replacement and installation method.

The former `Review` commands are retained in their platform-appropriate core:
22 are in `RetainCore`, while Windows-only `Invoke-Apartment` is in
`RetainWindowsCore`.

The completed per-command value, output, naming, common-parameter, path, and
help audit is maintained in
[`PSCX_RETAINED_COMMAND_AUDIT.psd1`](PSCX_RETAINED_COMMAND_AUDIT.psd1). Packaged
tests require it to cover all 70 retained commands exactly once and enforce its
runtime metadata decisions.

## Phase 5.1 retained-core review

| Area | Commands | Differentiation | Current output contract | Finding |
| --- | --- | --- | --- | --- |
| PATH editing | `Get-PathVariable`, `Add-PathVariable`, `Remove-PathVariable`, `Set-PathVariable` | Treats path-like environment variables as ordered entries, supports process/user/machine targets, and avoids ad hoc separator manipulation. | `Get-PathVariable` emits `System.String` entries; mutators emit no objects. | Retain. Output metadata was missing from `Get-PathVariable` and is now explicit. |
| Environment frames | `Get-EnvironmentBlock`, `Push-EnvironmentBlock`, `Pop-EnvironmentBlock` | Snapshots and restores a process environment as a stack, which has no direct built-in equivalent. | `Get-EnvironmentBlock` emits `Pscx.EnvironmentBlock.EnvironmentFrame`; push/pop emit no objects. | Retain. The getter's output metadata is now explicit. |
| Assembly and PE inspection | `Test-Assembly`, `Get-PEHeader` | Provides pipeline-friendly validation and structured portable-executable metadata without requiring callers to write reflection/parsing code. | `System.Boolean` and `Pscx.Reflection.PEHeader`. | Retain. Existing structured contracts are suitable. |
| XML tooling | `Test-Xml`, `Format-Xml`, `Convert-Xml` | Combines validation, readable formatting, and XSL transformation with pipeline and path support. | `System.Boolean` or `System.String`, depending on command. | Retain pending the normal path/error audit. |
| Unit and byte formatting | `ConvertTo-Unit`, `Format-Byte` | Supplies reusable measurement objects and concise human-readable byte formatting. | `Pscx.SimpleUnits.Measurement` and `System.String`. | Retain. `Format-Byte` is intentionally display-oriented. |
| File/editor utilities | `Edit-File`, `Set-FileTime` | Adds configurable editor launching, in-place replacement, pipeline paths, timestamp selection, and `ShouldProcess`. | Both can emit `System.IO.FileInfo`; `Edit-File` does so only with `-PassThru`. | Retain. `Edit-File` output metadata is now explicit. |
| Error inspection | `Resolve-ErrorRecord` | Walks `ErrorRecord`, invocation, and nested exception details more deeply than the default view. | Emits `Pscx.ErrorRecordDetail` by default; `-AsText` preserves the PSCX 3.x formatted representation. | Retain. Structured details include the original record, invocation metadata, category, position, script stack, and exception chain. |
| Enhanced location navigation | `Set-PscxLocation` and `cd` | Adds backward/forward FIFO stacks, indexed navigation, repeated-dot parent traversal, pipeline paths, and `-PassThru`. | `-PassThru` emits `PathInfo`; stack display emits strings; preferences can cause child-item output. | Retain. Output modes need documentation and should not be collapsed into a misleading single type. |
| Base64 conversion | `ConvertFrom-Base64`, `ConvertTo-Base64` | Supports pipeline aggregation, files, large-input chunking, optional streamed encoding, whitespace-tolerant decoding, and direct file output. | `System.Byte[]` when decoding to the pipeline; `System.String` when encoding; file output is otherwise silent. | Retain. Output metadata is explicit and file progress uses the verbose stream instead of writing directly to the host. |
| Script parsing | `Test-Script` | Provides path and pipeline input around PowerShell's modern language parser without requiring callers to invoke parser APIs directly. | Emits `System.Boolean` by default. `-PassThru` emits `Pscx.Commands.ScriptTestResult` with structured `ParseError` objects and no duplicate warnings. | Retain with both compatibility and structured modes. |

## Approved Phase 5.1 output decisions

1. `Test-Script` retains Boolean output by default and provides structured
   parser results through `-PassThru`.
2. `Resolve-ErrorRecord` emits structured details by default in PSCX 4.0 and
   preserves the prior representation through `-AsText`.
3. `Set-PscxLocation` retains its context-dependent modes and documents
   `PathInfo` as the stable `-PassThru` contract.
4. Base64 file progress uses the verbose stream and never writes directly to
   the host.

The archive commands now ship in the optional, cross-platform `Pscx.Archive`
module using the managed SharpCompress backend. The nine WinAdmin commands
ship in the separately imported `Pscx.WinAdmin` sibling module. Other
relocation and deprecation buckets remain approved destinations whose
implementation and compatibility work is tracked in the corresponding Phase 5
sections.

## Phase 5.1 audit conclusions

- All retained commands have a concise group-level differentiation statement
  and an explicit output contract.
- Structured and pass-through commands expose output metadata. Silent mutators,
  host/native wrappers, and context-dependent commands have documented reasons
  when a single output type would be misleading.
- Existing non-Verb-Noun names are limited to seven reviewed compatibility or
  native-integration exceptions.
- Common parameters are available everywhere except `gsudo`, `QuoteList`, and
  `QuoteString`, whose arbitrary argument forwarding would be broken by advanced
  parameter binding.
- Wildcard-capable `-Path` parameters pair with `-LiteralPath`.
  `Set-VolumeLabel -Path` is the sole documented exception because it identifies
  a native volume root rather than a provider path.
- Every retained command has at least one installed or authoritative-source
  example. Optional `Add-DirectoryLength` is validated from its FileSystem
  submodule source; default-loaded commands are validated at package runtime.

## Phase 5.4 platform-source audit

Every non-generated C# and PowerShell source under `Pscx.Core`, `Pscx`,
`Pscx.Archive`, `Pscx.Win`, and `Pscx.WinAdmin` was reviewed against its
project's platform contract.

- `ConvertFrom-Yaml`, `ConvertTo-Yaml`, their type accelerators, and YamlDotNet
  now belong to the cross-platform `Pscx` assembly and package payload.
- `Pscx.Win` and `Pscx.WinAdmin` retain assembly-level Windows platform
  annotations; their remaining sources implement Windows APIs or support
  Windows-only commands and providers.
- `Stop-RemoteProcess` moved from the cross-platform Utility script module to
  `PscxWin`. Its removed `Get-WmiObject` dependency was replaced by the modern
  CIM cmdlets while preserving its public parameters and `ShouldProcess`
  behavior.
- `Set-ForegroundWindow` remains the approved Windows-core exception in the
  otherwise cross-platform `Pscx` assembly and carries an explicit
  `SupportedOSPlatform("windows")` annotation.
- The shared OEM-encoding conversion remains available on Windows, but now
  rejects non-Windows use before reaching its `kernel32` interop call.

Repository static validation enforces these boundaries by checking the Windows
assembly annotations, the reviewed native-interop exceptions, their platform
guards, and the absence of Windows automation APIs from cross-platform
PowerShell sources.
