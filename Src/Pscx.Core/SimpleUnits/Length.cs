// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Length quantities and units
    /// </summary>
    /// <see href="https://github.com/angularsen/UnitsNet">Units.Net library</see>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    [Serializable]
    public struct Length : IQuantity {
        public static readonly Unit Micrometer = Unit.GetUnit("Micrometer", "µm,um", QuantityType.Length, 1e-6);
        public static readonly Unit Millimeter = Unit.GetUnit("Millimeter", "mm", QuantityType.Length, 1e-3);
        public static readonly Unit Centimeter = Unit.GetUnit("Centimeter", "cm", QuantityType.Length, 1e-2);
        public static readonly Unit Inch = Unit.GetUnit("Inch", "in,''", QuantityType.Length, 0.0254);
        public static readonly Unit Foot = Unit.GetUnit("Foot", "ft,'", QuantityType.Length, 0.3048);
        public static readonly Unit Yard = Unit.GetUnit("Yard", "yd", QuantityType.Length, 0.9144);
        public static readonly Unit Kilometer = Unit.GetUnit("Kilometer", "km", QuantityType.Length, 1000);
        public static readonly Unit Mile = Unit.GetUnit("Mile", "mi", QuantityType.Length, 1609.34);
        public static readonly Unit NauticalMile = Unit.GetUnit("Nautical Mile", "nm", QuantityType.Length, 1852);
        public static readonly Unit LightYear = Unit.GetUnit("Light Year", "ly", QuantityType.Length, 9.461e+15);
        public static readonly Unit Meter = Unit.GetStandardUnit("Meter", "m", QuantityType.Length);

        private static readonly Unit _canonicalUnit = Meter;

        public Length(double value) {
            CanonicalValue = value;
            QuantityType = QuantityType.Length;
        }

        public Length(double value, Unit unit) : this(new Measurement(value, unit)) {}

        public Length(Measurement msmt) : this(msmt?.Canonical ?? 0) {
            if (msmt != null && msmt.unit.QuantityType != QuantityType.Length) {
                throw new ArgumentException($"Unit {msmt.unit.Name} is not an Length type unit");
            }
        }

        public Length(string strValue) : this((Measurement)strValue) {}

        public double Millimeters {
            get => Millimeter.FromStandard(CanonicalValue); set => CanonicalValue = Millimeter.ToStandard(value);
        }

        public double Inches {
            get => Inch.FromStandard(CanonicalValue); set => CanonicalValue = Inch.ToStandard(value);
        }

        public double Feet {
            get => Foot.FromStandard(CanonicalValue); set => CanonicalValue = Foot.ToStandard(value);
        }

        public double Yards {
            get => Yard.FromStandard(CanonicalValue); set => CanonicalValue = Yard.ToStandard(value);
        }

        public double Miles {
            get => Mile.FromStandard(CanonicalValue); set => CanonicalValue = Mile.ToStandard(value);
        }

        public double Kilometers {
            get => Kilometer.FromStandard(CanonicalValue); set => CanonicalValue = Kilometer.ToStandard(value);
        }

        public double Meters {
            get => CanonicalValue; set => CanonicalValue = value;
        }

        public double CanonicalValue { get; private set; }
        public Measurement Measurement => new (CanonicalValue, _canonicalUnit);
        public Measurement ToUnit(Unit unit) {
            if (unit.QuantityType != _canonicalUnit.QuantityType) {
                throw new InvalidOperationException($"Incompatible units: cannot convert {_canonicalUnit.Name} into {unit.Name}");
            }
            return new (unit.FromStandard(CanonicalValue), unit);
        } 
        public QuantityType QuantityType { get; private set; }
        public Unit CanonicalUnit => _canonicalUnit;
        public string ToString(Unit unit) => ToUnit(unit).AsString();
        public List<Unit> Units { get; } = UnitHelper.GetQuantityUnits(QuantityType.Length);
        public override string ToString() => Measurement.AsAutoScaledString();

        public override int GetHashCode() => CanonicalValue.GetHashCode();
        public bool Equals(IQuantity other) => Equals((object)other);
        public override bool Equals(object other) {
            if (other is Length length) {
                //use a tolerance approach due to uncertainty in double represenation - e.g. 0.33333 is not equal with 1/3
                return Math.Abs(CanonicalValue - length.CanonicalValue) <= (Unit.Precision * CanonicalValue);
            }
            return false;
        }
        public int CompareTo(IQuantity other) => CompareTo((object)other);
        public int CompareTo(object obj) {
            if (obj is Length length) {
                return CanonicalValue.CompareTo(length.CanonicalValue);
            }
            throw PscxArgumentException.ObjectMustBeOfType("obj", typeof(Length));
        }

        public static Length FromMillimeters(double millimeters) => new(0) { Millimeters = millimeters };
        public static Length FromInches(double inches) => new(0) { Inches = inches };
        public static Length FromFeet(double feet) => new(0) { Feet = feet };
        public static Length FromYards(double yards) => new(0) { Yards = yards };
        public static Length FromMiles(double miles) => new(0) { Miles = miles };

        public static explicit operator double(Length l) => l.CanonicalValue;
        public static explicit operator Measurement(Length l) => l.Measurement;
        public static explicit operator Length(string value) => new (value);
        public static Length operator -(Length ar) => new(-ar.CanonicalValue);
        public static Length operator +(Length ti) => ti;
        public static Length operator -(Length x, Length y) => new(x.CanonicalValue - y.CanonicalValue);
        public static Length operator -(Length x, Measurement y) =>
            y.unit.QuantityType == QuantityType.Length ? new Length(x.CanonicalValue - y.Canonical) : throw new ArgumentException("Operand unit not compatible with Length");
        public static Length operator +(Length x, Length y) => new(x.CanonicalValue + y.CanonicalValue);
        public static Length operator +(Length x, Measurement y) => 
            y.unit.QuantityType == QuantityType.Length ? new Length(x.CanonicalValue + y.Canonical) : throw new ArgumentException("Operand unit not compatible with Length");
        public static Length operator *(Length x, double factor) => new(x.CanonicalValue * factor);
        public static Area operator *(Length x, Length factor) => new(x.Meters * factor.Meters, Area.SquareMeter);
        public static Volume operator *(Length x, Area factor) => new(x.Meters * factor.SquareMeters, Volume.CubicMeter);
        public static Length operator /(Length x, double factor) => new(x.CanonicalValue / factor);
        public static bool operator ==(Length x, Length y) => Equals(x, y);
        public static bool operator !=(Length x, Length y) => !Equals(x, y);
        public static bool operator >(Length x, Length y) => x.CanonicalValue > y.CanonicalValue;
        public static bool operator >=(Length x, Length y) => x.CanonicalValue >= y.CanonicalValue;
        public static bool operator <(Length x, Length y) => x.CanonicalValue < y.CanonicalValue;
        public static bool operator <=(Length x, Length y) => x.CanonicalValue <= y.CanonicalValue;
    }
}
