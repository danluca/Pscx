// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using NUnit.Framework;
using Pscx.SimpleUnits;

namespace PscxInternalTests.SimpleUnits {
    [TestFixture]
    public class UnitConversionTests {
        [Test]
        public void LengthConversionUsesCanonicalValue() {
            var distance = Length.FromMiles(1);

            Assert.That(distance.Meters, Is.EqualTo(1609.34).Within(0.001));
            Assert.That(distance.ToUnit(Length.Kilometer).value, Is.EqualTo(1.60934).Within(0.000001));
        }

        [Test]
        public void TemperatureConversionSupportsOffsetScales() {
            var freezing = new Temperature(32, Temperature.DegreeFahrenheit);

            Assert.That(freezing.Celsius, Is.EqualTo(0).Within(0.000001));
            Assert.That(freezing.ToUnit(Temperature.DegreeKelvin).value, Is.EqualTo(273.15).Within(0.000001));
        }

        [Test]
        public void ConversionRejectsIncompatibleQuantities() {
            var distance = new Length(1);

            Assert.That(
                () => distance.ToUnit(TimeInterval.Second),
                Throws.InvalidOperationException);
        }
    }
}
