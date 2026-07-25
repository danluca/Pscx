// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using Microsoft.Data.SqlClient;
using System;
using System.Management.Automation;

namespace Pscx.Commands.Database {
    public class SqlCommandBase : PscxCmdlet {
        private string connectionString;

        [Parameter(ParameterSetName = "BuildConnectionString")] public string Server { get; set; } = "localhost";

        [Parameter(ParameterSetName = "BuildConnectionString")] public string UserName { get; set; }

        [Parameter(ParameterSetName = "BuildConnectionString")] public string Password { get; set; }

        [Parameter(ParameterSetName = "BuildConnectionString")]
        [Alias("Database", "Catalog")]
        public string InitialCatalog { get; set; }

        [Parameter(Mandatory = true)] public string Query { get; set; }

        [Parameter(ParameterSetName = "SupplyConnectionString")]
        public string ConnectionString {
            get {
                if (connectionString == null) {
                    connectionString = BuildConnectionString();
                }

                return connectionString;
            }
            set { connectionString = value; }
        }

        protected string CommandText {
            get { return Query; }
        }

        protected SqlConnection CreateConnection() {
            return new SqlConnection(ConnectionString);
        }

        private string BuildConnectionString() {
            if (string.IsNullOrEmpty(UserName) && string.IsNullOrEmpty(Password)) {
                return BuildTrustedConnectionString();
            }

            return BuildStandardSecurityConnectionString();
        }

        private string BuildStandardSecurityConnectionString() {
            return $"Data Source={Server};Initial Catalog={InitialCatalog};User Id={UserName};Password={Password};";
        }

        private string BuildTrustedConnectionString() {
            const string conn = "Server = {0}; Database = {1}; Trusted_Connection = True;";
            return string.Format(conn, Server, InitialCatalog);
        }

        protected string GetCommandDescription() {
            return $"Connection: {ConnectionString}{Environment.NewLine}Command: {Query}";
        }
    }
}