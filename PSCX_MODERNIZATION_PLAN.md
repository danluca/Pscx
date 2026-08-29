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
| `Pscx.Archive` | Optional, cross-platform archive support beginning with PSCX 4.0 | Read, create, and safely expand archives through the managed SharpCompress backend |
| `Pscx.WinAdmin` | Optional Windows administration | Generic ADO/OLE DB access, batch environment import, short-path annotation, and foreground-window inspection |
| `Pscx.Time` | Optional date/time helpers beginning with PSCX 4.0 | NodaTime-backed types and accelerators with a documented supported API |

`Pscx.Time` is packaged as a separate sibling module in the unified ZIP so
consumers explicitly choose whether to install and import its NodaTime-backed
API.

## Release strategy

Use three release stages:

1. **3.x stabilization release**
   - Publish this work as PSCX 3.8.0 after Phase 3 is complete and before Phase 4 begins.
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
  - `Src/Pscx.Time/Time/LocalDateTime.cs`;
  - `Src/Pscx.Time/Time/OffsetDateTime.cs`;
  - `Src/Pscx.Time/Time/ZonedDateTime.cs`.
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
- [x] Verify every declared export resolves after import.
- [x] Verify no undeclared function, cmdlet, provider, or alias leaks from the module.
- [x] Verify `Get-Help` is available for every public command.
- [x] Verify examples in help and README where feasible.
- [x] Test pipeline binding and output object types.
- [x] Test `-Path` and `-LiteralPath`, including wildcard and special-character paths.
- [x] Test `-WhatIf`/`-Confirm` for mutating commands.
- [x] Test error IDs, categories, and non-terminating versus terminating behavior.
- [x] Test import with default preferences and with each optional feature enabled.
- [x] Verify importing PSCX does not replace global commands or aliases unless explicitly opted in.

### 2.4 Focused .NET unit suite

- [x] Retain tests for pure algorithms and internal value objects only.
- [x] Add regression coverage for date/time forwarding methods.
- [x] Test unit conversion independently of formatting and PowerShell parameter binding.
- [x] Test encoding and parser primitives independently, and hashing through the packaged public cmdlet. Archive safety moves to the Phase 5 module extraction because no standalone archive-safety primitive is retained in core.
- [x] Avoid environmental dependencies such as installed modules, profiles, user PATH, network services, AD, SQL Server, or desktop state.
- [x] Move environmental and PowerShell-host-dependent cases to Pester.

### 2.5 Static validation

- [x] Run PSScriptAnalyzer over all `.ps1`, `.psm1`, and `.psd1` files.
- [x] Validate all manifests with `Test-ModuleManifest`.
- [x] Validate XML help, type data, and format data.
- [ ] Treat compiler warnings as errors after the existing warning backlog is resolved.
  - Deferred: the clean Full build still reports an existing compiler-warning backlog. High/critical dependency warnings already fail; general warnings-as-errors will be enabled after the backlog is resolved.
- [x] Add formatting checks for C#, PowerShell, Markdown, XML, and YAML. Checked-in baselines prevent new debt while allowing incremental cleanup.

### Exit criteria

- [x] Tests execute on every pull request.
- [x] One documented command runs the complete test strategy locally and in CI.
- [x] Every test has one clear owner: public PowerShell contract or pure internal algorithm.
- [x] The packaged module imports successfully on every supported OS.
- [x] Export and help consistency are enforced automatically.
- [x] Cross-platform claims have cross-platform evidence.

---

## Phase 3: Align metadata, documentation, and release automation

**Goal:** Make the published compatibility and feature story accurate and self-maintaining.

- [x] Decompose Phase 3 into reviewable GitHub issues and link each issue to its corresponding section. Decompose later phases as their design work approaches.

### 3.1 Correct current documentation drift

