using System;
using System.Collections.Generic;
using System.IO;
using SharpCompress.Archives;
using SharpCompress.Common;
using SharpCompress.Readers;

namespace Pscx.Commands.IO.Compression {
    internal static class ArchiveBackend {
        internal static IReadOnlyList<ArchiveEntry> ReadEntries(string archivePath) {
            try {
                return ReadArchiveEntries(archivePath);
            } catch (InvalidFormatException) {
                return ReadStreamingEntries(archivePath);
            } catch (NotSupportedException) {
                return ReadStreamingEntries(archivePath);
            } catch (ArchiveOperationException) {
                return ReadStreamingEntries(archivePath);
            }
        }

        internal static IReadOnlyList<ArchiveEntry> Extract(
            string archivePath,
            string destinationPath,
            bool overwrite,
            Action<int, int, string> reportProgress) {
            var entries = ReadEntries(archivePath);
            ValidateEntries(entries, destinationPath);

            try {
                ExtractArchiveEntries(archivePath, destinationPath, overwrite, reportProgress);
            } catch (InvalidFormatException) {
                ExtractStreamingEntries(archivePath, destinationPath, overwrite, reportProgress);
            } catch (NotSupportedException) {
                ExtractStreamingEntries(archivePath, destinationPath, overwrite, reportProgress);
            } catch (ArchiveOperationException) {
                ExtractStreamingEntries(archivePath, destinationPath, overwrite, reportProgress);
            }
            return entries;
        }

        internal static string GetSafeDestinationPath(string destinationPath, string entryPath) {
            if (string.IsNullOrWhiteSpace(entryPath) || entryPath.IndexOf('\0') >= 0) {
                throw new InvalidDataException("Archive entry has an empty or invalid path.");
            }

            var normalizedEntry = entryPath.Replace('\\', '/');
            if (normalizedEntry.StartsWith("/", StringComparison.Ordinal) ||
                normalizedEntry.StartsWith("//", StringComparison.Ordinal) ||
                (normalizedEntry.Length >= 2 && char.IsLetter(normalizedEntry[0]) && normalizedEntry[1] == ':')) {
                throw new InvalidDataException($"Archive entry uses a rooted path: {entryPath}");
            }
            foreach (var segment in normalizedEntry.Split('/', StringSplitOptions.RemoveEmptyEntries)) {
                if (segment == "..") {
                    throw new InvalidDataException($"Archive entry attempts path traversal: {entryPath}");
                }
            }

            var root = Path.GetFullPath(destinationPath);
            var candidate = Path.GetFullPath(Path.Combine(root, normalizedEntry.Replace('/', Path.DirectorySeparatorChar)));
            var rootPrefix = root.EndsWith(Path.DirectorySeparatorChar) ? root : root + Path.DirectorySeparatorChar;
            var comparison = OperatingSystem.IsWindows()
                ? StringComparison.OrdinalIgnoreCase
                : StringComparison.Ordinal;
            if (!candidate.StartsWith(rootPrefix, comparison) && !candidate.Equals(root, comparison)) {
                throw new InvalidDataException($"Archive entry escapes the extraction root: {entryPath}");
            }
            AssertNoLinkTraversal(root, candidate, entryPath);
            return candidate;
        }

        private static void AssertNoLinkTraversal(string root, string candidate, string entryPath) {
            var current = root;
            AssertNotLink(current, entryPath);
            var relativePath = Path.GetRelativePath(root, candidate);
            foreach (var segment in relativePath.Split(
                Path.DirectorySeparatorChar,
                StringSplitOptions.RemoveEmptyEntries)) {
                current = Path.Combine(current, segment);
                AssertNotLink(current, entryPath);
            }
        }

        private static void AssertNotLink(string path, string entryPath) {
            FileSystemInfo info = Directory.Exists(path)
                ? new DirectoryInfo(path)
                : new FileInfo(path);
            if (info.LinkTarget != null ||
                (info.Exists && info.Attributes.HasFlag(FileAttributes.ReparsePoint))) {
                throw new InvalidDataException(
                    $"Archive entry would traverse or replace a filesystem link: {entryPath}");
            }
        }

        private static IReadOnlyList<ArchiveEntry> ReadArchiveEntries(string archivePath) {
            var entries = new List<ArchiveEntry>();
            using var archive = ArchiveFactory.OpenArchive(archivePath);
            var index = 0;
            foreach (var entry in archive.Entries) {
                entries.Add(ToArchiveEntry(entry, archivePath, index++));
            }
            return entries;
        }

