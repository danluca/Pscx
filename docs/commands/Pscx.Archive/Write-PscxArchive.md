---
document type: cmdlet
external help file: Pscx.Archive.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Archive
ms.date: 08/21/2026
PlatyPS schema version: 2024-05-01
title: Write-PscxArchive
---

# Write-PscxArchive

## SYNOPSIS

Creates a ZIP, 7z, TAR, TAR.GZ, or TAR.BZ2 archive.

## SYNTAX

### Path (Default)

```
Write-PscxArchive [-Path] <string[]> [-OutputPath] <string> [-EntryPathRoot <string>] [-ShowProgress] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### LiteralPath

```
Write-PscxArchive [-LiteralPath] <string[]> [-OutputPath] <string> [-EntryPathRoot <string>] [-ShowProgress] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Object

```
Write-PscxArchive [-OutputPath] <string> [-EntryPathRoot <string>] -InputObject <psobject> [-ShowProgress] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

`Write-PscxArchive` collects filesystem input and creates one archive. The output filename selects the format: `.zip`, `.7z`, `.tar`, `.tar.gz` or `.tgz`, and `.tar.bz2` or `.tbz2`.

## EXAMPLES

### Example 1 - Archive a directory

```powershell
Write-PscxArchive -LiteralPath ./logs -OutputPath ./logs.tar.gz -ShowProgress
```

Creates a compressed TAR archive containing the `logs` directory tree.

### Example 2 - Archive pipeline input relative to a root

```powershell
Get-ChildItem ./src -File -Recurse |
    Write-PscxArchive -OutputPath ./source.zip -EntryPathRoot ./src
```

Stores the files using paths relative to `./src`.

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

### -EntryPathRoot

Specifies a directory used to calculate paths stored in the archive. Every input must be beneath this root.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases:
- Root
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

Replaces an existing output archive.

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

Specifies input paths exactly as typed.

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

Specifies the output archive. The filename extension selects the format.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Path

Specifies input paths. Wildcard syntax is supported.

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

Displays archive creation progress.

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

Shows what would happen without creating the archive.

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

### System.IO.FileInfo

## NOTES

Pscx.Archive 4.0 creates unencrypted archives. ACLs and Unix permission modes are not preserved as a portable contract.

## RELATED LINKS

[Expand-PscxArchive](Expand-PscxArchive.md)

[Read-PscxArchive](Read-PscxArchive.md)
