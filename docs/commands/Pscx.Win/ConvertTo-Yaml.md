---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: ConvertTo-Yaml
---

# ConvertTo-Yaml

## SYNOPSIS

PSCX Cmdlet: Converts object graphs into YAML string. The output can be listed on the console or saved into a yml file.

## SYNTAX

### Object

```
ConvertTo-Yaml [-InputObject] <psobject> [[-OutputPath] <PscxPathInfo>] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Converts object graphs into YAML string.
The output can be listed on the console or saved into a yml file.

## EXAMPLES

### Example 1 - Use ConvertTo-Yaml

```powershell
cat ./file.yml | ConvertFrom-Yaml | ConvertTo-Yaml
```

Converts the YAML content parsed into a PSObject graph, back into YAML content. Note in this process the comments are not preserved.

### Example 2 - Use ConvertTo-Yaml

```powershell
ConvertTo-Yaml $objGraph -OutputPath /path/to/file.yaml
```

Converts the PSObject graph into YAML content and save it to the file path provided

## PARAMETERS

### -InputObject

object graph to be converted into YAML string.
Input also accepted from pipeline.

```yaml
Type: System.Management.Automation.PSObject
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Object
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -OutputPath

Optional - the path of YAML file to save the serialized object graph.
If not specified, the serialized YAML is sent to the console.

```yaml
Type: Pscx.Core.IO.PscxPathInfo
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
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

### System.Management.Automation.PSObject

Accepts a System.Management.Automation.PSObject value.

## OUTPUTS

## NOTES

Using the OutputPath parameter is faster than using 'set-content -enc byte foo.dll' to write the output to a file.

Parent directories are created automatically - if they don't exist - for the OutputPath

An existing OutputPath file cannot be overwritten


## RELATED LINKS

- [Online Version]()
- [ConvertFrom-Yaml]()
