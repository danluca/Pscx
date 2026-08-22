---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Stop-TerminalSession
---

# Stop-TerminalSession

## SYNOPSIS

PSCX Cmdlet: Logs off a specific remote desktop session on a system running Terminal Services/Remote Desktop

## SYNTAX

### __AllParameterSets

```
Stop-TerminalSession [[-ComputerName] <string[]>] [[-Id] <int[]>] [-Force] [-Wait] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Logs off and terminates a specific remote desktop session. Programs running in
the session are closed. Use `Disconnect-TerminalSession` when the session and
its programs should remain available for later reconnection.

## EXAMPLES

### Example 1 - View detailed command help

```powershell
Get-Help Stop-TerminalSession -Full
```

Displays the complete installed help for this command.

## PARAMETERS

### -ComputerName

Logs off a remote desktop session on the specified computers.
The default is the local computer.
Type the NETBIOS name, an IP address or a fully-qualified domain name of one or more computers.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
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

### -Force

Does not ask for confirmation.

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

### -Id

Identifier of the session to be logged of.

```yaml
Type: System.Int32[]
DefaultValue: ''
SupportsWildcards: false
Aliases:
- SessionId
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Wait

Wait for results before returning.

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

### System.Int32

Accepts a System.Int32[] value.

### System.String

Accepts a System.String[] value.

### System.Int32[]

Accepts a System.Int32[] value.

### System.String[]

Accepts a System.String[] value.

## OUTPUTS

## NOTES




## RELATED LINKS

- [Online Version]()
