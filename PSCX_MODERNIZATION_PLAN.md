# PSCX Modernization Plan

## Purpose

This plan evolves PSCX into a focused, reliable set of PowerShell CLI extensions. The intended result is:

- a small, dependency-light, cross-platform core module;
- optional packages for archives and Windows administration;
- a documented and tested public API;
- consistent PowerShell, .NET, manifest, build, and release requirements;
- fewer commands that duplicate modern PowerShell;
- predictable module imports that do not unexpectedly replace user commands or aliases.

The plan is intentionally incremental. Compatibility-breaking removals and package splits should be announced, deprecated, and delivered in a new major version.

## Guiding principles

1. **Keep distinctive shell functionality.** Prefer features that are difficult to reproduce correctly with a short built-in PowerShell command.
2. **Use modern PowerShell first.** Do not retain a PSCX command solely to duplicate an established built-in command.
3. **Keep the default import focused.** Windows distributions may retain deliberately selected CLI utilities such as gsudo and less. Large specialized frameworks and unrelated administration libraries belong in optional modules.
4. **Make platform support explicit.** A cross-platform claim must be covered by CI and package-import tests on Windows, Linux, and macOS.
5. **Treat the manifest as a contract.** Every exported command must exist, be documented, and be tested. Nothing should be exported accidentally.
6. **Generate repeatable artifacts.** Versions, compatibility information, command catalogs, help coverage, and packages should be validated or generated rather than manually synchronized.
7. **Deprecate before removing.** Existing users should receive actionable warnings and migration guidance before a public command disappears.

## Target package structure

The proposed package family is:

| Package | Purpose | Typical contents |
| --- | --- | --- |
| `Pscx` | Platform-aware CLI essentials | PATH/environment tools, file metadata, editor integration, XML tools, units, reflection/PE inspection, error helpers; gsudo and less in the default Windows payload |
| `Pscx.Archive` | Optional archive support beginning with PSCX 4.0; exact platform contract to be proven | Read, create, and expand archives; 7-Zip integration or another selected backend |
| `Pscx.WindowsAdmin` | Optional Windows administration | AD, DHCP, SQL/OLE DB, privileges, terminal services, VHD, COM, shortcuts, mount/reparse-point operations |
| `Pscx.Time` | Optional date/time helpers beginning with PSCX 4.0 | NodaTime-backed types and accelerators with a documented supported API |

`Pscx.Time` will be packaged separately so consumers explicitly choose whether
to install and import its NodaTime-backed API.

## Release strategy

Use three release stages:

1. **3.x stabilization release**
   - Correct defects, security warnings, CI, documentation, and metadata.
   - Add tests without intentionally breaking the public API.
   - Mark removal candidates as deprecated.
2. **4.0 preview releases**
   - Introduce package boundaries and explicit exports.
   - Provide compatibility shims and migration warnings.
   - Collect user feedback about proposed removals.
3. **4.0 stable**
   - Remove deprecated low-value duplicates.
   - Publish the final package family and supported-platform contract.

---

## Phase 0: Record baseline and decisions

**Goal:** Establish measurable current behavior and settle compatibility choices before restructuring.

