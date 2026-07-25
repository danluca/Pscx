// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using Microsoft.PowerShell.Commands;
using Pscx.Core;
using Pscx.Core.IO;
using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Management.Automation;
using System.Security;
using System.Text;
using System.Text.RegularExpressions;

namespace Pscx.Commands.IO {
    [Cmdlet(PscxVerbs.Edit, PscxNouns.File, DefaultParameterSetName = ParameterSetNoFile, SupportsShouldProcess = true)]
    [Description("Edit file with configured editor - VSCode, Notepad++/TextMate, default for OS")]
    [ProviderConstraint(typeof(FileSystemProvider))]
    public class EditFileCommand : PscxPathCommandBase {
        private const string ParameterSetPathReplace = "PathReplace";
        private const string ParameterSetLiteralPathReplace = "LiteralPathReplace";
        private const string ParameterSetNoFile = "NoFile";
        private const string TextEditorKey = "TextEditor";
        private readonly string _defaultEditor;
        private string _editor;
        private bool _hasBeenInitialized;
        private string _patternArrayAsString;

        private Regex[] _regexes;
        private string _replacementArrayAsString;

        /// <summary>
        ///     Initializes the editor with sensible default for the operating system
        /// </summary>
        public EditFileCommand() {
            _defaultEditor = PscxContext.DefaultTextEditor;
            _editor = _defaultEditor;
        }

        [Parameter(ParameterSetName = ParameterSetPath, Position = 0, Mandatory = true, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true,
            HelpMessage = "Specifies the path to the file to process. Wildcard syntax is allowed."
        )]
        [Parameter(ParameterSetName = ParameterSetPathReplace, Position = 0, Mandatory = true, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true,
            HelpMessage = "Specifies the path to the file to process. Wildcard syntax is allowed."
        )]
        [AcceptsWildcards(true)]
        [PscxPath(Tag = "PathCommand.Path")]
        public override PscxPathInfo[] Path {
            get { return _paths; }
            set { _paths = value; }
        }

        [Parameter(ParameterSetName = ParameterSetLiteralPath, Mandatory = true, ValueFromPipeline = false, ValueFromPipelineByPropertyName = true,
            HelpMessage =
                "Specifies a path to the item. The value of -LiteralPath is used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters, enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any characters as escape sequences."
        )]
        [Parameter(ParameterSetName = ParameterSetLiteralPathReplace, Mandatory = true, ValueFromPipeline = false, ValueFromPipelineByPropertyName = true,
            HelpMessage =
                "Specifies a path to the item. The value of -LiteralPath is used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters, enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any characters as escape sequences."
        )]
        [Alias("PSPath")]
        [PscxPath(NoGlobbing = true, Tag = "PathCommand.LiteralPath")]
        public override PscxPathInfo[] LiteralPath {
            get { return _literalPaths; }
            set { _literalPaths = value; }
        }

        [Parameter(Mandatory = true, Position = 1, ParameterSetName = ParameterSetPathReplace)]
        [Parameter(Mandatory = true, Position = 1, ParameterSetName = ParameterSetLiteralPathReplace)]
        [ValidateNotNull]
        [AllowEmptyString]
        public string[] Pattern { get; set; }

        [Parameter(Mandatory = true, Position = 2, ParameterSetName = ParameterSetPathReplace)]
        [Parameter(Mandatory = true, Position = 2, ParameterSetName = ParameterSetLiteralPathReplace)]
        [ValidateNotNull]
        [AllowEmptyString]
        public string[] Replacement { get; set; }

        [Parameter(ParameterSetName = ParameterSetPathReplace)]
        [Parameter(ParameterSetName = ParameterSetLiteralPathReplace)]
        [ValidateSet("unknown", "string", "unicode", "bigendianunicode", "utf8", "utf7", "utf32", "ascii", "default", "oem")]
        [ValidateNotNullOrEmpty]
        public string Encoding { get; set; }

