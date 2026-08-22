---
document type: cmdlet
external help file: Pscx.WinAdmin.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.WinAdmin
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Get-OleDbDataSet
---

# Get-OleDbDataSet

## SYNOPSIS

PSCX Cmdlet: Executes a sql query, and returns a System.Data.DataSet containing the result set.

## SYNTAX

### __AllParameterSets

```
Get-OleDbDataSet -Query <string> -ConnectionString <string> [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Get-OleDbDataSet provides an easy way to query a database via ADO.Net 2.0, using an OleDb connection.
It returns a System.Data.DataSet containing the data returned by the query.

## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help Get-OleDbDataSet -Full
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
