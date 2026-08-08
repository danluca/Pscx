---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Expand-PscxArchive
---

# Expand-PscxArchive

## SYNOPSIS

PSCX Cmdlet: Expands a compressed archive file, or ArchiveEntry object, to its constituent file(s).

## SYNTAX

### Path (Default)

```
Expand-PscxArchive [-Path] <PscxPathInfo[]> [[-OutputPath] <PscxPathInfo>] [-PassThru]
 [-ShowProgress] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Object

```
Expand-PscxArchive [[-OutputPath] <PscxPathInfo>] -InputObject <psobject> [-PassThru]
 [-ShowProgress] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### LiteralPath

```
Expand-PscxArchive [-LiteralPath] <PscxPathInfo[]> [[-OutputPath] <PscxPathInfo>] [-PassThru]
 [-ShowProgress] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Expands a compressed archive file, or ArchiveEntry object, to its constituent file(s).

## EXAMPLES

### Example 1 - Use Expand-PscxArchive

```powershell
Expand-PscxArchive -Path *.zip -OutputPath .\Temp\ -ShowProgress
```

Expand all zip files in the current directory to .\temp while showing a progress bar.

### Example 2 - Use Expand-PscxArchive

```powershell
Expand-PscxArchive -Path setup.exe -EntryPath en-us\readme.htm
```

Search a self-expanding zip file named setup.exe in the current directory for a file named "readme.htm" in a subdirectory named "en-us," and expand it to the current directory.

### Example 3 - Use Expand-PscxArchive

```powershell
Read-PscxArchive *.iso | where { $_.size -gt 1mb } | Expand-PscxArchive
```

Scan through all ISOs in the current directory and expand any files bigger than 1MB to the current directory.

### Example 4 - Use Expand-PscxArchive

```powershell
dir x:\ISOs -rec -inc *.iso | Read-PscxArchive | where {$_.path -eq "setup.exe"} | extract-PscxArchive -path {$_.archivepath} -index (0..19)
```

Look through all files under x:\ISOs for ISOs that contain a setup.exe in the root, and if so, expand the first twenty files of that ISO to the current directory.

## PARAMETERS

### -Confirm

Prompts you for confirmation before running the cmdlet.

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

### -OutputPath

The path to place the expanded file(s).
This path must lie on the FileSystem provider.

```yaml
Type: Pscx.Core.IO.PscxPathInfo
DefaultValue: ''
SupportsWildcards: false
Aliases:
- To
ParameterSets:
- Name: Object
  Position: 0
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: Path
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: LiteralPath
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

Output a FileInfo or DirectoryInfo for each file or directory expanded, respectively.

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

### -ShowProgress

Show the PowerShell progress bar while performing expansion and scanning operations.

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

Runs the command in a mode that only reports what would happen without performing the actions.

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

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.IO.FileInfo

Accepts a System.IO.FileInfo value.

### Pscx.IO.Compression.ArchiveEntry

Accepts a Pscx.IO.Compression.ArchiveEntry value.

### Pscx.Core.IO.PscxPathInfo

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

### System.Management.Automation.PSObject

Accepts a System.Management.Automation.PSObject value.

### Pscx.Core.IO.PscxPathInfo[]

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

## OUTPUTS

### System.IO.FileSystemInfo

Returns a System.IO.FileSystemInfo value.

### System.IO.DirectoryInfo

Returns a System.IO.DirectoryInfo value.

### System.IO.FileInfo

Returns a System.IO.FileInfo value.

## NOTES

Supported formats are: SevenZip, Arj, BZip2, Cab, Chm, Compound, Cpio, Deb, GZip, Iso, Lzh, Lzma, Nsis, Rar, Rpm, Split, Tar, Wim, Z, Zip.


## RELATED LINKS

- [Online Version]()
