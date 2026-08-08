---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: ConvertTo-Unit
---

# ConvertTo-Unit

## SYNOPSIS

PSCX Cmdlet: Converts a measurement from one unit into another, as long as they are compatible - i.e. belong to the same quantity type: length, mass, etc.

## SYNTAX

### Numeric

```
ConvertTo-Unit [-Value] <double> [-FromUnit] <Unit> [-ToUnit] <Unit> [<CommonParameters>]
```

### String

```
ConvertTo-Unit [-Measurement] <Measurement> [-ToUnit] <Unit> [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Converts a measurement from one unit into another, as long as they are compatible - i.e.
belong to the same quantity type: length, mass, etc.

## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help ConvertTo-Unit -Full
```

Displays the complete installed help for this command.

## PARAMETERS

### -FromUnit

Unit associated with the numeric value to convert

```yaml
Type: Pscx.SimpleUnits.Unit
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Numeric
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Measurement

The measurement to convert - can be provided as a string in form [number] [unit]

```yaml
Type: Pscx.SimpleUnits.Measurement
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: String
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ToUnit

Unit to convert to - must be compatible with 'FromUnit' argument and belong to the same measurement type

```yaml
Type: Pscx.SimpleUnits.Unit
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Value

Numeric value to convert

```yaml
Type: System.Double
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Numeric
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

### Pscx.SimpleUnits.Measurement

Accepts a Pscx.SimpleUnits.Measurement value.

### Pscx.SimpleUnits.Unit

Accepts a Pscx.SimpleUnits.Unit value.

### double

Accepts a double value.

### System.Double

Accepts a System.Double value.

## OUTPUTS

### Pscx.SimpleUnits.Measurement

Returns a Pscx.SimpleUnits.Measurement value.

## NOTES




## RELATED LINKS

- [Online Version]()
