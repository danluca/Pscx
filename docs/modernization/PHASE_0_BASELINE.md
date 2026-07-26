# Phase 0 Baseline and Decision Record

## Status

Phase 0 is **complete**.

This document records the PSCX 3.8.0 starting point and the maintainer decisions
that must be settled before the build, compatibility, packaging, and API work
proceeds. Measurements are descriptive rather than performance guarantees.

## Baseline identity

| Item | Value |
| --- | --- |
| Branch | `dev/13-upgrade-net10` |
| Baseline commit | `9c2ca00` |
| Packaged artifact | `Output/Pscx/3.8.0` |
| Package archive | `Output/Pscx-3.8.0.zip` |
| Module version | `3.8.0` |
| Project target framework | `net10.0` |
| PowerShell SDK reference | `7.6.4` |
| Manifest minimum PowerShell version | `7.2` (known inconsistency) |
| Measurement host | Windows 10.0.26200, x64 |
| Measurement PowerShell/.NET | PowerShell 7.6.4, .NET 10.0.10 |

The checked-in 3.8.0 package was used because it represents the current
ship-shaped artifact without requiring the existing fragile build pipeline.
Linux and macOS measurements remain outstanding until cross-platform CI or
equivalent clean environments are available.

## Public API baseline

The generated Windows API inventory is stored in
[`baseline/pscx-3.8.0-windows-api.json`](baseline/pscx-3.8.0-windows-api.json).
It includes exported commands and parameter sets, aliases, providers, type
accelerators, type data, and format data.

Regenerate it from a fresh PowerShell process:

```powershell
pwsh -NoProfile -File ./Tools/Get-PscxApiInventory.ps1 `
    -ModulePath ./Output/Pscx/3.8.0/Pscx.psd1 `
    -OutputPath ./docs/modernization/baseline/pscx-3.8.0-windows-api.json `
    -PackageLabel Output/Pscx/3.8.0
