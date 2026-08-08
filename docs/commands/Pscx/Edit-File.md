---
document type: cmdlet
external help file: Pscx.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Edit-File
---

# Edit-File

## SYNOPSIS

PSCX Cmdlet: Edits a file using a regex pattern to find text to be replaced by a specified replacement string.

## SYNTAX

### NoFile (Default)

```
Edit-File [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Path

```
Edit-File [-Path] <PscxPathInfo[]> [-PassThru] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### PathReplace

```
Edit-File [-Path] <PscxPathInfo[]> [-Pattern] <string[]> [-Replacement] <string[]>
 [-Encoding <string>] [-CaseSensitive] [-SimpleMatch] [-SingleString] [-PassThru] [-Force] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

### LiteralPath

```
Edit-File -LiteralPath <PscxPathInfo[]> [-PassThru] [-Force] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

### LiteralPathReplace

```
Edit-File [-Pattern] <string[]> [-Replacement] <string[]> -LiteralPath <PscxPathInfo[]>
 [-Encoding <string>] [-CaseSensitive] [-SimpleMatch] [-SingleString] [-PassThru] [-Force] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## ALIASES

e

## DESCRIPTION

The Edit-File cmdlet modifies the specified files using a search pattern and replacement text.
The search pattern is specified by the Pattern parameter and can be either "simple match" text or a regular expression.
 The replacement text is specified by the Replacement parameter.
 The Edit-File cmdlet can also be used to edit files interactively.
 By default, notepad.exe is used to interactively edit the specified file.
 You can specify an alternate interactive text editor using $Pscx:Preferences['TextEditor] = 'notepad2.exe'.

By default the regex is applied to the file line by line.
You can use the SingleString parameter to load the entire file into memory as a single string.
 With SingleString, the regex is applied to the entire file at once.
 This enables you to specify a regular expression such as '(?s)(<PostBuildEvent>).*?(</PostBuildEvent>)' that spans multiple lines.
 The regular expression mode modifier '(?s)' enables Singleline mode which causes the '.' metacharacter to match every character including newline characters.

One consequence of processing the file using the SingleString parameter is that your regex may have to handle carriage return (\r) characters.
 The regex metacharacter $ matches only newline (\n) and NOT carriage return (\r) characters.
 You need to be aware of this when using the metacharacter $ in Multiline mode to replace the entire contents of a line.
 If you're not careful you can eliminate \r from the newline sequence.
 To avoid this, use an end of line regex positve look-ahead pattern like '(?=\r$)'.

## EXAMPLES

### Example 1 - Use Edit-File

```powershell
Edit-File
```

Starts the editor. Notepad.exe is started unless the PSCX TextEditor preference has been set to another text editor.  You can specify an alternate text editor using $Pscx:Preferences['TextEditor] = 'notepad2.exe'

### Example 2 - Use Edit-File

```powershell
Edit-File $profile
```

Starts the text editor passing the specified file to be opened. Notepad.exe is started unless the PSCX TextEditor preference has been set to another text editor.  You can specify an alternate text editor using $Pscx:Preferences['TextEditor] = 'notepad2.exe'

### Example 3 - Use Edit-File

```powershell
Edit-File Acme\Src\Foo\Foo.csproj -Pattern v4\.0 -Replacement v4.5.1
```

Edits the C# project file replacing v4.0 with v4.5.1

### Example 4 - Use Edit-File

```powershell
Get-ChildItem Acme\Src\*.csproj -Recurse | Edit-File -Pattern v4.0 -Replacement v4.5.1 -Force -SimpleMatch
```

Edits all of the C# project files replacing v4.0 with v4.5.1 and making them writable with the Force parameter.By using the SimpleMatch parameter, you can specify a Pattern that is not interpreted as a regular expression.

### Example 5 - Use Edit-File

```powershell
Get-ChildItem Acme\Src\*.csproj -Recurse | Edit-File -Pattern v4\.0 -Replacement v4.5.1 -Force -PassThru | Set-ReadOnly
```

Edits all of the C# project files replacing v4.0 with v4.5.1 and making them writable with the Force parameter.The PassThru switch causes each file to be passed down the pipeline to the Set-ReadOnly command.

### Example 6 - Use Edit-File

```powershell
$pattern = '(?s)(<PostBuildEvent>).*?(</PostBuildEvent>)'
Get-ChildItem Acme\Src\*.csproj -Recurse | Edit-File -Pattern $pattern -Replacement '$1$2' -SingleString
```

Edits all of the C# project files effectivly removing all text between the opening and closing PostBuildEvent XML tags.Specifying the SingleString parameter loads the file into memory as a single string.  This enables Singleline mode which causes the '.' metacharacter to match newline (\n) characters.  This allows a regex pattern to select text that spans multiple lines.

### Example 7 - Use Edit-File

```powershell
Edit-File site.css -Pattern '#555\s*;' -Replacement '#5f5f5f;' -Encoding ascii
```

The Encoding parameter specifies that the cmdlet writes the file using the specified encoding.

## PARAMETERS

### -CaseSensitive

Makes Pattern matches case-sensitive.
By default, Pattern matches are not case-sensitive.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: PathReplace
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: LiteralPathReplace
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
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

### -Encoding

Specifies the type of character encoding used to write to the file.
Valid values are "Unicode", "UTF7", "UTF8", "UTF32", "ASCII", "BigEndianUnicode", "Default", and "OEM".
 By default, the cmdlet uses the encoding it detected while reading the file.

"Default" uses the encoding of the system's current ANSI code page.

"OEM" uses the current original equipment manufacturer code page identifier for the operating system.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: PathReplace
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: LiteralPathReplace
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

Allows the cmdlet to edit files that are read-only by making them writable.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Path
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: LiteralPath
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: PathReplace
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: LiteralPathReplace
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -LiteralPath

Specifies a path to the file to edit.
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
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
- Name: LiteralPathReplace
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PassThru

Passes a FileInfo object representing the file to the pipeline.
By default, this cmdlet does not generate any output.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Path
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: LiteralPath
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: PathReplace
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: LiteralPathReplace
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

Specifies the path to the file to edit.
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
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
- Name: PathReplace
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Pattern

Specifies the text to replace.
Type a string or regular expression.
If you type a string, use the SimpleMatch parameter.
To learn about regular expressions, see about_Regular_Expressions.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: PathReplace
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: LiteralPathReplace
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Replacement

The replacement string to use for the specified pattern.
 You can use regular expression substitutions in the replacement string.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: PathReplace
  Position: 2
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: LiteralPathReplace
  Position: 2
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -SimpleMatch

Uses a simple match rather than a regular expression match.
In a simple match, Edit-File searches the file for the text in the Pattern parameter.
It does not interpret the value of the Pattern parameter as a regular expression statement.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: PathReplace
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: LiteralPathReplace
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -SingleString

Processes the file's contents as a single string.
 By default, the cmdlet processes the file one line at at time.
 Using SingleString enables regex patterns to select text that spans multiple lines.
 In order to take take advantage of SingleString you will likely need to use the Singleline mode modifier (?s), Multiline mode modifier (?m) or both (?sm).

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: PathReplace
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: LiteralPathReplace
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

### System.String

Accepts a System.String value.

### Pscx.Core.IO.PscxPathInfo

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

### Pscx.Core.IO.PscxPathInfo[]

Accepts a Pscx.Core.IO.PscxPathInfo[] value.

## OUTPUTS

### None or a System.IO.FileInfo object representing the file.

Returns a None or a System.IO.FileInfo object representing the file.
value.

## NOTES




## RELATED LINKS

- [Online Version]()
