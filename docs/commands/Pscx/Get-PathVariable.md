---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/23/2026
PlatyPS schema version: 2024-05-01
title: Get-PathVariable
---

# Get-PathVariable

## SYNOPSIS

PSCX Cmdlet: Gets the specified path-oriented environment variable.

## SYNTAX

### __AllParameterSets

```
Get-PathVariable [[-Name] <string>] [-RemoveEmptyPaths] [-StripQuotes] [-Unique]
 [-Target <EnvironmentVariableTarget>] [-CaseInsensitive] [-Normalize] [-Validate]
 [-RetainUnavailable] [<CommonParameters>]
```

## ALIASES

None


## DESCRIPTION

Gets a path-oriented environment variable as one string per entry. With no
cleanup switches, the command preserves empty entries and duplicates for
compatibility.

Use `-Unique`, `-Normalize`, or `-Validate` to process entries. Processed
output is deduplicated without changing the environment variable. Comparisons
are case-insensitive on Windows and case-sensitive on Linux and macOS unless
`-CaseInsensitive` is specified.

## EXAMPLES

### Example 1 - Use Get-PathVariable

```powershell
Get-PathVariable Path
```

Gets the Path environment variable from the Process scope as an array of strings.

### Example 2 - Preview normalized, unique entries

```powershell
Get-PathVariable -Name PATH -Normalize -Unique
```

Returns canonical absolute entries with duplicates removed without modifying
`PATH`.

### Example 3 - Retain unavailable entries while validating

```powershell
Get-PathVariable -Name PATH -Validate -RetainUnavailable
```

Checks whether entries exist but retains unavailable entries in the output.

## PARAMETERS

### -CaseInsensitive

Uses case-insensitive entry comparison. Windows path comparison is already
case-insensitive. On Linux and macOS, comparison is case-sensitive unless this
switch is specified. This switch enables processed, duplicate-free output.

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

### -Normalize

Expands environment-variable references, removes surrounding whitespace and
quotes, resolves entries to canonical absolute paths, and removes trailing
directory separators except for filesystem roots. Normalized output is also
deduplicated.

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

### -RetainUnavailable

Retains entries that do not resolve to an existing file or directory.
Specifying this switch also enables validation. This is useful for paths on
temporarily disconnected drives or filesystems.

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

Specifies which target scope to get: `Process` (default), `User`, or `Machine`.
Only `Process` is supported on Linux and macOS. Persistent `User` and `Machine`
targets are supported on Windows.

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

### -Unique

Removes duplicate entries while preserving their first-occurrence order.

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

### -Validate

Checks whether each entry resolves to an existing file or directory and omits
unavailable entries. Use `-RetainUnavailable` to report the same cleaned output
without omitting unavailable entries.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.String

One string for each selected path-variable entry.

## NOTES

`Get-PathVariable` never modifies the environment variable. To apply cleaned
output, pipe it to `Set-PathVariable` explicitly.

## RELATED LINKS

- [Online Version]()
- [Add-PathVariable]()
- [Set-PathVariable]()
- [Remove-PathVariable]()
- [Pop-EnvironmentBlock]()
- [Push-EnvironmentBlock]()
