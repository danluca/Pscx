// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Mass quantities and units
    /// </summary>
    /// <see href="https://github.com/angularsen/UnitsNet">Units.Net library</see>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    [Serializable]
    public struct Mass : IQuantity {
        public static readonly Unit Milligram = Unit.GetUnit("Milligram", "mg", QuantityType.Mass, 1e-6);
        public static readonly Unit Gram = Unit.GetUnit("Gram", "g", QuantityType.Mass, 1e-3);
        public static readonly Unit Ounce = Unit.GetUnit("Ounce", "oz", QuantityType.Mass, 0.0283495);
        public static readonly Unit Pound = Unit.GetUnit("Pound", "lb", QuantityType.Mass, 0.453592);
        public static readonly Unit Stone = Unit.GetUnit("Stone", "st", QuantityType.Mass, 6.35029);
        public static readonly Unit USTon = Unit.GetUnit("US Ton", "ut", QuantityType.Mass, 907.185);
        public static readonly Unit Ton = Unit.GetUnit("Ton", "t", QuantityType.Mass, 1e+3);
        public static readonly Unit ImperialTon = Unit.GetUnit("Imperial Ton", "bt", QuantityType.Mass, 1016.05);
        public static readonly Unit Kilogram = Unit.GetStandardUnit("Kilogram", "kg", QuantityType.Mass);
        public static readonly Unit _canonicalUnit = Kilogram;

        public Mass(double value) {
            CanonicalValue = value;
            QuantityType = QuantityType.Mass;
        }

        public Mass(double value, Unit unit) : this(new Measurement(value, unit)) {}
        public Mass(string value) : this((Measurement)value) {}

        public Mass(Measurement msmt) : this(msmt?.Canonical ?? 0) {
            if (msmt != null && msmt.unit.QuantityType != QuantityType.Mass) {
                throw new ArgumentException($"Unit {msmt.unit.Name} is not a Mass type unit");
            }
        }

        public double Pounds {
            get => Pound.FromStandard(CanonicalValue); set => CanonicalValue = Pound.ToStandard(value);
        }

        public double Ounces {
            get => Ounce.FromStandard(CanonicalValue); set => CanonicalValue = Ounce.ToStandard(value);
        }

        public double USTons {
            get => USTon.FromStandard(CanonicalValue); set => CanonicalValue = USTon.ToStandard(value);
        }

        public double Tons {
            get => Ton.FromStandard(CanonicalValue); set => CanonicalValue = Ton.ToStandard(value);
        }

        public double Kilograms {
            get => CanonicalValue; set => CanonicalValue = value;
        }

        public double Milligrams {
            get => Milligram.FromStandard(CanonicalValue); set => CanonicalValue = Milligram.ToStandard(value);
        }

        public double CanonicalValue { get; private set; }
        public Measurement ToUnit(Unit unit) {
            if (unit.QuantityType != _canonicalUnit.QuantityType) {
                throw new InvalidOperationException($"Incompatible units: cannot convert {_canonicalUnit.Name} into {unit.Name}");
            }
            return new (unit.FromStandard(CanonicalValue), unit);
        } 
        public QuantityType QuantityType { get; private set; }
        public string ToString(Unit unit) => ToUnit(unit).AsString();
        public Unit CanonicalUnit => _canonicalUnit;
        public Measurement Measurement => new (CanonicalValue, _canonicalUnit);
        public List<Unit> Units { get; } = UnitHelper.GetQuantityUnits(QuantityType.Mass);

        public override int GetHashCode() => CanonicalValue.GetHashCode();
        public bool Equals(IQuantity other) => Equals((object)other);
        public override bool Equals(object other) {
            if (other is Mass mass) {
                //use a tolerance approach due to uncertainty in double represenation - e.g. 0.33333 is not equal with 1/3
                return Math.Abs(CanonicalValue - mass.CanonicalValue) <= (Unit.Precision * CanonicalValue);
            }
            return false;
        }
        public int CompareTo(IQuantity other) => CompareTo((object)other);
        public int CompareTo(object obj) {
            if (obj is Mass mass) {
                return CanonicalValue.CompareTo(mass.CanonicalValue);
            }
            throw PscxArgumentException.ObjectMustBeOfType("obj", typeof(Mass));
        }
        public override string ToString() => Measurement.AsAutoScaledString();

        public static Mass FromOunces(double ounces) => new(0) { Ounces = ounces };
        public static Mass FromTons(double tons) => new(0) { Tons = tons };
        public static Mass FromUSTons(double tons) => new(0) { USTons = tons };
        public static Mass FromPounds(double pounds) => new(0) { Pounds = pounds };
        public static Mass FromKilograms(double kg) => new(0) { Kilograms = kg };
        public static Mass FromMilligrams(double mg) => new(0) { Milligrams = mg };

        public static explicit operator double(Mass m) => m.CanonicalValue;
        public static explicit operator Measurement(Mass l) => l.Measurement;
        public static explicit operator Mass(string value) => new (value);
        public static Mass operator -(Mass ar) => new(-ar.CanonicalValue);
        public static Mass operator +(Mass ti) => ti;
        public static Mass operator -(Mass x, Mass y) => new(x.CanonicalValue - y.CanonicalValue);
        public static Mass operator -(Mass x, Measurement y) =>
            y.unit.QuantityType == QuantityType.Mass ? new Mass(x.CanonicalValue - y.Canonical) : throw new ArgumentException("Operand unit not compatible with Mass");
        public static Mass operator +(Mass x, Mass y) => new(x.CanonicalValue + y.CanonicalValue);
        public static Mass operator +(Mass x, Measurement y) => 
            y.unit.QuantityType == QuantityType.Mass ? new Mass(x.CanonicalValue + y.Canonical) : throw new ArgumentException("Operand unit not compatible with Mass");
        public static Mass operator *(Mass x, double factor) => new(x.CanonicalValue * factor);
        public static Mass operator /(Mass x, double factor) => new(x.CanonicalValue / factor);
        public static bool operator ==(Mass x, Mass y) => Equals(x, y);
        public static bool operator !=(Mass x, Mass y) => !Equals(x, y);
        public static bool operator >(Mass x, Mass y) => x.CanonicalValue > y.CanonicalValue;
        public static bool operator >=(Mass x, Mass y) => x.CanonicalValue >= y.CanonicalValue;
        public static bool operator <(Mass x, Mass y) => x.CanonicalValue < y.CanonicalValue;
        public static bool operator <=(Mass x, Mass y) => x.CanonicalValue <= y.CanonicalValue;
    }
}
