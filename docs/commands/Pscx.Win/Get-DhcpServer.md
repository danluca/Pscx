---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Get-DhcpServer
---

# Get-DhcpServer

## SYNOPSIS

PSCX Cmdlet: Gets a list of authorized DHCP servers.

## SYNTAX

### __AllParameterSets

```
Get-DhcpServer [-Server <string>] [-Credential <pscredential>] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Gets a list of authorized DHCP servers.

## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help Get-DhcpServer -Full
```

Displays the complete installed help for this command.

## PARAMETERS

### -Credential

Specifies credentials required to authenticate on the domain controller.

```yaml
Type: System.Management.Automation.PSCredential
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

### -Server

Send the request to this active directory domain controller.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases:
- DC
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

### Pscx.Win.Commands.DirectoryServices.DhcpServerInfo

Returns a Pscx.Win.Commands.DirectoryServices.DhcpServerInfo value.

## NOTES




## RELATED LINKS

- [Online Version]()
