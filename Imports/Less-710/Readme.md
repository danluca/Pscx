# LESS for Windows

`less` pager is developed and maintained by Mark Nudelman at http://www.greenwoodsoftware.com/less.

The Windows version has been downloaded from a site [sanctioned](http://www.greenwoodsoftware.com/less/download.html#binaries) by Mark Nudelman - https://github.com/jftuga/less-Windows

Both license files (MIT) have been included.

PSCX currently pins release 710 and redistributes its x64 `less.exe`.
Upstream removed the obsolete `lesskey` compiler in this release; less reads
key-binding source files directly. Checksums, source, license, and update ownership are recorded in
[`Imports/REDISTRIBUTED_BINARIES.psd1`](../REDISTRIBUTED_BINARIES.psd1). The
scheduled dependency audit checks the upstream releases; native binaries must
still be reviewed and approved before replacement.
