// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.IO;
using NUnit.Framework;
using Pscx.Runtime.Serialization.Binary;

namespace PscxInternalTests.Runtime.Serialization.Binary {
    [TestFixture]
    public class BinaryParserTests {
        [Test]
        public void AlignAdvancesToRequestedBoundary() {
            using var stream = new MemoryStream(new byte[] { 1, 2, 3, 4, 5, 6 });
            using var parser = new BinaryParser(stream, 1);
            parser.ReadByte();

            parser.Align(4);

            Assert.That(parser.Position, Is.EqualTo(4));
            Assert.That(parser.ReadByte(), Is.EqualTo(4));
        }

        [Test]
        public void PeekByteDoesNotAdvancePosition() {
            using var parser = new BinaryParser(new MemoryStream(new byte[] { 42, 43 }));

            Assert.That(parser.PeekByte(), Is.EqualTo(42));
            Assert.That(parser.Position, Is.Zero);
            Assert.That(parser.ReadByte(), Is.EqualTo(42));
        }

        [Test]
        public void ReadStringAsciiZStopsAtNullTerminator() {
            using var parser = new BinaryParser(new MemoryStream(new byte[] { 80, 83, 67, 88, 0, 99 }));

            Assert.That(parser.ReadStringAsciiZ(), Is.EqualTo("PSCX"));
        }

        [TestCase(0u, 0)]
        [TestCase(0b101101u, 4)]
        [TestCase(uint.MaxValue, 32)]
        public void BitCountCountsSetBits(uint value, int expected) {
            Assert.That(BinaryParser.BitCount(value), Is.EqualTo(expected));
        }

        [Test]
        public void PeekByteAtEndThrowsStableException() {
            using var parser = new BinaryParser(new MemoryStream(Array.Empty<byte>()));

            Assert.That(() => parser.PeekByte(), Throws.InvalidOperationException);
        }
    }
}
