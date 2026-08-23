# Sudo for Windows

The sudo utility embedded into PSCX comes from the
[gsudo project](https://github.com/gerardog/gsudo). PSCX currently pins the
x64 executable from release 2.6.0. Its reviewed checksum, signer, source, and
update owner are recorded in
[`Imports/REDISTRIBUTED_BINARIES.psd1`](../REDISTRIBUTED_BINARIES.psd1).

## Integration

* Download `gsudo.portable.zip` from the reviewed upstream release without
  committing the archive to PSCX.
* Extract and review the `x64` payload. Copy `gsudo.exe` and
  `Invoke-ElevatedCommand.ps1` into the `win` folder.
* Copy the PowerShell files from the x64 folder into
  `Src/Pscx.Win/Modules/Sudo` and retain the PSCX module naming and local
  integration changes.
* Update the machine-readable inventory and both the repository and packaged
  validation tests. Run the full Windows build before requesting review.

The submodule is named **Pscx\Sudo**. Carry that rename and the PSCX integration
changes forward when updating from upstream. The build packages the reviewed
executable under both `gsudo.exe` and `sudo.exe` for command-name compatibility.
