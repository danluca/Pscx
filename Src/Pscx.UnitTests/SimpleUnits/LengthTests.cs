using NUnit.Framework;
using Pscx.SimpleUnits;

namespace PscxUnitTests.SimpleUnits {
    [TestFixture]
    public class LengthTests {
        private static void TestLength(string expected, double meters) {
            Assert.AreEqual(expected, new Length(meters).ToString());
        }

        [Test]
        public void TestToString() {
            TestLength("1.250 cm", 0.0125);
            TestLength("1.000 cm", 0.01);
            TestLength("0.000 m", 0);
            TestLength("1.000 m", 1);
            TestLength("512.000 m", 512);
        }

        [Test]
        public void TestToAutoscaledString() {
            //for length, the autoscaled unit is matched to inch
            TestLength("3.937 in", 0.1);
            Assert.AreEqual("10.000 cm", Length.FromMillimeters(100).ToUnit(Length.Centimeter).ToString());
            TestLength("1.000 km", 1000);
            TestLength("15.240 km", 15240);
        }

        [Test]
        public void TestVariousScales() {
            Length l1 = Length.FromMiles(4.87);
            Length l2 = Length.FromFeet(243);
            Length l3 = new(146.998);
            Length l4 = (Length)"2458.6 m";

            Assert.AreEqual("7.837 km", l1.ToUnit(Length.Kilometer).AsString());
            Assert.AreEqual("74.066 m", l2.ToString());
            Assert.AreEqual("0.091 mi", l3.ToString(Length.Mile));
            Assert.AreEqual("2.459 km", l4.ToString());
        }

        [Test]
        public void TestConversion() {
            Assert.AreEqual(Length.Meter, (Unit)"m");
            Assert.AreEqual(Length.Millimeter, (Unit)"mm");
            Assert.AreEqual(Length.Mile, (Unit)"mi");
            var area = new Length(1.024, Length.Meter) * new Length(1.024, Length.Meter);
            Assert.IsAssignableFrom(typeof(Area), area);
            Assert.AreEqual(new Area(1.049, Area.SquareMeter).ToString(), area.ToString());
        }
    }
}