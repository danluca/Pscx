---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Add-PathVariable
---

# Add-PathVariable

## SYNOPSIS

PSCX Cmdlet: Adds the specified paths to the end of the named, path-oriented environment variable.

## SYNTAX

### __AllParameterSets

```
Add-PathVariable [-Value] <string[]> [-Name <string>] [-Prepend]
 [-Target <EnvironmentVariableTarget>] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Adds the specified paths to the end of the named, path-oriented environment variable by taking the paths specified by the Value parameter and concatenating them into a semi-colon separated string.
 The paths can be prepended to the environment variable by using the -Prepend switch parameter.

## EXAMPLES

### Example 1 - Use Add-PathVariable

```powershell
Add-PathVariable Lib C:\Lib, C:\ProjA\Lib
```

Adds the specified paths to the end of current Lib environment variable setting (creating it if necessary) in the Process scope.

### Example 2 - Use Add-PathVariable

```powershell
Add-PathVariable Lib C:\Lib, C:\ProjA\Lib -Target User
```

Adds the specified paths to the end of current Lib environment variable setting (creating it if necessary) in the User scope.

## PARAMETERS

### -Name

The name of the environment variable to add to.
 Typically either Path (default), Lib, Include, etc.

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

### -Prepend

The specified paths will be prepended to the environment variable instead of appended.

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

### -Target

Specifies which target scope to modify.
 The valid values are Process (default), User or Machine.
 Using either the User or the Machine target scope will cause the new value to persist.

```yaml
Type: System.EnvironmentVariableTarget
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

The paths to concat together with semi-colon separators.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
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

Accepts a System.String[] value.

### System.String[]

Accepts a System.String[] value.

## OUTPUTS

## NOTES




## RELATED LINKS

- [Online Version]()
- [Get-PathVariable]()
- [Set-PathVariable]()
- [Pop-EnvironmentBlock]()
- [Push-EnvironmentBlock]()
