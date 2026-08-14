---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/10/2026
PlatyPS schema version: 2024-05-01
title: Remove-PathVariable
---

# Remove-PathVariable

## SYNOPSIS

Removes one or more entries from a path-oriented environment variable.

## SYNTAX

### __AllParameterSets

```
Remove-PathVariable [-Value] <string[]> [-Name <string>]
 [-Target <EnvironmentVariableTarget>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

`Remove-PathVariable` removes matching entries from the named path-oriented
environment variable. The default variable is `PATH`, and the default target
scope is the current process. Values are compared without regard to case after
environment-variable references and surrounding whitespace are normalized.

Use `-Target User` or `-Target Machine` to modify a persistent environment
variable where the operating system and current permissions allow it.

## EXAMPLES

### Example 1 - Preview removal from PATH

```powershell
Remove-PathVariable -Value "$HOME/.old-tool/bin" -WhatIf
```

Shows the proposed change without modifying the current process's `PATH`.

### Example 2 - Remove entries from another path variable

```powershell
Remove-PathVariable -Name LIB -Value '/opt/old/lib', '/opt/unused/lib'
```

Removes the specified entries from the process-scoped `LIB` environment
variable when they are present.

## PARAMETERS

### -Name

The name of the path-oriented environment variable to modify. The default is
`PATH`.

```yaml
Type: System.String
DefaultValue: PATH
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

Specifies the environment-variable scope to modify: `Process`, `User`, or
`Machine`. The default is `Process`.

```yaml
Type: System.EnvironmentVariableTarget
DefaultValue: Process
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

One or more entries to remove. Values that are not present are ignored.

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

### -WhatIf

Shows what would happen if the command runs. The command is not run.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: [wi]
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

### -Confirm

Prompts for confirmation before running the command.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: [cf]
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

### System.String

You can pipe path entries to this cmdlet.

### System.String[]

You can pipe arrays of path entries to this cmdlet.

## OUTPUTS

### None

This cmdlet returns no output.

## NOTES

Existing versions of the variable are left unchanged when none of the supplied
values match.

## RELATED LINKS

- [Add-PathVariable]()
- [Get-PathVariable]()
- [Set-PathVariable]()
- [Pop-EnvironmentBlock]()
- [Push-EnvironmentBlock]()