**Tracking:** [#24 Correct PSCX 3.8 documentation and metadata drift](https://github.com/danluca/Pscx/issues/24)

- [x] Update the README's PowerShell and .NET versions.
- [x] Add a 3.8.0 changelog section.
- [x] Correct the fork-origin version, release link, displayed commit, and linked commit so they agree.
- [x] Correct the `Format-Hex` versus `Format-PscxHex` contradiction.
- [x] Correct `Invoke-Sudo` versus `Invoke-Gsudo`/`gsudo` naming.
- [x] Resolve whether `Search-Transcript` is public; export and document it or remove it from the catalog.
- [x] Document the existing JSON, YAML, Base64, ISO date/time, and other type accelerators if retained.
- [x] Document which features and commands are Windows-only.
- [x] Replace “latest PowerShell” with a precise supported-version range.
- [x] Remove promotional/profile content that distracts from installing and evaluating PSCX, or move it to a related-projects section.

### 3.2 Generate the public API catalog

**Tracking:** [#25 Generate and validate the PSCX public API catalog](https://github.com/danluca/Pscx/issues/25)

- [x] Enhance `Tools/find_cmdlets.ps1` or replace it with a validation/generation tool.
- [x] Generate the README command tables from manifests and help metadata.
- [x] Generate a platform column for every public command.
- [x] Generate short descriptions from a single authoritative source.
- [x] Fail CI when generated documentation differs from committed documentation.

### 3.3 Replace `Pscx.Help` with mainstream external help

**Tracking:** [#26 Replace Pscx.Help with Markdown and PlatyPS](https://github.com/danluca/Pscx/issues/26)

The current `Pscx.Help` project is an internal build-time tool, not a useful user-facing module. It contains a snap-in-era `Get-PSSnapinHelp` generator, bespoke XML source files, and a custom XSLT conversion to MAML. Replace this pipeline with the supported `Microsoft.PowerShell.PlatyPS` workflow.

Use Markdown as the canonical, reviewable help source for all public commands. Generate external MAML help during the build and ship that generated MAML with each module so `Get-Help` works offline immediately.

PowerShell can infer command syntax and parameter metadata from a loaded command, but it does not extract a complete high-quality help topic—including detailed descriptions, parameter explanations, examples, notes, and related links—from the current C# attributes. Those parts still require authored documentation.

- [x] Add a `docs/commands/` Markdown help tree organized by package.
- [x] Import the built package and bootstrap Markdown topics from command metadata using `Microsoft.PowerShell.PlatyPS`.
- [x] Migrate useful descriptions, examples, notes, inputs, outputs, and links from `Src/Pscx.Help/Help/*.xml`.
- [x] Do not migrate help topics for commands already removed from the product.
- [x] Use PlatyPS to generate each module's external MAML file into the correct culture directory, such as `en-US/`.
- [x] Use comment-based help for small private/internal functions where external documentation adds no value.
- [x] For public script functions, either:
  - use the same external PlatyPS-generated help as compiled cmdlets for consistency; or
  - use comment-based help only when it remains the single authoritative source and passes the same validation.
- [x] Generate `about_Pscx` from Markdown rather than concatenated header/footer text.
- [x] Validate Markdown help schema during CI.
- [x] Import the packaged module and verify `Get-Help <command> -Full` for every export.
- [x] Verify that documented parameter names and syntax match `Get-Command`.
- [x] Smoke-test code examples that are deterministic and safe.
- [x] Remove:
  - the `Pscx.Help` project and assembly;
  - `PscxHelp.psd1` and `PscxHelp.psm1`;
  - the `Get-PSSnapinHelp` implementation;
  - bespoke localized command XML after migration;
  - the custom MAML XSLT and generation scripts;
  - the help project from the solution and build dependencies.
- [x] Ship local offline help only. PSCX will not configure online/updatable
  help or publish separate help packages.

### 3.4 Improve installation and publishing

**Tracking:** [#27 Modernize PSCX installation and release artifacts](https://github.com/danluca/Pscx/issues/27)

- [x] Use GitHub Releases as the only supported distribution channel; do not
  publish PSCX to PowerShell Gallery.
- [x] Document direct ZIP installation as the supported installation method.
- [x] Upload the package ZIP itself to a draft GitHub Release from a tagged
  build, avoiding the Actions artifact wrapper/double-ZIP problem while
  preserving maintainer approval before publication.
- [x] Add SHA-256 checksums for release artifacts.
- [x] Generate a pinned-tool SPDX 2.2 SBOM for release packages.
- [x] Keep Authenticode signing as an explicit local maintainer operation for
  selected PowerShell files. Do not provide CI signing credentials, and leave
  PSCX-built binary artifacts unsigned.
- [x] Validate installation and module import from the completed release ZIP in
  an isolated module path before publishing.

### Exit criteria

- [x] README, manifests, projects, CI, and changelog describe the same release.
- [x] The public command catalog is generated or mechanically validated.
- [x] A user can install PSCX through the documented GitHub Release ZIP
  workflow without a gallery dependency.
- [x] Release artifacts are reproducible and validated.

---

## Release gate: PSCX 3.8.0 and transition to 4.0 development — complete

**Tracking:** [#28 Validate and release PSCX 3.8.0](https://github.com/danluca/Pscx/issues/28)

This is an ordered boundary between Phase 3 and Phase 4. Do not begin the
breaking public-surface or package-boundary work in Phase 4 on the 3.8
development line.

- [x] Complete every Phase 3 exit criterion.
- [x] Run the final release validation from a clean checkout on every supported
  operating system. The Windows, Linux, and macOS CI matrix is green, and a
  local stable-version `PublishPrep` rehearsal validated the ZIP installation,
  SPDX SBOM, and SHA-256 release assets on August 8, 2026.
- [x] Have [pull request #23](https://github.com/danluca/Pscx/pull/23) ready for
  review and ask the maintainer to merge it.
- [x] Merge pull request #23 into `master`, then update the local `master` branch
  to the resulting release commit.
- [x] Create and push the annotated `v3.8.0` tag from that exact release commit.
- [x] Verify the tag-triggered release workflow rebuilds 3.8.0 and creates a
  draft GitHub Release containing the ZIP, SPDX SBOM, and SHA-256 checksum.
- [x] Review the generated notes and attached assets, then publish the draft
  GitHub Release.
- [x] Perform a local install/upgrade of PSCX from the published GitHub Release.
- [x] After `v3.8.0` is released, create a `dev/29-rel40`.
- [x] In the first 4.0 development commit, change the authoritative `PscxVersionPrefix` in `Directory.Build.props` from `3.8.0` to `4.0.0-preview.1` and start the 4.0 changelog section.
- [x] Establish the 4.0 development line before beginning Phase 4 work.

---

## Phase 4: Make the public API explicit and safe

**Goal:** Prevent accidental exports and unexpected session changes.

### Tasks

- [x] Replace `AliasesToExport = '*'` with an explicit alias list.
- [x] Replace all `Export-ModuleMember -Alias * -Function * -Cmdlet *` calls with explicit exports.
- [x] Ensure each child module explicitly exports its own API.
- [x] Generate or validate the parent manifest's aggregate exports.
- [x] Add `Remove-PathVariable` to the public API and documentation, or explicitly mark it private.
- [x] Review every alias for cross-platform collisions:
  - `tail`;
  - `touch`;
  - `skip`;
  - `ln`;
  - `help`;
  - all other short aliases.
- [x] Preserve existing commands by default and allow deliberate alias collisions through
  `OverrideExistingAliases`; always replace `cd` when the CD submodule is enabled.
- [x] Never replace the global `help` command during a default import.
- [x] Add module-qualified examples where a PSCX command intentionally resembles a built-in.
- [x] Document the alias collision policy and retain the convenience aliases as supported API.

### Exit criteria

- [x] Default import has no wildcard exports.
- [x] Default import does not replace existing commands except for the documented `cd`
  behavior selected by enabling the CD submodule.
- [x] An automated test catches every accidental API addition or removal.

---

## Phase 5: Classify the existing feature set — complete

**Goal:** Decide what belongs in the modern core, what moves to an optional package, and what is deprecated.

- [x] Create a machine-validated proposed disposition for every public command in
  [`PSCX_COMMAND_DISPOSITION.psd1`](PSCX_COMMAND_DISPOSITION.psd1), with review
  findings in [`PSCX_COMMAND_DISPOSITION.md`](PSCX_COMMAND_DISPOSITION.md).
- [x] Review and approve each proposed disposition before implementing removals or
  package moves.

### 5.1 Retain and invest in the core

These areas are distinctive enough to keep, subject to normal API and quality review:

- [x] PATH/environment-variable editing:
  - `Get-PathVariable`;
  - `Add-PathVariable`;
  - `Remove-PathVariable`;
  - `Set-PathVariable`.
- [x] Environment-frame management:
  - `Get-EnvironmentBlock`;
  - `Push-EnvironmentBlock`;
  - `Pop-EnvironmentBlock`.
- [x] Assembly and PE inspection:
  - `Test-Assembly`;
  - `Get-PEHeader`.
- [x] XML tooling:
  - `Test-Xml`;
  - `Format-Xml`;
  - `Convert-Xml`.
- [x] Unit and byte formatting:
  - `ConvertTo-Unit`;
  - `Format-Byte`.
- [x] File/editor utilities:
  - `Edit-File`;
  - `Set-FileTime`.
- [x] Error inspection:
  - [x] retain `Resolve-ErrorRecord` with structured output by default and an
    explicit `-AsText` compatibility mode;
  - [x] retain Windows-native error decoding in the default Windows core.
- [x] Retain enhanced location-stack behavior and document `PathInfo` as the stable
  `-PassThru` output contract.
- [x] Retain Base64 conversion and route file progress through the verbose stream.
- [x] Retain `Test-Script` with its Boolean default and a `-PassThru` structured
  parser-result mode.

For every retained command:

- [x] Write a concise differentiation statement in
  [`PSCX_RETAINED_COMMAND_AUDIT.psd1`](PSCX_RETAINED_COMMAND_AUDIT.psd1).
- [x] Audit and document its output contract; provide a stable output type wherever
  structured output is expected.
- [x] Ensure output is structured rather than display-only where practical.
- [x] Review approved verbs and naming, documenting compatibility exceptions.
- [x] Support standard common parameters and expected path semantics, documenting
  the few intentional exceptions.
- [x] Provide at least one realistic example and enforce example coverage for
  default-loaded retained commands in packaged tests.

### 5.2 Move to `Pscx.Archive`

`Pscx.Archive` is a separately imported, managed-only sibling module using
SharpCompress 0.50.4 and distributed in the unified PSCX release ZIP. It
supports PowerShell 7.6/.NET 10 on Windows, Linux, and macOS without loading
archive dependencies during the default `Pscx` import. PSCX 4.0 creates ZIP,
7z, TAR, TAR.GZ/TGZ, and TAR.BZ2/TBZ2 archives;
listing and extraction use SharpCompress's detected read formats. Extraction
is intentionally unencrypted and rejects rooted paths, parent traversal, and
symbolic-link entries before writing. File timestamps are preserved when
available; ACL and Unix-mode preservation are not part of the portable 4.0
contract.

- [x] `Write-PscxArchive`.
- [x] `Read-PscxArchive`.
- [x] `Expand-PscxArchive`.
- [x] Select and document the archive backend.
- [x] Define the supported-platform contract from demonstrated backend behavior.
- [ ] Verify archive creation, listing, and extraction on every claimed platform.
- [x] Add zip-slip/path-traversal tests.
- [x] Add symbolic-link and permission-handling tests.
- [x] Decide that encrypted archive extraction is unsupported in 4.0 and reject it explicitly without accepting or exposing passwords.
- [x] Eliminate architecture-specific archive binaries by using the managed-only backend.
- [x] Avoid storing duplicate source archives, NuGet packages, framework builds, and runtime binaries in the main repository.

### 5.3 Move to `Pscx.WinAdmin`

Implemented disposition:

- [x] Remove PSCX Active Directory and DHCP commands in favor of the Windows
  ActiveDirectory and DhcpServer modules; document their installation and
  command replacements.
- [x] Remove the SQL Server-specific PSCX commands in favor of Microsoft's
  SqlServer module; retain the provider-neutral ADO and OLE DB commands in
  `Pscx.WinAdmin`.
- [x] Retain privileges and user/group membership in the default Windows core.
- [x] Retain Terminal Services/Remote Desktop sessions in the default Windows core.
- [x] Remove PSCX VHD operations in favor of the Hyper-V module's `Mount-VHD`
  and `Dismount-VHD` commands.
- [x] Retain COM running-object access in the default Windows core.
- [x] Move `Add-ShortPath` to WinAdmin; retain shortcut creation and short-path lookup in Windows core.
- [x] Retain mount points, reparse points, and volume labels in the default Windows core.
- [x] Move `Get-ForegroundWindow` to WinAdmin; retain `Set-ForegroundWindow` in Windows core.
- [x] Retain Windows-native error decoding in the default Windows core.
- [x] Retain Visual Studio environment import in the default Windows core.
- [x] Keep elevation/gsudo integration in the default Windows core rather than moving it into this optional module.
- [x] Keep `Disconnect-TerminalSession` with its Terminal Services companions:
  unlike `Stop-TerminalSession`, it preserves the session and its programs for
  later reconnection.
- [x] Move `Invoke-BatchFile` to WinAdmin because its arbitrary batch-file
  environment capture remains broader than Visual Studio's developer shells.

For each group:

- [x] Identify maintained Microsoft or community modules that already cover it.
- [x] Retain PSCX only when it offers simpler installation, better pipeline behavior, or otherwise distinctive value.
- [x] Avoid importing heavy dependencies until a related command is invoked.
- [x] Add `[SupportedOSPlatform("windows")]` consistently.
- [x] Package `Pscx.WinAdmin` as a separately imported sibling root in the
  unified Full Windows ZIP and validate its nine-command public contract.

### 5.4 Move platform-neutral features out of the Windows assembly

- [x] Move `ConvertFrom-Yaml` and `ConvertTo-Yaml`, their type accelerators, and
  YamlDotNet into the cross-platform core.
- [x] Review archive commands for cross-platform placement; they ship in the optional cross-platform `Pscx.Archive` module.
- [x] Move `Get-ForegroundWindow` out of the cross-platform project and into `Pscx.WinAdmin`; retain `Set-ForegroundWindow` in Windows core.
- [x] Audit every source file against its project's platform contract; move
  `Stop-RemoteProcess` into `PscxWin`, guard the shared OEM-encoding interop,
  and enforce the reviewed boundaries in static validation. See the
  [Phase 5.4 platform-source audit](PSCX_COMMAND_DISPOSITION.md#phase-54-platform-source-audit).

### 5.5 Deprecate and remove low-value duplicates

| Command/feature | Resolution | Replacement or reason |
| --- | --- | --- |
| `ConvertTo-MacOs9LineEnding` | Removed in 4.0 | Obsolete line-ending format |
| `Get-LoremIpsum` | Removed in 4.0 | Outside the core CLI productivity scope |
| `Get-FileTail` | Retained as a thin function | Delegates to `Get-Content -Tail` and optional `-Wait` |
| `Get-PscxHash` | Retained | Its string and aggregated byte-array pipeline hashing remains distinctive from `Get-FileHash` |
| `Format-Hex` | Removed in 4.0 | Use the built-in `Format-Hex`; the PSCX name collided |
| `Join-PscxString` | Removed in 4.0 | Use the built-in `Join-String` |
| `Split-PscxString` | Removed in 4.0 | Use native string splitting or `-split` |
| `Get-PscxUptime` | Removed in 4.0 | Use the built-in `Get-Uptime` |
| `New-Hardlink` | Retained as a thin function | Delegates to `New-Item -ItemType HardLink` on all supported platforms |
| `New-Symlink` | Retained as a thin function | Delegates to `New-Item -ItemType SymbolicLink` on all supported platforms |
| `New-Junction` | Retained as a thin Windows function | Delegates to `New-Item -ItemType Junction` |
| `Invoke-GC` | Removed in 4.0 | Manual garbage collection is rarely appropriate |
| `PscxHelp` | Removed in 4.0 | Use PowerShell's built-in `Get-Help` and `help`; retain `PscxLess` for explicit paging |
| `PscxLess` | Retained in the default Windows core | The bundled pager remains a valuable Windows CLI utility |
| Screen CSS/HTML helpers | Removed in 4.0 | Narrow, host-specific, and unrelated surface |
| WMI accelerator module | Removed in 4.0 | Use modern CIM commands and native `DateTime`/`TimeSpan` values |

### Deprecation mechanics

- [x] Do not emit deprecation warnings from the retained convenience wrappers;
  they are maintained PSCX APIs backed by modern built-ins.
- [x] Document replacements for commands removed at the 4.0 breaking boundary.
- [x] Publish 4.0.0 as the removal version; its release date remains controlled
  by the maintainer's release decision.
- [x] Do not ship a compatibility module for the low-value duplicates; the
  retained file-tail and link wrappers cover the convenience use cases chosen
  by the maintainer.
- [x] Record the decisions in the roadmap and migration guidance rather than
  delaying the already-approved 4.0 removals for a second preview cycle.

### 5.6 Extract the optional time module

- [x] Package the NodaTime-backed types and accelerators as the separately
  imported `Pscx.Time` module approved in Phase 0.
- [x] Remove NodaTime and the `isodate`, `zonedtime`, `offsettime`,
  `localtime`, `tz`, and `tzi` accelerators from the default `Pscx`
  import.
- [x] Preserve the corrected arithmetic behavior and managed tests in the new
  module boundary.
- [x] Add packaged-module import, export, help, dependency-isolation, and
  cross-platform tests for `Pscx.Time`.
- [x] Document installation, explicit import, migration, and the unified ZIP
  layout for the optional sibling module.

### Exit criteria

- [x] Every existing public command has a documented disposition.
- [x] The core module has a coherent scope.
- [x] Optional dependencies are not loaded by the default core import.

---

## Phase 6: Reduce bundled binaries and supply-chain surface

**Goal:** Reduce package size, repository weight, update burden, and exposure from redistributed executables.

### Tasks

- [x] Inventory every copy of 7-Zip, gsudo, less, SevenZipSharp, PowerShell assemblies, and native support libraries.
- [x] Identify duplicate architectures, compressed source packages, NuGet packages, and extracted binaries.
- [x] Stop committing generated `Output` packages to the repository.
- [x] Prefer NuGet/package restore over committing third-party managed assemblies.
- [x] Do not redistribute PowerShell runtime assemblies unless there is a demonstrated runtime requirement.
- [x] Retain bundled gsudo in the default Windows core package.
- [x] Retain bundled less in the default Windows core package.
- [x] Determine whether the byte-identical `gsudo.exe` and `sudo.exe` files are both required for command-name compatibility or can share one payload safely.
- [x] Package only the archive binary for the user's operating system and architecture. Superseded by the managed-only, cross-platform `Pscx.Archive` module; no native archive binary ships.
- [x] Add checksums and provenance records for every redistributed executable.
- [x] Automate third-party update detection.
- [x] Add malware/signature scanning to the release workflow where available.

### Exit criteria

- [x] The default PSCX package contains no unrelated native executable.
- [x] Optional package size and contents are documented.
- [x] Every redistributed binary has version, license, source, checksum, and update ownership recorded.

---

## Phase 7: Add a small set of cohesive improvements

**Goal:** Add features that strengthen the modern CLI mission after the existing surface is reliable.

### 7.1 PATH management improvements

- [x] Add normalization and duplicate removal.
- [x] Add existence validation with an option to retain unavailable paths.
- [x] Support process, user, and machine scope where the OS permits it.
- [x] Preserve platform-specific path comparison behavior, with an explicit
  `-CaseInsensitive` override for Unix systems.
- [x] Provide `-PassThru` for commands that mutate PATH-like variables.
- [x] Add dry-run/`-WhatIf` support for persistent changes.
- [x] Provide structured output describing added, removed, retained, invalid, and duplicate entries.

### 7.2 File text diagnostics

- [x] Add encoding and BOM detection through structured `Get-TextFileInfo` output.
- [x] Add line-ending detection, including mixed-line-ending reporting and per-style counts.
- [x] Evaluate consolidating the line-ending commands; retain the explicit
  `ConvertTo-UnixLineEnding` and `ConvertTo-WindowsLineEnding` names because
  they communicate intent clearly, while sharing one implementation and not
  adding a legacy Mac-specific command.
- [x] Preserve encoding, BOM, and final-newline state by default, with explicit
  `-FinalNewline Preserve|Add|Remove` control.
- [x] Support non-mutating `-Check` operation with structured
  `NeedsConversion` output for CI use.
- [x] Cover byte-level conversion behavior in managed tests and the shipped
  command contract in packaged-module Pester tests.

### 7.3 Installation diagnostics

- [x] Add `Test-PscxInstallation` as an observational, cross-platform command
  that does not import modules, execute tools, access the network, or mutate
  the session.
- [x] Report:
  - PSCX version;
  - PowerShell and .NET versions;
  - operating system and architecture;
  - loaded optional modules;
  - editor and pager resolution;
  - archive backend availability;
  - missing or incompatible native dependencies;
  - manifest/help/export validation status.
- [x] Return one `Pscx.InstallationDiagnostic` object per check, with category,
  name, status, actual and expected values, message, and details, plus a concise
  default table view.
- [x] Treat unavailable or unloaded optional packages as informational,
  unresolved user-facing tools as warnings, and broken loaded/package
  contracts as failures.
- [x] Cover the shipped command, output shape, default view, session
  non-mutation, and degraded editor/pager resolution in packaged Pester tests.

### 7.4 Command discovery and documentation

- [x] Add examples organized by task rather than only alphabetically by noun in
  the [task-oriented command guide](docs/COMMAND_DISCOVERY.md), and surface
  practical starting points in the installed `about_Pscx` help.
- [x] Add “Why PSCX instead of the built-in?” notes for commands with nearby
  built-in functionality, including guidance to prefer the built-in when the
  PSCX convenience layer adds no needed behavior.
- [x] Add a platform/support table covering the core, Windows companion,
  explicit sibling modules, and platform-specific PATH behavior.
- [x] Add a [PSCX 4.0 migration guide](docs/MIGRATING_TO_4.0.md) for both PSCX
  Light 3.x and older full/upstream PSCX, including runtime, installation,
  package-boundary, command-removal, alias, and output-contract changes.
- [x] Validate the new guides' PowerShell example syntax, README links, removed
  command coverage, and installed about-help discovery content in packaged
  Pester tests.

### 7.5 Guided update and installation

- [x] Add an explicitly invoked PowerShell update script that discovers the
  latest compatible stable PSCX release from GitHub Releases, compares it with
  installed versions, and reports the available version and release-notes URL.
  Allow prerelease discovery only through an explicit opt-in switch.
- [x] Require interactive confirmation immediately before installation and
  support `ShouldProcess`, including `-WhatIf`; do not check the network or
  prompt automatically during module import or normal command execution.
- [x] Download the release ZIP and checksum to a temporary location, verify the
  SHA-256 checksum and package manifest/version, and reject unsafe archive paths
  before modifying a module directory.
- [x] Install atomically into the versioned `Pscx/<module-version>/...` layout,
  retain existing versions for rollback, and report the installed path and the
  command needed to import the new version. Keep removal of older versions a
  separate, explicit operation.
- [x] Handle offline, proxy, rate-limit, incompatible-runtime, permission, and
  interrupted-install failures with actionable errors and no partial install.
- [x] Test release selection, semantic-version comparison, confirmation,
  `-WhatIf`, checksum failure, archive safety, side-by-side installation, and
  recovery behavior without depending on the live GitHub service.

### Exit criteria

- [x] New features have cross-platform tests and full help.
- [x] Each feature directly supports the CLI-extension mission.
- [x] No new large mandatory dependency is introduced into the core.

---

## Phase 8: Release PSCX 4.0

**Goal:** Deliver the simplified package family with a clear migration path.

### Preview checklist

- [x] Replace the flaky per-file/rule-batch parallel PSScriptAnalyzer subprocess
  pattern with deterministic, bounded static-analysis orchestration.
- [x] Preserve complete diagnostics for analyzer infrastructure failures,
  including the file, rule batch, exit code, standard output, and standard
  error; distinguish those failures from actual analyzer findings, and ensure
  that any narrowly scoped transient retry still reports the initial failure
  and never retries or hides a genuine finding.
- [x] Add regression coverage for the static-analysis runner so a child-process
  failure cannot lose its diagnostic context on Windows, Linux, or macOS.
- [x] Generate a portable HTML test dashboard from the existing managed-test
  TRX, Pester NUnit XML, coverage, and static-validation JSON outputs. Present
  overall and per-suite status, passed/failed/skipped counts, failure details,
  duration, and the separate PowerShell and managed-code coverage results.
- [x] Produce the same HTML dashboard from local and CI test runs and upload it
  as a browsable CI artifact. Keep the XML, JSON, TRX, and coverage files as
  the authoritative machine-readable results; the dashboard is a convenience
  view and must not become a second source of test truth.
- [x] Make the report self-contained and usable offline without CDN resources,
  platform-specific browser automation, or exposing environment-sensitive
  paths and data.
- [x] Generate release ZIPs with the standard versioned module layout,
  `Pscx/<module-version>/...`, deriving the directory name from the
  authoritative module version rather than hard-coding it.
- [x] Validate that extracting the ZIP directly into a directory on
  `$env:PSModulePath` supports normal discovery, version-qualified import, and
  side-by-side installation without rearranging package contents.
- [x] Include the maintainer's public code-signing root certificate for
  optional Windows Authenticode validation, document its expected identity and
  broad trust implications, and require certificate-store or publisher-trust
  changes to remain explicit manual user actions.
- [ ] Publish at least one preview of each new package.
- [ ] Publish a complete 3.x-to-4.0 migration guide.
- [ ] Test clean install, upgrade, uninstall, and side-by-side scenarios.
- [ ] Test package import in clean Windows, Linux, and macOS environments.
- [ ] Test direct GitHub Release ZIP installation.
- [ ] Validate command help and examples from installed packages.
- [ ] Collect and triage preview feedback.
- [ ] Freeze the public API before release-candidate builds.

### Stable release checklist

- [ ] All CI checks pass from a clean checkout.
- [ ] No unapproved high or critical dependency vulnerability remains.
- [ ] Package contents and SBOM are reviewed.
- [ ] Release notes list additions, fixes, removals, and replacements.
- [ ] Checksums and an SBOM are published, and signing status is documented.
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
21. Prototype the `Pscx.WinAdmin` package.
22. Add PATH normalization and validation.
23. Add `Test-PscxInstallation`.

## Progress summary

| Phase | Status | Completion |
| --- | --- | --- |
| 0. Baseline and decisions | Complete | 100% |
| 1. Correctness, security, builds | Complete | 100% |
| 2. Tests and CI | Complete | 100% |
| 3. Metadata, docs, releases | Complete | 100% |
| 4. Explicit public API | Complete | 100% |
| 5. Feature classification | Complete | 100% |
| 6. Dependency and binary reduction | Complete | 100% |
| 7. Cohesive improvements | Complete | 100% |
| 8. PSCX 4.0 release | In progress | 33% |

Update this table when a phase changes state. Detailed completion should remain in the checklists so the summary does not become a second source of truth.