        [Parameter(ParameterSetName = ParameterSetPathReplace)]
        [Parameter(ParameterSetName = ParameterSetLiteralPathReplace)]
        public SwitchParameter CaseSensitive { get; set; }

        [Parameter(ParameterSetName = ParameterSetPathReplace)]
        [Parameter(ParameterSetName = ParameterSetLiteralPathReplace)]
        public SwitchParameter SimpleMatch { get; set; }

        [Parameter(ParameterSetName = ParameterSetPathReplace)]
        [Parameter(ParameterSetName = ParameterSetLiteralPathReplace)]
        public SwitchParameter SingleString { get; set; }

        [Parameter(ParameterSetName = ParameterSetPath)]
        [Parameter(ParameterSetName = ParameterSetLiteralPath)]
        [Parameter(ParameterSetName = ParameterSetPathReplace)]
        [Parameter(ParameterSetName = ParameterSetLiteralPathReplace)]
        public SwitchParameter PassThru { get; set; }

        [Parameter(ParameterSetName = ParameterSetPath)]
        [Parameter(ParameterSetName = ParameterSetLiteralPath)]
        [Parameter(ParameterSetName = ParameterSetPathReplace)]
        [Parameter(ParameterSetName = ParameterSetLiteralPathReplace)]
        public SwitchParameter Force { get; set; }

        // This used to be BeginProcessing override but the ParameterSetName property started lying to me.
        private void MyBeginProcessing() {
            _hasBeenInitialized = true;

            if (ParameterSetName == ParameterSetPathReplace || ParameterSetName == ParameterSetLiteralPathReplace) {
                if (Pattern.Length != Replacement.Length) {
                    ErrorHandler.ThrowIncompatibleArrayParameters("Pattern", "Replacement", "The array length must be the same for both parameters.");
                }

                var patternStrBld = new StringBuilder();
                var replacementStrBld = new StringBuilder();

                _regexes = new Regex[Pattern.Length];
                for (int i = 0; i < Pattern.Length; i++) {
                    string pattern = SimpleMatch ? Regex.Escape(Pattern[i]) : Pattern[i];
                    RegexOptions regexOptions = CaseSensitive ? RegexOptions.None : RegexOptions.IgnoreCase;
                    _regexes[i] = new Regex(pattern, regexOptions);

                    if (i != 0) {
                        patternStrBld.Append(",");
                        replacementStrBld.AppendFormat(",");
                    }

                    patternStrBld.AppendFormat("'{0}'", Pattern[i]);
                    replacementStrBld.AppendFormat("'{0}'", Replacement[i]);
                }

                _patternArrayAsString = patternStrBld.ToString();
                _replacementArrayAsString = replacementStrBld.ToString();
            } else if (PscxContext.Instance.Preferences.ContainsKey(TextEditorKey)) {
                object textEditorPath = PscxContext.Instance.Preferences[TextEditorKey];
                if (textEditorPath == null) {
                    _editor = _defaultEditor;
                    return;
                }

                // Unwrap if a PSObject
                if (textEditorPath is PSObject psObject) {
                    textEditorPath = psObject.BaseObject;
                }

                if (textEditorPath is string editorPath) {
                    _editor = editorPath;
                } else if (textEditorPath is FileInfo fileInfo) {
                    _editor = fileInfo.FullName;
                } else {
                    _editor = textEditorPath.ToString();
                }

                //Process.Start is rather finicky with the location of the process - especially if the process is a batch file (e.g. code.cmd)
                //enforce externally configured editors to provide full path to the application otherwise use default editor
                if (!File.Exists(_editor)) {
                    _editor = _defaultEditor;
                }
            }
        }

        protected override PscxPathInfo[] GetSelectedPathParameter(string parameterSetName) {
            return ParameterSetName == ParameterSetPath || ParameterSetName == ParameterSetPathReplace
                ? _paths
                : _literalPaths;
        }

