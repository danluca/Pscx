// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System.Text;
using NUnit.Framework;

namespace PscxInternalTests {
    [TestFixture]
    public class EncodingConversionTests {
        [TestCase(null)]
        [TestCase("")]
        [TestCase("unknown")]
        [TestCase("string")]
        [TestCase("unicode")]
        public void UnicodeAliasesResolveToUnicode(string name) {
            Assert.That(Pscx.EncodingConversion.Convert(null, name, "Encoding"), Is.SameAs(Encoding.Unicode));
        }

        [TestCase("ascii", "us-ascii")]
        [TestCase("utf8", "utf-8")]
        [TestCase("utf32", "utf-32")]
        [TestCase("bigendianunicode", "utf-16BE")]
        public void NamedEncodingsResolveWithoutPowerShellHost(string name, string webName) {
            var encoding = Pscx.EncodingConversion.Convert(null, name, "Encoding");

            Assert.That(encoding.WebName, Is.EqualTo(webName).IgnoreCase);
        }
    }
}
