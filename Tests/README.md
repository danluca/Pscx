# PSCX test architecture

Run the complete release-blocking test path from the repository root:

```powershell
./build.ps1 -Task TestPipeline
```

The command restores and builds the appropriate platform scope, assembles the
package in an isolated artifacts directory, runs both active suites, validates
the package, and fails if either suite or its independent coverage gate fails.

- `Pscx.InternalTests` owns cross-platform pure algorithms and value objects.
- `Pscx.Package.Tests.ps1` owns module and public PowerShell behavior against
  the staged package. It enforces manifest exports, aliases, providers, help,
  README example syntax, representative parameter/pipeline/error behavior, and
  default plus optional-feature imports. Import variants run in fresh child
  processes to prevent session state from leaking between cases.
- `Pscx.LegacyTests` is a non-release-blocking migration source. Run it
  explicitly with `./build.ps1 -Task TestAll -BuildScope Full`.

`TestPolicy.psd1` pins Pester and defines separate initial managed and
PowerShell coverage gates. Results are written beneath
`artifacts/test-results` as TRX, NUnit 3 XML, Cobertura XML, framework JSON, and
one aggregate JSON status.

`Pscx.PublicContract.psd1` temporarily records aliases and providers because
the legacy manifests cannot declare providers and still use wildcard alias
exports. Phase 4 will make aliases explicit in the manifests; the contract file
should then retain only data that cannot be expressed by module metadata.

## Test-only dependencies

- [Pester 6.0.0](https://www.powershellgallery.com/packages/Pester/6.0.0)
  (Apache-2.0) is saved under ignored `.tools/modules`.
- [coverlet.collector 10.0.1](https://www.nuget.org/packages/coverlet.collector/10.0.1)
  (MIT) is a private test-project dependency.

Neither dependency is included in the PSCX package.
