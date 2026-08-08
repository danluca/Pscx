---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Remove-MountPoint
---

# Remove-MountPoint

## SYNOPSIS

PSCX Cmdlet: Removes a mount point, dismounting the current media if any. If used against the root of a fixed drive, removes the drive letter assignment.

## SYNTAX

### Path (Default)

```
Remove-MountPoint [-Path] <PscxPathInfo[]> [<CommonParameters>]
```

### LiteralPath

```
Remove-MountPoint [-LiteralPath] <PscxPathInfo[]> [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Removes a mount point, dismounting the current media if any.
If used against the root of a fixed drive, removes the drive letter assignment.

## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help Remove-MountPoint -Full
```

Displays the complete installed help for this command.

## PARAMETERS

### -LiteralPath



```yaml
Type: Pscx.Core.IO.PscxPathInfo[]
DefaultValue: ''
SupportsWildcards: false
Aliases:
- PSPath
ParameterSets:
- Name: LiteralPath
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Path



```yaml
Type: Pscx.Core.IO.PscxPathInfo[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Path
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### Pscx.Core.IO.PscxPathInfo

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

### Pscx.Core.IO.PscxPathInfo[]

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

## OUTPUTS

## NOTES




## RELATED LINKS

- [Online Version]()
- [New-Hardlink]()
- [New-Junction]()
- [Get-MountPoint]()
- [Get-ReparsePoint]()
- [Remove-ReparsePoint]()
- [New-Symlink]()
