// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Energy quantities and units
    /// </summary>
    /// <see href="https://github.com/angularsen/UnitsNet">Units.Net library</see>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    [Serializable]
    public struct Energy : IQuantity {
        public static readonly Unit ElectronVolt = Unit.GetUnit("ElectronVolt", "eV", QuantityType.Energy, 1.6022e-19);
        public static readonly Unit KiloelectronVolt = Unit.GetUnit("KiloelectronVolt", "keV", QuantityType.Energy, 1.6022e-16);
        public static readonly Unit MegaelectronVolt = Unit.GetUnit("MegaelectronVolt", "MeV", QuantityType.Energy, 1.6022e-13);
        public static readonly Unit FootPound = Unit.GetUnit("Foot pound", "ftlb", QuantityType.Energy, 1.35582);
        public static readonly Unit Calorie = Unit.GetUnit("Gram calorie", "Cal", QuantityType.Energy, 4.184);
        public static readonly Unit KiloJoule = Unit.GetUnit("KiloJoule", "kJ", QuantityType.Energy, 1000);
        public static readonly Unit BTU = Unit.GetUnit("British thermal unit", "BTU", QuantityType.Energy, 1055.06);
        public static readonly Unit WattHour = Unit.GetUnit("Watt hour", "Wh", QuantityType.Energy, 3600);
        public static readonly Unit KiloCalorie = Unit.GetUnit("KiloCalorie", "kCal", QuantityType.Energy, 4184);
        public static readonly Unit KilowattHour = Unit.GetUnit("Kilowatt hour", "kWh", QuantityType.Energy, 3.6e+6);
        public static readonly Unit MegawattHour = Unit.GetUnit("Megawatt hour", "MWh", QuantityType.Energy, 3.6e+9);
        public static readonly Unit Therm = Unit.GetUnit("US therm", "therm", QuantityType.Energy, 1.055e+8);
        public static readonly Unit Joule = Unit.GetStandardUnit("Joule", "J", QuantityType.Energy);
        public static readonly Unit _canonicalUnit = Joule;

        public Energy(double value) {
            CanonicalValue = value;
            QuantityType = QuantityType.Energy;
        }

        public Energy(double value, Unit unit) : this(new Measurement(value, unit)) {}
        public Energy(string value) : this((Measurement)value) {}

        public Energy(Measurement msmt) : this(msmt?.Canonical ?? 0) {
            if (msmt != null && msmt.unit.QuantityType != QuantityType.Energy) {
                throw new ArgumentException($"Unit {msmt.unit.Name} is not an Energy type unit");
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
        public List<Unit> Units { get; } = UnitHelper.GetQuantityUnits(QuantityType.Energy);
        public override string ToString() => Measurement.AsAutoScaledString();
        public string ToString(Unit unit) => ToUnit(unit).AsString();

        public double ElectronVolts {
            get => ElectronVolt.FromStandard(CanonicalValue); set => CanonicalValue = ElectronVolt.ToStandard(value);
        }

        public double Calories {
            get => Calorie.FromStandard(CanonicalValue); set => CanonicalValue = Calorie.ToStandard(value);
        }

        public double FootPounds {
            get => FootPound.FromStandard(CanonicalValue); set => CanonicalValue = FootPound.ToStandard(value);
        }

        public double KilowattHours {
            get => KilowattHour.FromStandard(CanonicalValue); set => CanonicalValue = KilowattHour.ToStandard(value);
        }

        public double BritishTermalUnits {
            get => BTU.FromStandard(CanonicalValue); set => CanonicalValue = BTU.ToStandard(value);
        }

        public double Therms {
            get => Therm.FromStandard(CanonicalValue); set => CanonicalValue = Therm.ToStandard(value);
        }

        public double Joules {
            get => CanonicalValue; set => CanonicalValue = value;
        }

        public int CompareTo(IQuantity other) => CompareTo(other);
        public bool Equals(IQuantity other) {
            if (other is Energy energy) {
                //use a tolerance approach due to uncertainty in double represenation - e.g. 0.33333 is not equal with 1/3
                return Math.Abs(CanonicalValue - energy.CanonicalValue) <= (Unit.Precision * CanonicalValue);
            }
            return false;
        }
        public int CompareTo(object obj) {
            if (obj is Energy energy) {
                return CanonicalValue.CompareTo(energy.CanonicalValue);
            }
            throw PscxArgumentException.ObjectMustBeOfType("obj", typeof(Energy));
        }

        public static Energy FromElectronVolts(double electronVolts) => new(0) { ElectronVolts = electronVolts };
        public static Energy FromCalories(double calories) => new(0) { Calories = calories };
        public static Energy FromFootPounds(double footPounds) => new(0) { FootPounds = footPounds };
        public static Energy FromBritishTermalUnits(double britishTermalUnits) => new(0) { BritishTermalUnits = britishTermalUnits };
        public static Energy FromKilowattHours(double kwh) => new(0) { KilowattHours = kwh };
        public static Energy FromTherms(double therms) => new(0) { Therms = therms };

        public static explicit operator double(Energy e) => e.CanonicalValue;
        public static explicit operator Measurement(Energy l) => l.Measurement;
        public static explicit operator Energy(string value) => new (value);
        public static Energy operator -(Energy ar) => new(-ar.CanonicalValue);
        public static Energy operator +(Energy ti) => ti;
        public static Energy operator -(Energy x, Energy y) => new(x.CanonicalValue - y.CanonicalValue);
        public static Energy operator -(Energy x, Measurement y) =>
            y.unit.QuantityType == QuantityType.Energy ? new Energy(x.CanonicalValue - y.Canonical) : throw new ArgumentException("Operand unit not compatible with Energy");
        public static Energy operator +(Energy x, Energy y) => new(x.CanonicalValue + y.CanonicalValue);
        public static Energy operator +(Energy x, Measurement y) => 
            y.unit.QuantityType == QuantityType.Energy ? new Energy(x.CanonicalValue + y.Canonical) : throw new ArgumentException("Operand unit not compatible with Energy");
        public static Energy operator *(Energy x, double factor) => new(x.CanonicalValue * factor);
        public static Energy operator /(Energy x, double factor) => new(x.CanonicalValue / factor);
        public static Power operator /(Energy x, TimeInterval factor) => new(x.ToUnit(WattHour).value / factor.Hours, Power.Watt);
        public static bool operator ==(Energy x, Energy y) => Equals(x, y);
        public static bool operator !=(Energy x, Energy y) => !Equals(x, y);
        public static bool operator >(Energy x, Energy y) => x.CanonicalValue > y.CanonicalValue;
        public static bool operator >=(Energy x, Energy y) => x.CanonicalValue >= y.CanonicalValue;
        public static bool operator <(Energy x, Energy y) => x.CanonicalValue < y.CanonicalValue;
        public static bool operator <=(Energy x, Energy y) => x.CanonicalValue <= y.CanonicalValue;
    }
}
