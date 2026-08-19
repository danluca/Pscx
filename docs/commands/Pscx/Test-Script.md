---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Test-Script
---

# Test-Script

## SYNOPSIS

PSCX Cmdlet: Determines whether a PowerShell script has any syntax errors.

## SYNTAX

### Path (Default)

```
Test-Script [-Path] <PscxPathInfo[]> [-Context <int[]>] [-PassThru] [<CommonParameters>]
```

### Object

```
Test-Script -InputObject <psobject> [-Context <int[]>] [-PassThru] [<CommonParameters>]
```

### LiteralPath

```
Test-Script [-LiteralPath] <PscxPathInfo[]> [-Context <int[]>] [-PassThru] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Determines whether a PowerShell script has syntax errors using PowerShell's
modern language parser. By default, the command returns a Boolean and reports
formatted diagnostics as warnings. Use `-PassThru` to receive a structured
`Pscx.Commands.ScriptTestResult` containing the parser errors instead.

## EXAMPLES

### Example 1 - Use Test-Script

```powershell
Test-Script foo.ps1
```

Displays syntax errors and returns a boolean indicating if there were.

### Example 2 - Use Test-Script

```powershell
Test-Script foo.ps1 -WarningAction SilentlyContinue
```

Returns a boolean indicating if there were any syntax errors, suppressing all warnings.

### Example 3 - Use Test-Script

```powershell
Test-Script foo.ps1 -Context 1
```

Displays syntax errors as well as the line of script before and after the line containing each syntax error.  Returns a boolean indicating if there was a syntax error.

### Example 4 - Return structured parser diagnostics

```powershell
$result = Test-Script ./build.ps1 -PassThru
$result.Errors | Select-Object ErrorId, Message, Extent
```

Returns one result object for the script. `IsValid` reports overall validity,
and `Errors` contains PowerShell parser-error objects with source extents.

## PARAMETERS

### -Context

The number of lines of source script to show before and after the line containing the syntax error.

```yaml
Type: System.Int32[]
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

### -PassThru

Returns a structured `Pscx.Commands.ScriptTestResult` instead of a Boolean.
Structured mode does not also write formatted parser warnings.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
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

### System.String

Accepts a System.String value.

### Pscx.Core.IO.PscxPathInfo

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

### System.Management.Automation.PSObject

Accepts a System.Management.Automation.PSObject value.

### Pscx.Core.IO.PscxPathInfo[]

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

## OUTPUTS

### System.Boolean

Returns a System.Boolean value by default.

### Pscx.Commands.ScriptTestResult

Returns a structured result with `Path`, `IsValid`, and `Errors` when
`-PassThru` is specified.

## NOTES




## RELATED LINKS

- [Online Version]()
