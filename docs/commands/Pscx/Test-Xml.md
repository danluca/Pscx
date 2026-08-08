---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Test-Xml
---

# Test-Xml

## SYNOPSIS

PSCX Cmdlet: Tests for well formedness and optionally validates against XML Schema.

## SYNTAX

### Path (Default)

```
Test-Xml [-Path] <PscxPathInfo[]> [-SchemaPath <PscxPathInfo[]>] [-Validate] [-EnableDtd]
 [<CommonParameters>]
```

### Object

```
Test-Xml -InputObject <psobject> [-SchemaPath <PscxPathInfo[]>] [-Validate] [-EnableDtd]
 [<CommonParameters>]
```

### LiteralPath

```
Test-Xml [-LiteralPath] <PscxPathInfo[]> [-SchemaPath <PscxPathInfo[]>] [-Validate] [-EnableDtd]
 [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Tests for well formedness and optionally validates against XML Schema.
 It doesn't handle specifying the targetNamespace.
 To see validation error messages, specify the -Verbose flag.

## EXAMPLES

### Example 1 - Use Test-Xml

```powershell
Test-Xml foo.xml
```

Returns true or false indicating whether or not foo.xml is well-formed.

### Example 2 - Use Test-Xml

```powershell
Test-Xml foo.xml -Verbose
```

Returns true or false indicating whether or not foo.xml is well-formed and displays any XML error info.

### Example 3 - Use Test-Xml

```powershell
Test-Xml foo.xml -SchemaPath .\foo.xsd
```

Returns true or false indicating whether or not foo.xml is well-formed and conforms to the schema defined in foo.xsd.

### Example 4 - Use Test-Xml

```powershell
Test-Xml foo.xml -EnableDtd
```

Returns true or false indicating whether or not foo.xml is well-formed. This examples enables DTD processing for XML files that use a DTD.

## PARAMETERS

### -EnableDtd

Enables document type definition (DTD) processing.

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

### -SchemaPath

Array of paths to the required schema files to perform schema-based validation.

```yaml
Type: Pscx.Core.IO.PscxPathInfo[]
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

### -Validate

Forces schema validation of the XML against inline schema.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### Pscx.Core.IO.PscxPathInfo

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

### System.Management.Automation.PSObject

Accepts a System.Management.Automation.PSObject value.

### Pscx.Core.IO.PscxPathInfo[]

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

## OUTPUTS

### System.Boolean

Returns a System.Boolean value.

## NOTES




## RELATED LINKS

- [Online Version]()
- [Convert-Xml]()
- [Format-Xml]()
