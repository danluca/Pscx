---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Read-PscxArchive
---

# Read-PscxArchive

## SYNOPSIS

PSCX Cmdlet: Enumerates compressed archives such as 7z or rar, emitting ArchiveEntry objects representing records in the archive.

## SYNTAX

### Path (Default)

```
Read-PscxArchive [-Path] <PscxPathInfo[]> [-IncludeDirectories] [<CommonParameters>]
```

### Object

```
Read-PscxArchive -InputObject <psobject> [-IncludeDirectories] [<CommonParameters>]
```

### LiteralPath

```
Read-PscxArchive [-LiteralPath] <PscxPathInfo[]> [-IncludeDirectories] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Enumerates compressed archives such as 7z or rar, emitting ArchiveEntry objects representing records in the archive.Read-PscxArchive is used to list the contents of a compressed archive containing one or more compressed file(s).
The format of the file being read can be overriden with the Format parameter, for example to enumerate the contents of a self-extracting archive (EXE).Read-PscxArchive is useful if you wish to perform filtering using standard pipeline Where-Object and/or ForEach-Object cmdlets before piping ArchiveEntry objects to Expand-PscxArchive.

## EXAMPLES

### Example 1 - Use Read-PscxArchive

```powershell
Read-PscxArchive -Path *.iso > contents.txt
```

Read all ISO compressed archives and dump the contents into a text file.

### Example 2 - Use Read-PscxArchive

```powershell
Read-PscxArchive -Path Setup.exe -Format Zip | Where-Object { $_.Name -like "*.txt" } | Expand-PscxArchive
```

Read contents from a self-extracting zip file and expand any txt files into the current filesystem location.

## PARAMETERS

### -IncludeDirectories

If present, directs Read-PscxArchive to list the 0-length directory entries that represent folders in the archive.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.IO.FileInfo

Accepts a System.IO.FileInfo value.

### Pscx.Core.IO.PscxPathInfo

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

### System.Management.Automation.PSObject

Accepts a System.Management.Automation.PSObject value.

### Pscx.Core.IO.PscxPathInfo[]

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

## OUTPUTS

### Pscx.IO.Compression.ArchiveEntry

Returns a Pscx.IO.Compression.ArchiveEntry value.

### Pscx.Commands.IO.Compression.ArchiveEntry

Returns a Pscx.Commands.IO.Compression.ArchiveEntry value.

## NOTES

Supported formats are: SevenZip, Arj, BZip2, Cab, Chm, Compound, Cpio, Deb, GZip, Iso, Lzh, Lzma, Nsis, Rar, Rpm, Split, Tar, Wim, Z, Zip.


## RELATED LINKS

- [Online Version]()
