# Dependency Security Policy

## Audit policy

PSCX audits direct and transitive NuGet dependencies during restore.
`Directory.Build.props` configures NuGet Audit to report high and critical
vulnerabilities and treats `NU1903` and `NU1904` as build errors.

Run the same checks locally:

```powershell
dotnet restore ./Src/Pscx.sln
dotnet package list `
    --project ./Src/Pscx.sln `
    --include-transitive `
    --vulnerable `
    --no-restore
```

The dedicated dependency-audit workflow runs these commands for pull requests,
pushes to `master`, a weekly schedule, and manual dispatches.

## Current transitive override

`Microsoft.PowerShell.SDK` 7.6.4 currently resolves
`System.Security.Cryptography.Xml` 10.0.6, which has known high-severity
vulnerabilities. PSCX promotes that transitive dependency to an explicit
10.0.10 reference in the affected projects.

The override should be removed after a future PowerShell SDK dependency graph
selects an equal or newer non-vulnerable version without it.

## Inventories

- [NuGet dependencies](NUGET_DEPENDENCIES.md) lists every direct and transitive
  package resolved by the solution and its declared license.
- [Redistributed binaries](REDISTRIBUTED_BINARIES.md) records the native
  executables and libraries shipped in the PSCX package.

Regenerate the NuGet inventory after dependency changes:

```powershell
dotnet restore ./Src/Pscx.sln
./Tools/Get-NuGetDependencyInventory.ps1
```

## Exceptions

Do not use `NoWarn` or disable NuGet Audit to bypass a vulnerability.

A temporary exception requires explicit maintainer approval and must:

1. identify the advisory URL and affected package/version;
2. explain whether the vulnerable code is reachable in PSCX;
3. link to a tracking issue;
4. name an owner;
5. specify an expiration date or concrete removal condition.

Record an approved exception as a narrowly scoped `NuGetAuditSuppress` item in
`Directory.Build.props`, next to a comment containing that information.

## Automated updates

Dependabot checks NuGet packages under `Src` and GitHub Actions weekly. Its pull
requests remain subject to normal review, build, test, audit, and maintainer
approval requirements.

## References

- [NuGet vulnerability warning and suppression guidance](https://learn.microsoft.com/nuget/reference/errors-and-warnings/nu1901-nu1904)
- [Dependency-audit command reference](https://learn.microsoft.com/dotnet/core/tools/dotnet-package-list)
- [Dependabot version-update configuration](https://docs.github.com/code-security/reference/supply-chain-security/dependabot-options-reference)
- [`System.Security.Cryptography.Xml` 10.0.10 package metadata](https://www.nuget.org/packages/System.Security.Cryptography.Xml/10.0.10)
