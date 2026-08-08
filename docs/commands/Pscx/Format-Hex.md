---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Format-Hex
---

# Format-Hex

## SYNOPSIS

PSCX Cmdlet: Displays the contents of files or byte streams in hex format and optionally ASCII.

## SYNTAX

### Path (Default)

```
Format-Hex [-Path] <PscxPathInfo[]> [-Width <int>] [-Columns <int>] [-Offset <long>] [-Count <int>]
 [-HideHeader] [-HideAddress] [-HideAscii] [<CommonParameters>]
```

### Object

```
Format-Hex -InputObject <psobject> [-Width <int>] [-Columns <int>] [-Offset <long>] [-Count <int>]
 [-HideHeader] [-HideAddress] [-HideAscii] [-StringEncoding <StringEncodingParameter>]
 [<CommonParameters>]
```

### LiteralPath

```
Format-Hex [-LiteralPath] <PscxPathInfo[]> [-Width <int>] [-Columns <int>] [-Offset <long>]
 [-Count <int>] [-HideHeader] [-HideAddress] [-HideAscii] [<CommonParameters>]
```

## ALIASES

fhex, fhx

## DESCRIPTION

The Format-Hex command displays the contents of the specified files in hex format.
 This cmdlet will also accept pipeline input in the form of a byte stream.
 The output can be controlled via various parameters to indicate the number of columns that should be displayed or alternatively you can specify the width of the output.
 The header, address and ASCII portions of the display can also be turned off individually.
 The offset and count can also be specified via parameters to control where in the input to start displaying and how much to display.

## EXAMPLES

### Example 1 - Use Format-Hex

```powershell
Format-PscxHex $pshome\PowerShell.exe -Count 256
```

This displays the first 256 bytes of the PowerShell executable.

### Example 2 - Use Format-Hex

```powershell
[byte[]](1..255) | Format-PscxHex
```

This examples accepts a byte array as input and displays those byte values in hex and ASCII.

### Example 3 - Use Format-Hex

```powershell
"hello world" | Format-PscxHex -InputObject {$_}
```

In this scenario the string is always converted to bytes assuming the string encoding is Unicode which is true of PowerShell strings.

### Example 4 - Use Format-Hex

```powershell
"hello world" | Format-PscxHex -InputObject {$_} -StringEncoding ASCII
```

If you want to view the bytes using an alternate encoding then use the -StringEncoding parameter to specify the preferred encoding.

## PARAMETERS

### -Columns



```yaml
Type: System.Int32
DefaultValue: ''
SupportsWildcards: false
Aliases:
- NumBytesPerLine
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

### -Count

Specifies the number of bytes to display.

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

### -HideAddress

Hides the address information.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- NoAddress
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

### -HideAscii

Hides the ASCII representation of the bytes.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- NoAscii
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

### -HideHeader

Hides the header lines.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- NoHeader
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

### -InputObject

Accepts an object as input to the cmdlet.
Enter a variable that contains the objects or type a command or expression that gets the objects.

```yaml
Type: System.Management.Automation.PSObject
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Object
  Position: Named
  IsRequired: true
  ValueFromPipeline: true
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

### -Offset

Specifies the number of bytes to offset into file.

```yaml
Type: System.Int64
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
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -StringEncoding

The encoding to use for string InputObjects.
 Valid values are: ASCII, UTF7, UTF8, UTF32, Unicode, BigEndianUnicode and Default.

```yaml
Type: Pscx.StringEncodingParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Object
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Width

Specifies desired width of output text.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### byte

Accepts a byte value.

### string

Accepts a string value.

### Pscx.StringEncodingParameter

Accepts a Pscx.StringEncodingParameter value.

### Pscx.Core.IO.PscxPathInfo

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

### System.Management.Automation.PSObject

Accepts a System.Management.Automation.PSObject value.

### Pscx.Core.IO.PscxPathInfo[]

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

## OUTPUTS

### Formatted

Returns a Formatted text value.

### System.String

Returns a System.String value.

## NOTES

Strings can be viewed in hex but because the cmdlet interprets pipeline input of type string to specify a file path you need to use the -InputObject parameter.
 See example number three below.


## RELATED LINKS

- [Online Version]()
