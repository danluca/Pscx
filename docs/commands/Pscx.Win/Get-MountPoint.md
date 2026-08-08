---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Get-MountPoint
---

# Get-MountPoint

## SYNOPSIS

PSCX Cmdlet: Returns all mount points defined for a specific root path.

## SYNTAX

### __AllParameterSets

```
Get-MountPoint [[-Volume] <string>] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Returns all mount points defined for a specific root path.

## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help Get-MountPoint -Full
```

Displays the complete installed help for this command.

## PARAMETERS

### -Volume

When specified, gets mount points on the specified volume; otherwise, returns mount points on all volumes.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
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

## OUTPUTS

## NOTES




## RELATED LINKS

- [Online Version]()
- [New-Hardlink]()
- [New-Junction]()
- [Remove-MountPoint]()
- [Get-ReparsePoint]()
- [Remove-ReparsePoint]()
- [New-Symlink]()
