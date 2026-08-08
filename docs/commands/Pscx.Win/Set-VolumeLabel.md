---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Set-VolumeLabel
---

# Set-VolumeLabel

## SYNOPSIS

PSCX Cmdlet: Modifies the label shown in Windows Explorer for a particular disk volume.

## SYNTAX

### __AllParameterSets

```
Set-VolumeLabel [[-Path] <string>] [[-Label] <string>] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Modifies the label shown in Windows Explorer for a particular disk volume.

## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help Set-VolumeLabel -Full
```

Displays the complete installed help for this command.

## PARAMETERS

### -Label

New volume label.
If not specified, the volume label will be blank.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Path

Path to the root directory of a file system volume.
This can be a folder where a volume is mounted.
If not specified, defaults to the root of the current FileSystem location.

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

### System.String

Accepts a System.String value.

## OUTPUTS

### System.Boolean

Returns a System.Boolean value.

## NOTES




## RELATED LINKS

- [Online Version]()
