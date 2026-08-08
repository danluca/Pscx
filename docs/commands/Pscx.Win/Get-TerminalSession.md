---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Get-TerminalSession
---

# Get-TerminalSession

## SYNOPSIS

PSCX Cmdlet: Gets information on terminal services sessions.

## SYNTAX

### __AllParameterSets

```
Get-TerminalSession [[-ComputerName] <string[]>] [[-Id] <int[]>] [-Resolve] [-Wait]
 [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Gets information on terminal services sessions.

## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help Get-TerminalSession -Full
```

Displays the complete installed help for this command.

## PARAMETERS

### -ComputerName



```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Id



```yaml
Type: System.Int32[]
DefaultValue: ''
SupportsWildcards: false
Aliases:
- SessionId
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

### -Resolve



```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Wait

Wait for results before returning.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
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

### System.Int32

Accepts a System.Int32[] value.

### System.String

Accepts a System.String[] value.

### System.Int32[]

Accepts a System.Int32[] value.

### System.String[]

Accepts a System.String[] value.

## OUTPUTS

## NOTES




## RELATED LINKS

- [Online Version]()
