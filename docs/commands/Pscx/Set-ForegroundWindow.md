---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Set-ForegroundWindow
---

# Set-ForegroundWindow

## SYNOPSIS

PSCX Cmdlet: Given an hWnd or window handle, brings that window to the foreground. Useful for restoring a window to uppermost after an application which seizes the foreground is invoked. See also Get-ForegroundWindow

## SYNTAX

### __AllParameterSets

```
Set-ForegroundWindow [[-Handle] <IntPtr>] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Given an hWnd or window handle, brings that window to the foreground.
Useful for restoring a window to uppermost after an application which seizes the foreground is invoked.
See also Get-ForegroundWindow

## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help Set-ForegroundWindow -Full
```

Displays the complete installed help for this command.

## PARAMETERS

### -Handle

handle for the window to be set as the foreground window.
If not specified, this defaults to the main window of the current process.

```yaml
Type: System.IntPtr
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
- [Get-ForegroundWindow]()
