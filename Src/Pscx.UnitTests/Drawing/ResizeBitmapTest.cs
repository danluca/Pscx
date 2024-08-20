//---------------------------------------------------------------------
// Author: jachymko
//
// Description: Resize-Bitmap tests
//
// Creation Date: Dec 30, 2006
//---------------------------------------------------------------------
using System.Drawing;
using System.Drawing.Imaging;
using NUnit.Framework;

namespace PscxUnitTests.Drawing
{
    [TestFixture]
    public class ResizeBitmapTest : BitmapTestBase
    {
        protected Bitmap CreateIndexedBitmap()
        {
            return new Bitmap(100, 100, PixelFormat.Format8bppIndexed);
        }


        [Test]
        public void ResizeBitmapPercent()
        {
            using(Bitmap bmp = OpenTestBitmap())
            {
                using (Bitmap result = TestBitmap(bmp, "$input | Set-BitmapSize -Percent 25"))
                {
                    Assert.That(bmp.Width / 4, Is.EqualTo(result.Width).Within(0.01d));
                    Assert.That(bmp.Height / 4, Is.EqualTo(result.Height).Within(0.01d));
                }
            }
        }

        [Test]
        public void ResizeIndexedBitmap()
        {
            using(Bitmap bmp = CreateIndexedBitmap())
            {
                using (Bitmap result = TestBitmap(bmp, "$input | Set-BitmapSize -Height 60"))
                {
                    Assert.That(60, Is.EqualTo(result.Height));
                    Assert.That(bmp.Width, Is.EqualTo(result.Width));
                }
            }
        }

        [Test]
        public void ResizeBitmapKeepAspectRatio()
        {
            using(Bitmap bmp = new Bitmap(100, 200))
            {
                using(Bitmap result = TestBitmap(bmp, "$input | Set-BitmapSize -Width 50 -KeepAspectRatio"))
                {
                    Assert.That(50, Is.EqualTo(result.Width));
                    Assert.That(100, Is.EqualTo(result.Height));
                }
            }
        }
    }
}
