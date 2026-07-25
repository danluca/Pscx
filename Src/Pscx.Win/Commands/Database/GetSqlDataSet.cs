// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using Microsoft.Data.SqlClient;
using System;
using System.ComponentModel;
using System.Data;
using System.Management.Automation;

namespace Pscx.Commands.Database {
    [Cmdlet(VerbsCommon.Get, PscxWinNouns.SqlDataSet, SupportsShouldProcess = true)]
    [Description("Query and retrieve SQL data set")]
    public class GetSqlDataSet : SqlCommandBase {
        protected override void ProcessRecord() {
            try {
                if (!ShouldProcess(GetCommandDescription())) {
                    return;
                }

                DataSet dataSet = new();
                SqlDataAdapter adapter = new(Query, CreateConnection());
                adapter.Fill(dataSet);
                WriteObject(dataSet);
            } catch (Exception ex) {
                WriteError(new ErrorRecord(ex, "GetSqlDataSetFailed", ErrorCategory.NotSpecified, null));
            }
        }
    }
}