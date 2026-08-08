---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Set-PathVariable
---

# Set-PathVariable

## SYNOPSIS

PSCX Cmdlet: Sets the specified path-oriented environment variable.

## SYNTAX

### __AllParameterSets

```
Set-PathVariable [-Value] <string[]> [-Name <string>] [-Target <EnvironmentVariableTarget>]
 [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Sets the specified path-oriented environment variable by taking the paths specified by the Value parameter and concatenating them into a semi-colon separated string.

## EXAMPLES

### Example 1 - Use Set-PathVariable

```powershell
Set-PathVariable Lib C:\Lib, C:\ProjA\Lib
```

Sets the Lib environment variable (creating it if necessary) to the value "C:\Lib;C:\ProjA\Lib" in the Process scope.

### Example 2 - Use Set-PathVariable

```powershell
Set-PathVariable Lib C:\Lib, C:\ProjA\Lib -Target User
```

Sets the Lib environment variable (creating it if necessary) to the value "C:\Lib;C:\ProjA\Lib" in the User scope.  This enviornment variable will be persisted across PowerShell sessions.

### Example 3 - Use Set-PathVariable

```powershell
Get-PathVariable Path -RemoveEmptyPaths -StripQuotes -Target Machine | Set-PathVariable Path -Target Machine
```

Gets the Machine scope Path environment variable while removing unnecessary quotes and empty paths and then sets it to the updated value. This enviornment variable will be persisted across PowerShell sessions.

## PARAMETERS

### -Name

The name of the environment variable to set.
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
- [Add-PathVariable]()
- [Remove-PathVariable]()
- [Get-PathVariable]()
- [Pop-EnvironmentBlock]()
- [Push-EnvironmentBlock]()
