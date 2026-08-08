---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Format-Byte
---

# Format-Byte

## SYNOPSIS

PSCX Cmdlet: Displays numbers in multiples of byte units.

## SYNTAX

### __AllParameterSets

```
Format-Byte [-Value] <long> [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Turns numbers into nicely formatted byte count, using the highest possible unit.

## EXAMPLES

### Example 1 - Use Format-Byte

```powershell
10560 | Format-Byte
```

Returns a formatted kilobyte value.

## PARAMETERS

### -Value

The byte count to be formated.

```yaml
Type: System.Int64
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
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

### System.Int64

Accepts a System.Int64 value.

## OUTPUTS

### System.String

Returns a System.String value.

## NOTES




## RELATED LINKS

- [Online Version]()
