---
document type: cmdlet
external help file: Pscx.Archive.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Archive
ms.date: 08/21/2026
PlatyPS schema version: 2024-05-01
title: Expand-PscxArchive
---

# Expand-PscxArchive

## SYNOPSIS

Safely expands an archive into a filesystem directory.

## SYNTAX

### Path (Default)

```
Expand-PscxArchive [-Path] <string[]> [[-OutputPath] <string>] [-PassThru] [-ShowProgress] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### LiteralPath

```
Expand-PscxArchive [-LiteralPath] <string[]> [[-OutputPath] <string>] [-PassThru] [-ShowProgress] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Object

```
Expand-PscxArchive [[-OutputPath] <string>] -InputObject <psobject> [-PassThru] [-ShowProgress] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

`Expand-PscxArchive` extracts supported archives through the managed SharpCompress backend. Before writing, it rejects rooted paths, parent-directory traversal, symbolic-link entries, and encrypted entries. Existing files require `Force`.

## EXAMPLES

### Example 1 - Expand ZIP archives

```powershell
Expand-PscxArchive -Path *.zip -OutputPath ./expanded -ShowProgress
```

Expands all matching ZIP archives into `./expanded`.

## PARAMETERS

### -Confirm

Prompts for confirmation before running the cmdlet.

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

### -Force

Overwrites existing destination files.

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

Specifies an archive path string or `FileInfo` from the pipeline.

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

Specifies archive paths exactly as typed.

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

### -OutputPath

Specifies the destination directory. The current filesystem directory is used by default.

```yaml
Type: System.String
DefaultValue: Current filesystem directory
SupportsWildcards: false
Aliases:
- To
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

### -PassThru

Emits a `FileInfo` or `DirectoryInfo` for each extracted entry.

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

### -ShowProgress

Displays extraction progress.

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

### -WhatIf

Shows what would happen without extracting files.

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

This cmdlet supports the common parameters. For more information, see [about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.Management.Automation.PSObject

## OUTPUTS

### System.IO.FileSystemInfo

## NOTES

Pscx.Archive 4.0 supports unencrypted extraction only. It preserves file timestamps where the archive supplies them, but does not promise to restore ACLs or Unix permission modes.

## RELATED LINKS

[Read-PscxArchive](Read-PscxArchive.md)

[Write-PscxArchive](Write-PscxArchive.md)
