---
document type: cmdlet
external help file: Pscx.WinAdmin.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.WinAdmin
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Get-AdoDataProvider
---

# Get-AdoDataProvider

## SYNOPSIS

PSCX Cmdlet: List all registered ADO.NET Data Providers on the current machine.

## SYNTAX

### __AllParameterSets

```
Get-AdoDataProvider [[-Name] <string>] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

List all registered ADO.NET Data Providers on the current machine.

## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help Get-AdoDataProvider -Full
```

Displays the complete installed help for this command.

## PARAMETERS

### -Name

The name of the ADO provider you wish to retrieve.
Wildcards * and ? are accepted.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
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

### System.String

Accepts a System.String value.

## OUTPUTS

### System.Management.Automation.PSObject

Returns a System.Management.Automation.PSObject value.

## NOTES




## RELATED LINKS

- [Online Version]()