        protected override bool OnValidatePscxPath(string parameterName, IPscxPathSettings settings) {
            if (parameterName == ParameterSetLiteralPath || parameterName == ParameterSetLiteralPathReplace) {
                // allow derived classes to tweak literal path validation
                OnValidateLiteralPath(settings);
            } else if (parameterName == ParameterSetPath || parameterName == ParameterSetPathReplace) {
                // allow derived classes to tweak path validation
                OnValidatePath(settings);
            }

            return base.OnValidatePscxPath(parameterName, settings);
        }

        protected override PscxPathInfo[] GetResolvedPscxPathInfos(string path) {
            return GetPscxPathInfos(new[] { path }, ParameterSetName == ParameterSetLiteralPath || ParameterSetName == ParameterSetLiteralPathReplace);
        }

        protected override void ProcessRecord() {
            if (!_hasBeenInitialized) {
                MyBeginProcessing();
            }

            if (ParameterSetName != ParameterSetNoFile) {
                base.ProcessRecord();
            }
        }

        protected override void ProcessPath(PscxPathInfo pscxPath) {
            if (ParameterSetName == ParameterSetNoFile) {
                return;
            }

            //enclose path in double quotes to account for space or other characters that need escaped
            string path = $"\"{pscxPath.ProviderPath}\"";

            try {
                if (ParameterSetName == ParameterSetPath || ParameterSetName == ParameterSetLiteralPath) {
                    if (ShouldProcess(pscxPath.ProviderPath, "Edit-File interactive")) {
                        if (Force) {
                            MakeFileWritable(path);
                        }

                        Process.Start(_editor, path);
                    }
                } else {
                    if (ShouldProcess(pscxPath.ProviderPath, "Edit-File replacing pattern " + _patternArrayAsString + " with " + _replacementArrayAsString)) {
                        if (Force) {
                            MakeFileWritable(path);
                        }

                        // Get threshold value to determine whether to use backing file instead of in MemoryStream to contain
                        // the modified file contents until they can be copied back to the source file (after regex processing).
                        var editFileBackingFileThresholdPreference = PscxContext.Instance.Preferences[PscxContext.EditFileBackingFileThreshold];
                        int backingFileThreshold = editFileBackingFileThresholdPreference is int backingFileThresholdPreference
                            ? backingFileThresholdPreference
                            : PscxContext.EditFileBackingFileThresholdDefaultValue;

                        var fileData = new FileData(path);
                        if (SingleString) {
                            EditFileAsSingleString(fileData);
                        } else if (fileData.Length >= backingFileThreshold) {
                            EditFileByLineFileBacked(fileData);
                        } else {
                            EditFileByLineMemoryBacked(fileData);
                        }
                    }
                }

                if (PassThru) {
                    Collection<PSObject> results = SessionState.InvokeProvider.Item.Get(path);
                    if (results.Count > 0) {
                        WriteObject(results[0]);
                    }
                }
            } catch (FileNotFoundException ex) {
                WriteError(new ErrorRecord(ex, "FileError", ErrorCategory.ObjectNotFound, path));
            } catch (SecurityException ex) {
                WriteError(new ErrorRecord(ex, "FileError", ErrorCategory.SecurityError, path));
            } catch (UnauthorizedAccessException ex) {
                WriteError(new ErrorRecord(ex, "FileError", ErrorCategory.SecurityError, path));
            } catch (PipelineStoppedException) {
                throw;
            } catch (Exception ex) {
                WriteError(new ErrorRecord(ex, "FileError", ErrorCategory.NotSpecified, path));
            }
        }

        protected override void EndProcessing() {
            if (ParameterSetName == ParameterSetNoFile) {
                Process.Start(_editor);
            }

            base.EndProcessing();
        }

