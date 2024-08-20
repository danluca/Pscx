using NUnit.Framework;
using Pscx.SimpleUnits;

namespace PscxUnitTests.SimpleUnits {
    [TestFixture]
    public class LengthTests {
        private static void TestLength(string expected, double meters) {
            Assert.That(expected, Is.EqualTo(new Length(meters).ToString()));
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
            Assert.That("10.000 cm", Is.EqualTo(Length.FromMillimeters(100).ToUnit(Length.Centimeter).ToString()));
            TestLength("1.000 km", 1000);
            TestLength("15.240 km", 15240);
        }

        [Test]
        public void TestVariousScales() {
            Length l1 = Length.FromMiles(4.87);
            Length l2 = Length.FromFeet(243);
            Length l3 = new(146.998);
            Length l4 = (Length)"2458.6 m";

            Assert.That("7.837 km", Is.EqualTo(l1.ToUnit(Length.Kilometer).AsString()));
            Assert.That("74.066 m", Is.EqualTo(l2.ToString()));
            Assert.That("0.091 mi", Is.EqualTo(l3.ToString(Length.Mile)));
            Assert.That("2.459 km", Is.EqualTo(l4.ToString()));
        }

        [Test]
        public void TestConversion() {
            Assert.That(Length.Meter, Is.EqualTo((Unit)"m"));
            Assert.That(Length.Millimeter, Is.EqualTo((Unit)"mm"));
            Assert.That(Length.Mile, Is.EqualTo((Unit)"mi"));
            var area = new Length(1.024, Length.Meter) * new Length(1.024, Length.Meter);
            Assert.That(area, Is.AssignableTo(typeof(Area)));
            Assert.That(new Area(1.049, Area.SquareMeter).ToString(), Is.EqualTo(area.ToString()));
        }
    }
}