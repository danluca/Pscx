using System;
using System.IO;
using System.Management.Automation;

namespace Pscx.Commands.IO.Compression {
    [Cmdlet(VerbsData.Expand, "PscxArchive", DefaultParameterSetName = PathParameterSet,
        SupportsShouldProcess = true, ConfirmImpact = ConfirmImpact.Medium)]
    [OutputType(typeof(FileSystemInfo))]
    public sealed class ExpandArchiveCommand : ArchivePathCommandBase {
        [Parameter(Position = 1)]
        [Alias("To")]
        [ValidateNotNullOrEmpty]
        public string OutputPath { get; set; }

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        [Parameter]
        public SwitchParameter ShowProgress { get; set; }

        [Parameter]
        public SwitchParameter Force { get; set; }

        protected override void ProcessRecord() {
            var destinationPath = string.IsNullOrWhiteSpace(OutputPath)
                ? SessionState.Path.CurrentFileSystemLocation.Path
                : ResolveLiteralPath(OutputPath);
            destinationPath = System.IO.Path.GetFullPath(destinationPath);

            foreach (var archivePath in ResolveInputPaths(allowDirectories: false)) {
                if (!ShouldProcess(destinationPath, $"Expand archive '{archivePath}'")) {
                    continue;
                }

                Directory.CreateDirectory(destinationPath);
                var entries = ArchiveBackend.Extract(
                    archivePath,
                    destinationPath,
                    Force,
                    ShowProgress ? ReportProgress : null);
                if (ShowProgress) {
                    WriteProgress(new ProgressRecord(1, "Expanding archive", archivePath) {
                        RecordType = ProgressRecordType.Completed,
                        PercentComplete = 100
                    });
                }
                if (PassThru) {
                    foreach (var entry in entries) {
                        var expandedPath = ArchiveBackend.GetSafeDestinationPath(destinationPath, entry.Path);
                        if (entry.IsFolder && Directory.Exists(expandedPath)) {
                            WriteObject(new DirectoryInfo(expandedPath));
                        } else if (!entry.IsFolder && File.Exists(expandedPath)) {
                            WriteObject(new FileInfo(expandedPath));
                        }
                    }
                }
            }
        }

        private void ReportProgress(int completed, int total, string currentEntry) {
            var percent = total == 0 ? 100 : (int)Math.Floor(100d * completed / total);
            WriteProgress(new ProgressRecord(1, "Expanding archive", currentEntry) {
                RecordType = ProgressRecordType.Processing,
                PercentComplete = percent
            });
        }
    }
}
