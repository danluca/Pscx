// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Volume quantities and units
    /// </summary>
    /// <see href="https://github.com/angularsen/UnitsNet">Units.Net library</see>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    [Serializable]
    public struct Volume : IQuantity {
        public static readonly Unit Gallon = Unit.GetUnit("Gallon", "gal", QuantityType.Volume, 3.78541);
        public static readonly Unit Quart = Unit.GetUnit("Quart", "qt", QuantityType.Volume, 0.946353);
        public static readonly Unit Pint = Unit.GetUnit("Pint", "pt", QuantityType.Volume, 0.473176);
        public static readonly Unit Cup = Unit.GetUnit("Cup", "c", QuantityType.Volume, 0.24);
        public static readonly Unit FluidOunce = Unit.GetUnit("Fluid Ounce", "floz", QuantityType.Volume, 1/33.814);
        public static readonly Unit Tablespoon = Unit.GetUnit("Tablespoon", "tbsp", QuantityType.Volume, 1/67.628);
        public static readonly Unit Teaspoon = Unit.GetUnit("Teaspoon", "tsp", QuantityType.Volume, 1/202.9);
        public static readonly Unit CubicMeter = Unit.GetUnit("Cubic meter", "m³,m3", QuantityType.Volume, 1e+3);
        public static readonly Unit Milliliter = Unit.GetUnit("Milliliter", "ml", QuantityType.Volume, 1e-3);
        public static readonly Unit ImperialGallon = Unit.GetUnit("Imperial Gallon", "igal", QuantityType.Volume, 4.54609);
        public static readonly Unit ImperialQuart = Unit.GetUnit("Imperial Quart", "iqt", QuantityType.Volume, 1.13652);
        public static readonly Unit ImperialPint = Unit.GetUnit("Imperial Pint", "ipt", QuantityType.Volume, 1/1.76);
        public static readonly Unit ImperialCup = Unit.GetUnit("Imperial Cup", "ic", QuantityType.Volume, 1/3.52);
        public static readonly Unit ImperialFluidOunce = Unit.GetUnit("Imperial Fluid Ounce", "ifloz", QuantityType.Volume, 1/35.195);
        public static readonly Unit ImperialTablespoon = Unit.GetUnit("Imperial Tablespoon", "itbsp", QuantityType.Volume, 1/56.312);
        public static readonly Unit ImperialTeaspoon = Unit.GetUnit("Imperial Teaspoon", "itsp", QuantityType.Volume, 1/168.9);
        public static readonly Unit CubicFoot = Unit.GetUnit("Cubic foot", "ft³,cuft", QuantityType.Volume, 28.3168);
        public static readonly Unit CubicInch = Unit.GetUnit("Cubic inch", "in³,cuin", QuantityType.Volume, 1/61.024); 
        public static readonly Unit Liter = Unit.GetStandardUnit("Liter", "l", QuantityType.Volume);
        private static readonly Unit _canonicalUnit = Liter;

        /// <summary>
        /// Creates new area, assuming canonical unit
        /// </summary>
        /// <param name="value"></param>
        public Volume(double value) {
            CanonicalValue = value;
            QuantityType = QuantityType.Volume;
        }

        public Volume(double value, Unit unit) : this(new Measurement(value, unit)) {}

        public Volume(Measurement msmt) : this(msmt?.Canonical ?? 0) {
            if (msmt != null && msmt.unit.QuantityType != QuantityType.Volume) {
                throw new ArgumentException($"Unit {msmt.unit.Name} is not a Volume type unit");
            }
        }
        public Volume(string value) : this((Measurement)value) {}

        public double Milliliters {
            get => Milliliter.FromStandard(CanonicalValue); set => CanonicalValue = Milliliter.ToStandard(value);
        }

        public double Gallons {
            get => Gallon.FromStandard(CanonicalValue); set => CanonicalValue = Gallon.ToStandard(value);
        }

        public double FluidOunces {
            get => FluidOunce.FromStandard(CanonicalValue); set => CanonicalValue = FluidOunce.ToStandard(value);
        }

        public double CubicMeters {
            get => CubicMeter.FromStandard(CanonicalValue); set => CanonicalValue = CubicMeter.ToStandard(value);
        }

        public double CubicFeet {
            get => CubicFoot.FromStandard(CanonicalValue); set => CanonicalValue = CubicFoot.ToStandard(value);
        }

        public double Cups {
            get => Cup.FromStandard(CanonicalValue); set => CanonicalValue = Cup.ToStandard(value);
        }

        public double Tablespoons {
            get => Tablespoon.FromStandard(CanonicalValue); set => CanonicalValue = Tablespoon.ToStandard(value);
        }

        public double Teaspoons {
            get => Teaspoon.FromStandard(CanonicalValue); set => CanonicalValue = Teaspoon.ToStandard(value);
        }

        public double Liters {
            get => CanonicalValue; set => CanonicalValue = value;
        }

        public override string ToString() => Measurement.AsAutoScaledString();
        public string ToString(Unit unit) => ToUnit(unit).AsString();
        public Measurement Measurement => new (CanonicalValue, _canonicalUnit);
        public double CanonicalValue { get; private set; }
        public QuantityType QuantityType { get; private set; }
        public Unit CanonicalUnit => _canonicalUnit;
        public List<Unit> Units { get; } = UnitHelper.GetQuantityUnits(QuantityType.Volume);
        public Measurement ToUnit(Unit unit) {
            if (unit.QuantityType != _canonicalUnit.QuantityType) {
                throw new InvalidOperationException($"Incompatible units: cannot convert {_canonicalUnit.Name} into {unit.Name}");
            }
            return new (unit.FromStandard(CanonicalValue), unit);
        } 

        public override int GetHashCode() => CanonicalValue.GetHashCode();
        public bool Equals(IQuantity other) => Equals((object)other);
        public override bool Equals(object other) {
            if (other is Volume volume) {
                //use a tolerance approach due to uncertainty in double representation - e.g. 0.33333 is not equal with 1/3
                return Math.Abs(CanonicalValue - volume.CanonicalValue) <= (Unit.Precision * CanonicalValue);
            }
            return false;
        }
        public int CompareTo(IQuantity other) => CompareTo((object)other);
        public int CompareTo(object obj) {
            if (obj is Area area) {
                return CanonicalValue.CompareTo(area.CanonicalValue);
            }
            throw PscxArgumentException.ObjectMustBeOfType("obj", typeof(Area));
        }

        public static Volume FromMilliliters(double ml) => new(0) { Milliliters = ml };
        public static Volume FromGallons(double gallons) => new(0) { Gallons = gallons };
        public static Volume FromFluidOunces(double floz) => new(0) { FluidOunces = floz };
        public static Volume FromCubicMeters(double cubicMeters) => new(0) { CubicMeters = cubicMeters };
        public static Volume FromCubicFeet(double cuft) => new(0) { CubicFeet = cuft };
        public static Volume FromCups(double cups) => new(0) { Cups = cups };
        public static Volume FromTablespoons(double tbsp) => new(0) { Tablespoons = tbsp };
        public static Volume FromTeaspoons(double tsp) => new(0) { Teaspoons = tsp };

        public static explicit operator double(Volume l) => l.CanonicalValue;
        public static explicit operator Measurement(Volume l) => l.Measurement;
        public static explicit operator Volume(string value) => new (value);
        public static Volume operator -(Volume ar) => new(-ar.CanonicalValue);
        public static Volume operator +(Volume ti) => ti;
        public static Volume operator -(Volume x, Volume y) => new(x.CanonicalValue - y.CanonicalValue);
        public static Volume operator -(Volume x, Measurement y) =>
            y.unit.QuantityType == QuantityType.Volume ? new Volume(x.CanonicalValue - y.Canonical) : throw new ArgumentException("Operand unit not compatible with Volume");
        public static Volume operator +(Volume x, Volume y) => new(x.CanonicalValue + y.CanonicalValue);
        public static Volume operator +(Volume x, Measurement y) => 
            y.unit.QuantityType == QuantityType.Volume ? new Volume(x.CanonicalValue + y.Canonical) : throw new ArgumentException("Operand unit not compatible with Volume");
        public static Volume operator *(Volume x, double factor) => new(x.CanonicalValue * factor);
        public static Volume operator /(Volume x, double factor) => new(x.CanonicalValue / factor);
        public static Area operator /(Volume x, Length factor) => new(x.CubicMeters / factor.Meters, Area.SquareMeter);
        public static Length operator /(Volume x, Area factor) => new(x.CubicMeters / factor.SquareMeters, Length.Meter);
        public static bool operator ==(Volume x, Volume y) => Equals(x, y);
        public static bool operator !=(Volume x, Volume y) => !Equals(x, y);
        public static bool operator >(Volume x, Volume y) => x.CanonicalValue > y.CanonicalValue;
        public static bool operator >=(Volume x, Volume y) => x.CanonicalValue >= y.CanonicalValue;
        public static bool operator <(Volume x, Volume y) => x.CanonicalValue < y.CanonicalValue;
        public static bool operator <=(Volume x, Volume y) => x.CanonicalValue <= y.CanonicalValue;
    }
}
