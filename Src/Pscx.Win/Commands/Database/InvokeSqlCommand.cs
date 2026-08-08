// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using Microsoft.Data.SqlClient;
using System;
using System.ComponentModel;
using System.Data;
using System.Management.Automation;

namespace Pscx.Commands.Database {
    [Cmdlet(PscxWinVerbs.Invoke, PscxWinNouns.SqlCommand, DefaultParameterSetName = "BuildConnectionString", SupportsShouldProcess = true)]
    [Description("Invokes sql commands on Sql Server database")]
    public class InvokeSqlCommand : SqlCommandBase {
        protected override void ProcessRecord() {
            try {
                if (!ShouldProcess(GetCommandDescription())) {
                    return;
                }

                using var connection = CreateConnection();
                if (connection.State != ConnectionState.Open) {
                    connection.Open();
                }

                using var command = new SqlCommand(CommandText, connection);
                WriteObject(command.ExecuteNonQuery());
            } catch (Exception ex) {
                WriteError(new ErrorRecord(ex, "InvokeSqlCommandFailed", ErrorCategory.NotSpecified, null));
            }
        }
    }
}