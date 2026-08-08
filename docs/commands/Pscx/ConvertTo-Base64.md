---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: ConvertTo-Base64
---

# ConvertTo-Base64

## SYNOPSIS

PSCX Cmdlet: Converts byte array or specified file contents to base64 string.

## SYNTAX

### Path (Default)

```
ConvertTo-Base64 [-Path] <PscxPathInfo[]> [-NoLineBreak] [-Stream] [<CommonParameters>]
```

### Object

```
ConvertTo-Base64 -InputObject <psobject> [-NoLineBreak] [-Stream] [<CommonParameters>]
```

### LiteralPath

```
ConvertTo-Base64 [-LiteralPath] <PscxPathInfo[]> [-NoLineBreak] [-Stream] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Converts byte array or specified file contents to base64 string.
 By default, this cmdlet inserts line breaks every 76 characters and outputs the result in a single string.
For very large files, you may run into OutOfMemoryExceptions.
In this case, use the -Stream parameter which will generate multiple string outputs that, combined together, result in the equivalent base 64 text.

## EXAMPLES

### Example 1 - Use ConvertTo-Base64

```powershell
[byte[]](1..127) | ConvertTo-Base64
```

This buffers up the steam of bytes and then outputs the base64 string.

### Example 2 - Use ConvertTo-Base64

```powershell
$arr = [byte[]](1..127); ConvertTo-Base64 -Inp $arr
```

This outputs the base64 string based on the byte array passed into the InputObject parameter.

### Example 3 - Use ConvertTo-Base64

```powershell
$b64 = ConvertTo-Base64 Foo.dll -NoLineBreak
```

Converts the specified file (read as binary) to a base 64 string.

### Example 4 - Use ConvertTo-Base64

```powershell
ConvertTo-Base64 $PSHome\PowerShell.exe -stream > b64.txt
```

When dealing with large files it is usually better to pass the path to ConvertTo-Base64.

## PARAMETERS

### -InputObject



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

### -NoLineBreak

Suppress line breaks that are added by default every 76 characters.

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

### -Stream

Outputs multiple strings for the base 64 encoded data.
By default, the bytes are accumulated and encoded as a single string which can generate OutOfMemoryExceptions for very large files.

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

### Pscx.Core.IO.PscxPathInfo

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

### System.Management.Automation.PSObject

Accepts a System.Management.Automation.PSObject value.

### Pscx.Core.IO.PscxPathInfo[]

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

## OUTPUTS

## NOTES




## RELATED LINKS

- [Online Version]()
- [ConvertFrom-Base64]()
