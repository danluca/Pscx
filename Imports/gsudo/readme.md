# Sudo for Windows

Sudo utility embedded into PSCX is leveraged from [GSudo Project](https://github.com/gerardog/gsudo). The version chosen is 2.6.0 - as current, stable and robust for Windows 11.

## Integration

* Download the `ZIP` from the release of choice and extract the contents of the `x64` folder. 
* Move the files `x64\gsudo`, `x64\gsudo.exe` and `x64\Invoke-ElevatedCommand.ps1` into `win` folder (use force flag to override existing files)
* Copy the PowerShell files from x64 folder into `Src/Pscx.Win/Modules/Sudo` and change the name of module files to _Pscx.Sudo.psd1_. Keep the other file names unchanged in the destination folder.

The name of the (sub-)module is therefore __Pscx\Sudo__ and this should be reflected into the module files. As changes get integrated from the original project GgitHub source, the rename must be carried forward.
The executable (`gsudo.exe`) is copied into the output folder renamed as `sudo.exe` (see `pscxwin-postbuild.ps1` script).
