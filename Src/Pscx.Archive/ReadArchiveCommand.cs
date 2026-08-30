using System.IO;
using System.Management.Automation;

namespace Pscx.Commands.IO.Compression {
    [Cmdlet(VerbsCommunications.Read, "PscxArchive", DefaultParameterSetName = PathParameterSet)]
    [OutputType(typeof(ArchiveEntry))]
    public sealed class ReadArchiveCommand : ArchivePathCommandBase {
        [Parameter]
        public SwitchParameter IncludeDirectories { get; set; }

        protected override void ProcessRecord() {
            foreach (var archivePath in ResolveInputPaths(allowDirectories: false)) {
                foreach (var entry in ArchiveBackend.ReadEntries(archivePath)) {
                    if (IncludeDirectories || !entry.IsFolder) {
                        WriteObject(entry);
                    }
                }
            }
        }
    }
}
