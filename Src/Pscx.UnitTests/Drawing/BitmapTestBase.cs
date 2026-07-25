// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using NUnit.Framework;
using System;
using System.Collections.ObjectModel;
using System.Drawing;
using System.IO;
using System.Management.Automation;

namespace PscxUnitTests.Drawing {
    public class BitmapTestBase : PscxCmdletTest {
        protected Bitmap TestBitmap(Bitmap bmp, string command) {
            if (!OperatingSystem.IsWindows()) {
                Assert.Inconclusive("This test is only applicable on Windows.");
            }

            Collection<PSObject> results = Invoke(command, bmp);
            Assert.That(1, Is.EqualTo(results.Count));

            Bitmap output = results[0].BaseObject as Bitmap;
            Assert.That(output, Is.Not.Null);

            return output;
        }

        protected Bitmap OpenTestBitmap() {
            Stream stream = GetType().Assembly.GetManifestResourceStream("PscxUnitTests.Drawing.TestBitmap.jpg");
            return new Bitmap(stream);
        }
    }
}