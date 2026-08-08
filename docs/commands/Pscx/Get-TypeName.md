---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Get-TypeName
---

# Get-TypeName

## SYNOPSIS

PSCX Cmdlet: Get-TypeName displays the typename of the input object.

## SYNTAX

### __AllParameterSets

```
Get-TypeName [-InputObject] <psobject> [-FullName] [-PassThru] [<CommonParameters>]
```

## ALIASES

gtn

## DESCRIPTION

Get-TypeName displays the typename of the input object.
Normally you would use Get-Member to     determine this but if you are only interested in the type name     this filter produces much less output.
 Also, since Get-Member     accumulates multiple instances of the same type into a single output     record for that type, you don't get any sense of how many objects of     that type are traversing the pipeline.
 With Get-TypeName, you will     see the type name of *every* object passed into it.
 NOTE: If you     specify any arguments then all pipeline input is ignored.
This is     due to the fact that PowerShell executes the Process function even     if there isn't any input so it is impossible to distinguish between     $null pipeline input and no pipeline input.
 NOTE: the type name is displayed     directly to the host so that it doesn't interfere with pipeline operations.
    If you want the original object to pass thru, use the PassThru parameter.

## EXAMPLES

### Example 1 - Use Get-TypeName

```powershell
Get-TypeName (Get-Date)
```

Displays the typename for the object returned by the Get-Date cmdlet.

### Example 2 - Use Get-TypeName

```powershell
Get-Command Get-* | Get-TypeName
```

Displays the typename for each of the Get cmdlets.

### Example 3 - Use Get-TypeName

```powershell
Get-TypeName $PSVersionTable
```

Displays the typename for each of the $PSVersionTable variable.

### Example 4 - Use Get-TypeName

```powershell
$PSVersionTable | Get-TypeName -PassThru | Foreach {$_.PSVersion}
```

Stick Get-TypeName -PassThru in the middle of a pipeline to observe the object types in the pipeline.

## PARAMETERS

### -FullName

Displays the full type name.

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

The object whose typename you want to know.

```yaml
Type: System.Management.Automation.PSObject
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PassThru

Outputs the original input object and writes the typename to the host.

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

### PSObject

Accepts a PSObject value.

### System.Management.Automation.PSObject

Accepts a System.Management.Automation.PSObject value.

## OUTPUTS

### PSObject

Returns a PSObject value.

### System.Management.Automation.PSObject

Returns a System.Management.Automation.PSObject value.

## NOTES




## RELATED LINKS

- [Online Version]()
