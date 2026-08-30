---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/25/2026
PlatyPS schema version: 2024-05-01
title: ConvertTo-UnixLineEnding
---

# ConvertTo-UnixLineEnding

## SYNOPSIS

PSCX Cmdlet: Converts the line endings in the specified file to Unix line endings "\n".

## SYNTAX

### Path (Default)

```
ConvertTo-UnixLineEnding [-Path] <PscxPathInfo[]> [[-Destination] <string>]
 [[-Encoding] <StringEncodingParameter>] [-Force] [-NoClobber] [-FinalNewline <FinalNewlineMode>]
 [-Check] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### LiteralPath

```
ConvertTo-UnixLineEnding [-LiteralPath] <PscxPathInfo[]> [[-Destination] <string>]
 [[-Encoding] <StringEncodingParameter>] [-Force] [-NoClobber] [-FinalNewline <FinalNewlineMode>]
 [-Check] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

None


## DESCRIPTION

Converts CRLF, LF, and CR line endings to Unix LF (`\n`) line endings.
By default, the command preserves the source encoding, byte-order mark, and
whether the source ends with a newline. Use `-FinalNewline` to override the
final-newline behavior, or `-Check` to report whether conversion is needed
without writing a file.

## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help ConvertTo-UnixLineEnding -Full
```

Displays the complete installed help for this command.

### Example 2 - Check files without changing them

```powershell
ConvertTo-UnixLineEnding -Path ./src/*.cs -Check |
    Where-Object NeedsConversion
```

Returns a structured result for each matching file and filters the results to
files that need Unix line endings. No files are written.

### Example 3 - Convert a file and add a final newline

```powershell
ConvertTo-UnixLineEnding -LiteralPath ./input.txt -Destination ./output.txt -FinalNewline Add
```

Writes `output.txt` with LF line endings and exactly one final newline while
preserving the source encoding and byte-order mark.

## PARAMETERS

### -Check

Reports whether conversion is needed without writing a file. `-Destination`
is not required in check mode. The command returns a
`Pscx.Commands.Text.LineEndingCheckResult` object for each input file.

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

### -Destination

Destination to write the converted file.
If the destination is a directory, then the file is written to the directory using the same name.
This parameter is required unless `-Check` is specified.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Encoding

Encoding used to write the output file.
By default the encoding of the input file is used.
Valid values are: unicode, utf7, utf8, utf32, ascii and bigendianunicode.

```yaml
Type: Pscx.StringEncodingParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -FinalNewline

Controls the final newline in the converted file. `Preserve` (the default)
retains whether the input has a final newline, `Add` writes exactly one final
newline when one is absent, and `Remove` removes all trailing line-ending
characters.

```yaml
Type: Pscx.Commands.Text.FinalNewlineMode
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

### -Force

Overwrite any existing readonly file.

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

### -LiteralPath

Specifies a path to the item.
The value of -LiteralPath is used exactly as it is typed.
No characters are interpreted as wildcards.
If the path includes escape characters, enclose it in single quotation marks.
Single quotation marks tell Windows PowerShell not to interpret any characters as escape sequences.

```yaml
Type: Pscx.Core.IO.PscxPathInfo[]
DefaultValue: ''
SupportsWildcards: false
Aliases:
- PSPath
ParameterSets:
- Name: LiteralPath
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -NoClobber

Specifies not to overwrite any existing file.

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

### -Path

Specifies the path to the file to process.
Wildcard syntax is allowed.

```yaml
Type: Pscx.Core.IO.PscxPathInfo[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Path
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
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

### Pscx.Core.IO.PscxPathInfo

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

### Pscx.Core.IO.PscxPathInfo[]

Accepts one or more file paths. `-Path` accepts pipeline input and both path
parameters accept input by property name.

## OUTPUTS

### Pscx.Commands.Text.LineEndingCheckResult

With `-Check`, returns the source and destination paths, target line-ending and
final-newline modes, current text-file information, and `NeedsConversion`.
Without `-Check`, the command produces no success output.

## NOTES

If the source encoding cannot be identified safely, specify `-Encoding` to
decode and write the file explicitly. Specifying `-Encoding` writes the chosen
encoding without adding a byte-order mark.

## RELATED LINKS

- [Get-TextFileInfo]()
- [ConvertTo-WindowsLineEnding]()
