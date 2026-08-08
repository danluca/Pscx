---
document type: cmdlet
external help file: Pscx.Win.dll-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Pscx.Win
ms.date: 08/06/2026
PlatyPS schema version: 2024-05-01
title: Invoke-AdoCommand
---

# Invoke-AdoCommand

## SYNOPSIS

PSCX Cmdlet: Execute a SQL query against an ADO.NET datasource.

## SYNTAX

### string (Default)

```
Invoke-AdoCommand [-ProviderName] <string> [-ConnectionString] <string> [-CommandText] <string>
 [[-CommandParameters] <hashtable>] [-NonQuery] [-AsDataSet] [-AsPSObject]
 [-CommandType <CommandType>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### object

```
Invoke-AdoCommand [-ProviderName] <string> [-Connection] <DbConnection> [-CommandText] <string>
 [[-CommandParameters] <hashtable>] [-NonQuery] [-AsDataSet] [-AsPSObject]
 [-CommandType <CommandType>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### properties

```
Invoke-AdoCommand [-ProviderName] <string> [-ConnectionProperties] <hashtable>
 [-CommandText] <string> [[-CommandParameters] <hashtable>] [-NonQuery] [-AsDataSet] [-AsPSObject]
 [-CommandType <CommandType>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### simple

```
Invoke-AdoCommand [-ProviderName] <string> [-CommandText] <string>
 [[-CommandParameters] <hashtable>] [-NonQuery] [-AsDataSet] [-AsPSObject]
 [-CommandType <CommandType>] [-Server <string>] [-UserName <string>] [-Password <string>]
 [-Database <string>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

None

## DESCRIPTION

Execute a SQL query against an ADO.NET datasource.

## EXAMPLES

### Example 1 - Use Invoke-AdoCommand

```powershell
$connection = Get-AdoProvider oracle | Get-AdoConnection -server orcl02 -username scott -password -tiger
          invoke-adocommand -connection $connection -commandtext "select * from foo"
```

This example fetches the oracle client provider and pipes it to Get-AdoConnection. Using this technique
          means you don't have to know the specifics of any given database's connection string properties.

### Example 2 - Use Invoke-AdoCommand

```powershell
$conn = 'Data Source=.\SQLEXPRESS;Initial Catalog=pubs;Integrated Security=SSPI'
              $ds = Invoke-AdoCommand -ProviderName SqlClient -ConnectionString $conn -CommandText 'Select * from Authors' -AsDataSet
              $ds.Tables

              au_id    : 172-32-1176
              au_lname : White
              au_fname : Johnson
              ...
```

This example queries the pubs database for all authors on the current machine's SQLEXPRESS database instance.

## PARAMETERS

### -AsDataSet

If specified returns the result as an ADO.NET DataSet.

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

### -AsPSObject



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

### -CommandParameters

The parameters of the Transact-SQL statement or stored procedure.
The default is an empty collection.

```yaml
Type: System.Collections.Hashtable
DefaultValue: ''
SupportsWildcards: false
Aliases:
- Parameters
ParameterSets:
- Name: (All)
  Position: 3
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -CommandText

The Transact-SQL statement, table name or stored procedure to execute at the data source.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases:
- Query
- Sql
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -CommandType

Specifies the type of command.
 Valid values are StoredProcedure, TableDirect and Text.
 The default value is Text.

```yaml
Type: System.Data.CommandType
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

### -Connection

The connection object used in lieu of a connection string.
 This object is created using the
                Get-AdoConnection cmdlet.

```yaml
Type: System.Data.Common.DbConnection
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: object
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ConnectionProperties

Accepts a hashtable of one or more common connection properties such as Server, User, Password and Database.

```yaml
Type: System.Collections.Hashtable
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: properties
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ConnectionString

The connecion string required to connect to the database.
 For help with connection strings see
              the following link - http://msdn.microsoft.com/en-us/library/ms254500.aspx.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: string
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Database

The name of the current database or the database to be used after a connection is opened.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: simple
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -NonQuery

Executes a command returning the number of rows affected.
 If specified then -AsDataSet is ignored.

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

### -Password

The password to use when connecting to the target server.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: simple
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ProviderName

The name of the desired .NET data provider.
Typical values are System.Data.SqlClient, System.Data.OleDb,
                System.Data.Odbc and System.Data.OracleClient.
Accepts pipeline input from Get-AdoProvider command.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Server

The name of the host or named instance (with MSSQL) to connect to.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: simple
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -UserName

The username to use when connecting to the target server.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: simple
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

## OUTPUTS

### System.Data.DataSet

Returns a System.Data.DataSet value.

### System.Data.Common.DbDataReader

Returns a System.Data.Common.DbDataReader value.

## NOTES

The typical problem encountered when using the ConnectionString property is getting the connection string right.
            See the following link for help with connection strings - http://msdn.microsoft.com/en-us/library/ms254500.aspx.
            For this reason, this Cmdlet uses the built-in .NET data factory classes when using the ConnectionProperties
            parameter or the individual connection property parameters.
Thankfully, you don't need to know the specifics
            of a support database's connection string properties.
The Server, Username, Password and Database properties are
            automatically translated to the target database's format.


## RELATED LINKS

- [Online Version]()
