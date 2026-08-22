# Redistributed Binary Inventory

This inventory covers third-party native executables and libraries in the
PSCX 4.0 default package. NuGet-provided managed assemblies are covered by
the generated [NuGet dependency inventory](NUGET_DEPENDENCIES.md).

| Component | Version | Packaged files | License | Source and license record |
| --- | --- | --- | --- | --- |
| gsudo | 2.6.0 | `Apps/Win/gsudo.exe`, `Apps/Win/sudo.exe` | MIT | [Import metadata and license](../../Imports/gsudo/) |
| less | 678 | `Apps/Win/less.exe`, `Apps/Win/lesskey.exe` | less upstream license; Windows-port changes under MIT | [Import metadata and licenses](../../Imports/Less-678/) |

The package contains byte-identical copies of gsudo 2.6.0 as `gsudo.exe` and
`sudo.exe`, both with SHA-256:

`21C470D6DEABFBD398349168E18ED1CF261D6C204D7BD12EEB53C846403A0D1A`

The duplicate names are currently retained for command compatibility. Whether
they can share one payload safely remains part of the later binary-reduction
work.

## Maintenance requirements

For every redistributed binary:

- retain its upstream license in the release package;
- record its upstream source, version, and checksum;
- verify that redistribution remains permitted before upgrading it;
- scan release artifacts using the available repository and hosting security
  tooling;
- update this inventory whenever the packaged binary set changes.
