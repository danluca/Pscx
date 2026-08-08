---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Get-DomainController
---

# Get-DomainController

## SYNOPSIS

PSCX Cmdlet: Gets domain controllers.

## SYNTAX

### Server (Default)

```
Get-DomainController [[-Name] <string>] [-Server] [-Credential <pscredential>] [<CommonParameters>]
```

### Site

```
Get-DomainController [[-Name] <string>] [-Site] [-Credential <pscredential>] [<CommonParameters>]
```

### Domain

```
Get-DomainController [[-Name] <string>] [-Domain] [-Credential <pscredential>] [<CommonParameters>]
```

### Forest

```
Get-DomainController [[-Name] <string>] [-Forest] [-Credential <pscredential>] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Gets all domain controllers at the specified scope.

## EXAMPLES

### Example 1 - Use Get-DomainController

```powershell
Get-DomainController
```

Gets the domain controller that authenticated the current session.

### Example 2 - Use Get-DomainController

```powershell
Get-DomainController -Domain Europe
```

Gets all domain controllers in the EUROPE domain.

### Example 3 - Use Get-DomainController

```powershell
Get-DomainController -Site
```

Gets all domain controllers in the site this computer is in.

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

### -Domain

Returns all domain controllers in the specified domain.
When no domain specified, returns all domain controllers in the current domain.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Domain
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Forest

Returns all domain controllers in the specified forest.
When no forest specified, returns all domain controllers in the forest.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Forest
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Name

Name of the server, site, domain, or forest.

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
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Server

Returns specified domain controller.
When no server specified, returns the domain controller which authenticated the current session.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Server
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Site

Returns all domain controllers in the specified site.
When no site specified, returns all domain controllers in the site this machine is member of.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Site
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

### System.String

Accepts a System.String value.

## OUTPUTS

### System.DirectoryServices.ActiveDirectory.DomainController

Returns a System.DirectoryServices.ActiveDirectory.DomainController value.

### System.DirectoryServices.ActiveDirectory.DomainControllerCollection

Returns a System.DirectoryServices.ActiveDirectory.DomainControllerCollection value.

## NOTES




## RELATED LINKS

- [Online Version]()
