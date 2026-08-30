# about_Pscx.Time

## SHORT DESCRIPTION

Pscx.Time provides the optional NodaTime-backed PSCX date and time types.

## LONG DESCRIPTION

PSCX 4.0 no longer loads NodaTime as part of the default `Pscx` module. Import
the sibling `Pscx.Time` module when you need the PSCX time wrappers or their
PowerShell type accelerators.

```powershell
Import-Module Pscx.Time
[localtime]::now()
[zonedtime]::utcNow()
[isodate]::ParseOffsetDateTime('2026-08-23T12:00:00Z')
```

The module registers `isodate`, `zonedtime`, `offsettime`, `localtime`, `tz`,
and `tzi`. It exports no commands and can be removed independently of `Pscx`.

## MIGRATION

Scripts that use these accelerators should add `Import-Module Pscx.Time` before
their first use. The accelerator names and public .NET namespaces are unchanged.

## SEE ALSO

about_Pscx
