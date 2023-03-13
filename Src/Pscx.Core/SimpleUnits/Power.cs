// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Power quantities and units
    /// </summary>
    /// <see href="https://github.com/angularsen/UnitsNet">Units.Net library</see>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    [Serializable]
    public struct Power : IQuantity {
        public static readonly Unit HorsePower = Unit.GetUnit("Horse Power", "hp", QuantityType.Power, 745.7);
        public static readonly Unit KiloWatt = Unit.GetUnit("Kilowatt", "kW", QuantityType.Power, 1e+3);
        public static readonly Unit MegaWatt = Unit.GetUnit("Megawatt", "MW", QuantityType.Power, 1e+6);
        public static readonly Unit Watt = Unit.GetStandardUnit("Watt", "W", QuantityType.Power);
        public static readonly Unit _canonicalUnit = Watt;

        public Power(double value) {
            CanonicalValue = value;
            QuantityType = QuantityType.Power;
        }

        public Power(double value, Unit unit) : this(new Measurement(value, unit)) {}
        public Power(string value) : this((Measurement)value) {}

        public Power(Measurement msmt) : this(msmt?.Canonical ?? 0) {
            if (msmt != null && msmt.unit.QuantityType != QuantityType.Power) {
                throw new ArgumentException($"Unit {msmt.unit.Name} is not a Digital Power type unit");
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
        public List<Unit> Units { get; } = UnitHelper.GetQuantityUnits(QuantityType.Power);

        public double Kilowatts {
            get => KiloWatt.FromStandard(CanonicalValue); set => CanonicalValue = KiloWatt.ToStandard(value);
        }

        public double Megawatts {
            get => MegaWatt.FromStandard(CanonicalValue); set => CanonicalValue = MegaWatt.ToStandard(value);
        }

        public double HorsesPower {
            get => HorsePower.FromStandard(CanonicalValue); set => CanonicalValue = HorsePower.ToStandard(value);
        }

        public double Watts {
            get => CanonicalValue; set => CanonicalValue = value;
        }

        public int CompareTo(IQuantity other) => CompareTo(other);
        public bool Equals(IQuantity other) {
            if (other is Power data) {
                //use a tolerance approach due to uncertainty in double represenation - e.g. 0.33333 is not equal with 1/3
                return Math.Abs(CanonicalValue - data.CanonicalValue) <= (Unit.Precision * CanonicalValue);
            }
            return false;
        }
        public int CompareTo(object obj) {
            if (obj is Power data) {
                return CanonicalValue.CompareTo(data.CanonicalValue);
            }
            throw PscxArgumentException.ObjectMustBeOfType("obj", typeof(Power));
        }

        public override string ToString() => Measurement.AsAutoScaledString();
        public string ToString(Unit unit) => ToUnit(unit).AsString();

        public static Power FromKilowatts(double kilowatts) => new(0) { Kilowatts = kilowatts };
        public static Power FromMegawatts(double megawatts) => new(0) { Megawatts = megawatts };
        public static Power FromHorsePower(double hp) => new(0) { HorsesPower = hp };

        public static explicit operator double(Power e) => e.CanonicalValue;
        public static explicit operator Measurement(Power l) => l.Measurement;
        public static explicit operator Power(string value) => new (value);
        public static Power operator -(Power ar) => new(-ar.CanonicalValue);
        public static Power operator +(Power ti) => ti;
        public static Power operator -(Power x, Power y) => new(x.CanonicalValue - y.CanonicalValue);
        public static Power operator -(Power x, Measurement y) =>
            y.unit.QuantityType == QuantityType.Power ? new Power(x.CanonicalValue - y.Canonical) : throw new ArgumentException("Operand unit not compatible with Power");
        public static Power operator +(Power x, Power y) => new(x.CanonicalValue + y.CanonicalValue);
        public static Power operator +(Power x, Measurement y) => 
            y.unit.QuantityType == QuantityType.Power ? new Power(x.CanonicalValue + y.Canonical) : throw new ArgumentException("Operand unit not compatible with Power");
        public static Power operator *(Power x, double factor) => new(x.CanonicalValue * factor);
        public static Energy operator *(Power x, TimeInterval ti) => new(x.Watts * ti.Hours, Energy.WattHour);
        public static Power operator /(Power x, double factor) => new(x.CanonicalValue / factor);
        public static bool operator ==(Power x, Power y) => Equals(x, y);
        public static bool operator !=(Power x, Power y) => !Equals(x, y);
        public static bool operator >(Power x, Power y) => x.CanonicalValue > y.CanonicalValue;
        public static bool operator >=(Power x, Power y) => x.CanonicalValue >= y.CanonicalValue;
        public static bool operator <(Power x, Power y) => x.CanonicalValue < y.CanonicalValue;
        public static bool operator <=(Power x, Power y) => x.CanonicalValue <= y.CanonicalValue;
    }
}
