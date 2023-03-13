// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Fuel economy quantities and units
    /// </summary>
    /// <see href="https://github.com/angularsen/UnitsNet">Units.Net library</see>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    [Serializable]
    public struct FuelEconomy : IQuantity {
        public static readonly Unit MilePerGallon = Unit.GetUnit("Miles per Gallon", "mpg", QuantityType.FuelEconomy, d=> 232.215/d, d=> 232.15/d);
        public static readonly Unit KilometerPerLiter = Unit.GetUnit("Kilometer per Liter", "km/L", QuantityType.FuelEconomy, d=> 100/d, d=> 100/d);
        public static readonly Unit LiterPer100Km = Unit.GetStandardUnit("Liter per 100km", "L/100km", QuantityType.FuelEconomy);
        public static readonly Unit _canonicalUnit = LiterPer100Km;

        public FuelEconomy(double value) {
            CanonicalValue = value;
            QuantityType = QuantityType.FuelEconomy;
        }

        public FuelEconomy(double value, Unit unit) : this(new Measurement(value, unit)) {}
        public FuelEconomy(string value) : this((Measurement)value) {}
        public FuelEconomy(Measurement msmt) : this(msmt?.Canonical ?? 0) {
            if (msmt != null && msmt.unit.QuantityType != QuantityType.FuelEconomy) {
                throw new ArgumentException($"Unit {msmt.unit.Name} is not a Digital FuelEconomy type unit");
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
        public List<Unit> Units { get; } = UnitHelper.GetQuantityUnits(QuantityType.FuelEconomy);

        public double MilesPerGallon {
            get => MilePerGallon.FromStandard(CanonicalValue); set => CanonicalValue = MilePerGallon.ToStandard(value);
        }

        public double KilometersPerLiter {
            get => KilometerPerLiter.FromStandard(CanonicalValue); set => CanonicalValue = KilometerPerLiter.ToStandard(value);
        }

        public double LitersPer100Km {
            get => CanonicalValue; set => CanonicalValue = value;
        }

        public int CompareTo(IQuantity other) => CompareTo(other);
        public bool Equals(IQuantity other) {
            if (other is FuelEconomy data) {
                //use a tolerance approach due to uncertainty in double represenation - e.g. 0.33333 is not equal with 1/3
                return Math.Abs(CanonicalValue - data.CanonicalValue) <= (Unit.Precision * CanonicalValue);
            }
            return false;
        }
        public int CompareTo(object obj) {
            if (obj is FuelEconomy data) {
                return CanonicalValue.CompareTo(data.CanonicalValue);
            }
            throw PscxArgumentException.ObjectMustBeOfType("obj", typeof(FuelEconomy));
        }

        public override string ToString() => Measurement.AsAutoScaledString();
        public string ToString(Unit unit) => ToUnit(unit).AsString();

        public static FuelEconomy FromMilesPerGallon(double mpg) => new(0) { MilesPerGallon = mpg };
        public static FuelEconomy FromKilometersPerLiter(double kml) => new(0) { KilometersPerLiter = kml };

        public static explicit operator double(FuelEconomy e) => e.CanonicalValue;
        public static explicit operator Measurement(FuelEconomy l) => l.Measurement;
        public static explicit operator FuelEconomy(string value) => new (value);
        public static FuelEconomy operator -(FuelEconomy ar) => new(-ar.CanonicalValue);
        public static FuelEconomy operator +(FuelEconomy ti) => ti;
        public static FuelEconomy operator -(FuelEconomy x, FuelEconomy y) => new(x.CanonicalValue - y.CanonicalValue);
        public static FuelEconomy operator -(FuelEconomy x, Measurement y) =>
            y.unit.QuantityType == QuantityType.FuelEconomy ? new FuelEconomy(x.CanonicalValue - y.Canonical) : throw new ArgumentException("Operand unit not compatible with FuelEconomy");
        public static FuelEconomy operator +(FuelEconomy x, FuelEconomy y) => new(x.CanonicalValue + y.CanonicalValue);
        public static FuelEconomy operator +(FuelEconomy x, Measurement y) => 
            y.unit.QuantityType == QuantityType.FuelEconomy ? new FuelEconomy(x.CanonicalValue + y.Canonical) : throw new ArgumentException("Operand unit not compatible with FuelEconomy");
        public static FuelEconomy operator *(FuelEconomy x, double factor) => new(x.CanonicalValue * factor);
        public static Length operator *(FuelEconomy x, Volume factor) => new(x.MilesPerGallon * factor.Gallons, Length.Mile);
        public static Volume operator *(FuelEconomy x, Length factor) => new(x.LitersPer100Km * factor.Kilometers / 100, Volume.Liter);
        public static FuelEconomy operator /(FuelEconomy x, double factor) => new(x.CanonicalValue / factor);
        public static bool operator ==(FuelEconomy x, FuelEconomy y) => Equals(x, y);
        public static bool operator !=(FuelEconomy x, FuelEconomy y) => !Equals(x, y);
        public static bool operator >(FuelEconomy x, FuelEconomy y) => x.CanonicalValue > y.CanonicalValue;
        public static bool operator >=(FuelEconomy x, FuelEconomy y) => x.CanonicalValue >= y.CanonicalValue;
        public static bool operator <(FuelEconomy x, FuelEconomy y) => x.CanonicalValue < y.CanonicalValue;
        public static bool operator <=(FuelEconomy x, FuelEconomy y) => x.CanonicalValue <= y.CanonicalValue;
    }
}
