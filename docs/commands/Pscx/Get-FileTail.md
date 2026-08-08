---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Get-FileTail
---

# Get-FileTail

## SYNOPSIS

PSCX Cmdlet: Tails the contents of a file - optionally waiting on new content.

## SYNTAX

### Path (Default)

```
Get-FileTail [-Path] <PscxPathInfo[]> [-Count <int>] [-Encoding <EncodingParameter>]
 [-LineTerminator <string>] [-Wait] [<CommonParameters>]
```

### LiteralPath

```
Get-FileTail [-LiteralPath] <PscxPathInfo[]> [-Count <int>] [-Encoding <EncodingParameter>]
 [-LineTerminator <string>] [-Wait] [<CommonParameters>]
```

## ALIASES

tail

## DESCRIPTION

This implentation efficiently tails the contents of a file by reading lines from the end rather then processing the entire file.
This behavior is crucial for efficiently tailing large log files and large log files over a network.
 You can also specify the Wait parameter to have the cmdlet wait and display new content as it is written to the file.
 Use Ctrl+C to break out of the wait loop.
 Note that if an encoding is not specified, the cmdlet will attempt to auto-detect the encoding by reading the first character from the file.
If no character haven't been written to the file yet, the cmdlet will default to using Unicode encoding.
You can override this behavior by explicitly specifying the encoding via the Encoding parameter.

## EXAMPLES

### Example 1 - Use Get-FileTail

```powershell
Tail-File foo.log -Count 20
```

Displays the last 20 lines of the file foo.log.  If there are fewer than 20 lines, it will display all lines.

### Example 2 - Use Get-FileTail

```powershell
Tail-File ascii.log -Wait -Encoding Ascii
```

Displays the last 10 lines of the ASCII encoded file ascii.log and then waits.  Any new content appended to the file will be displayed.  Press Ctrl+C to break out of the loop and return control to the console.

## PARAMETERS

### -Count

The number of lines to display from the end of the file.

```yaml
Type: System.Int32
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

### -Encoding

The encoding to use for string InputObjects.
 Valid values are: ASCII, Unicode and UTF8.
If the file contains only ASCII characters specify the parameter "-Encoding ASCII" on the file.
UTF8 is only supported if the file contains ASCII characters.

```yaml
Type: Pscx.EncodingParameter
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

### -LineTerminator

The line termination sequence for the file.

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

### -Wait

Puts Tail-File into an infinite wait loop, waiting for new content to be appended to the file.
 When new content is appended to the file it will be displayed.
 Use Ctrl+C to exit the wait loop.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- Follow
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

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

## OUTPUTS

### System.String

Returns a System.String value.

## NOTES




## RELATED LINKS

- [Online Version]()
