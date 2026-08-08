---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Join-PscxString
---

# Join-PscxString

## SYNOPSIS

PSCX Cmdlet: Joins an array of strings into a single string.

## SYNTAX

### NewLineSeparator (Default)

```
Join-PscxString [-Strings] <string[]> [-NewLine] [<CommonParameters>]
```

### CustomSeparator

```
Join-PscxString [-Strings] <string[]> [-Separator <string>] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Joins an array of strings into a single string.

## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help Join-PscxString -Full
```

Displays the complete installed help for this command.

## PARAMETERS

### -NewLine

Insert newline as separator between joined strings.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: NewLineSeparator
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Separator

Insert specified string as the separator between joined strings.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: CustomSeparator
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Strings

String(s) to be joined.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
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

### System.String

Accepts a System.String[] value.

### System.String[]

Accepts a System.String[] value.

## OUTPUTS

### System.String

Returns a System.String value.

## NOTES




## RELATED LINKS

- [Online Version]()
- [Split-PscxString]()
