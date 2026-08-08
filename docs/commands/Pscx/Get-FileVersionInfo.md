---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Get-FileVersionInfo
---

# Get-FileVersionInfo

## SYNOPSIS

PSCX Cmdlet: Gets a FileVersionInfo object for the specified path.

## SYNTAX

### Path (Default)

```
Get-FileVersionInfo [-Path] <PscxPathInfo[]> [<CommonParameters>]
```

### LiteralPath

```
Get-FileVersionInfo [-LiteralPath] <PscxPathInfo[]> [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Attempts to get the FileVersionInfo object for the specified path.
Usually only executable files include file version information.

## EXAMPLES

### Example 1 - Use Get-FileVersionInfo

```powershell
Get-FileVersionInfo $PSHOME\PowerShell.exe | Format-List *
```

Gets the file version information for PowerShell.exe.

## PARAMETERS

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

### System.Diagnostics.FileVersionInfo

Returns a System.Diagnostics.FileVersionInfo value.

## NOTES




## RELATED LINKS

- [Online Version]()
