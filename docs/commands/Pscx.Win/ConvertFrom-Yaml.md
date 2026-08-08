---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: ConvertFrom-Yaml
---

# ConvertFrom-Yaml

## SYNOPSIS

PSCX Cmdlet: Converts YAML files to object graphs. The object graph leverages largely the dictionary and list native structures.

## SYNTAX

### Path

```
ConvertFrom-Yaml [-Path] <PscxPathInfo[]> [-AllDocuments] [<CommonParameters>]
```

### Object

```
ConvertFrom-Yaml -InputObject <psobject> [-AllDocuments] [<CommonParameters>]
```

### LiteralPath

```
ConvertFrom-Yaml [-LiteralPath] <PscxPathInfo[]> [-AllDocuments] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Converts YAML files to object graphs.
The object graph leverages largely the dictionary and list native structures.

## EXAMPLES

### Example 1 - Use ConvertFrom-Yaml

```powershell
$obj = cat ./file.yml | ConvertFrom-Yaml
```

Converts the YAML content into a PSObject that can be used with dot notation to navigate properties: e.g. $obj.property.name.

### Example 2 - Use ConvertFrom-Yaml

```powershell
ConvertFrom-Yaml -Path /path/to/file.yaml
```

Converts the YAML content into a PSObject, its summary is displayed on the console. The object can be captured and property graph navigated using dot notation

## PARAMETERS

### -AllDocuments



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

YAML string to be converted into object graph.
Input also accepted from pipeline.

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

The literal (string) path of YAML file to parse into object graph

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

The path of YAML file to parse into object graph

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

## NOTES

Path and LiteralPath are mutually exclusive.

Comments are not preserved.


## RELATED LINKS

- [Online Version]()
- [ConvertTo-Yaml]()
