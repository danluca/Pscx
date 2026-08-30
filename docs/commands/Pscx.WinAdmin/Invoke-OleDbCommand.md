---
document type: cmdlet
external help file: Pscx.WinAdmin.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.WinAdmin
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Invoke-OleDbCommand
---

# Invoke-OleDbCommand

## SYNOPSIS

PSCX Cmdlet: Provides an easy way to execute a sql command against a database via ADO.Net 2.0.

## SYNTAX

### __AllParameterSets

```
Invoke-OleDbCommand -Query <string> -ConnectionString <string> [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Invoke-OleDbCommand provides an easy way to execute a sql command against a database via ADO.Net 2.0.
It returns an int value, reflecting the number of rows affected by the command.

## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help Invoke-OleDbCommand -Full
```

Displays the complete installed help for this command.

## PARAMETERS

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- cf
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

### -ConnectionString

Connection string to use.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Query

SQL Query to execute

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -WhatIf

Runs the command in a mode that only reports what would happen without performing the actions.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- wi
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

## OUTPUTS

## NOTES




## RELATED LINKS

- [Online Version]()
