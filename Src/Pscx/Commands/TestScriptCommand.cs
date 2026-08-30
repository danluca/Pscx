//---------------------------------------------------------------------
// Author: Keith Hill
//
// Description: Class to implement the Test-Script cmdlet.
//
// Creation Date: Sept 27, 2009
//---------------------------------------------------------------------
using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Text;
using Microsoft.PowerShell.Commands;
using Pscx.Core.IO;
using System.ComponentModel;

namespace Pscx.Commands
{
    [Cmdlet(VerbsDiagnostic.Test, PscxNouns.Script, DefaultParameterSetName = ParameterSetPath), Description("Test script for validity")]
    [OutputType(typeof(bool), typeof(ScriptTestResult))]
    [ProviderConstraint(typeof(FileSystemProvider))]
    public class TestScriptCommand : PscxInputObjectPathCommandBase
    {
        [Parameter]
        [ValidateCount(1, 2)]
        public new int[] Context { get; set; }

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        protected override PscxInputObjectPathSettings InputSettings
        {
            get
            {
                PscxInputObjectPathSettings settings = base.InputSettings;
                settings.ProcessDirectoryInfoAsPath = false;
                return settings;
            }
        }

        protected override void BeginProcessing()
        {
            RegisterInputType<string>(str => TestScript(str, null));

            // Dont throw on directories, just ignore them
            IgnoreInputType<DirectoryInfo>();

            base.BeginProcessing();
        }

        protected override void ProcessPath(PscxPathInfo pscxPath)
        {
            FileHandler.ProcessRead(pscxPath.ProviderPath, delegate(Stream stream)
            {
                using (var streamReader = new StreamReader(stream))
                {
                    string script = streamReader.ReadToEnd();
                    TestScript(script, pscxPath.ToPathInfo().Path);
                }
            });
        }

        private void TestScript(string script, string path)
        {
            Token[] tokens;
            ParseError[] parseErrors;
            Parser.ParseInput(script, path ?? string.Empty, out tokens, out parseErrors);
            var result = new ScriptTestResult(path, parseErrors);
            if (!result.IsValid && !PassThru)
            {
                foreach (var parseError in parseErrors)
                {
                    var strBld = new StringBuilder();

                    var errorMessage = 
                        String.Format("Parse error on line:{0} char:{1} - {2}",
                                      parseError.Extent.StartLineNumber, parseError.Extent.StartColumnNumber,
                                      parseError.Message);
                    strBld.AppendLine(errorMessage);
                    if (Context != null)
                    {
                        string[] lines = script.Split('\n');
                        for (int i = 0; i < lines.Length; i++)
                        {
                            lines[i] = lines[i].TrimEnd();
                        }

                        int startLine = parseError.Extent.StartLineNumber;
                        int start = Math.Max(1, startLine - Context[0]);
                        int numLinesAfter = (Context.Length == 2) ? Context[1] : Context[0];
                        int endLine = Math.Min(lines.Length, startLine + numLinesAfter);
                        
                        // Create format message
                        string filename = "";
                        if (!String.IsNullOrEmpty(path))
                        {
                            filename = System.IO.Path.GetFileName(path) + ":";
                        }
                        string formatMsg = String.Format("{{0,1}} {0}{{1}}: {{2}}", filename);

                        // Display context lines before erroring line
                        for (int i = start; i < startLine; i++)
                        {
                            strBld.AppendFormat(formatMsg, "", i, lines[i-1]);
                            strBld.AppendLine();
                        }

                        // Display erroring line
                        string badLine = lines[startLine - 1];
                        int startCol = Math.Max(1, parseError.Extent.StartColumnNumber);
                        startCol = Math.Min(badLine.Length + 1, startCol);
                        badLine = badLine.Insert(startCol - 1, "<<<< ");
                        strBld.AppendFormat(formatMsg, ">", startLine, badLine);
                        strBld.AppendLine();

                        // Display context lines after erroring line
                        for (int i = startLine + 1; i <= endLine; i++)
                        {
                            strBld.AppendFormat(formatMsg, "", i, lines[i - 1]);
                            strBld.AppendLine();
                        }
                    }

                    WriteWarning(strBld.ToString());
                }
            }

            WriteObject(PassThru ? result : result.IsValid);
        }
    }
}
