---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Push-EnvironmentBlock
---

# Push-EnvironmentBlock

## SYNOPSIS

PSCX Cmdlet: Pushes the current environment onto the environment block stack.

## SYNTAX

### __AllParameterSets

```
Push-EnvironmentBlock [-Description <string>] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Stores the state of all environment variables into an environment block and pushes that onto the environment block stack.

## EXAMPLES

### Example 1 - Use Push-EnvironmentBlock

```powershell
Push-EnvironmentBlock -Description "Before loading VS 2010 env vars"
```

Demonstrates Push-EnvironmentBlock.

## PARAMETERS

### -Description



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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES




## RELATED LINKS

- [Online Version]()
- [Add-PathVariable]()
- [Get-PathVariable]()
- [Set-PathVariable]()
- [Pop-EnvironmentBlock]()