        private void EditFileAsSingleString(FileData fileData) {
            using (var fileStream = new FileStream(fileData.Path, FileMode.Open, FileAccess.ReadWrite, FileShare.Read)) {
                if (Encoding == null) {
                    WriteVerboseEncodingInfo(fileData);
                }

                Encoding encoding = Encoding != null ? EncodingConversion.Convert(this, Encoding, "Encoding") : fileData.Encoding;
                var streamReader = new StreamReader(fileStream, encoding);
                var content = streamReader.ReadToEnd();

                for (int i = 0; i < _regexes.Length; i++) {
                    content = _regexes[i].Replace(content, Replacement[i]);
                }

                streamReader.DiscardBufferedData();
                fileStream.SetLength(0L);
                var streamWriter = new StreamWriter(fileStream, encoding);
                streamWriter.Write(content);
                streamWriter.Flush();
            }
        }

        private void EditFileByLineMemoryBacked(FileData fileData) {
            const int lohThreshold = 85000;
            int memoryStreamCapacity;

            // If file length is within 10% of LOH size or higher, jump up to next order ot magnitude
            // to limit the number of different sized LOH segments created.  Keeping in mind that the 
            // edit operation can make the file larger.
            if (fileData.Length >= lohThreshold / 1.2) {
                memoryStreamCapacity = (int)Math.Pow(10, (int)Math.Ceiling(Math.Log10(fileData.Length)));
            } else {
                memoryStreamCapacity = (int)Math.Max(10, fileData.Length);
            }

            using (var sourceFileStream = new FileStream(fileData.Path, FileMode.Open, FileAccess.ReadWrite, FileShare.Read))
            using (var editResultsStream = new MemoryStream(memoryStreamCapacity)) {
                EditFileByLineImpl(fileData, sourceFileStream, editResultsStream);
            }
        }

        private void EditFileByLineFileBacked(FileData fileData) {
            string tempPath = System.IO.Path.GetTempFileName();
            WriteVerbose(string.Format("Edit-File using temp file '{0}' for '{1}'", tempPath, fileData.Path));

            try {
                using (var sourceFileStream = new FileStream(fileData.Path, FileMode.Open, FileAccess.ReadWrite, FileShare.Read))
                using (var editResultsStream = new FileStream(tempPath, FileMode.Open, FileAccess.ReadWrite)) {
                    EditFileByLineImpl(fileData, sourceFileStream, editResultsStream);
                }
            } finally {
                File.Delete(tempPath);
            }
        }

        private void EditFileByLineImpl(FileData fileData, FileStream sourceFileStream, Stream editResultsStream) {
            if (Encoding == null) {
                WriteVerboseEncodingInfo(fileData);
            }

            Encoding writeEncoding = Encoding != null ? EncodingConversion.Convert(this, Encoding, "Encoding") : fileData.Encoding;
            var streamReader = new StreamReader(sourceFileStream);
            var streamWriter = new StreamWriter(editResultsStream, writeEncoding);

            string prevLine = null;
            string line;
            while ((line = streamReader.ReadLine()) != null) {
                if (prevLine != null) {
                    streamWriter.WriteLine(prevLine);
                }

                prevLine = line;
                for (int i = 0; i < _regexes.Length; i++) {
                    prevLine = _regexes[i].Replace(prevLine, Replacement[i]);
                }
            }

            // Use Write or WriteLine on last line depending on whether the source file ends in a newline.
            if (fileData.LastLineEndsWithNewline) {
                streamWriter.WriteLine(prevLine ?? "");
            } else {
                streamWriter.Write(prevLine ?? "");
            }

            streamWriter.Flush();

            // Resets results stream and source file stream to beginning to prep for copy operation.
            streamReader.DiscardBufferedData();
            sourceFileStream.SetLength(0L);
            editResultsStream.Seek(0L, SeekOrigin.Begin);

            editResultsStream.CopyTo(sourceFileStream);
            sourceFileStream.Flush();
        }

        private void MakeFileWritable(string path) {
            var fileInfo = new FileInfo(path);
            if (fileInfo.IsReadOnly) {
                WriteVerbose("Edit-File -Force specified, making readonly file writable: " + path);
                fileInfo.IsReadOnly = false;
            }
        }

