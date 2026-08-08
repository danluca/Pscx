---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Get-PscxHash
---

# Get-PscxHash

## SYNOPSIS

PSCX Cmdlet: Gets the hash value for the specified file or byte array via the pipeline.

## SYNTAX

### Path (Default)

```
Get-PscxHash [-Path] <PscxPathInfo[]> [-Algorithm <string>] [<CommonParameters>]
```

### Object

```
Get-PscxHash -InputObject <psobject> [-Algorithm <string>]
 [-StringEncoding <StringEncodingParameter>] [<CommonParameters>]
```

### LiteralPath

```
Get-PscxHash [-LiteralPath] <PscxPathInfo[]> [-Algorithm <string>] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Gets the hash value for the specified file or byte array via the pipeline.
 The default hash algorithm is MD5, although you can specify other algorithms using the -Algorithm parameter (MD5, SHA1, SHA256, SHA384, SHA512 and RIPEMD160).
 This cmdlet emits a HashInfo object that has properties for Path, Algorithm, HashString and Hash.

## EXAMPLES

### Example 1 - Use Get-PscxHash

```powershell
Get-Hash $PSHOME\PowerShell.exe
        Algorithm: MD5

        Path       : C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe
        HashString : E22825B10BE3E8709BA1AB4D2DF36B57
```

Gets the MD5 hash (default hash algorithm) of the PowerShell executable.

### Example 2 - Use Get-PscxHash

```powershell
Get-Hash $PSHOME\PowerShell.exe -Algorithm SHA1
        Algorithm: SHA1

        Path       : C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe
        HashString : 3BA6DDF13A5DEDE95D427E7EFFEDFBC6F1BB267D
```

Gets the SHA1 hash of the PowerShell executable.

### Example 3 - Use Get-PscxHash

```powershell
"Hello" | Get-Hash -Algorithm SHA1 -StringEncoding Ascii
        Algorithm: SHA1

        Path       :
        HashString : F7FF9E8B7BB2E09B70935A5D785E0CC5D9D0ABF0
```

Gets the SHA1 hash of the string "Hello" interpreted as Ascii characters.

## PARAMETERS

### -Algorithm

Specifies the hash algorithm to use.
 Valid values are MD5 (default), SHA1, SHA256, SHA384, SHA512, RIPEMD160

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### Pscx.StringEncodingParameter

Accepts a Pscx.StringEncodingParameter value.

### Pscx.Core.IO.PscxPathInfo

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

### System.Management.Automation.PSObject

Accepts a System.Management.Automation.PSObject value.

### Pscx.Core.IO.PscxPathInfo[]

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

## OUTPUTS

### Pscx.Commands.IO.HashInfo

Returns a Pscx.Commands.IO.HashInfo value.

## NOTES




## RELATED LINKS

- [Online Version]()
