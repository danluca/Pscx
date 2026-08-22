---
document type: cmdlet
external help file: Pscx.Archive.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Archive
ms.date: 08/21/2026
PlatyPS schema version: 2024-05-01
title: Read-PscxArchive
---

# Read-PscxArchive

## SYNOPSIS

Lists entries in an archive.

## SYNTAX

### Path (Default)

```
Read-PscxArchive [-Path] <string[]> [-IncludeDirectories] [<CommonParameters>]
```

### LiteralPath

```
Read-PscxArchive [-LiteralPath] <string[]> [-IncludeDirectories] [<CommonParameters>]
```

### Object

```
Read-PscxArchive -InputObject <psobject> [-IncludeDirectories] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

`Read-PscxArchive` reads supported archive formats through the managed SharpCompress backend and emits structured archive-entry objects. Directory entries are omitted unless `IncludeDirectories` is specified.

## EXAMPLES

### Example 1 - List files in ZIP archives

```powershell
Read-PscxArchive -Path *.zip | Where-Object Size -gt 1MB
```

Lists entries larger than one megabyte in each matching ZIP archive.

## PARAMETERS

### -IncludeDirectories

Includes directory entries in the output.

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

Specifies a filesystem path string, `FileInfo`, or `DirectoryInfo` from the pipeline.

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

Specifies archive paths exactly as typed. Wildcard characters are not expanded.

```yaml
Type: System.String[]
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

Specifies archive paths. Wildcard syntax is supported.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: true
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

This cmdlet supports the common parameters. For more information, see [about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.Management.Automation.PSObject

## OUTPUTS

### Pscx.Commands.IO.Compression.ArchiveEntry

## NOTES

Encrypted archives can be listed, but Pscx.Archive 4.0 does not extract them.

## RELATED LINKS

[Expand-PscxArchive](Expand-PscxArchive.md)

[Write-PscxArchive](Write-PscxArchive.md)
