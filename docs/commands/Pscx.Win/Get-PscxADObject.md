---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Get-PscxADObject
---

# Get-PscxADObject

## SYNOPSIS

PSCX Cmdlet: Search for objects in the Active Directory/Global Catalog.

## SYNTAX

### __AllParameterSets

```
Get-PscxADObject [-Domain <string>] [-Class <GetADObjectCommand+ObjectClass[]>] [-Value <string>]
 [-GlobalCatalog] [-Scope <SearchScope>] [-DistinguishedName <string>] [-Filter <string>]
 [-PageSize <int>] [-SizeLimit <int>] [-Server <string>] [-Credential <pscredential>]
 [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Search for objects in the Active Directory/Global Catalog.

## EXAMPLES

### Example 1 - Use Get-PscxADObject

```powershell
Get-PsxcADObject -domain example.com -class user
```

This command displays all Active Directory user from the domain example.com.

### Example 2 - Use Get-PscxADObject

```powershell
Get-PsxcADObject -value "*user*"
```

This command returns all Active Directory objects that contain the word "user".

### Example 3 - Use Get-PscxADObject

```powershell
Get-PsxcADObject -filter "(&(mail=*user*)(sn=*user*))"
```

This command returns all Active Directory objects that contain the word "user"
        within the e-mail and surename fields.

## PARAMETERS

### -Class

Result returns only objects form the selected classes.

```yaml
Type: Pscx.Win.Commands.DirectoryServices.GetADObjectCommand+ObjectClass[]
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

### -DistinguishedName

Specify the search path (Format: distinguished name  e.g.
"DC=some,DC=domain,DC=xx")

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases:
- DN
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

### -Domain

Specify the domain name for the search.
(Format: canonical name  e.g.
some.domain.xx)

```yaml
Type: System.String
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

### -Filter

Specify the search filter

```yaml
Type: System.String
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

### -GlobalCatalog

Use Global Catalog for the search

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- GC
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

### -PageSize



```yaml
Type: System.Int32
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

### -Scope

Search scope

```yaml
Type: System.DirectoryServices.SearchScope
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

### -SizeLimit



```yaml
Type: System.Int32
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

### -Value

Search string.
Wildcards are permitted.

```yaml
Type: System.String
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

## OUTPUTS

### System.DirectoryServices.DirectoryEntry

Returns a System.DirectoryServices.DirectoryEntry value.

## NOTES

Using this cmdlet without a parameter will return all Active Directory objects from
        the current domain.
Depending on the size of the logon domain this operation can take
        longer.


## RELATED LINKS

- [Online Version]()
