---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/23/2026
PlatyPS schema version: 2024-05-01
title: Remove-PathVariable
---

# Remove-PathVariable

## SYNOPSIS

Removes one or more entries from a path-oriented environment variable.

## SYNTAX

### __AllParameterSets

```
Remove-PathVariable [-Value] <string[]> [-Name <string>] [-PassThru]
 [-Target <EnvironmentVariableTarget>] [-CaseInsensitive] [-Normalize] [-Validate]
 [-RetainUnavailable] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

None


## DESCRIPTION

`Remove-PathVariable` removes matching entries from the named path-oriented
environment variable. The default variable is `PATH`, and the default target
scope is the current process. Comparisons are case-insensitive on Windows and
case-sensitive on Linux and macOS unless `-CaseInsensitive` is specified.

Every mutation removes duplicates while preserving first-occurrence order.
Use `-Normalize` and `-Validate` for explicit cleanup in the same operation.

Use `-Target User` or `-Target Machine` to modify a persistent environment
variable on Windows where current permissions allow it. Linux and macOS
support the `Process` target only.

## EXAMPLES

### Example 1 - Preview removal from PATH

```powershell
Remove-PathVariable -Value "$HOME/.old-tool/bin" -PassThru -WhatIf
```

Returns the proposed change without modifying the current process's `PATH`.

### Example 2 - Remove entries from another path variable

```powershell
Remove-PathVariable -Name LIB -Value '/opt/old/lib', '/opt/unused/lib'
```

Removes the specified entries from the process-scoped `LIB` environment
variable when they are present.

## PARAMETERS

### -CaseInsensitive

Uses case-insensitive entry comparison. Windows path comparison is already
case-insensitive. On Linux and macOS, comparison is case-sensitive unless this
switch is specified.

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

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases:
- cf
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

### -Normalize

Expands environment-variable references, removes surrounding whitespace and
quotes, resolves entries to canonical absolute paths, and removes trailing
directory separators except for filesystem roots.

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

### -PassThru

Returns a `PathVariableChange` object describing the proposed and applied
change, including added, removed, retained, invalid, and duplicate entries.

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

### -RetainUnavailable

Retains entries that do not resolve to an existing file or directory.
Specifying this switch also enables validation.

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

Specifies the environment-variable scope to modify: `Process`, `User`, or
`Machine`. The default is `Process`. Only `Process` is supported on Linux and
macOS. Persistent `User` and `Machine` targets are supported on Windows and
may require additional permissions.

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

### -Validate

Checks whether each entry resolves to an existing file or directory and omits
unavailable entries. Use `-RetainUnavailable` to validate and report them
without removing them.

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

Runs the command in a mode that only reports what would happen without performing the actions.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases:
- wi
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

### Pscx.Commands.EnvironmentBlock.PathVariableChange

A structured change description when `-PassThru` is specified. Otherwise the
cmdlet returns no output.

## NOTES

Existing versions of the variable are left unchanged when none of the supplied
values match.

`-WhatIf -PassThru` returns the proposed `After` value with `Applied` set to
`False`.

## RELATED LINKS

- [Add-PathVariable]()
- [Get-PathVariable]()
- [Set-PathVariable]()
- [Pop-EnvironmentBlock]()
- [Push-EnvironmentBlock]()
