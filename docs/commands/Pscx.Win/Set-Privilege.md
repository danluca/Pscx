---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Set-Privilege
---

# Set-Privilege

## SYNOPSIS

PSCX Cmdlet: Adjusts privileges associated with a user (identity).

## SYNTAX

### __AllParameterSets

```
Set-Privilege [-Privileges] <TokenPrivilegeCollection> [[-Identity] <WindowsIdentity>]
 [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Adjusts privileges associated with a user (identity).

## EXAMPLES

### Example 1 - Use Set-Privilege

```powershell
$p = Get-Privilege
$p.Enable('SeTimeZonePrivilege')
Set-Privilege $p
Get-Privilege | ft Name, Status -a

Name Status
---- ------
SeShutdownPrivilege Disabled
SeChangeNotifyPrivilege EnabledByDefault, Enabled
SeUndockPrivilege Disabled
SeIncreaseWorkingSetPrivilege Disabled
SeTimeZonePrivilege Enabled
```

This enables the SeTimeZonePrivilege for the current user.

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

### -Privileges

The privileges to modify.
See http://msdn.microsoft.com/en-us/library/bb530716(VS.85).aspx for details.

```yaml
Type: Pscx.Win.Interop.Security.Privileges.TokenPrivilegeCollection
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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.Security.Principal.WindowsIdentity

Accepts a System.Security.Principal.WindowsIdentity value.

## OUTPUTS

## NOTES




## RELATED LINKS

- [Online Version]()