```

### Export summary

| API kind | Count |
| --- | ---: |
| Cmdlets | 70 |
| Functions | 31 |
| Aliases | 22 |
| Variables | 0 |
| Total exported commands | 123 |
| Providers | 3 |
| Packaged type-data files | 8 |
| Packaged format-data files | 10 |

The three providers observed on Windows are `PscxSettings`, `AssemblyCache`,
and `DirectoryServices`.

The 22 exported aliases are:

`call`, `cvxml`, `e`, `ehp`, `ep`, `fhex`, `fxml`, `gpar`, `gtn`, `igc`,
`ln`, `lorem`, `ql`, `qs`, `rver`, `rvhr`, `rvwer`, `skip`, `sro`, `swr`,
`tail`, and `touch`.

## Package baseline

| Measurement | Value |
| --- | ---: |
| Extracted size | 26,929,357 bytes (25.68 MiB) |
| ZIP size | 11,964,421 bytes (11.41 MiB) |
| Packaged files | 69 |

### Package weight by extension

| Extension | Files | Size |
| --- | ---: | ---: |
| `.exe` | 5 | 9.26 MiB |
| No extension | 2 | 8.35 MiB |
| `.dll` | 7 | 5.08 MiB |
| `.xml` | 5 | 2.03 MiB |
| `.ps1xml` | 18 | 0.32 MiB |
| `.psm1` | 8 | 0.24 MiB |
| `.psd1` | 11 | 0.17 MiB |
| Other | 13 | 0.24 MiB |

The largest files are native tools or third-party dependencies:

| File | Size |
| --- | ---: |
| `Apps/macOS/7zz` | 5.61 MiB |
| `Apps/Win/gsudo.exe` | 4.07 MiB |
| `Apps/Win/sudo.exe` | 4.07 MiB |
| `Apps/Linux/7zz` | 2.74 MiB |
| `Apps/Win/7z.dll` | 1.82 MiB |
| `SevenZipSharp.dll` | 1.75 MiB |

The package contains byte-identical copies of the same gsudo executable under
two names. Native executables and extensionless native binaries account for
about 17.61 MiB, or approximately 69% of the extracted package.

## Import baseline

Five fresh `pwsh -NoProfile` imports on the Windows measurement host took:

| Run | Milliseconds |
| --- | ---: |
| 1 | 945.9 |
| 2 | 982.3 |
| 3 | 837.4 |
| 4 | 960.3 |
| 5 | 908.8 |

Median import time was **945.9 ms**. These figures include loading the default
Windows companion and enabled submodules. They are a starting point, not a CI
threshold.

Repeated import/removal within one process produced warnings because PSCX type
accelerators remain registered after `Remove-Module`. Fresh-process tests avoid
that contamination. Type-accelerator unload behavior should receive an explicit
test and lifecycle decision.

## Test baseline

| Measurement | Value |
| --- | ---: |
| Managed test source files | 22 |
| NUnit `[Test]` methods found statically | 46 |
| NUnit test fixtures found statically | 14 |
| Pester `*.Tests.ps1` files | 0 |
| Configured coverage collection | None found |
| CI test execution | Disabled/commented out |

This is a source inventory, not a passing-test count. Direct
`dotnet test Src/Pscx.UnitTests/Pscx.UnitTests.csproj` currently fails before
test discovery because project pre/post-build targets assume `$(SolutionDir)`
exists. The current CI workflow does not execute the test project.

Coverage remains unknown until the unified test entry point and coverage
collection are implemented.

## Maintainer decisions

No proposed decision in this table is final until the maintainer records an
approval.

| Decision | Recommendation | Status |
| --- | --- | --- |
| Minimum PowerShell version | Require PowerShell 7.6 LTS beginning with PSCX 3.8. The 3.7-to-3.8 minor-version change is sufficient for this dependency-baseline update. PowerShell 7.6/.NET 10 is supported through November 14, 2028. See the [PowerShell support lifecycle](https://learn.microsoft.com/powershell/scripting/install/powershell-support-lifecycle). | Approved July 25, 2026 |
| Target .NET version | Target .NET 10 and the PowerShell 7.6 API dependencies associated with the selected LTS baseline. | Approved July 25, 2026 |
| Next breaking release | Use PSCX 4.0 for removals, renames, explicit exports, and package splits. | Approved July 25, 2026 |
| `Pscx.Time` | Beginning with PSCX 4.0, move the NodaTime-backed functionality into a separate optional module so consumers explicitly choose whether to install and activate it. | Approved July 25, 2026 |
| Archive placement | Beginning with PSCX 4.0, move archive commands and their backend into optional `Pscx.Archive`. | Approved July 25, 2026 |
| Archive platform contract | Do not assume full cross-platform support. Establish the supported platforms from the selected backend and verified behavior during the `Pscx.Archive` module work. | Deferred to Phase 5 |
| Archive backend | Evaluate bundled 7-Zip, a managed library, and system tools when work begins on `Pscx.Archive`. | Deferred to Phase 5 |
| Windows native utilities | Retain bundled gsudo and less in the default Windows core package because they provide valuable Windows CLI functionality. Record their provenance and keep them maintained. | Approved July 25, 2026 |

## Phase 0 completion checklist

- [x] Capture the packaged Windows public API inventory.
- [x] Record package size by component and major imported binary.
- [x] Record Windows import time.
- [x] Defer Linux and macOS import measurements to the clean packaged-module CI jobs in Phase 2.1.
- [x] Record current test-source count and coverage status.
- [x] Set PowerShell 7.6 LTS as the minimum supported version beginning with PSCX 3.8.
- [x] Target .NET 10 and the associated PowerShell 7.6 API dependencies.
- [x] Confirm PSCX 4.0 as the next breaking release.
- [x] Decide to move `Pscx.Time` into a separate optional module in PSCX 4.0.
- [x] Confirm `Pscx.Archive` as a separate optional module.
- [x] Defer archive backend selection and its supported-platform contract to the `Pscx.Archive` module work.
- [x] Retain bundled gsudo and less in the default Windows core package.
- [x] Link the Phase 0 compatibility work to [GitHub issue #16](https://github.com/danluca/Pscx/issues/16).

## Known limitations

- Only Windows runtime measurements are currently available; Linux and macOS
  measurements are assigned to the clean packaged-module CI jobs in Phase 2.1.
- The inventory describes the checked-in package, not a freshly reproduced
  package from a clean build.
- Import timing has a small sample size and was collected on one host.
- Managed test counts were obtained statically because the current direct test
  command fails before discovery.
- Usage telemetry is unavailable, so retain/remove recommendations rely on
  differentiation, overlap with modern PowerShell, package cost, and
  maintenance risk rather than measured command usage.
