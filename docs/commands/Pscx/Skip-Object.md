---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Skip-Object
---

# Skip-Object

## SYNOPSIS

PSCX Cmdlet: Skips the specified objects in the pipeline.

## SYNTAX

### __AllParameterSets

```
Skip-Object [[-First] <int>] [[-Last] <int>] [[-Index] <int[]>] [-InputObject <psobject>]
 [<CommonParameters>]
```

## ALIASES

skip

## DESCRIPTION

Skips the specified number of objects at the beginning of a sequence and/or the end of a sequence.

## EXAMPLES

### Example 1 - Use Skip-Object

```powershell
0..20 | Skip-Object -first 5 -last 2 -index 10,11
```

This command will prevent the first five objects, the last two objects and the objects at index 10 and 11 from being output by the pipeline.

## PARAMETERS

### -First

Skips the selected number of objects at the head of the pipeline sequence.

```yaml
Type: System.Int32
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

### -Index

Skips objects at the selected indices within the pipeline sequence.

```yaml
Type: System.Int32[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -InputObject

Accepts an object as input to the cmdlet.
Enter a variable that contains the objects or type a command or expression that gets the objects.

```yaml
Type: System.Management.Automation.PSObject
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Last

Skips the selected number of objects at the tail of the pipeline sequence.

```yaml
Type: System.Int32
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
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

### Object

Accepts a Object value.

### System.Management.Automation.PSObject

Accepts a System.Management.Automation.PSObject value.

## OUTPUTS

### PSobject

Returns a PSobject value.

## NOTES




## RELATED LINKS

- [Online Version]()
