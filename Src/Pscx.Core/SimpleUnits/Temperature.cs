// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Temperature quantities and units
    /// </summary>
    /// <see href="https://github.com/angularsen/UnitsNet">Units.Net library</see>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    [Serializable]
    public struct Temperature : IQuantity {
        public static readonly Unit DegreeFahrenheit = Unit.GetUnit("Degree Fahrenheit", "°F,F", QuantityType.Temperature, f=> (f-32)*5/9, c=> c*9/5+32);
        public static readonly Unit DegreeKelvin = Unit.GetUnit("Degree Kelvin", "°K,K", QuantityType.Temperature, k=> k-273.15, c=> c+273.15);
        public static readonly Unit DegreeCelsius = Unit.GetStandardUnit("Degree Celsius", "°C,C", QuantityType.Temperature);
        public static readonly Unit _canonicalUnit = DegreeCelsius;

        public Temperature(double value) {
            CanonicalValue = value;
            QuantityType = QuantityType.Mass;
        }
        public Temperature(double value, Unit unit) : this(new Measurement(value, unit)) {}
        public Temperature(string value) : this((Measurement)value) {}

        public Temperature(Measurement msmt) : this(msmt?.Canonical ?? 0) {
            if (msmt != null && msmt.unit.QuantityType != QuantityType.Temperature) {
                throw new ArgumentException($"Unit {msmt.unit.Name} is not a Temperature type unit");
            }
        }
        public double Fahrenheit {
            get => DegreeCelsius.FromStandard(CanonicalValue); set => CanonicalValue = DegreeCelsius.ToStandard(value);
        }

        public double Kelvin {
            get => DegreeKelvin.FromStandard(CanonicalValue); set => CanonicalValue = DegreeKelvin.ToStandard(value);
        }

        public double Celsius {
            get => CanonicalValue; set => CanonicalValue = value;
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
        public List<Unit> Units { get; } = UnitHelper.GetQuantityUnits(QuantityType.Temperature);
        public override string ToString() => Measurement.AsAutoScaledString();

        public override int GetHashCode() => CanonicalValue.GetHashCode();
        public bool Equals(IQuantity other) => Equals((object)other);
        public override bool Equals(object other) {
            if (other is Temperature temperature) {
                //use a tolerance approach due to uncertainty in double represenation - e.g. 0.33333 is not equal with 1/3
                return Math.Abs(CanonicalValue - temperature.CanonicalValue) <= (Unit.Precision * CanonicalValue);
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

        public static Temperature FromFahrenheit(double fahrenheit) => new (0) { Fahrenheit = fahrenheit };
        public static Temperature FromKelvin(double kelvin) => new (0) { Kelvin = kelvin };

        public static explicit operator double(Temperature m) => m.CanonicalValue;
        public static explicit operator Measurement(Temperature l) => l.Measurement;
        public static explicit operator Temperature(string value) => new (value);
        public static Temperature operator -(Temperature ar) => new(-ar.CanonicalValue);
        public static Temperature operator +(Temperature ti) => ti;
        public static Temperature operator -(Temperature x, Temperature y) => new(x.CanonicalValue - y.CanonicalValue);
        public static Temperature operator -(Temperature x, Measurement y) =>
            y.unit.QuantityType == QuantityType.Temperature ? new Temperature(x.CanonicalValue - y.Canonical) : throw new ArgumentException("Operand unit not compatible with Temperature");
        public static Temperature operator +(Temperature x, Temperature y) => new(x.CanonicalValue + y.CanonicalValue);
        public static Temperature operator +(Temperature x, Measurement y) => 
            y.unit.QuantityType == QuantityType.Temperature ? new Temperature(x.CanonicalValue + y.Canonical) : throw new ArgumentException("Operand unit not compatible with Temperature");
        public static Temperature operator *(Temperature x, double factor) => new(x.CanonicalValue * factor);
        public static Temperature operator /(Temperature x, double factor) => new(x.CanonicalValue / factor);
        public static bool operator ==(Temperature x, Temperature y) => Equals(x, y);
        public static bool operator !=(Temperature x, Temperature y) => !Equals(x, y);
        public static bool operator >(Temperature x, Temperature y) => x.CanonicalValue > y.CanonicalValue;
        public static bool operator >=(Temperature x, Temperature y) => x.CanonicalValue >= y.CanonicalValue;
        public static bool operator <(Temperature x, Temperature y) => x.CanonicalValue < y.CanonicalValue;
        public static bool operator <=(Temperature x, Temperature y) => x.CanonicalValue <= y.CanonicalValue;
    }
}
