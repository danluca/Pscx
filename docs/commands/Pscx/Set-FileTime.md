---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Set-FileTime
---

# Set-FileTime

## SYNOPSIS

PSCX Cmdlet: Sets a file or folder's created and last accessed/write times.

## SYNTAX

### Path (Default)

```
Set-FileTime [-Path] <PscxPathInfo[]> [[-Time] <datetime>] [-UseTimeFromFile <string>] [-Accessed]
 [-Created] [-Modified] [-Force] [-PassThru] [-Utc] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### LiteralPath

```
Set-FileTime [-LiteralPath] <PscxPathInfo[]> [[-Time] <datetime>] [-UseTimeFromFile <string>]
 [-Accessed] [-Created] [-Modified] [-Force] [-PassThru] [-Utc] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## ALIASES

touch

## DESCRIPTION

Updates timestamps on an existing file or creates an empty file when the path does not exist.
With no timestamp switches, only LastWriteTime (modified time) is updated.
Use -Accessed, -Created, and/or -Modified to select the timestamps to update.
If neither -Time nor -UseTimeFromFile is supplied, the current time is used.

## EXAMPLES

### Example 1 - Use Set-FileTime

```powershell
Set-FileTime foo.txt
```

Updates LastWriteTime on foo.txt to the current local time, creating an empty file if it does not exist. Existing file contents are preserved.

### Example 2 - Use Set-FileTime

```powershell
Set-FileTime foo.txt -Time ((get-date).AddDays(-14))
```

Updates LastWriteTime on foo.txt to the current local time minus 14 days.

### Example 3 - Use Set-FileTime

```powershell
Get-ChildItem . *.cs -r | Set-FileTime
```

Updates LastWriteTime on all files with extension .CS in the current dir and below to the current local time.

### Example 4 - Use Set-FileTime

```powershell
Get-ChildItem . *.cs -r | Set-FileTime -Accessed -Modified
```

Updates LastAccessTime and LastWriteTime on all files with extension .CS in the current dir and below to the current local time.

### Example 5 - Use Set-FileTime

```powershell
Get-ChildItem . *.cs -r | Set-FileTime -UseTimeFromFile C:\boot.ini
```

Updates LastWriteTime on all files with extension .CS in the current dir and below to the LastWriteTime of C:\boot.ini.

## PARAMETERS

### -Accessed

Update the accessed time.
 Created and modified time will not be updated unless also specified.
Parameter alias is SetAccessedTime.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- SetAccessedTime
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

### -Created

Update the created time.
 Accessed and modified time will not be upated unless also specified.
Parameter alias is SetCreatedTime.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- SetCreatedTime
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

Attempt to set the specified time even if the file is readonly.

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

### -Modified

Update the modified time.
 Accessed and created time will not be updated unless also specified.
This is the default when no timestamp switches are selected.
Parameter alias is SetModifiedTime.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- SetModifiedTime
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

### -PassThru

Passing the processing path to the next stage of the pipeline.

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
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Time

The time to use for the selected timestamps. Defaults to the current time.
Only modified time is updated unless -Accessed, -Created and/or -Modified is specified.

```yaml
Type: System.DateTime
DefaultValue: ''
SupportsWildcards: false
Aliases: []
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

### -UseTimeFromFile

Use the date and time from the file at the specified path to set the access and/or write times.

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

### -Utc

Set the accessed, created and/or modified times as UTC times.

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

### Pscx.Core.IO.PscxPathInfo

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

### Pscx.Core.IO.PscxPathInfo[]

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

## OUTPUTS

### System.IO.FileInfo

Returns a System.IO.FileInfo value.

## NOTES

Creation-time behavior follows the operating system and .NET filesystem APIs.
On Linux, -Created sets modified time because Linux does not provide an API to
set file birth time. When birth time is unavailable, the reported CreationTime
is derived from modification/status-change time and may change after a modified-time update.



## RELATED LINKS

- [Online Version]()
