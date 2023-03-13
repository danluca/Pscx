// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Speed quantities and units
    /// </summary>
    /// <see href="https://github.com/angularsen/UnitsNet">Units.Net library</see>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    [Serializable]
    public struct Speed : IQuantity {
        private static readonly Unit FootPerSecond = Unit.GetUnit("Foot per Second", "ft/s", QuantityType.Speed, 0.3048);
        private static readonly Unit KilometerPerHour = Unit.GetUnit("Kilometer per Hour", "km/h", QuantityType.Speed, 1 / 3.6);
        private static readonly Unit MilePerHour = Unit.GetUnit("Mile per Hour", "mph", QuantityType.Speed, 1 / 2.237);
        private static readonly Unit Knot = Unit.GetUnit("Knots", "knot", QuantityType.Speed, 1 / 1.944);
        private static readonly Unit MeterPerSecond = Unit.GetStandardUnit("Meters per Second", "m/s", QuantityType.Speed);
        private static readonly Unit _canonicalUnit = MeterPerSecond;

        public Speed(double value) {
            CanonicalValue = value;
            QuantityType = QuantityType.Speed;
        }

        public Speed(double value, Unit unit) : this(new Measurement(value, unit)) {}
        public Speed(string value) : this((Measurement)value) {}

        public Speed(Measurement msmt) : this(msmt?.Canonical ?? 0) {
            if (msmt != null && msmt.unit.QuantityType != QuantityType.Speed) {
                throw new ArgumentException($"Unit {msmt.unit.Name} is not a Speed type unit");
            }
        }

        public double CanonicalValue { get; private set; }
        public Measurement ToUnit(Unit unit) {
            if (unit.QuantityType != _canonicalUnit.QuantityType) {
                throw new InvalidOperationException($"Incompatible units: cannot convert {_canonicalUnit.Name} into {unit.Name}");
            }
            return new (unit.FromStandard(CanonicalValue), unit);
        } 

        public double FeetPerSecond {
            get => FootPerSecond.FromStandard(CanonicalValue); set => CanonicalValue = FootPerSecond.ToStandard(value);
        }

        public double KilometersPerHour {
            get => KilometerPerHour.FromStandard(CanonicalValue); set => CanonicalValue = KilometerPerHour.ToStandard(value);
        }

        public double MilesPerHour {
            get => MilePerHour.FromStandard(CanonicalValue); set => CanonicalValue = MilePerHour.ToStandard(value);
        }

        public double Knots {
            get => Knot.FromStandard(CanonicalValue); set => CanonicalValue = Knot.ToStandard(value);
        }

        public double MetersPerSecond {
            get => CanonicalValue; set => CanonicalValue = value;
        }

        public QuantityType QuantityType { get; private set; }
        public Unit CanonicalUnit => _canonicalUnit;
        public Measurement Measurement => new (CanonicalValue, _canonicalUnit);
        public override string ToString() => Measurement.AsAutoScaledString();
        public string ToString(Unit unit) => ToUnit(unit).AsString();
        public List<Unit> Units { get; } = UnitHelper.GetQuantityUnits(QuantityType.Speed);

        public int CompareTo(IQuantity other) => CompareTo(other);
        public bool Equals(IQuantity other) {
            if (other is Speed speed) {
                //use a tolerance approach due to uncertainty in double represenation - e.g. 0.33333 is not equal with 1/3
                return Math.Abs(CanonicalValue - speed.CanonicalValue) <= (Unit.Precision * CanonicalValue);
            }
            return false;
        }
        public int CompareTo(object obj) {
            if (obj is Speed speed) {
                return CanonicalValue.CompareTo(speed.CanonicalValue);
            }
            throw PscxArgumentException.ObjectMustBeOfType("obj", typeof(Speed));
        }

        public static Speed FromFeetPerSecond(double feetPerSecond) => new(0) { FeetPerSecond = feetPerSecond };
        public static Speed FromKilometersPerHour(double kmPerHour) => new(0) { KilometersPerHour = kmPerHour };
        public static Speed FromMilesPerHour(double mph) => new(0) { MilesPerHour = mph };
        public static Speed FromKnots(double knots) => new(0) { Knots = knots };

        public static explicit operator double(Speed e) => e.CanonicalValue;
        public static explicit operator Measurement(Speed l) => l.Measurement;
        public static explicit operator Speed(string value) => new (value);
        public static Speed operator -(Speed ar) => new(-ar.CanonicalValue);
        public static Speed operator +(Speed ti) => ti;
        public static Speed operator -(Speed x, Speed y) => new(x.CanonicalValue - y.CanonicalValue);
        public static Speed operator -(Speed x, Measurement y) =>
            y.unit.QuantityType == QuantityType.Speed ? new Speed(x.CanonicalValue - y.Canonical) : throw new ArgumentException("Operand unit not compatible with Speed");
        public static Speed operator +(Speed x, Speed y) => new(x.CanonicalValue + y.CanonicalValue);
        public static Speed operator +(Speed x, Measurement y) => 
            y.unit.QuantityType == QuantityType.Speed ? new Speed(x.CanonicalValue + y.Canonical) : throw new ArgumentException("Operand unit not compatible with Speed");
        public static Speed operator *(Speed x, double factor) => new(x.CanonicalValue * factor);
        public static Length operator *(Speed x, TimeInterval factor) => new(x.MetersPerSecond * factor.Seconds, Length.Meter);
        public static Speed operator /(Speed x, double factor) => new(x.CanonicalValue / factor);
        public static bool operator ==(Speed x, Speed y) => Equals(x, y);
        public static bool operator !=(Speed x, Speed y) => !Equals(x, y);
        public static bool operator >(Speed x, Speed y) => x.CanonicalValue > y.CanonicalValue;
        public static bool operator >=(Speed x, Speed y) => x.CanonicalValue >= y.CanonicalValue;
        public static bool operator <(Speed x, Speed y) => x.CanonicalValue < y.CanonicalValue;
        public static bool operator <=(Speed x, Speed y) => x.CanonicalValue <= y.CanonicalValue;
    }
}
