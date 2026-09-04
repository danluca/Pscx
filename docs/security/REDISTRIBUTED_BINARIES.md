# Redistributed Binary Inventory

This inventory covers third-party native executables and libraries in the
PSCX 4.0 default package. NuGet-provided managed assemblies are covered by
the generated [NuGet dependency inventory](NUGET_DEPENDENCIES.md).

| Component | Version | Packaged files | Purpose | License | Source and license record |
| --- | --- | --- | --- | --- | --- |
| gsudo | 2.6.0 | `Pscx/Apps/Win/gsudo.exe`, `Pscx/Apps/Win/sudo.exe` | Windows elevation used by the bundled gsudo integration | MIT | [Import notes and license](../../Imports/gsudo/) |
| less | 678 | `Pscx/Apps/Win/less.exe` | Windows pager used by `PscxLess` | less upstream license; Windows-port changes under MIT | [Import notes and licenses](../../Imports/Less-678/) |
| lesskey | 678 | `Pscx/Apps/Win/lesskey.exe` | Companion compiler for user-defined less key bindings | less upstream license; Windows-port changes under MIT | [Import notes and licenses](../../Imports/Less-678/) |

The authoritative, machine-readable record is
[`Imports/REDISTRIBUTED_BINARIES.psd1`](../../Imports/REDISTRIBUTED_BINARIES.psd1).
It records each source file's exact size and SHA-256, expected Authenticode
state, upstream release, license paths, packaged names, and update owner. The
repository and assembled package are checked against it by
[`Test-PscxRedistributedBinary.ps1`](../../Tools/Test-PscxRedistributedBinary.ps1).

The package contains byte-identical copies of gsudo 2.6.0 as `gsudo.exe` and
`sudo.exe`, both with SHA-256:

`21C470D6DEABFBD398349168E18ED1CF261D6C204D7BD12EEB53C846403A0D1A`

Both command names are retained for compatibility. A release ZIP cannot
portably preserve a Windows hard link, and a symbolic link would introduce
installation and privilege-policy failures on some systems. Replacing
`sudo.exe` with a global PowerShell alias would also affect only PowerShell and
violate PSCX's default alias policy. The two packaged copies are therefore the
smallest reliable compatibility option with the current ZIP distribution.

## Repository and package audit

- The old 7-Zip/SevenZipSharp native archive payload has been removed.
  `Pscx.Archive` restores SharpCompress from NuGet and is managed-only on every
  supported operating system and architecture.
- PowerShell runtime assemblies are supplied by the supported PowerShell host;
  PSCX does not commit or redistribute them.
- NuGet packages and restored managed assemblies are not committed under
  `Imports`; package references and the generated
  [NuGet dependency inventory](NUGET_DEPENDENCIES.md) are authoritative.
- The unused multi-architecture gsudo release ZIP and WSL wrapper are not kept
  in the repository or release package. Only the reviewed x64 executable is
  retained for the Windows PSCX payload.
- `Output/`, `artifacts/`, `bin/`, and `obj/` are ignored generated locations.
  Static validation also rejects tracked files under `Output/`.
- The only native executables in a Full release are `gsudo.exe`, `sudo.exe`,
  `less.exe`, and `lesskey.exe`. Core packages contain none.

## Module contents and size reporting

The unified ZIP contains the following sibling module roots. Exact file counts
and uncompressed byte sizes for every build are written to
`artifacts/test-results/Pscx.PackageContents.json` and uploaded with CI test
results.

| Module root | Contents | Current 4.0 prerelease size, uncompressed |
| --- | --- | ---: |
| `Pscx` | Cross-platform core plus the Full build's Windows companion and retained Windows utilities | about 11.1 MiB |
| `Pscx.Archive` | Optional managed SharpCompress archive module | about 2.4 MiB |
| `Pscx.Time` | Optional NodaTime-backed time module | about 1.4 MiB |
| `Pscx.WinAdmin` | Optional Windows administration module; Full build only | about 0.4 MiB |

The optional module roots do not load with `Pscx`; clients install or import
them according to need. The current combined compressed prerelease ZIP is about
6.6 MiB.

## Maintenance requirements

For every redistributed binary:

- retain its upstream license in the release package;
- record its upstream source, version, and checksum;
- verify that redistribution remains permitted before upgrading it;
- scan release artifacts using the available repository and hosting security
  tooling;
- update this inventory whenever the packaged binary set changes.

The scheduled dependency audit queries the official GitHub release APIs and
fails when a newer upstream tag needs maintainer review; detection is not
authorization to replace native binaries. Release preparation also scans the
completed ZIP with Microsoft Defender Antivirus on Windows when the antivirus
engine is available and publishes a JSON security report with the test
results. gsudo must retain its reviewed valid Authenticode signer; the less
Windows binaries are expected to be unsigned.
