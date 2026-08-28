# PowerShell Community Extensions Light Changelog

## 4.0.0 - Unreleased

* Started PSCX 4.0 development after publishing the stabilized PSCX 3.8.0
  release.
* Made module and child-module exports explicit, preventing accidental public
  API additions and removals.
* Made convenience aliases collision-aware: aliases are created normally when
  their names are available, existing commands are preserved unless
  `OverrideExistingAliases` is enabled, the CD submodule deliberately replaces
  `cd`, and PowerShell's built-in `help` command is never replaced.
* Added the previously internal `Remove-PathVariable` cmdlet to the supported
  public API with help, `ShouldProcess`, and packaged-module tests.
* Added explicit output metadata to retained core commands, structured
  `Test-Script -PassThru` parser results, and structured-by-default
  `Resolve-ErrorRecord` output with `-AsText` compatibility.
* Removed direct host output from Base64 conversion and documented
  `Set-PscxLocation -PassThru` as returning `PathInfo`.
* Completed the retained-command contract audit, added missing output metadata
  and common-parameter support, and added literal-path handling to
  `Get-ViewDefinition`.
* Moved `Read-PscxArchive`, `Write-PscxArchive`, and `Expand-PscxArchive` into
  an optional cross-platform `Pscx.Archive` module shipped beside `Pscx` in a
  unified release ZIP and backed by SharpCompress;
  removed SevenZipSharp and bundled 7-Zip binaries from the default package,
  and added safe-extraction and portable archive round-trip tests.
* Added the optional Windows-only `Pscx.WinAdmin` sibling module for nine
  lower-frequency ADO/OLE DB, batch-environment, short-path, and foreground
  window commands without loading them during the default import.
* Moved YAML conversion and its type accelerators into the cross-platform core,
  moved `Stop-RemoteProcess` into the Windows companion module with a modern
  CIM implementation, and made the .NET SDK policy accept stable 10.0.x
  feature bands.
* Removed PSCX's AD/DHCP, SQL Server-specific, and VHD commands in favor of the
  maintained Microsoft ActiveDirectory, DhcpServer, SqlServer, and Hyper-V
  modules, with replacement and installation guidance in the README.
* Removed low-value line-ending, sample-text, hex-formatting, string, uptime,
  garbage-collection, help, screen-capture, and WMI compatibility features;
  retained `Get-FileTail` and the link commands as thin wrappers over modern
  built-ins, and retained `Get-PscxHash` for its pipeline hashing behavior.
* Moved the NodaTime-backed PSCX types and the `isodate`, `zonedtime`,
  `offsettime`, `localtime`, `tz`, and `tzi` accelerators into the
  separately imported, cross-platform `Pscx.Time` sibling module; the default
  `Pscx` payload and import no longer include or load NodaTime.
* Modernized PATH-variable management with ordered duplicate removal,
  normalization and existence validation, platform-native case comparison
  with an explicit Unix `-CaseInsensitive` override, Windows persistent
  scopes, `ShouldProcess`, and structured `-PassThru` change results.
* Added task-oriented command discovery, a concise platform/support matrix,
  guidance on when PSCX adds value over nearby built-ins, and a PSCX Light
  3.x/legacy PSCX-to-4.0 migration guide.

## 3.8.0 - August 2026

* Updated the runtime baseline to PowerShell 7.6 LTS and .NET 10.
* Corrected NodaTime date/time arithmetic forwarding defects.
* Enforced high/critical NuGet vulnerability policy and resolved the current
  vulnerable transitive dependency.
* Centralized version identity and replaced the legacy desktop workflow and
  post-build packaging scripts with one local/CI build entry point.
* Added Windows, Ubuntu, and macOS CI builds plus clean packaged-module import
  checks on the minimum and current PowerShell 7.6 versions.
* Established one release-blocking managed/Pester test pipeline with separate
  standard result files, managed and PowerShell coverage, and an aggregate
  status.
* Split pure logic tests into `Pscx.InternalTests`, classified the remaining
  legacy fixtures, and removed a non-reproducible external lab fixture.
* Expanded packaged-module Pester coverage for exports, help, aliases,
  providers, optional features, and representative public command behavior.
