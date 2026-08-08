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

Sets a file or folder's created and last accessed/write times.

## EXAMPLES

### Example 1 - Use Set-FileTime

```powershell
Set-FileTime foo.txt
```

Updates the LastWriteTime and LastAccessTime properties of the file foo.txt to the current local time.

### Example 2 - Use Set-FileTime

```powershell
Set-FileTime foo.txt -Time ((get-date).AddDays(-14))
```

Updates the LastWriteTime and LastAccessTime properties of the file foo.txt to the current local time minus 14 days.

### Example 3 - Use Set-FileTime

```powershell
Get-ChildItem . *.cs -r | Set-FileTime
```

Updates the LastWriteTime and LastAccessTime properties on all files with extension .CS in the current dir and below to the current local time.

### Example 4 - Use Set-FileTime

```powershell
Get-ChildItem . *.cs -r | Set-FileTime -Modified
```

Updates only the LastWriteTime property on all files with extension .CS in the current dir and below to the current local time.

### Example 5 - Use Set-FileTime

```powershell
Get-ChildItem . *.cs -r | Set-FileTime -UseTimeFromFile C:\boot.ini
```

Updates the LastWriteTime and LastAccessTime properties on all files with extension .CS in the current dir and below to the same time as the LastWriteTime of the file C:\boot.ini.

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

The time to use to set the access, created and modified times unless -Accessed, -Created and/or -Modified is specified, then only those times will be updated.

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




## RELATED LINKS

- [Online Version]()
