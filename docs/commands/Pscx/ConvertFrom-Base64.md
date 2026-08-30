---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: ConvertFrom-Base64
---

# ConvertFrom-Base64

## SYNOPSIS

PSCX Cmdlet: Converts base64 encoded string to byte array.

## SYNTAX

### __AllParameterSets

```
ConvertFrom-Base64 [-Base64Text] <string[]> [-OutputPath <string>] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Converts base64 encoded string to byte array.

## EXAMPLES

### Example 1 - Use ConvertFrom-Base64

```powershell
$b64 | ConvertFrom-Base64 -OutputPath foo.dll
```

Converts the Base64 string in $b64 to a byte array and stores it in the foo.dll file.

### Example 2 - Use ConvertFrom-Base64

```powershell
ConvertFrom-Base64 -Base64Text $b64 -OutputPath foo.dll
```

Converts the Base64 string in $b64 to a byte array and stores it in the foo.dll file.

## PARAMETERS

### -Base64Text

Base64 encoded string to be converted into byte arary.

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

### -OutputPath

The path to write the results to.
 The results are written in binary format.

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

### System.Byte[]

Returns decoded bytes when `-OutputPath` is not specified. File output is
otherwise silent.

## NOTES

If an OutputPath is not specified then an array of bytes is output.
 Using the OutputPath parameter is faster than using 'set-content -enc byte foo.dll' to write the output to a file.


## RELATED LINKS

- [Online Version]()
- [ConvertTo-Base64]()
