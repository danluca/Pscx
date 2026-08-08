---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Invoke-Apartment
---

# Invoke-Apartment

## SYNOPSIS

Invokes a script block using a specified apartment threading model.

## SYNTAX

### __AllParameterSets

```
Invoke-Apartment [-Apartment] <ApartmentState> [-Expression] <scriptblock> [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Runs a script block in a thread configured with the requested COM apartment state.


## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help Invoke-Apartment -Full
```

Displays the complete installed help for this command.

## PARAMETERS

### -Apartment



```yaml
Type: System.Threading.ApartmentState
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Expression



```yaml
Type: System.Management.Automation.ScriptBlock
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
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

### System.Management.Automation.PSObject

Returns a System.Management.Automation.PSObject value.

## NOTES




## RELATED LINKS

- [Online Version]()
