---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Test-UserGroupMembership
---

# Test-UserGroupMembership

## SYNOPSIS

PSCX Cmdlet: Tests whether or not a user (current user by default) is a member of the specified group name.

## SYNTAX

### name (Default)

```
Test-UserGroupMembership [-GroupName] <string[]> [[-Identity] <WindowsIdentity>]
 [<CommonParameters>]
```

### id

```
Test-UserGroupMembership [-IdentityReference] <IdentityReference[]> [[-Identity] <WindowsIdentity>]
 [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Tests whether or not a user (current user by default) is a member of the specified group name.
 This can be used to test whether a user is admin or elevated to admin.

## EXAMPLES

### Example 1 - Use Test-UserGroupMembership

```powershell
Test-UserGroupMembership -GroupName Administrators
False
```

Tests to see if the current user is a member of the Administrators group.

## PARAMETERS

### -GroupName

Name of the group to test membership of.
Examples: Administrators, Users, Power Users, etc

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: name
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

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

### -IdentityReference

Reference to the identity to act upon.

```yaml
Type: System.Security.Principal.IdentityReference[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: id
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

### Boolean

Returns a Boolean value.

### System.Boolean

Returns a System.Boolean value.

## NOTES




## RELATED LINKS

- [Online Version]()
