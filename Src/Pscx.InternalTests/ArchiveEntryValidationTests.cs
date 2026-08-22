using System;
using System.IO;
using NUnit.Framework;
using Pscx.Commands.IO.Compression;

namespace PscxInternalTests;

[TestFixture]
public sealed class ArchiveEntryValidationTests {
    [Test]
    public void ValidateEntriesRejectsEncryptedContentWithoutAcceptingAPassword() {
        var destination = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        var entry = new ArchiveEntry(
            0,
            "secret.txt",
            1,
            null,
            true,
            false,
            "encrypted.zip",
            "Deflate",
            0,
            null);

        var exception = Assert.Throws<NotSupportedException>(
            () => ArchiveBackend.ValidateEntries([entry], destination));

        Assert.That(exception!.Message, Does.Contain("Encrypted archives are not supported"));
        Assert.That(Directory.Exists(destination), Is.False);
    }
}
