using System;
using System.Collections.Generic;
using System.IO;
using System.Management.Automation;

namespace Pscx.Commands.IO.Compression {
    public abstract class ArchivePathCommandBase : PSCmdlet {
        protected const string PathParameterSet = "Path";
        protected const string LiteralPathParameterSet = "LiteralPath";
        protected const string ObjectParameterSet = "Object";

        [Parameter(Mandatory = true, Position = 0, ParameterSetName = PathParameterSet,
            ValueFromPipelineByPropertyName = true)]
        [ValidateNotNullOrEmpty]
        public string[] Path { get; set; }

        [Parameter(Mandatory = true, Position = 0, ParameterSetName = LiteralPathParameterSet,
            ValueFromPipelineByPropertyName = true)]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty]
        public string[] LiteralPath { get; set; }

        [Parameter(Mandatory = true, ParameterSetName = ObjectParameterSet, ValueFromPipeline = true)]
        [ValidateNotNull]
        public PSObject InputObject { get; set; }

        protected IReadOnlyList<string> ResolveInputPaths(bool allowDirectories) {
            var paths = new List<string>();
            if (ParameterSetName == ObjectParameterSet) {
                var value = InputObject?.BaseObject;
                if (value is FileSystemInfo fileSystemInfo) {
                    AddValidatedPath(paths, fileSystemInfo.FullName, allowDirectories);
                } else if (value is string path) {
                    AddValidatedPath(paths, ResolveLiteralPath(path), allowDirectories);
                } else {
                    throw new PSArgumentException(
                        "InputObject must be a FileInfo, DirectoryInfo, or filesystem path string.",
                        nameof(InputObject));
                }
                return paths;
            }

            if (ParameterSetName == LiteralPathParameterSet) {
                foreach (var path in LiteralPath) {
                    AddValidatedPath(paths, ResolveLiteralPath(path), allowDirectories);
                }
                return paths;
            }

            foreach (var path in Path) {
                ProviderInfo provider;
                var resolvedPaths = SessionState.Path.GetResolvedProviderPathFromPSPath(path, out provider);
                if (!string.Equals(provider.Name, "FileSystem", StringComparison.OrdinalIgnoreCase)) {
                    throw new PSArgumentException($"Path must resolve through the FileSystem provider: {path}");
                }
                foreach (var resolvedPath in resolvedPaths) {
                    AddValidatedPath(paths, resolvedPath, allowDirectories);
                }
            }
            return paths;
        }

        protected string ResolveLiteralPath(string path) {
            return SessionState.Path.GetUnresolvedProviderPathFromPSPath(path);
        }

        private static void AddValidatedPath(ICollection<string> paths, string path, bool allowDirectories) {
            var fullPath = System.IO.Path.GetFullPath(path);
            if (File.Exists(fullPath) || (allowDirectories && Directory.Exists(fullPath))) {
                paths.Add(fullPath);
                return;
            }
            throw new FileNotFoundException($"The filesystem path does not exist: {path}", path);
        }
    }
}
