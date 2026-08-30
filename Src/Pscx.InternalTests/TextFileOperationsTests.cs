// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Text;
using NUnit.Framework;
using Pscx.Commands.Text;

namespace PscxInternalTests
{
    [TestFixture]
    public class TextFileOperationsTests
    {
        [Test]
        public void DetectsBomlessAsciiAndMixedLineEndings()
        {
            byte[] bytes = Encoding.ASCII.GetBytes("one\r\ntwo\nthree\r");

            TextFileInfo info = TextFileOperations.Analyze(bytes, "mixed.txt");

            Assert.Multiple(() =>
            {
                Assert.That(info.Path, Is.EqualTo("mixed.txt"));
                Assert.That(info.Encoding, Is.EqualTo(TextFileEncodingKind.Ascii));
                Assert.That(info.Bom, Is.EqualTo(TextFileBomKind.None));
                Assert.That(info.HasBom, Is.False);
                Assert.That(info.LineEnding, Is.EqualTo(TextFileLineEndingKind.Mixed));
                Assert.That(info.HasMixedLineEndings, Is.True);
                Assert.That(info.CrLfCount, Is.EqualTo(1));
                Assert.That(info.LfCount, Is.EqualTo(1));
                Assert.That(info.CrCount, Is.EqualTo(1));
                Assert.That(info.HasFinalNewline, Is.True);
                Assert.That(info.IsValidText, Is.True);
            });
        }

        [TestCase(new byte[] { 0xEF, 0xBB, 0xBF }, TextFileEncodingKind.Utf8, TextFileBomKind.Utf8)]
        [TestCase(new byte[] { 0xFF, 0xFE }, TextFileEncodingKind.Utf16LittleEndian, TextFileBomKind.Utf16LittleEndian)]
        [TestCase(new byte[] { 0xFE, 0xFF }, TextFileEncodingKind.Utf16BigEndian, TextFileBomKind.Utf16BigEndian)]
        [TestCase(new byte[] { 0xFF, 0xFE, 0x00, 0x00 }, TextFileEncodingKind.Utf32LittleEndian, TextFileBomKind.Utf32LittleEndian)]
        [TestCase(new byte[] { 0x00, 0x00, 0xFE, 0xFF }, TextFileEncodingKind.Utf32BigEndian, TextFileBomKind.Utf32BigEndian)]
        public void DetectsSupportedByteOrderMarks(
            byte[] preamble,
            TextFileEncodingKind expectedEncoding,
            TextFileBomKind expectedBom)
        {
            TextFileInfo info = TextFileOperations.Analyze(preamble);

            Assert.Multiple(() =>
            {
                Assert.That(info.Encoding, Is.EqualTo(expectedEncoding));
                Assert.That(info.Bom, Is.EqualTo(expectedBom));
                Assert.That(info.HasBom, Is.True);
                Assert.That(info.IsValidText, Is.True);
                Assert.That(info.LineEnding, Is.EqualTo(TextFileLineEndingKind.None));
            });
        }

        [Test]
        public void DetectsBomlessUtf8AndRejectsInvalidUtf8()
        {
            TextFileInfo utf8 = TextFileOperations.Analyze(
                new UTF8Encoding(false).GetBytes("café\n"));
            TextFileInfo unknown = TextFileOperations.Analyze(new byte[] { 0x80, 0x81 });
            TextFileInfo ambiguousUtf16 = TextFileOperations.Analyze(
                new UnicodeEncoding(false, false).GetBytes("text"));

            Assert.Multiple(() =>
            {
                Assert.That(utf8.Encoding, Is.EqualTo(TextFileEncodingKind.Utf8));
                Assert.That(utf8.HasBom, Is.False);
                Assert.That(utf8.LineEnding, Is.EqualTo(TextFileLineEndingKind.Lf));
                Assert.That(unknown.Encoding, Is.EqualTo(TextFileEncodingKind.Unknown));
                Assert.That(unknown.IsValidText, Is.False);
                Assert.That(unknown.LineEnding, Is.EqualTo(TextFileLineEndingKind.Unknown));
                Assert.That(ambiguousUtf16.Encoding, Is.EqualTo(TextFileEncodingKind.Unknown));
                Assert.That(ambiguousUtf16.IsValidText, Is.False);
            });
        }

        [Test]
        public void ConversionPreservesBomAndFinalNewlineByDefault()
        {
            byte[] withoutBom = new UTF8Encoding(false).GetBytes("one\ntwo");
            byte[] withBom = Combine(
                new UTF8Encoding(true).GetPreamble(),
                new UTF8Encoding(false).GetBytes("one\ntwo\n"));

            byte[] convertedWithoutBom = TextFileOperations.ConvertLineEndings(
                TextFileOperations.Analyze(withoutBom),
                TextFileLineEndingKind.CrLf,
                FinalNewlineMode.Preserve,
                null);
            byte[] convertedWithBom = TextFileOperations.ConvertLineEndings(
                TextFileOperations.Analyze(withBom),
                TextFileLineEndingKind.CrLf,
                FinalNewlineMode.Preserve,
                null);

            Assert.That(
                convertedWithoutBom,
                Is.EqualTo(new UTF8Encoding(false).GetBytes("one\r\ntwo")));
            Assert.That(
                convertedWithBom,
                Is.EqualTo(Combine(
                    new UTF8Encoding(true).GetPreamble(),
                    new UTF8Encoding(false).GetBytes("one\r\ntwo\r\n"))));
        }

        [Test]
        public void FinalNewlineModesAreExplicit()
        {
            TextFileInfo withoutFinal = TextFileOperations.Analyze(Encoding.ASCII.GetBytes("one\ntwo"));
            TextFileInfo withFinal = TextFileOperations.Analyze(Encoding.ASCII.GetBytes("one\n\n"));

            byte[] added = TextFileOperations.ConvertLineEndings(
                withoutFinal,
                TextFileLineEndingKind.Lf,
                FinalNewlineMode.Add,
                null);
            byte[] removed = TextFileOperations.ConvertLineEndings(
                withFinal,
                TextFileLineEndingKind.Lf,
                FinalNewlineMode.Remove,
                null);

            Assert.Multiple(() =>
            {
                Assert.That(Encoding.ASCII.GetString(added), Is.EqualTo("one\ntwo\n"));
                Assert.That(Encoding.ASCII.GetString(removed), Is.EqualTo("one"));
            });
        }

        [Test]
        public void CheckDetectsOnlyByteLevelChanges()
        {
            TextFileInfo info = TextFileOperations.Analyze(Encoding.ASCII.GetBytes("one\ntwo\n"));
            byte[] unchanged = TextFileOperations.ConvertLineEndings(
                info,
                TextFileLineEndingKind.Lf,
                FinalNewlineMode.Preserve,
                null);
            byte[] changed = TextFileOperations.ConvertLineEndings(
                info,
                TextFileLineEndingKind.CrLf,
                FinalNewlineMode.Preserve,
                null);

            Assert.Multiple(() =>
            {
                Assert.That(TextFileOperations.NeedsConversion(info, unchanged), Is.False);
                Assert.That(TextFileOperations.NeedsConversion(info, changed), Is.True);
            });
        }

        private static byte[] Combine(byte[] first, byte[] second)
        {
            byte[] result = new byte[first.Length + second.Length];
            Buffer.BlockCopy(first, 0, result, 0, first.Length);
            Buffer.BlockCopy(second, 0, result, first.Length, second.Length);
            return result;
        }
    }
}
