---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/25/2026
PlatyPS schema version: 2024-05-01
title: Get-TextFileInfo
---

# Get-TextFileInfo

## SYNOPSIS

Reports a text file's encoding, byte-order mark, line endings, and final-newline state.

## SYNTAX

### Path (Default)

```
Get-TextFileInfo [-Path] <PscxPathInfo[]> [<CommonParameters>]
```

### LiteralPath

```
Get-TextFileInfo [-LiteralPath] <PscxPathInfo[]> [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

`Get-TextFileInfo` inspects text files without changing them.
It reports the detected encoding and byte-order mark, counts CRLF, LF, and CR
line endings, identifies mixed line endings, and reports whether the file ends
with a newline.

BOM-marked UTF-8, UTF-16, and UTF-32 encodings are identified exactly.
BOM-less ASCII and valid UTF-8 are also recognized. Other BOM-less encodings
are reported as `Unknown` rather than being guessed.

## EXAMPLES

### Example 1 - Find files with mixed line endings

```powershell
Get-TextFileInfo -Path ./src/*.cs |
    Where-Object HasMixedLineEndings
```

Inspects the matching files and returns those containing more than one
line-ending style.

## PARAMETERS

### -LiteralPath

Specifies a path exactly as typed. Wildcard characters are not interpreted.

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

### -Path

Specifies file paths to inspect. Wildcard syntax is allowed.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### Pscx.Core.IO.PscxPathInfo

Accepts file paths from the pipeline.

### Pscx.Core.IO.PscxPathInfo[]

Accepts one or more file paths.

## OUTPUTS

### Pscx.Commands.Text.TextFileInfo

Returns structured encoding, BOM, line-ending, and final-newline information
for each file.

## NOTES

Encoding detection is intentionally conservative. Use an explicit encoding
when converting a file reported as `Unknown`.

## RELATED LINKS

- [ConvertTo-UnixLineEnding]()
- [ConvertTo-WindowsLineEnding]()
