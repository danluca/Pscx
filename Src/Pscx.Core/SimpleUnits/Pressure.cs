// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Pressure quantities and units
    /// </summary>
    /// <see href="https://github.com/angularsen/UnitsNet">Units.Net library</see>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    [Serializable]
    public struct Pressure : IQuantity {
        public static readonly Unit Bar = Unit.GetUnit("Bar", "Ba", QuantityType.Pressure, 1e+5);
        public static readonly Unit PoundForcePerSquareInch = Unit.GetUnit("Pound-force per square inch", "psi", QuantityType.Pressure, 6894.76);
        public static readonly Unit Atmosphere = Unit.GetUnit("Atmosphere", "atm", QuantityType.Pressure, 101325);
        public static readonly Unit Torr = Unit.GetUnit("Torr", "tor", QuantityType.Pressure, 133.322);
        public static readonly Unit Pascal = Unit.GetStandardUnit("Pascal", "Pa", QuantityType.Pressure);
        public static readonly Unit _canonicalUnit = Pascal;

        public Pressure(double value) {
            CanonicalValue = value;
            QuantityType = QuantityType.Pressure;
        }
        public Pressure(double value, Unit unit) : this(new Measurement(value, unit)) {}
        public Pressure(string value) : this((Measurement)value) {}

        public Pressure(Measurement msmt) : this(msmt?.Canonical ?? 0) {
            if (msmt != null && msmt.unit.QuantityType != QuantityType.Pressure) {
                throw new ArgumentException($"Unit {msmt.unit.Name} is not a Pressure type unit");
            }
        }

        public double Atmospheres {
            get => Atmosphere.FromStandard(CanonicalValue); set => CanonicalValue = Atmosphere.ToStandard(value);
        }
        public double Bars {
            get => Bar.FromStandard(CanonicalValue); set => CanonicalValue = Bar.ToStandard(value);
        }
        public double Psi {
            get => PoundForcePerSquareInch.FromStandard(CanonicalValue); set => CanonicalValue = PoundForcePerSquareInch.ToStandard(value);
        }
        public double Torrs {
            get => Torr.FromStandard(CanonicalValue); set => CanonicalValue = Torr.ToStandard(value);
        }
        public double Pascals {
            get => CanonicalValue; set => CanonicalValue = value;
        }

        public double CanonicalValue { get; private set; }
        public Measurement ToUnit(Unit unit)  {
            if (unit.QuantityType != _canonicalUnit.QuantityType) {
                throw new InvalidOperationException($"Incompatible units: cannot convert {_canonicalUnit.Name} into {unit.Name}");
            }
            return new (unit.FromStandard(CanonicalValue), unit);
        } 

        public QuantityType QuantityType { get; private set; }
        public Unit CanonicalUnit => _canonicalUnit;
        public string ToString(Unit unit) => ToUnit(unit).AsString();
        public Measurement Measurement => new (CanonicalValue, _canonicalUnit);
        public List<Unit> Units { get; } = UnitHelper.GetQuantityUnits(QuantityType.Pressure);
        public override string ToString() => Measurement.AsAutoScaledString();

        public int CompareTo(IQuantity other) => CompareTo(other);
        public bool Equals(IQuantity other) {
            if (other is Pressure pressure) {
                //use a tolerance approach due to uncertainty in double represenation - e.g. 0.33333 is not equal with 1/3
                return Math.Abs(CanonicalValue - pressure.CanonicalValue) <= (Unit.Precision * CanonicalValue);
            }
            return false;
        }
        public int CompareTo(object obj) {
            if (obj is Pressure pressure) {
                return CanonicalValue.CompareTo(pressure.CanonicalValue);
            }
            throw PscxArgumentException.ObjectMustBeOfType("obj", typeof(Pressure));
        }

        public static Pressure FromAtmospheres(double atmospheres) => new() { Atmospheres = atmospheres };
        public static Pressure FromBars(double bars) => new() { Bars = bars };
        public static Pressure FromPsi(double psi) => new() { Psi = psi };
        public static Pressure FromTorrs(double torrs) => new() { Torrs = torrs };

        public static explicit operator double(Pressure e) => e.CanonicalValue;
        public static explicit operator Measurement(Pressure l) => l.Measurement;
        public static explicit operator Pressure(string value) => new (value);
        public static Pressure operator -(Pressure ar) => new(-ar.CanonicalValue);
        public static Pressure operator +(Pressure ti) => ti;
        public static Pressure operator -(Pressure x, Pressure y) => new(x.CanonicalValue - y.CanonicalValue);
        public static Pressure operator -(Pressure x, Measurement y) =>
            y.unit.QuantityType == QuantityType.Pressure ? new Pressure(x.CanonicalValue - y.Canonical) : throw new ArgumentException("Operand unit not compatible with Pressure");
        public static Pressure operator +(Pressure x, Pressure y) => new(x.CanonicalValue + y.CanonicalValue);
        public static Pressure operator +(Pressure x, Measurement y) => 
            y.unit.QuantityType == QuantityType.Pressure ? new Pressure(x.CanonicalValue + y.Canonical) : throw new ArgumentException("Operand unit not compatible with Pressure");
        public static Pressure operator *(Pressure x, double factor) => new(x.CanonicalValue * factor);
        public static Pressure operator /(Pressure x, double factor) => new(x.CanonicalValue / factor);
        public static bool operator ==(Pressure x, Pressure y) => Equals(x, y);
        public static bool operator !=(Pressure x, Pressure y) => !Equals(x, y);
        public static bool operator >(Pressure x, Pressure y) => x.CanonicalValue > y.CanonicalValue;
        public static bool operator >=(Pressure x, Pressure y) => x.CanonicalValue >= y.CanonicalValue;
        public static bool operator <(Pressure x, Pressure y) => x.CanonicalValue < y.CanonicalValue;
        public static bool operator <=(Pressure x, Pressure y) => x.CanonicalValue <= y.CanonicalValue;
    }
}
