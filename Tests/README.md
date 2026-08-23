# PSCX test architecture

Run the complete release-blocking test path from the repository root:

```powershell
./build.ps1 -Task TestPipeline
```

The command restores and builds the appropriate platform scope, assembles the
package in an isolated artifacts directory, runs the managed and Pester suites,
runs static validation, validates the package, and fails if any gate fails.

- `Pscx.InternalTests` owns pure algorithms and value objects. Windows-only
  implementation tests are compiled only for `Full` builds.
- `Pscx.Package.Tests.ps1` owns module and public PowerShell behavior against
  the staged package. It enforces manifest exports, aliases, providers, help,
  README example syntax, representative parameter/pipeline/error behavior, and
  default plus optional-feature imports. Import variants run in fresh child
  processes to prevent session state from leaking between cases.
- `Pscx.Time.Package.Tests.ps1` owns the accelerator-only sibling-module
  contract, including default-import dependency isolation, explicit
  registration/removal, offline help, and package contents.
- `Test-PscxStatic.ps1` owns repository-wide PSScriptAnalyzer, module-manifest,
  XML/type/format-data, and formatting regression checks.

`TestPolicy.psd1` pins Pester, PSScriptAnalyzer, and the build-only PlatyPS
module and defines separate initial managed and PowerShell coverage gates.
`StaticAnalysisBaseline.psd1` records
existing analyzer and formatting debt; the static gate permits reductions but
fails on regressions. Results are written beneath
`artifacts/test-results` as TRX, NUnit 3 XML, Cobertura XML, framework JSON, and
one aggregate JSON status.

`Pscx.PublicContract.psd1` temporarily records aliases and providers because
the legacy manifests cannot declare providers and still use wildcard alias
exports. Phase 4 will make aliases explicit in the manifests; the contract file
should then retain only data that cannot be expressed by module metadata.

## Test-only dependencies

- [Pester 6.0.0](https://www.powershellgallery.com/packages/Pester/6.0.0)
  (Apache-2.0) is saved under ignored `.tools/modules`.
- [PSScriptAnalyzer 1.25.0](https://www.powershellgallery.com/packages/PSScriptAnalyzer/1.25.0)
  (MIT) is saved under ignored `.tools/modules`.
- [coverlet.collector 10.0.1](https://www.nuget.org/packages/coverlet.collector/10.0.1)
  (MIT) is a private test-project dependency.

Neither dependency is included in the PSCX package.
