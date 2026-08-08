---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Convert-Xml
---

# Convert-Xml

## SYNOPSIS

PSCX Cmdlet: Performs XSLT transforms on the specified XML file or XmlDocument.

## SYNTAX

### Path (Default)

```
Convert-Xml [-Path] <PscxPathInfo[]> [-XsltPath] <PscxPathInfo> [-OutputPath <PscxPathInfo>]
 [-EnableScript] [-ConformanceLevel <ConformanceLevel>] [-EnableDocumentFunction] [-EnableDtd]
 [<CommonParameters>]
```

### Object

```
Convert-Xml [-XsltPath] <PscxPathInfo> -InputObject <psobject> [-OutputPath <PscxPathInfo>]
 [-EnableScript] [-ConformanceLevel <ConformanceLevel>] [-EnableDocumentFunction] [-EnableDtd]
 [<CommonParameters>]
```

### LiteralPath

```
Convert-Xml [-LiteralPath] <PscxPathInfo[]> [-XsltPath] <PscxPathInfo> [-OutputPath <PscxPathInfo>]
 [-EnableScript] [-ConformanceLevel <ConformanceLevel>] [-EnableDocumentFunction] [-EnableDtd]
 [<CommonParameters>]
```

## ALIASES

cvxml

## DESCRIPTION

Performs XSLT transforms on the specified XML file or XmlDocument.
 Use the EnableScript parameter to enable script embedded in the XSLT file.

## EXAMPLES

### Example 1 - Use Convert-Xml

```powershell
Convert-Xml foo.xml foo.xslt
```

Transforms the XML in the input file foo.xml based on the XSLT specified foo.xslt.

### Example 2 - Use Convert-Xml

```powershell
Convert-Xml foo.xml bar.xslt -EnableScript
```

Transforms the XML in the input file foo.xml based on the XSLT specified foo.xslt while enabling embedded script to be processed.

## PARAMETERS

### -ConformanceLevel



```yaml
Type: System.Xml.ConformanceLevel
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

### -EnableDocumentFunction

Enable the document() function in XPath expressions.

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

### -EnableScript

Enable embedded script blocks in the XSLT.

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

### -OutputPath

If set, specifies the path to a file to receive the output.
No characters are interpreted as wildcards.

```yaml
Type: Pscx.Core.IO.PscxPathInfo
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
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -XsltPath

Path to the XSLT file to apply during the transform.

```yaml
Type: Pscx.Core.IO.PscxPathInfo
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
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

### System.String

Returns a System.String value.

## NOTES




## RELATED LINKS

- [Online Version]()
- [Test-Xml]()
- [Format-Xml]()
