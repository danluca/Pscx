---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Pop-EnvironmentBlock
---

# Pop-EnvironmentBlock

## SYNOPSIS

PSCX Cmdlet: Pops the topmost environment block.

## SYNTAX

### __AllParameterSets

```
Pop-EnvironmentBlock [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Pops the environment block and restores the state of all environment variables to the values stored in the environment block.

## EXAMPLES

### Example 1 - Use Pop-EnvironmentBlock

```powershell
Pop-EnvironmentBlock
```

Restores the current set of environment variables from the set at the top of the environment block stack.

## PARAMETERS

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
- [Push-EnvironmentBlock]()
