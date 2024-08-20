using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using NUnit.Framework;

namespace PscxUnitTests.Drawing
{
    [TestFixture]
    public class ExportBitmapTest : BitmapTestBase
    {
        protected void TestExportBitmap(string path, string format)
        {
            TestExportBitmap(path, path, format, null, null);
        }

        protected void TestExportBitmap(string path, string format, PixelFormat? pixelFormat)
        {
            TestExportBitmap(path, path, format, null, pixelFormat);
        }

        protected void TestExportBitmap(string path, string expectedPath, string format, string quality)
        {
            TestExportBitmap(path, expectedPath, format, quality, null);
        }

        protected void TestExportBitmap(string path, string expectedPath, string format, string quality, PixelFormat? pixelFormat)
        {
            using(Bitmap original = OpenTestBitmap())
            {
                string tempPath = Path.GetTempPath();

                string exportScript = "Set-Location $Env:Temp;  Export-Bitmap -Bitmap @($input)[0] -Path {0} {1} {2}";
                exportScript = string.Format(exportScript, path, format, quality);

                Invoke(exportScript, original);

                Assert.That(File.Exists(Path.Combine(tempPath, expectedPath)), Is.True);

                string importScript = "Set-Location $Env:Temp; Import-Bitmap {0}";
                importScript = string.Format(importScript, expectedPath);

                using(Bitmap exported = Invoke(importScript)[0].BaseObject as Bitmap)
                {
                    Assert.That(exported, Is.Not.Null);
                    Assert.That(original.Width, Is.EqualTo(exported.Width));
                    Assert.That(original.Height, Is.EqualTo(exported.Height));
                    Assert.That(pixelFormat ?? original.PixelFormat, Is.EqualTo(exported.PixelFormat));
                }

                File.Delete(expectedPath);
            }
        }

        [Test]
        public void SaveBitmap()
        {
            using (Bitmap original = OpenTestBitmap())
            {
                string path = Path.Combine(Path.GetTempPath(), "neco.png");
                original.Save(path, System.Drawing.Imaging.ImageFormat.Png);

                Assert.That(File.Exists(path), Is.True);
                File.Delete(path);
            }
        }

        [Test]
        public void ExportBmp()
        {
            TestExportBitmap("test.bmp", "bmp");
        }

        [Test]
        public void ExportJpeg()
        {
            TestExportBitmap("jpegicek", "jpegicek.jpeg", "jpeg", "10");
        }

        [Test]
        public void ExportTiff()
        {
            TestExportBitmap("tifficek.tif", "tiff");
        }

        [Test]
        public void ExportPng()
        {
            TestExportBitmap("png", "png.png", "png", "100");
        }
        
        [Test]
        public void ExportGif()
        {
            TestExportBitmap("gifecek.gif", "gif", PixelFormat.Format8bppIndexed);
        }
    }
}
