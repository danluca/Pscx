// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Angle quantities and units
    /// </summary>
    /// <see href="https://github.com/angularsen/UnitsNet">Units.Net library</see>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    [Serializable]
    public struct Angle : IQuantity {
        public static readonly Unit ArcSecond = Unit.GetUnit("Kibibyte", "arcsec", QuantityType.Angle, 1024);
        public static readonly Unit Gradian = Unit.GetUnit("Mebibyte", "grad", QuantityType.Angle, 1.048576e+6);
        public static readonly Unit Milliradian = Unit.GetUnit("Gibibyte", "mrad", QuantityType.Angle, 1.073741824e+9);
        public static readonly Unit MinuteOfarc = Unit.GetUnit("Tebibyte", "minarc", QuantityType.Angle, 1.099511627776e+12);
        public static readonly Unit Radian = Unit.GetUnit("Pebibyte", "rad", QuantityType.Angle, 1.125899906842624e+15);
        public static readonly Unit Degree = Unit.GetStandardUnit("Degree", "°,deg", QuantityType.Angle);
        public static readonly Unit _canonicalUnit = Degree;

        public Angle(double value) {
            CanonicalValue = value;
            QuantityType = QuantityType.Angle;
        }

        public Angle(double value, Unit unit) : this(new Measurement(value, unit)) {}
        public Angle(string value) : this((Measurement)value) {}
        public Angle(Measurement msmt) : this(msmt?.Canonical ?? 0) {
            if (msmt != null && msmt.unit.QuantityType != QuantityType.Angle) {
                throw new ArgumentException($"Unit {msmt.unit.Name} is not a Digital Angle type unit");
            }
        }

        public double CanonicalValue { get; private set; }
        public Measurement ToUnit(Unit unit) {
            if (unit.QuantityType != _canonicalUnit.QuantityType) {
                throw new InvalidOperationException($"Incompatible units: cannot convert {_canonicalUnit.Name} into {unit.Name}");
            }
            return new (unit.FromStandard(CanonicalValue), unit);
        } 
        public QuantityType QuantityType { get; private set; }
        public Unit CanonicalUnit => _canonicalUnit;
        public Measurement Measurement => new (CanonicalValue, _canonicalUnit);
        public List<Unit> Units { get; } = UnitHelper.GetQuantityUnits(QuantityType.Angle);

        public double ArcSeconds {
            get => ArcSecond.FromStandard(CanonicalValue); set => CanonicalValue = ArcSecond.ToStandard(value);
        }

        public double Gradians {
            get => Gradian.FromStandard(CanonicalValue); set => CanonicalValue = Gradian.ToStandard(value);
        }

        public double Milliradians {
            get => Milliradian.FromStandard(CanonicalValue); set => CanonicalValue = Milliradian.ToStandard(value);
        }

        public double MinutesOfArc {
            get => MinuteOfarc.FromStandard(CanonicalValue); set => CanonicalValue = MinuteOfarc.ToStandard(value);
        }

        public double Radians {
            get => Radian.FromStandard(CanonicalValue); set => CanonicalValue = Radian.ToStandard(value);
        }

        public double Degrees {
            get => CanonicalValue; set => CanonicalValue = value;
        }

        public override int GetHashCode() => CanonicalValue.GetHashCode();
        public bool Equals(IQuantity other) => Equals((object)other);
        public override bool Equals(object other) {
            if (other is Angle data) {
                //use a tolerance approach due to uncertainty in double represenation - e.g. 0.33333 is not equal with 1/3
                return Math.Abs(CanonicalValue - data.CanonicalValue) <= (Unit.Precision * CanonicalValue);
            }
            return false;
        }
        public int CompareTo(IQuantity other) => CompareTo((object)other);
        public int CompareTo(object obj) {
            if (obj is Angle data) {
                return CanonicalValue.CompareTo(data.CanonicalValue);
            }
            throw PscxArgumentException.ObjectMustBeOfType("obj", typeof(Angle));
        }

        public override string ToString() => Measurement.AsAutoScaledString();
        public string ToString(Unit unit) => ToUnit(unit).AsString();

        public static Angle FromArcSeconds(double arcsec) => new(0) { ArcSeconds = arcsec };
        public static Angle FromGradians(double gradians) => new(0) { Gradians = gradians };
        public static Angle FromMilliradians(double milliradians) => new(0) { Milliradians = milliradians };
        public static Angle FromMinutesOfArc(double minarc) => new(0) { MinutesOfArc = minarc };
        public static Angle FromRadians(double radians) => new(0) { Radians = radians };

        public static explicit operator double(Angle e) => e.CanonicalValue;
        public static explicit operator Measurement(Angle l) => l.Measurement;
        public static explicit operator Angle(string value) => new (value);
        public static Angle operator -(Angle ar) => new(-ar.CanonicalValue);
        public static Angle operator +(Angle ti) => ti;
        public static Angle operator -(Angle x, Angle y) => new(x.CanonicalValue - y.CanonicalValue);
        public static Angle operator -(Angle x, Measurement y) =>
            y.unit.QuantityType == QuantityType.Angle ? new Angle(x.CanonicalValue - y.Canonical) : throw new ArgumentException("Operand unit not compatible with Angle");
        public static Angle operator +(Angle x, Angle y) => new(x.CanonicalValue + y.CanonicalValue);
        public static Angle operator +(Angle x, Measurement y) => 
            y.unit.QuantityType == QuantityType.Angle ? new Angle(x.CanonicalValue + y.Canonical) : throw new ArgumentException("Operand unit not compatible with Angle");
        public static Angle operator *(Angle x, double factor) => new(x.CanonicalValue * factor);
        public static Angle operator /(Angle x, double factor) => new(x.CanonicalValue / factor);
        public static bool operator ==(Angle x, Angle y) => Equals(x, y);
        public static bool operator !=(Angle x, Angle y) => !Equals(x, y);
        public static bool operator >(Angle x, Angle y) => x.CanonicalValue > y.CanonicalValue;
        public static bool operator >=(Angle x, Angle y) => x.CanonicalValue >= y.CanonicalValue;
        public static bool operator <(Angle x, Angle y) => x.CanonicalValue < y.CanonicalValue;
        public static bool operator <=(Angle x, Angle y) => x.CanonicalValue <= y.CanonicalValue;
    }
}