**Tracking:** [#16 Define supported PowerShell/.NET baseline and version policy](https://github.com/danluca/Pscx/issues/16)

### Tasks

- [x] Capture the current exported command, function, alias, provider, type, and format-data inventory from a packaged build.
- [x] Record package size by component and imported native binary.
- [x] Record Windows module import time and defer Linux/macOS measurements to the clean CI environments in Phase 2.1.
- [x] Record the current test count and code coverage. Coverage is currently not configured.
- [x] Set PowerShell 7.6 LTS as the minimum supported version, beginning with PSCX 3.8.
- [x] Target the associated .NET 10 runtime and PowerShell 7.6 API dependencies.
- [x] Confirm PSCX 4.0 as the next breaking release.
- [x] Decide to package `Pscx.Time` as an optional module in PSCX 4.0 so consumers activate it explicitly.
- [x] Defer archive backend and platform decisions to the `Pscx.Archive` module work in Phase 5.
- [x] Open and link the initial tracked issues for the Phase 0 decisions and the first Phase 1/2 work.

### Approved compatibility decision

Beginning with PSCX 3.8, require PowerShell 7.6 LTS and target its associated
.NET 10 runtime and API dependencies. The 3.7-to-3.8 minor-version change is
the approved representation of this dependency-baseline update. Do not claim
PowerShell 7.2 compatibility for assemblies targeting .NET 10. The following
must agree:

- `README.md`;
- `CHANGELOG.md`;
- all module manifests;
- all project target frameworks and PowerShell SDK references;
- CI setup;
- package metadata;
- release artifact names and release notes.

### Exit criteria

- [x] Compatibility and packaging decisions are written down.
- [x] A baseline API inventory is version-controlled and can be regenerated.
- [x] Breaking changes are assigned to PSCX 4.0.

---

## Phase 1: Stabilize correctness, security, and builds

**Goal:** Make the existing product safe to build and validate before changing its architecture.

### 1.1 Correct known defects

**Tracking:** [#17 Fix and test NodaTime arithmetic defects](https://github.com/danluca/Pscx/issues/17)

- [x] Fix `PlusSeconds()` in:
  - `Src/Pscx/Time/LocalDateTime.cs`;
  - `Src/Pscx/Time/OffsetDateTime.cs`;
  - `Src/Pscx/Time/ZonedDateTime.cs`.
- [x] Fix `PlusMilliseconds()` in the same three classes.
- [x] Add tests covering positive, zero, negative, boundary, and daylight-saving-time cases where applicable.
- [x] Review all adjacent date/time forwarding methods for copy/paste errors; no additional unit-forwarding defects were found.

### 1.2 Resolve dependency warnings

**Tracking:** [#18 Resolve vulnerable transitive dependencies](https://github.com/danluca/Pscx/issues/18)

- [x] Identify `Microsoft.PowerShell.SDK` 7.6.4 as the direct dependency that resolves the vulnerable `System.Security.Cryptography.Xml` 10.0.6 version.
- [x] Override the affected dependency graph with `System.Security.Cryptography.Xml` 10.0.10 until the PowerShell SDK selects a non-vulnerable version.
- [x] Add `dotnet package list --vulnerable --include-transitive` to a dedicated CI audit workflow.
- [x] Fail restore and CI on high or critical known vulnerabilities, with a documented maintainer-approved exception process.
- [x] Add Dependabot for NuGet and GitHub Actions dependency updates.
- [x] Inventory licenses for all resolved NuGet dependencies and redistributed native binaries.

### 1.3 Modernize the build and GitHub Actions workflow

Replace `.github/workflows/dotnet-desktop.yml`; do not treat the current desktop-application template as the foundation of the new pipeline. PSCX is a PowerShell module with managed and optional native components, not a WPF/Windows Forms desktop application.

#### Establish one build entry point

**Tracking:** [#19 Create the unified repository build/test entry point](https://github.com/danluca/Pscx/issues/19)

- [x] Add one cross-platform repository build entry point, such as `build.ps1`, with explicit operations for:
  - clean;
  - restore;
  - compile;
  - generate help;
  - test;
  - package;
  - validate package;
  - publish preparation.
- [x] Make GitHub Actions invoke the same entry point developers use locally.
- [x] Avoid duplicating build, test, version, and packaging logic inside workflow YAML.
- [x] Make the build script noninteractive and fail fast with actionable errors.
- [x] Ensure each operation can run independently when its prerequisites already exist.

#### Use one authoritative version

**Tracking:** [#20 Centralize semantic versioning and CI build identity](https://github.com/danluca/Pscx/issues/20)

- [x] Choose one committed file as the sole source of the user-controlled semantic version, preferably `Directory.Build.props` or a small dedicated version file.
- [x] Store only the semantic release portion there, for example `4.0.0` or `4.0.0-preview.1`.
- [x] Remove independently maintained versions from:
  - individual `.csproj` files;
  - shared and project-specific assembly-info files;
  - module manifests;
  - workflow environment variables;
  - packaging scripts;
  - artifact names.
- [x] Generate or stamp output manifests and assembly metadata from the authoritative version during the build.
- [x] Add a validation task that fails when a committed compatibility/version field cannot be derived from the authoritative source.
- [x] Retire `Tools/version_update.ps1` once output generation makes multi-file source rewriting unnecessary, or reduce it to the one deliberate operation that changes the authoritative semantic version.

#### Derive CI build identity automatically

The maintainer controls the semantic version. CI controls the unique build identity. Define the mapping explicitly because PowerShell manifests, .NET assemblies, NuGet-style package versions, and filenames do not all accept exactly the same version syntax.

- [x] Derive the CI build number from `github.run_number` or another monotonic workflow value.
- [x] Include the short commit SHA in informational metadata.
- [x] Use a documented mapping such as:

  | Target | Example derived value |
  | --- | --- |
  | User-controlled semantic version | `4.0.0` |
  | Stable package/module version | `4.0.0` |
  | CI prerelease artifact version | `4.0.0-ci.1234` |
  | Assembly version | a compatibility-stable policy such as `4.0.0.0` |
  | File version | `4.0.0.1234` |
  | Informational version | `4.0.0+build.1234.sha.abcdef0` |
  | Artifact filename | `Pscx-4.0.0-ci.1234.zip` |

- [x] For PowerShell manifests, map prerelease text through `PrivateData.PSData.Prerelease` rather than forcing a nonconforming value into `ModuleVersion`.
- [x] Keep `AssemblyVersion` stable according to an explicit binary-compatibility policy; do not change it merely to make each CI build unique.
- [x] Put the CI build number in `FileVersion`, informational version, prerelease metadata, and artifact names.
- [x] Ensure a tagged stable release produces exactly the user-controlled semantic version without an accidental CI prerelease suffix.
- [x] Verify that package filenames, embedded module versions, assembly metadata, release tags, and release notes refer to the same build.

#### Replace the workflow structure

**Tracking:** [#21 Replace the legacy GitHub Actions workflow](https://github.com/danluca/Pscx/issues/21)

- [x] Replace `dotnet-desktop.yml` with clearly named workflows, for example:
  - `ci.yml` for pull requests and branch pushes;
  - `release.yml` for approved tags/releases.
- [x] Pin the .NET SDK to the version required by the projects, from a single source such as `global.json`.
- [x] Remove the hard-coded .NET 9 setup when projects target a different runtime.
- [x] Remove the hard-coded `Build_Version: 3.7.0...` workflow value.
- [x] Remove unused signing, WAP/MSIX, and desktop-application template comments and variables.
- [x] Use least-privilege GitHub token permissions.
- [x] Add workflow concurrency so superseded builds on the same branch are cancelled.
- [ ] Add dependency caching only for immutable/restorable dependencies, not compiled output.
- [x] Set job and step timeouts.
- [ ] Upload test results, coverage, logs, and packages even when a validation step fails, where useful for diagnosis.
- [x] Pin third-party actions to reviewed major versions or commit SHAs according to the project's supply-chain policy.

#### Make builds location-independent

- [x] Remove the assumption that `$(SolutionDir)` is always defined.
- [ ] Make these workflows succeed independently:
  - `dotnet build Src/Pscx.sln`;
  - `dotnet build <individual project>`;
  - `dotnet test Src/Pscx.UnitTests/Pscx.UnitTests.csproj`;
  - a clean package build from the repository root.
- [x] Replace legacy pre/post-build event behavior with explicit, named MSBuild targets or the repository build script where practical.
- [x] Ensure generated output is not required as source input for a clean build.
- [x] Write all temporary and staged output beneath one configurable artifacts directory.
- [x] Ensure a clean checkout can build without a pre-existing `Output/Pscx` directory.

#### Streamline test execution

- [x] Make the build entry point execute the unified test architecture defined in Phase 2.
- [x] Build and package once per relevant runtime/platform, then run appropriate tests against that artifact rather than rebuilding separately for every test command.
- [x] Run fast, platform-neutral checks early.
- [ ] Run Windows-only tests only on Windows and report intentional skips clearly.
- [x] Run packaged-module import and public-contract tests on Windows, Linux, and macOS.
- [x] Publish one overall pass/fail status with separate Pester and managed-test diagnostics.
- [x] Make the exact CI test command reproducible locally without GitHub-specific environment variables.

### Exit criteria

- [x] Clean restore, build, test, and package commands succeed locally.
- [x] The old desktop-template workflow is removed.
- [x] One repository command implements the same build and test path used by CI.
- [x] The semantic version is maintained in exactly one committed location.
- [x] CI supplies build identity without rewriting the maintainer-controlled semantic version.
- [x] CI and local builds produce equivalent package contents given the same version and commit.
- [x] No high or critical dependency vulnerability is unaddressed.
- [x] Known time arithmetic defects have regression tests.
- [x] No build requires Visual Studio-specific implicit properties unless explicitly documented.

---

## Phase 2: Establish the test and CI safety net

**Goal:** Verify the real PowerShell user experience, not only C# internals.

### 2.1 CI matrix

- [x] Replace the Windows-only job with a matrix covering:
  - Windows;
  - Ubuntu;
  - macOS.
- [x] Build the cross-platform projects on all three operating systems.
- [x] Build Windows-specific projects on Windows.
- [x] Test the minimum supported PowerShell version.
- [x] Test the current stable PowerShell version.
- [x] Capture module import time on Windows, Linux, and macOS from clean packaged-module test jobs.
- [ ] Optionally test the latest preview without making preview failures release-blocking.
- [x] Cache NuGet dependencies without caching build output.

### 2.2 Unified test architecture

Use one repository test strategy and one entry point, while assigning each kind of behavior to the test framework that can verify it best.

**Pester is the authoritative public-contract suite.** It imports and exercises the final packaged module exactly as a user does. All cmdlet and function behavior belongs here, including compiled cmdlets. This avoids testing implementation details while missing module loading, manifests, parameter binding, formatting, help, aliases, or packaging.

**A small .NET unit-test project is retained only for pure implementation logic.** It covers algorithms and internal value types that can be tested more precisely without starting PowerShell—for example unit conversion, parsers, archive path validation, date/time arithmetic, and low-level encoding logic. It must not duplicate command behavior already covered by Pester.

Both suites run through one repository command, produce standard test-result files, contribute to a combined CI result, and are required for release. “Unified” therefore means one policy, one entry point, one result, and non-overlapping ownership—not using one framework for jobs it handles poorly.

#### Test ownership rules

| Behavior | Owner |
| --- | --- |
| Module import, manifests, exports, aliases, providers | Pester |
| Cmdlet/function parameters, pipeline behavior, errors, output types | Pester |
| `ShouldProcess`, filesystem behavior, OS behavior, integration with native tools | Pester |
| Installed-package help and examples | Pester |
| Pure algorithms with no PowerShell/session dependency | .NET unit tests |
| Internal parsing, conversion, and value-object edge cases | .NET unit tests |
| End-to-end packaging and clean installation | Pester invoked against the release artifact |

#### Migration tasks

- [x] Configure an NUnit test adapter so the existing managed tests are discovered and fail the build when no expected tests run.
- [x] Create one cross-platform repository command, `./build.ps1 -Task TestPipeline`, that:
  1. restores and builds;
  2. packages PSCX into an isolated test directory;
  3. runs the .NET unit tests;
  4. starts a clean `pwsh -NoProfile` process;
  5. runs Pester against the packaged module;
  6. emits standard test and coverage results;
  7. returns a nonzero exit code if either suite fails.
- [x] Rename/restructure `Pscx.UnitTests` so its limited internal-unit purpose is obvious.
- [x] Inventory every existing NUnit test and classify it as:
  - migrate to Pester because it tests command/module behavior;
  - retain as a .NET unit test because it tests a pure algorithm;
  - remove because the corresponding feature no longer exists or will be retired.
- [ ] Migrate tests that directly instantiate cmdlets or depend on a custom PowerShell harness to packaged-module Pester tests.
- [ ] Do not test the same behavior in both suites unless it is a deliberate high-risk regression case.
- [ ] Categorize Windows-only tests so they skip cleanly and visibly on other platforms.
- [x] Publish both suites as one CI test summary while preserving framework-specific diagnostic files.
- [x] Collect PowerShell coverage from Pester and managed-code coverage from the .NET test runner.
- [x] Establish separate realistic coverage thresholds; do not combine unlike line-coverage percentages into a misleading single number.

### 2.3 Pester public-contract suite

**Tracking:** [#22 Establish packaged-module Pester tests](https://github.com/danluca/Pscx/issues/22)

- [x] Replace `Tests/ItIsLoneyHere-NeedSomePesterTests.txt` with a real Pester test project.
- [x] Test importing from the final packaged directory, not only build output.
- [ ] Verify every declared export resolves after import.
- [ ] Verify no undeclared function, cmdlet, provider, or alias leaks from the module.
- [ ] Verify `Get-Help` is available for every public command.
- [ ] Verify examples in help and README where feasible.
- [ ] Test pipeline binding and output object types.
- [ ] Test `-Path` and `-LiteralPath`, including wildcard and special-character paths.
- [ ] Test `-WhatIf`/`-Confirm` for mutating commands.
- [ ] Test error IDs, categories, and non-terminating versus terminating behavior.
- [ ] Test import with default preferences and with each optional feature enabled.
- [ ] Verify importing PSCX does not replace global commands or aliases unless explicitly opted in.

### 2.4 Focused .NET unit suite

- [x] Retain tests for pure algorithms and internal value objects only.
- [x] Add regression coverage for date/time forwarding methods.
- [ ] Test unit conversion independently of formatting and PowerShell parameter binding.
- [ ] Test encoding, hashing, archive safety, and parser primitives independently where retained.
- [x] Avoid environmental dependencies such as installed modules, profiles, user PATH, network services, AD, SQL Server, or desktop state.
- [ ] Move environmental and PowerShell-host-dependent cases to Pester.

### 2.5 Static validation

- [ ] Run PSScriptAnalyzer over all `.ps1`, `.psm1`, and `.psd1` files.
- [ ] Validate all manifests with `Test-ModuleManifest`.
- [ ] Validate XML help, type data, and format data.
- [ ] Treat compiler warnings as errors after the existing warning backlog is resolved.
- [ ] Add formatting checks for C#, PowerShell, Markdown, XML, and YAML.

### Exit criteria

- [ ] Tests execute on every pull request.
- [ ] One documented command runs the complete test strategy locally and in CI.
- [ ] Every test has one clear owner: public PowerShell contract or pure internal algorithm.
- [ ] The packaged module imports successfully on every supported OS.
- [ ] Export and help consistency are enforced automatically.
- [ ] Cross-platform claims have cross-platform evidence.

---

## Phase 3: Align metadata, documentation, and release automation

**Goal:** Make the published compatibility and feature story accurate and self-maintaining.

- [ ] Before Phase 3 begins, decompose the remaining roadmap into reviewable GitHub issues and link each issue to its corresponding section.

### 3.1 Correct current documentation drift

- [ ] Update the README's PowerShell and .NET versions.
- [ ] Add a 3.8.0 changelog section.
- [ ] Correct the fork-origin version, release link, displayed commit, and linked commit so they agree.
- [ ] Correct the `Format-Hex` versus `Format-PscxHex` contradiction.
- [ ] Correct `Invoke-Sudo` versus `Invoke-Gsudo`/`gsudo` naming.
- [ ] Resolve whether `Search-Transcript` is public; export and document it or remove it from the catalog.
- [ ] Document the existing JSON, YAML, Base64, ISO date/time, and other type accelerators if retained.
- [ ] Document which features and commands are Windows-only.
- [ ] Replace “latest PowerShell” with a precise supported-version range.
- [ ] Remove promotional/profile content that distracts from installing and evaluating PSCX, or move it to a related-projects section.

### 3.2 Generate the public API catalog

- [ ] Enhance `Tools/find_cmdlets.ps1` or replace it with a validation/generation tool.
- [ ] Generate the README command tables from manifests and help metadata.
- [ ] Generate a platform column for every public command.
- [ ] Generate short descriptions from a single authoritative source.
- [ ] Fail CI when generated documentation differs from committed documentation.

### 3.3 Replace `Pscx.Help` with mainstream external help

The current `Pscx.Help` project is an internal build-time tool, not a useful user-facing module. It contains a snap-in-era `Get-PSSnapinHelp` generator, bespoke XML source files, and a custom XSLT conversion to MAML. Replace this pipeline with the supported `Microsoft.PowerShell.PlatyPS` workflow.

Use Markdown as the canonical, reviewable help source for all public commands. Generate external MAML help during the build and ship that generated MAML with each module so `Get-Help` works offline immediately.

PowerShell can infer command syntax and parameter metadata from a loaded command, but it does not extract a complete high-quality help topic—including detailed descriptions, parameter explanations, examples, notes, and related links—from the current C# attributes. Those parts still require authored documentation.

- [ ] Add a `docs/commands/` Markdown help tree organized by package.
- [ ] Import the built package and bootstrap Markdown topics from command metadata using `Microsoft.PowerShell.PlatyPS`.
- [ ] Migrate useful descriptions, examples, notes, inputs, outputs, and links from `Src/Pscx.Help/Help/*.xml`.
- [ ] Do not migrate help topics for commands already removed from the product.
- [ ] Use PlatyPS to generate each module's external MAML file into the correct culture directory, such as `en-US/`.
- [ ] Use comment-based help for small private/internal functions where external documentation adds no value.
- [ ] For public script functions, either:
  - use the same external PlatyPS-generated help as compiled cmdlets for consistency; or
  - use comment-based help only when it remains the single authoritative source and passes the same validation.
- [ ] Generate `about_Pscx` from Markdown rather than concatenated header/footer text.
- [ ] Validate Markdown help schema during CI.
- [ ] Import the packaged module and verify `Get-Help <command> -Full` for every export.
- [ ] Verify that documented parameter names and syntax match `Get-Command`.
- [ ] Smoke-test code examples that are deterministic and safe.
- [ ] Remove:
  - the `Pscx.Help` project and assembly;
  - `PscxHelp.psd1` and `PscxHelp.psm1`;
  - the `Get-PSSnapinHelp` implementation;
  - bespoke localized command XML after migration;
  - the custom MAML XSLT and generation scripts;
  - the help project from the solution and build dependencies.
- [ ] Decide later whether PSCX needs online/updatable help. If so, add `HelpInfoURI` and publish the required cross-platform help packages; this is optional and separate from shipping local help.

### 3.4 Improve installation and publishing

- [ ] Publish installable packages to PowerShell Gallery, if repository ownership and signing permit it.
- [ ] Document `Install-PSResource` as the preferred installation method.
- [ ] Keep a direct release ZIP as a secondary installation option.
- [ ] Remove the double-ZIP artifact problem by uploading the package itself as a release asset.
- [ ] Add SHA-256 checksums for release artifacts.
- [ ] Generate an SBOM for release packages.
- [ ] Sign PowerShell scripts, manifests, assemblies, and packages consistently if signing remains a project requirement.
- [ ] Validate the installed package in a clean environment before publishing.

### Exit criteria

- [ ] README, manifests, projects, CI, and changelog describe the same release.
- [ ] The public command catalog is generated or mechanically validated.
- [ ] A user can install PSCX with one standard PowerShell command.
- [ ] Release artifacts are reproducible and validated.

---

## Phase 4: Make the public API explicit and safe

**Goal:** Prevent accidental exports and unexpected session changes.

### Tasks

- [ ] Replace `AliasesToExport = '*'` with an explicit alias list.
- [ ] Replace all `Export-ModuleMember -Alias * -Function * -Cmdlet *` calls with explicit exports.
- [ ] Ensure each child module explicitly exports its own API.
- [ ] Generate or validate the parent manifest's aggregate exports.
- [ ] Add `Remove-PathVariable` to the public API and documentation, or explicitly mark it private.
- [ ] Review every alias for cross-platform collisions:
  - `tail`;
  - `touch`;
  - `skip`;
  - `ln`;
  - `help`;
  - all other short aliases.
- [ ] Move convenience aliases into an opt-in preference or separate `Pscx.LegacyAliases` module.
- [ ] Never replace the global `help` command during a default import.
- [ ] Add module-qualified examples where a PSCX command intentionally resembles a built-in.
- [ ] Give every public command a stable output type where structured output is expected.
- [ ] Document compatibility aliases and their planned removal date.

### Exit criteria

- [ ] Default import has no wildcard exports.
- [ ] Default import does not mutate global aliases.
- [ ] An automated test catches every accidental API addition or removal.

---

## Phase 5: Classify the existing feature set

**Goal:** Decide what belongs in the modern core, what moves to an optional package, and what is deprecated.

### 5.1 Retain and invest in the core

These areas are distinctive enough to keep, subject to normal API and quality review:

- [ ] PATH/environment-variable editing:
  - `Get-PathVariable`;
  - `Add-PathVariable`;
  - `Remove-PathVariable`;
  - `Set-PathVariable`.
- [ ] Environment-frame management:
  - `Get-EnvironmentBlock`;
  - `Push-EnvironmentBlock`;
  - `Pop-EnvironmentBlock`.
- [ ] Assembly and PE inspection:
  - `Test-Assembly`;
  - `Get-PEHeader`.
- [ ] XML tooling:
  - `Test-Xml`;
  - `Format-Xml`;
  - `Convert-Xml`.
- [ ] Unit and byte formatting:
  - `ConvertTo-Unit`;
  - `Format-Byte`.
- [ ] File/editor utilities:
  - `Edit-File`;
  - `Set-FileTime`.
- [ ] Error inspection:
  - `Resolve-ErrorRecord`;
  - platform-neutral portions of native error handling.
- [ ] Enhanced location-stack behavior, if usage and tests support it.
- [ ] Base64 conversion if its pipeline, file, and encoding behavior is meaningfully better than direct .NET calls.
- [ ] `Test-Script` if it exposes useful parser diagnostics as structured objects.

For every retained command:

- [ ] Write a concise differentiation statement.
- [ ] Ensure output is structured rather than display-only where practical.
- [ ] Review approved verbs and naming.
- [ ] Support standard common parameters and expected path semantics.
- [ ] Provide at least one realistic example.

### 5.2 Move to `Pscx.Archive`

Backend selection and the supported-platform contract are intentionally
deferred until this module is designed. Cross-platform support must be
demonstrated rather than assumed.

- [ ] `Write-PscxArchive`.
- [ ] `Read-PscxArchive`.
- [ ] `Expand-PscxArchive`.
- [ ] Select and document the archive backend.
- [ ] Define the supported-platform contract from demonstrated backend behavior.
- [ ] Verify archive creation, listing, and extraction on every claimed platform.
- [ ] Add zip-slip/path-traversal tests.
- [ ] Add symbolic-link and permission-handling tests.
- [ ] Decide whether encrypted archives are supported and test password handling without exposing secrets.
- [ ] Package only required architecture-specific binaries.
- [ ] Avoid storing duplicate source archives, NuGet packages, framework builds, and runtime binaries in the main repository.

### 5.3 Move to `Pscx.WindowsAdmin`

Candidate groups:

- [ ] Active Directory and DHCP.
- [ ] SQL Server, ADO, and OLE DB.
- [ ] Privileges and user/group membership.
- [ ] Terminal Services/Remote Desktop sessions.
- [ ] VHD operations.
- [ ] COM running-object access.
- [ ] Shortcuts and short paths.
- [ ] Mount points, reparse points, and volume labels.
- [ ] Windows foreground-window APIs.
- [ ] Windows-native error decoding.
- [ ] Visual Studio environment import.
- [x] Keep elevation/gsudo integration in the default Windows core rather than moving it into this optional module.

For each group:

- [ ] Identify maintained Microsoft or community modules that already cover it.
- [ ] Retain PSCX only when it offers simpler installation, better pipeline behavior, or otherwise distinctive value.
- [ ] Avoid importing heavy dependencies until a related command is invoked.
- [ ] Add `[SupportedOSPlatform("windows")]` consistently.

### 5.4 Move platform-neutral features out of the Windows assembly

- [ ] Move `ConvertFrom-Yaml` and `ConvertTo-Yaml` into the cross-platform core or a small optional data-format package.
- [ ] Review archive commands for cross-platform placement.
- [ ] Move `Get-ForegroundWindow` and `Set-ForegroundWindow` out of the cross-platform project and into `Pscx.WindowsAdmin`.
- [ ] Audit every source file against its project's platform contract.

### 5.5 Deprecate and remove low-value duplicates

| Command/feature | Proposed action | Replacement or reason |
| --- | --- | --- |
| `ConvertTo-MacOs9LineEnding` | Remove | Obsolete line-ending format |
| `Get-LoremIpsum` | Remove or move to examples | Outside the core CLI productivity scope |
| `Get-FileTail` | Deprecate | `Get-Content -Tail -Wait` |
| `Get-PscxHash` | Deprecate unless byte-array streaming is distinctive | `Get-FileHash` |
| `Format-Hex` | Remove or rename with proven differentiation | Built-in `Format-Hex`; current name collides |
| `Join-PscxString` | Deprecate unless behavior is distinctive | Built-in `Join-String` |
| `Split-PscxString` | Review for removal | Native string splitting and `-split` |
| `Get-PscxUptime` | Deprecate | Built-in `Get-Uptime` |
| `New-Hardlink` | Deprecate | `New-Item -ItemType HardLink` |
| `New-Symlink` | Deprecate | `New-Item -ItemType SymbolicLink` |
| `New-Junction` | Deprecate | `New-Item -ItemType Junction` |
| `Invoke-GC` | Remove | Manual garbage collection is rarely appropriate |
| `PscxHelp` | Make optional or remove | Modern help and pager behavior |
| `PscxLess` | Retain in the default Windows core; review its API and integration | The bundled pager is considered a valuable Windows CLI utility |
| Screen CSS/HTML helpers | Review for removal | Narrow and unrelated surface |
| WMI accelerator module | Review for removal | WMI-era compatibility surface needs a current use case |

### Deprecation mechanics

- [ ] Emit one actionable warning per session, not one warning per pipeline item.
- [ ] Add replacement examples to help.
- [ ] Publish a removal version and date.
- [ ] Provide a compatibility module for users who cannot migrate immediately.
- [ ] Measure feedback during 4.0 previews before final removal.

### Exit criteria

- [ ] Every existing public command has a documented disposition.
- [ ] The core module has a coherent scope.
- [ ] Optional dependencies are not loaded by the default core import.

---

## Phase 6: Reduce bundled binaries and supply-chain surface

**Goal:** Reduce package size, repository weight, update burden, and exposure from redistributed executables.

### Tasks

- [ ] Inventory every copy of 7-Zip, gsudo, less, SevenZipSharp, PowerShell assemblies, and native support libraries.
- [ ] Identify duplicate architectures, compressed source packages, NuGet packages, and extracted binaries.
- [ ] Stop committing generated `Output` packages to the repository.
- [ ] Prefer NuGet/package restore over committing third-party managed assemblies.
- [ ] Do not redistribute PowerShell runtime assemblies unless there is a demonstrated runtime requirement.
- [x] Retain bundled gsudo in the default Windows core package.
- [x] Retain bundled less in the default Windows core package.
- [ ] Determine whether the byte-identical `gsudo.exe` and `sudo.exe` files are both required for command-name compatibility or can share one payload safely.
- [ ] Package only the archive binary for the user's operating system and architecture.
- [ ] Add checksums and provenance records for every redistributed executable.
- [ ] Automate third-party update detection.
- [ ] Add malware/signature scanning to the release workflow where available.

### Exit criteria

- [ ] The default PSCX package contains no unrelated native executable.
- [ ] Optional package size and contents are documented.
- [ ] Every redistributed binary has version, license, source, checksum, and update ownership recorded.

---

## Phase 7: Add a small set of cohesive improvements

**Goal:** Add features that strengthen the modern CLI mission after the existing surface is reliable.

### 7.1 PATH management improvements

- [ ] Add normalization and duplicate removal.
- [ ] Add existence validation with an option to retain unavailable paths.
- [ ] Support process, user, and machine scope where the OS permits it.
- [ ] Preserve platform-specific path comparison behavior.
- [ ] Provide `-PassThru` for commands that mutate PATH-like variables.
- [ ] Add dry-run/`-WhatIf` support for persistent changes.
- [ ] Provide structured output describing added, removed, retained, invalid, and duplicate entries.

### 7.2 File text diagnostics

- [ ] Add encoding and BOM detection.
- [ ] Add line-ending detection, including mixed-line-ending reporting.
- [ ] Consider one consolidated line-ending command instead of separate Windows, Unix, and legacy Mac commands.
- [ ] Preserve final-newline behavior explicitly.
- [ ] Support check-only operation for CI use.

### 7.3 Installation diagnostics

- [ ] Add `Test-PscxInstallation` or equivalent.
- [ ] Report:
  - PSCX version;
  - PowerShell and .NET versions;
  - operating system and architecture;
  - loaded optional modules;
  - editor and pager resolution;
  - archive backend availability;
  - missing or incompatible native dependencies;
  - manifest/help/export validation status.
- [ ] Return structured diagnostic objects and provide a concise default view.

### 7.4 Command discovery and documentation

- [ ] Add examples organized by task rather than only alphabetically by noun.
- [ ] Add “Why PSCX instead of the built-in?” notes for commands with nearby built-in functionality.
- [ ] Add a platform/support table.
- [ ] Add migration guidance from legacy PSCX and from PSCX Light 3.x.

### Exit criteria

- [ ] New features have cross-platform tests and full help.
- [ ] Each feature directly supports the CLI-extension mission.
- [ ] No new large mandatory dependency is introduced into the core.

---

## Phase 8: Release PSCX 4.0

**Goal:** Deliver the simplified package family with a clear migration path.

### Preview checklist

- [ ] Publish at least one preview of each new package.
- [ ] Publish a complete 3.x-to-4.0 migration guide.
- [ ] Test clean install, upgrade, uninstall, and side-by-side scenarios.
- [ ] Test package import in clean Windows, Linux, and macOS environments.
- [ ] Test PowerShell Gallery installation and direct release ZIP installation.
- [ ] Validate command help and examples from installed packages.
- [ ] Collect and triage preview feedback.
- [ ] Freeze the public API before release-candidate builds.

### Stable release checklist

- [ ] All CI checks pass from a clean checkout.
- [ ] No unapproved high or critical dependency vulnerability remains.
- [ ] Package contents and SBOM are reviewed.
- [ ] Release notes list additions, fixes, removals, and replacements.
- [ ] Checksums and signatures are published.
- [ ] Documentation points to stable package names and versions.
- [ ] Legacy compatibility package or migration instructions are available.

---

## Cross-cutting quality requirements

Apply these requirements whenever a command is added or materially changed:

- [ ] Uses an approved PowerShell verb or documents why an exception is necessary.
- [ ] Has consistent `-Path`/`-LiteralPath` behavior.
- [ ] Accepts pipeline input where that improves composition.
- [ ] Emits objects, not preformatted text, unless formatting is the command's purpose.
- [ ] Uses `ShouldProcess` for changes and destructive actions.
- [ ] Uses stable error IDs and appropriate error categories.
- [ ] Supports cancellation for long-running operations where practical.
- [ ] Avoids changing global session state during import.
- [ ] Has comment-based or external help, including examples.
- [ ] Has Pester coverage at the module boundary.
- [ ] Has lower-level tests for complex implementation logic.
- [ ] Declares and tests its supported operating systems.
- [ ] Does not introduce an undeclared mandatory dependency.

## Suggested issue breakdown

The following issues are small enough to begin independently:

1. Fix and test NodaTime second/millisecond arithmetic.
2. Select and align the PowerShell/.NET compatibility baseline.
3. Establish one authoritative semantic-version source and derived-version policy.
4. Add the cross-platform repository build/test/package entry point.
5. Replace the legacy desktop GitHub workflow with streamlined CI and release workflows.
6. Make individual project builds independent of `$(SolutionDir)`.
7. Add the unified Pester and focused .NET test architecture.
8. Add cross-platform packaged-module import tests.
9. Resolve the vulnerable transitive dependency.
10. Replace wildcard exports with explicit exports.
11. Export or intentionally privatize `Remove-PathVariable`.
12. Move YAML commands to the cross-platform project.
13. Move foreground-window commands to the Windows project.
14. Resolve the `Format-Hex` naming/collision issue.
15. Replace `Pscx.Help` with Markdown and PlatyPS.
16. Generate and validate the README command catalog.
17. Stop committing generated release output.
18. Inventory and reduce bundled third-party binaries.
19. Draft the 4.0 command deprecation and migration table.
20. Prototype the `Pscx.Archive` package.
21. Prototype the `Pscx.WindowsAdmin` package.
22. Add PATH normalization and validation.
23. Add `Test-PscxInstallation`.

## Progress summary

| Phase | Status | Completion |
| --- | --- | --- |
| 0. Baseline and decisions | Complete | 100% |
| 1. Correctness, security, builds | In progress | 25% |
| 2. Tests and CI | Not started | 0% |
| 3. Metadata, docs, releases | Not started | 0% |
| 4. Explicit public API | Not started | 0% |
| 5. Feature classification | Not started | 0% |
| 6. Dependency and binary reduction | Not started | 0% |
| 7. Cohesive improvements | Not started | 0% |
| 8. PSCX 4.0 release | Not started | 0% |

Update this table when a phase changes state. Detailed completion should remain in the checklists so the summary does not become a second source of truth.
