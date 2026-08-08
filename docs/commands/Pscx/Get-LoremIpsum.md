---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Get-LoremIpsum
---

# Get-LoremIpsum

## SYNOPSIS

Generates lorem ipsum text of a specified length.

## SYNTAX

### Paragraph (Default)

```
Get-LoremIpsum [[-Length] <int>] [-Paragraph] [-Language <LoremIpsumLanguage>] [<CommonParameters>]
```

### Character

```
Get-LoremIpsum [[-Length] <int>] [-Character] [-Language <LoremIpsumLanguage>] [<CommonParameters>]
```

### Word

```
Get-LoremIpsum [[-Length] <int>] [-Word] [-Language <LoremIpsumLanguage>] [<CommonParameters>]
```

## ALIASES

lorem

## DESCRIPTION

Generates placeholder lorem ipsum text with the requested length and formatting.


## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help Get-LoremIpsum -Full
```

Displays the complete installed help for this command.

## PARAMETERS

### -Character



```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Character
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Language



```yaml
Type: Pscx.Commands.Text.LoremIpsumLanguage
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

### -Length



```yaml
Type: System.Int32
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Paragraph



```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Paragraph
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Word



```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Word
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

## OUTPUTS

### System.String

Returns a System.String value.

## NOTES




## RELATED LINKS

- [Online Version]()