        private static IReadOnlyList<ArchiveEntry> ReadStreamingEntries(string archivePath) {
            var entries = new List<ArchiveEntry>();
            using var reader = ReaderFactory.OpenReader(archivePath);
            var index = 0;
            while (reader.MoveToNextEntry()) {
                entries.Add(ToArchiveEntry(reader.Entry, archivePath, index++));
            }
            return entries;
        }

        private static ArchiveEntry ToArchiveEntry(IEntry entry, string archivePath, int index) {
            return new ArchiveEntry(
                index,
                entry.Key ?? string.Empty,
                checked((long)entry.Size),
                entry.LastModifiedTime,
                entry.IsEncrypted,
                entry.IsDirectory,
                archivePath,
                entry.CompressionType.ToString(),
                entry.Crc,
                entry.LinkTarget);
        }

        internal static void ValidateEntries(IEnumerable<ArchiveEntry> entries, string destinationPath) {
            foreach (var entry in entries) {
                GetSafeDestinationPath(destinationPath, entry.Path);
                if (entry.IsEncrypted) {
                    throw new NotSupportedException(
                        $"Encrypted archives are not supported by Pscx.Archive 4.0: {entry.Path}");
                }
                if (entry.IsSymbolicLink) {
                    throw new InvalidDataException(
                        $"Symbolic-link archive entries are rejected for safe extraction: {entry.Path}");
                }
            }
        }

        private static void ExtractArchiveEntries(
            string archivePath,
            string destinationPath,
            bool overwrite,
            Action<int, int, string> reportProgress) {
            using var archive = ArchiveFactory.OpenArchive(archivePath);
            var entries = new List<IArchiveEntry>(archive.Entries);
            for (var index = 0; index < entries.Count; index++) {
                var entry = entries[index];
                ExtractEntry(entry, destinationPath, overwrite);
                reportProgress?.Invoke(index + 1, entries.Count, entry.Key);
            }
        }

        private static void ExtractStreamingEntries(
            string archivePath,
            string destinationPath,
            bool overwrite,
            Action<int, int, string> reportProgress) {
            var total = ReadStreamingEntries(archivePath).Count;
            using var reader = ReaderFactory.OpenReader(archivePath);
            var index = 0;
            while (reader.MoveToNextEntry()) {
                ExtractEntry(reader, destinationPath, overwrite);
                index++;
                reportProgress?.Invoke(index, total, reader.Entry.Key);
            }
        }

        private static void ExtractEntry(IArchiveEntry entry, string destinationPath, bool overwrite) {
            var targetPath = GetSafeDestinationPath(destinationPath, entry.Key);
            if (entry.IsDirectory) {
                Directory.CreateDirectory(targetPath);
                return;
            }
            EnsureWritableTarget(targetPath, overwrite);
            using var input = entry.OpenEntryStream();
            using var output = new FileStream(targetPath, overwrite ? FileMode.Create : FileMode.CreateNew, FileAccess.Write);
            input.CopyTo(output);
            ApplyTimestamp(targetPath, entry.LastModifiedTime);
        }

        private static void ExtractEntry(IReader reader, string destinationPath, bool overwrite) {
            var entry = reader.Entry;
            var targetPath = GetSafeDestinationPath(destinationPath, entry.Key);
            if (entry.IsDirectory) {
                Directory.CreateDirectory(targetPath);
                return;
            }
            EnsureWritableTarget(targetPath, overwrite);
            using var input = reader.OpenEntryStream();
            using var output = new FileStream(targetPath, overwrite ? FileMode.Create : FileMode.CreateNew, FileAccess.Write);
            input.CopyTo(output);
            ApplyTimestamp(targetPath, entry.LastModifiedTime);
        }

        private static void EnsureWritableTarget(string targetPath, bool overwrite) {
            var parent = Path.GetDirectoryName(targetPath);
            if (!string.IsNullOrEmpty(parent)) {
                Directory.CreateDirectory(parent);
            }
            if (!overwrite && File.Exists(targetPath)) {
                throw new IOException($"The destination file already exists: {targetPath}");
            }
        }

        private static void ApplyTimestamp(string path, DateTime? timestamp) {
            if (timestamp.HasValue) {
                File.SetLastWriteTime(path, timestamp.Value);
            }
        }
    }
}
