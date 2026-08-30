---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/23/2026
PlatyPS schema version: 2024-05-01
title: Add-PathVariable
---

# Add-PathVariable

## SYNOPSIS

PSCX Cmdlet: Adds the specified paths to the end of the named, path-oriented environment variable.

## SYNTAX

### __AllParameterSets

```
Add-PathVariable [-Value] <string[]> [-Name <string>] [-Prepend] [-PassThru]
 [-Target <EnvironmentVariableTarget>] [-CaseInsensitive] [-Normalize] [-Validate]
 [-RetainUnavailable] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

None


## DESCRIPTION

Adds entries to a path-oriented environment variable while preserving their
order and removing duplicates. Use `-Prepend` to move the requested entries to
the beginning. Comparisons are case-insensitive on Windows and case-sensitive
on Linux and macOS unless `-CaseInsensitive` is specified.

Use `-Normalize` and `-Validate` for explicit cleanup. Unavailable paths are
preserved by default and are removed only when validation is requested without
`-RetainUnavailable`.

## EXAMPLES

### Example 1 - Use Add-PathVariable

```powershell
Add-PathVariable -Name LIB -Value '/opt/example/lib', '/opt/project/lib'
```

Adds two entries to the process-scoped `LIB` variable, creating it if needed.

### Example 2 - Preview a persistent Windows change

```powershell
Add-PathVariable -Name PATH -Value 'C:\Tools\bin' -Target User -PassThru -WhatIf
```

Returns a structured preview of a Windows user-scoped change without applying
it.

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
DefaultValue: ''
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

Specifies which target scope to modify: `Process` (default), `User`, or
`Machine`. Only `Process` is supported on Linux and macOS. Persistent `User`
and `Machine` targets are supported on Windows and may require additional
permissions.

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

One or more entries to append or prepend. Pipeline values are accumulated and
applied as one ordered change.

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
DefaultValue: ''
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

Duplicate removal preserves the first occurrence, except that `-Prepend`
moves a requested existing entry to the beginning.

## RELATED LINKS

- [Online Version]()
- [Get-PathVariable]()
- [Set-PathVariable]()
- [Pop-EnvironmentBlock]()
- [Push-EnvironmentBlock]()