        private void WriteVerboseEncodingInfo(FileData fileData) {
            var msg = string.Format("Edit-File detected encoding of {0} with {1}BOM for '{2}'{3}",
                fileData.Encoding.EncodingName,
                fileData.EncoderEmitsUtf8Identifier ? "" : "no ",
                fileData.Path,
                Encoding == null ? "" : " but overriden with " + Encoding + " encoding.");
            WriteVerbose(msg);
        }

        internal class FileData {
            private readonly char[] _tempReadEncodingBuffer = new char[256];
            private readonly byte[] _utf8Bom = { 0xEF, 0xBB, 0xBF };

            public FileData(string path) {
                if (string.IsNullOrWhiteSpace(path)) {
                    throw new ArgumentNullException("path");
                }

                Path = path;
                EncoderEmitsUtf8Identifier = true;

                using (var fileStream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read)) {
                    Length = fileStream.Length;

                    // According to MSDN topic, stream reader can't return accurate encoding until after the first read,
                    // so read some bytes if stream position indicates no reading has been done.
                    var streamReader = new StreamReader(fileStream, true);
                    streamReader.Read(_tempReadEncodingBuffer, 0, _tempReadEncodingBuffer.Length);
                    Encoding = streamReader.CurrentEncoding;

                    // Do not use streamReader after this point. If so, you need to call streamReader.DiscardBufferedData()
                    // to resync buffer with the underlying stream.

                    // Determine if file ends with a newline
                    byte[] endBytes;
                    if (fileStream.Length >= 2) {
                        fileStream.Seek(-2, SeekOrigin.End);
                        endBytes = new byte[2];
                        fileStream.Read(endBytes, 0, 2);
                        LastLineEndsWithNewline = endBytes[0] == '\n' || endBytes[0] == '\r' || endBytes[1] == '\n' || endBytes[1] == '\r';
                    } else if (fileStream.Length == 1) {
                        fileStream.Seek(-1, SeekOrigin.End);
                        endBytes = new byte[1];
                        fileStream.Read(endBytes, 0, 1);
                        LastLineEndsWithNewline = endBytes[0] == '\n' || endBytes[0] == '\r';
                    }

                    // Just because StreamReader says it is UTF8, that doesn't mean the original
                    // file has a UTF-8 BOM, this code attempts to detect that configure the returned
                    // encoding to only write a BOM if the original file had a BOM.
                    if (Encoding.Equals(Encoding.UTF8)) {
                        if (fileStream.Length < _utf8Bom.Length) {
                            // Can't have a BOM if file length is less than that of BOM
                            EncoderEmitsUtf8Identifier = false;
                            Encoding = new UTF8Encoding(EncoderEmitsUtf8Identifier, true);
                        } else {
                            var fileBytes = new byte[_utf8Bom.Length];
                            fileStream.Seek(0L, SeekOrigin.Begin);
                            fileStream.ReadExactly(fileBytes, 0, fileBytes.Length);
                            for (int i = 0; i < _utf8Bom.Length; i++) {
                                if (fileBytes[i] != _utf8Bom[i]) {
                                    EncoderEmitsUtf8Identifier = false;
                                    Encoding = new UTF8Encoding(EncoderEmitsUtf8Identifier, true);
                                }
                            }
                        }
                    } else if (fileStream.Length < 2) {
                        // No BOM at all so default to UTF8 with no BOM for output
                        EncoderEmitsUtf8Identifier = false;
                        Encoding = new UTF8Encoding(EncoderEmitsUtf8Identifier, true);
                    }
                }
            }

            public string Path { get; }
            public long Length { get; }
            public Encoding Encoding { get; }
            public bool EncoderEmitsUtf8Identifier { get; }
            public bool LastLineEndsWithNewline { get; }
        }
    }
}