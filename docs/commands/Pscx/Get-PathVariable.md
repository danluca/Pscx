---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Get-PathVariable
---

# Get-PathVariable

## SYNOPSIS

PSCX Cmdlet: Gets the specified path-oriented environment variable.

## SYNTAX

### __AllParameterSets

```
Get-PathVariable [[-Name] <string>] [-RemoveEmptyPaths] [-StripQuotes]
 [-Target <EnvironmentVariableTarget>] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Gets the specified path-oriented environment variable and outputs an array of strings.
 One string for each path.
 The environment variable string is split a semi-colon and you can option specify that empty paths be removed and unnecessary quotes be removed from each path.

## EXAMPLES

### Example 1 - Use Get-PathVariable

```powershell
Get-PathVariable Path
```

Gets the Path environment variable from the Process scope as an array of strings.

### Example 2 - Use Get-PathVariable

```powershell
Get-PathVariable Path -Target User
```

Gets the Path environment variable as it is configured in the User scope.

### Example 3 - Use Get-PathVariable

```powershell
Get-PathVariable Path -RemoveEmptyPaths -StripQuotes -Target Machine | Set-PathVariable Path -Target Machine
```

Gets the Machine scope Path environment variable while removing unnecessary quotes and empty paths and then sets it to the updated value. This enviornment variable will be persisted across PowerShell sessions.

## PARAMETERS

### -Name

The name of the environment variable to get.
 Typically either Path, Lib, Include, etc.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -RemoveEmptyPaths

Empty paths, as represented by back-to-back semi-colons will be removed from the output.

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

### -StripQuotes

Removes unnecessary quotes from each path.
Most path-oriented environments variables do not require quotes around paths (even those paths with spaces in them).
 Since the semi-colon is not a valid path character it is sufficient to mark the beginning and ending of a path.

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

Specifies which target scope to get: Process (default), User or Machine.

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
- [Add-PathVariable]()
- [Set-PathVariable]()
- [Remove-PathVariable]()
- [Pop-EnvironmentBlock]()
- [Push-EnvironmentBlock]()
