---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/23/2026
PlatyPS schema version: 2024-05-01
title: Set-PathVariable
---

# Set-PathVariable

## SYNOPSIS

PSCX Cmdlet: Sets the specified path-oriented environment variable.

## SYNTAX

### __AllParameterSets

```
Set-PathVariable [-Value] <string[]> [-Name <string>] [-PassThru]
 [-Target <EnvironmentVariableTarget>] [-CaseInsensitive] [-Normalize] [-Validate]
 [-RetainUnavailable] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

None


## DESCRIPTION

Replaces a path-oriented environment variable with an ordered, duplicate-free
set of entries. Comparisons are case-insensitive on Windows and case-sensitive
on Linux and macOS unless `-CaseInsensitive` is specified.

Use `-Normalize` and `-Validate` for explicit cleanup. Unavailable paths are
preserved by default and are removed only when validation is requested without
`-RetainUnavailable`.

## EXAMPLES

### Example 1 - Use Set-PathVariable

```powershell
Set-PathVariable -Name LIB -Value '/opt/example/lib', '/opt/project/lib'
```

Sets the process-scoped `LIB` variable to two ordered entries.

### Example 2 - Normalize and validate entries

```powershell
Set-PathVariable -Name PATH -Value $paths -Normalize -Validate -PassThru
```

Sets `PATH` from `$paths`, omits unavailable entries, and returns a structured
change description.

### Example 3 - Preview a persistent Windows change

```powershell
Get-PathVariable -Name PATH -Target User -Unique |
    Set-PathVariable -Name PATH -Target User -PassThru -WhatIf
```

Previews duplicate cleanup for the persistent Windows user `PATH` without
applying it.

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

The entries that replace the variable. Pipeline values are accumulated and
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

`-WhatIf -PassThru` returns the proposed `After` value with `Applied` set to
`False`.

## RELATED LINKS

- [Online Version]()
- [Add-PathVariable]()
- [Remove-PathVariable]()
- [Get-PathVariable]()
- [Pop-EnvironmentBlock]()
- [Push-EnvironmentBlock]()
