using System;
using System.Collections.Generic;
using System.IO;
using System.Management.Automation;
using SharpCompress.Common;
using SharpCompress.Common.Options;
using SharpCompress.Writers;
using SharpCompress.Writers.SevenZip;

namespace Pscx.Commands.IO.Compression {
    [Cmdlet(VerbsCommunications.Write, "PscxArchive", DefaultParameterSetName = PathParameterSet,
        SupportsShouldProcess = true, ConfirmImpact = ConfirmImpact.Medium)]
    [OutputType(typeof(FileInfo))]
    public sealed class WriteArchiveCommand : ArchivePathCommandBase {
        private readonly List<string> inputPaths = new();

        [Parameter(Mandatory = true, Position = 1)]
        [ValidateNotNullOrEmpty]
        public string OutputPath { get; set; }

        [Parameter]
        [Alias("Root")]
        [ValidateNotNullOrEmpty]
        public string EntryPathRoot { get; set; }

        [Parameter]
        public SwitchParameter ShowProgress { get; set; }

        [Parameter]
        public SwitchParameter Force { get; set; }

        protected override void ProcessRecord() {
            inputPaths.AddRange(ResolveInputPaths(allowDirectories: true));
        }

        protected override void EndProcessing() {
            if (inputPaths.Count == 0) {
                throw new PSInvalidOperationException("No filesystem entries were supplied for archiving.");
            }

            var outputPath = System.IO.Path.GetFullPath(ResolveLiteralPath(OutputPath));
            if (File.Exists(outputPath) && !Force) {
                throw new IOException($"The output archive already exists. Use -Force to replace it: {outputPath}");
            }

            var entries = BuildEntries();
            if (!ShouldProcess(outputPath, $"Create archive with {entries.Count} file(s)")) {
                return;
            }

            var parent = System.IO.Path.GetDirectoryName(outputPath);
            if (!string.IsNullOrEmpty(parent)) {
                Directory.CreateDirectory(parent);
            }

            try {
                using var stream = new FileStream(outputPath, FileMode.Create, FileAccess.Write, FileShare.None);
                var format = GetFormat(outputPath);
                using var writer = WriterFactory.OpenWriter(stream, format.ArchiveType, format.Options);
                for (var index = 0; index < entries.Count; index++) {
                    var entry = entries[index];
                    using var input = File.OpenRead(entry.SourcePath);
                    writer.Write(entry.EntryPath, input, File.GetLastWriteTime(entry.SourcePath));
                    if (ShowProgress) {
                        WriteProgress(new ProgressRecord(0, "Creating archive", entry.EntryPath) {
                            RecordType = ProgressRecordType.Processing,
                            PercentComplete = (int)Math.Floor(100d * (index + 1) / entries.Count)
                        });
                    }
                }
            } catch {
                if (File.Exists(outputPath)) {
                    File.Delete(outputPath);
                }
                throw;
            }

            if (ShowProgress) {
                WriteProgress(new ProgressRecord(0, "Creating archive", outputPath) {
                    RecordType = ProgressRecordType.Completed,
                    PercentComplete = 100
                });
            }
            WriteObject(new FileInfo(outputPath));
        }

        private List<ArchiveSourceEntry> BuildEntries() {
            string root = null;
            if (!string.IsNullOrWhiteSpace(EntryPathRoot)) {
                root = System.IO.Path.GetFullPath(ResolveLiteralPath(EntryPathRoot));
                if (!Directory.Exists(root)) {
                    throw new DirectoryNotFoundException($"EntryPathRoot does not exist: {root}");
                }
            }

            var entries = new List<ArchiveSourceEntry>();
            var names = new HashSet<string>(StringComparer.Ordinal);
            foreach (var inputPath in inputPaths) {
                if (File.Exists(inputPath)) {
                    AddEntry(entries, names, inputPath, root ?? System.IO.Path.GetDirectoryName(inputPath));
                    continue;
                }

                var entryRoot = root ?? Directory.GetParent(inputPath)?.FullName;
                foreach (var file in Directory.EnumerateFiles(inputPath, "*", SearchOption.AllDirectories)) {
                    AddEntry(entries, names, file, entryRoot);
                }
            }
            if (entries.Count == 0) {
                throw new PSInvalidOperationException("The supplied paths contain no files to archive.");
            }
            return entries;
        }

        private static void AddEntry(
            ICollection<ArchiveSourceEntry> entries,
            ISet<string> names,
            string sourcePath,
            string root) {
            var relativePath = System.IO.Path.GetRelativePath(root, sourcePath).Replace('\\', '/');
            if (relativePath == ".." || relativePath.StartsWith("../", StringComparison.Ordinal)) {
                throw new InvalidOperationException($"Input path is outside EntryPathRoot: {sourcePath}");
            }
            if (!names.Add(relativePath)) {
                throw new InvalidOperationException($"More than one input maps to archive entry '{relativePath}'.");
            }
            entries.Add(new ArchiveSourceEntry(sourcePath, relativePath));
        }

        private static ArchiveFormat GetFormat(string outputPath) {
            var name = outputPath.ToLowerInvariant();
            if (name.EndsWith(".tar.gz", StringComparison.Ordinal) || name.EndsWith(".tgz", StringComparison.Ordinal)) {
                return new ArchiveFormat(ArchiveType.Tar, WriterOptions.ForTar(CompressionType.GZip));
            }
            if (name.EndsWith(".tar.bz2", StringComparison.Ordinal) || name.EndsWith(".tbz2", StringComparison.Ordinal)) {
                return new ArchiveFormat(ArchiveType.Tar, WriterOptions.ForTar(CompressionType.BZip2));
            }
            if (name.EndsWith(".tar", StringComparison.Ordinal)) {
                return new ArchiveFormat(ArchiveType.Tar, WriterOptions.ForTar(CompressionType.None));
            }
            if (name.EndsWith(".7z", StringComparison.Ordinal)) {
                return new ArchiveFormat(
                    ArchiveType.SevenZip,
                    new SevenZipWriterOptions(CompressionType.LZMA2) { CompressHeader = true });
            }
            if (name.EndsWith(".zip", StringComparison.Ordinal)) {
                return new ArchiveFormat(ArchiveType.Zip, new WriterOptions(CompressionType.Deflate));
            }
            throw new PSArgumentException(
                "OutputPath must use .zip, .7z, .tar, .tar.gz, .tgz, .tar.bz2, or .tbz2.",
                nameof(OutputPath));
        }

        private sealed record ArchiveSourceEntry(string SourcePath, string EntryPath);
        private sealed record ArchiveFormat(ArchiveType ArchiveType, IWriterOptions Options);
    }
}
