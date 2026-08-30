//---------------------------------------------------------------------
// Author: Keith Hill, jachymko
//
// Description: Class to implement the Convet-LineEnding cmdlet which
//              converts line-endings to either Windows \r\n, Unix \n
//              or MacOs9 \r.
//
// Creation Date: Nov 12, 2006
//---------------------------------------------------------------------

using Pscx.Core.IO;
using System;
using System.IO;
using System.Management.Automation;

namespace Pscx.Commands.Text
{
    public static class LineEnding
    {
        public const string Windows = "\r\n";
        public const string Unix    = "\n";
        public const string MacOs9  = "\r";
    }

    /// <summary>
    /// Abstract class for "line ending" conversion cmdlets.    
    /// <remarks>Derived Cmdlets should be constrained to the FileSystemProvider using a <see cref="ProviderConstraintAttribute"/></remarks>
    /// </summary>
    public abstract class ConvertToLineEndingBaseCommand : PscxPathCommandBase
    {
        private string _destination;
        private StringEncodingParameter _encoding;
        private SwitchParameter _force;
        private SwitchParameter _noClobber;

        [Parameter(Position = 1,
                   HelpMessage="Destination to write the converted file. If the destination is a directory, then the file is written to the directory using the same name.")]
        public string Destination
        {
            get { return _destination; }
            set { _destination = value; }
        }

        [ValidateNotNullOrEmpty]
        [Parameter(Position = 2, HelpMessage="Encoding used to write the output file. By default the encoding of the input file is used.  Valid values are: unicode, utf7, utf8, utf32, ascii and bigendianunicode")]
        public StringEncodingParameter Encoding
        {
            get { return _encoding; }
            set { _encoding = value; }
        }

        [Parameter(HelpMessage = "Overwrite any existing readonly file.")]
        public SwitchParameter Force
        {
            get { return _force; }
            set { _force = value; }
        }

        [Parameter(HelpMessage = "Specifies not to overwrite any existing file.")]
        public SwitchParameter NoClobber
        {
            get { return _noClobber; }
            set { _noClobber = value; }
        }

        [Parameter(HelpMessage = "Controls whether the converted file preserves, adds, or removes trailing line endings.")]
        public FinalNewlineMode FinalNewline { get; set; } = FinalNewlineMode.Preserve;

        [Parameter(HelpMessage = "Reports whether conversion is needed without writing a file.")]
        public SwitchParameter Check { get; set; }

        protected abstract TextFileLineEndingKind TargetLineEnding { get; }

        protected override void BeginProcessing()
        {
            base.BeginProcessing();

            if (!Check && string.IsNullOrWhiteSpace(_destination))
            {
                ThrowTerminatingError(new ErrorRecord(
                    new PSArgumentException("Destination is required unless -Check is specified."),
                    "DestinationRequired",
                    ErrorCategory.InvalidArgument,
                    _destination));
            }
            if (!string.IsNullOrWhiteSpace(_destination) && WildcardPattern.ContainsWildcardCharacters(_destination))
            {
                ArgumentException ex = new ArgumentException("Illegal characters in destination path");
                ThrowTerminatingError(new ErrorRecord(ex, "IllegalCharsInPath", ErrorCategory.InvalidArgument, _destination));
            }
            if (!string.IsNullOrWhiteSpace(_destination))
            {
                _destination = GetUnresolvedProviderPathFromPSPath(_destination);
            }
        }

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
                string filePath = pscxPath.ProviderPath;
                TextFileInfo info = TextFileOperations.AnalyzeFile(filePath);
                System.Text.Encoding outputEncoding = _encoding.IsPresent ? _encoding.ToEncoding() : null;
                if (_encoding.IsPresent && outputEncoding == null)
                {
                    throw new ArgumentException($"Unsupported encoding '{_encoding}'.", nameof(Encoding));
                }
                byte[] convertedBytes = TextFileOperations.ConvertLineEndings(
                    info,
                    TargetLineEnding,
                    FinalNewline,
                    outputEncoding);
                string outputPath = GetOutputPath(filePath);
                bool needsConversion = TextFileOperations.NeedsConversion(info, convertedBytes);
                if (Check)
                {
                    WriteObject(new LineEndingCheckResult(
                        info,
                        outputPath,
                        TargetLineEnding,
                        FinalNewline,
                        needsConversion));
                    return;
                }
                if (!ShouldProcess(outputPath, $"Convert line endings to {TargetLineEnding}"))
                {
                    return;
                }

                using Stream output = OpenOutputStream(outputPath);
                output?.Write(convertedBytes, 0, convertedBytes.Length);
            }
            catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException ||
                                       ex is InvalidDataException || ex is ArgumentException)
            {
                WriteError(new ErrorRecord(ex, "LineEndingConversionError", ErrorCategory.InvalidData, pscxPath.ProviderPath));
            }
        }

        private string GetOutputPath(string filePath)
        {
            if (string.IsNullOrWhiteSpace(_destination))
            {
                return filePath;
            }

            string outputPath = _destination;
            if (Directory.Exists(outputPath))
            {
                string filename = System.IO.Path.GetFileName(filePath);
                outputPath = System.IO.Path.Combine(outputPath, filename);
            }

            return outputPath;
        }

        private Stream OpenOutputStream(string outputPath)
        {
            return FileHandler.OpenWrite(outputPath, _noClobber.IsPresent, _force.IsPresent);
        }
    }
}
