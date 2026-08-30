using Microsoft.PowerShell.Commands;
using Pscx.Core.IO;
using System;
using System.ComponentModel;
using System.IO;
using System.Management.Automation;

namespace Pscx.Commands.Text
{
    [OutputType(typeof(TextFileInfo))]
    [Cmdlet(VerbsCommon.Get, PscxNouns.TextFileInfo, DefaultParameterSetName = "Path")]
    [Description("Reports a text file's encoding, byte-order mark, line endings, and final-newline state.")]
    [ProviderConstraint(typeof(FileSystemProvider))]
    [RelatedLink(typeof(ConvertToUnixLineEndingCommand))]
    [RelatedLink(typeof(ConvertToWindowsLineEndingCommand))]
    public sealed class GetTextFileInfoCommand : PscxPathCommandBase
    {
        protected override void OnValidatePath(IPscxPathSettings settings)
        {
            settings.ShouldExist = true;
            settings.PathType = PscxPathType.Leaf;
        }

        protected override void OnValidateLiteralPath(IPscxPathSettings settings)
        {
            settings.ShouldExist = true;
            settings.PathType = PscxPathType.Leaf;
        }

        protected override void ProcessPath(PscxPathInfo pscxPath)
        {
            try
            {
                WriteObject(TextFileOperations.AnalyzeFile(pscxPath.ProviderPath));
            }
            catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException)
            {
                WriteError(new ErrorRecord(ex, "TextFileAnalysisError", ErrorCategory.ReadError, pscxPath.ProviderPath));
            }
        }
    }
}