* Restored the declared `AddRegex` function, prevented a Windows helper from
  shadowing `AddAccelerator`, and included the optional VHD module in Windows
  packages.
* Corrected the public documentation for supported versions, platforms,
  command names, optional exports, and registered type accelerators.
* Replaced the manually maintained README command inventory with a generated,
  CI-validated catalog sourced from packaged manifests and command help.
* Replaced the snap-in-era help project and bespoke XML/XSLT generator with
  pinned Microsoft.PowerShell.PlatyPS, canonical Markdown command/about help,
  localized packaged MAML, and build/test validation.
* Standardized distribution on direct GitHub Release ZIPs with clean-install
  validation, SHA-256 checksums, and a pinned-tool SPDX SBOM; retained local,
  selective PowerShell signing while keeping CI-built PSCX binaries unsigned.
* Modernized optional-module manifests and made build, test, static-analysis,
  and local-signing tooling reliable with PowerShell 7.6 across Windows,
  Linux, and macOS.

## 3.7.0 - June 2025
* Upgraded to .NET 9.0, PowerShell Core 7.5
* Upgraded gsudo to 2.6
* Upgraded auxilary apps
  * less to 6.7.8
  * sevenzipsharp to 1.6
  * 7zip to 24.09
* Fixed Add-PathVariable to force prepend to bring the path location to the front of the variable when location already exists in the variable


## 3.6.5 - August 2024
* Upgraded to .NET 8.0, PowerShell Core 7.4
* Upgraded gsudo to 2.5.1
* Added YamlDotNet library to support marshalling to/from YAML format

## 3.6.4 - January 2023

* GitHub CI/CD build pipeline (aka Actions) and published artifacts
* Upgraded to .NET 6.0, PowerShell Core 7.2
* Enhanced CD module, jump to top/bottom of stack, ANSI colors, more shortcuts
* Minimum PowerShell version is 7.0
* Deprecated more of the limited use cmdlets or marked obsoleted (especialy as they utility has been superseeded by new PoSh releases, or obsoleted by new .Net releases)
  * e.g. *-MSMQueue
* Removed Prompt submodule - not working, of no real use due to plenty options for PoSh prompts much more refined.
  * [ompgit](https://gitlab.com/danluca/ompgit)
  * cross-platform [oh-my-posh](https://github.com/JanDeDobbeleer/oh-my-posh)
  * old PowerShell [oh-my-posh](https://github.com/JanDeDobbeleer/oh-my-posh2)
* Expand sort alias to Sort-Object in PS1 files - fixes Get-Parameter on Linux/macOS
* Updated Import-VisualStudioVars to support Visual Studio 2022. Thanks @weloytty (Bill Loytty)!
* Renamed less function to PscxLess.
* Renamed help function to PscxHelp.
* Renamed Get-ADObject to Get-PscxADObject.
* Removed Get-Help submodule - not really working, the Utility submodule PscxHelp is more effective
* Renamed Mount/Dismount-VHD to Mount/Dismount-PscxVHD.
* Changed Pscx to only override the built-in help function if PageHelpUsingLess Pscx.UserPreference is $true
* Renamed Expand-Archive to Expand-PscxArchive and Read-Archive to Read-PscxArchive.
* Renamed Set-LocationEx to Set-PscxLocation.
* Removed all *-Clipboard commands - superseeded by built-in PowerShell utilities
* Renamed Get-Uptime to Get-PscxUptime.
* Renamed Join-String to Join-PscxString.
* Removed the gcb alias that now conflicts with the built-in gcb alias
* Fixed Expand-PscxArchive help topic to remove references to the Format parameter - this parameter does not exist.
* Changed help function to default to displaying Full help details.

## 3.5.0 - September 20, 2021

* Upgraded to .NET 5.0, PowerShell Core 7.1
* Extracted out Windows specific cmdlets & supporting code into dedicated assembly
- Fix New-*Link cmdlets due to path parameter constraints errors
* Removed more of the obscure cmdlets that are unlikely to be used

## 3.4.0 - March 12, 2020

* Converted to PowerShell Core 7 compliance, MacOS friendly
* Trimmed down the number of cmdlets and features to most useful ones


## Older changes

* See the Release notes for version 3.3.2 and older at https://github.com/Pscx/Pscx/blob/master/ReleaseNotes.txt
