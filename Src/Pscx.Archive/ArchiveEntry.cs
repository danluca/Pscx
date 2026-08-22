using System;

namespace Pscx.Commands.IO.Compression {
    [Serializable]
    public sealed class ArchiveEntry {
        internal ArchiveEntry(
            int index,
            string path,
            long size,
            DateTime? modifiedDate,
            bool isEncrypted,
            bool isFolder,
            string archivePath,
            string compressionMethod,
            long crc,
            string linkTarget) {
            Index = index;
            Path = path;
            Size = size;
            ModifiedDate = modifiedDate;
            IsEncrypted = isEncrypted;
            IsFolder = isFolder;
            ArchivePath = archivePath;
            CompressionMethod = compressionMethod;
            CRC = crc;
            LinkTarget = linkTarget;
        }

        public int Index { get; }
        public string Path { get; }
        public long Size { get; }
        public DateTime? ModifiedDate { get; }
        public string Name => System.IO.Path.GetFileName(Path.TrimEnd('/', '\\'));
        public bool IsEncrypted { get; }
        public bool IsFolder { get; }
        public string CompressionMethod { get; }
        public string ArchivePath { get; }
        public long CRC { get; }
        public string LinkTarget { get; }
        public bool IsSymbolicLink => !string.IsNullOrEmpty(LinkTarget);
    }
}
