---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Get-Privilege
---

# Get-Privilege

## SYNOPSIS

PSCX Cmdlet: Lists privileges held by the session and their current status.

## SYNTAX

### __AllParameterSets

```
Get-Privilege [[-Identity] <WindowsIdentity>] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Lists privileges held by the session and their current status.

## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help Get-Privilege -Full
```

Displays the complete installed help for this command.

## PARAMETERS

### -Identity

The identity to act upon.

```yaml
Type: System.Security.Principal.WindowsIdentity
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
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

### System.Security.Principal.WindowsIdentity

Accepts a System.Security.Principal.WindowsIdentity value.

## OUTPUTS

### Pscx.Win.Interop.Security.Privileges.TokenPrivilegeCollection

Returns a Pscx.Win.Interop.Security.Privileges.TokenPrivilegeCollection value.

## NOTES




## RELATED LINKS

- [Online Version]()
