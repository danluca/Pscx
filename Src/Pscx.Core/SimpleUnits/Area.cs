// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Area quantity and units
    /// </summary>
    /// <see href="https://github.com/angularsen/UnitsNet">Units.Net library</see>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    [Serializable]
    public struct Area : IQuantity {
        public static readonly Unit SquareFoot = Unit.GetUnit("Square Feet", "ft²,sqft", QuantityType.Area, 0.092903);
        public static readonly Unit Acre = Unit.GetUnit("Acres", "ac", QuantityType.Area, 4046.86);
        public static readonly Unit Hectare = Unit.GetUnit("Hectares", "ha", QuantityType.Area, 10000);
        public static readonly Unit SquareKilometer = Unit.GetUnit("Square Kilometers", "km²,sqkm", QuantityType.Area, 1e+6);
        public static readonly Unit SquareMile = Unit.GetUnit("Square Miles", "mi²,sqmi", QuantityType.Area, 2.59e+6);
        public static readonly Unit SquareMeter = Unit.GetStandardUnit("Square Meters", "m²,m2", QuantityType.Area);
        public static readonly Unit _canonicalUnit = SquareMeter;

        /// <summary>
        /// Creates new area, assuming canonical unit
        /// </summary>
        /// <param name="value"></param>
        public Area(double value) {
            CanonicalValue = value;
            QuantityType = QuantityType.Area;
        }

        public Area(double value, Unit unit) : this(new Measurement(value, unit)) {}
        public Area(string value) : this((Measurement)value) {}
        public Area(Measurement msmt) : this(msmt?.Canonical ?? 0) {
            if (msmt != null && msmt.unit.QuantityType != QuantityType.Area) {
                throw new ArgumentException($"Unit {msmt.unit.Name} is not an Area type unit");
            }
        }

        public double SquareFeet {
            get => SquareFoot.FromStandard(CanonicalValue); set => CanonicalValue = SquareFoot.ToStandard(value);
        }

        public double Acres {
            get => Acre.FromStandard(CanonicalValue); set => CanonicalValue = Acre.ToStandard(value);
        }

        public double SquareMiles {
            get => SquareMile.FromStandard(CanonicalValue); set => CanonicalValue = SquareMile.ToStandard(value);
        }

        public double Hectares {
            get => Hectare.FromStandard(CanonicalValue); set => CanonicalValue = Hectare.ToStandard(value);
        }

        public double SquareMeters {
            get => CanonicalValue; set => CanonicalValue = value;
        }

        public override int GetHashCode() => CanonicalValue.GetHashCode();
        public bool Equals(IQuantity other) => Equals((object)other);
        public override bool Equals(object other) {
            if (other is Area area) {
                //use a tolerance approach due to uncertainty in double represenation - e.g. 0.33333 is not equal with 1/3
                return Math.Abs(CanonicalValue - area.CanonicalValue) <= (Unit.Precision * CanonicalValue);
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

        public override string ToString() => Measurement.AsAutoScaledString();
        public string ToString(Unit unit) => ToUnit(unit).AsString();
        public Measurement Measurement => new (CanonicalValue, _canonicalUnit);
        public double CanonicalValue { get; private set; }
        public QuantityType QuantityType { get; private set; }
        public Unit CanonicalUnit => _canonicalUnit;
        public List<Unit> Units { get; } = UnitHelper.GetQuantityUnits(QuantityType.Area);

        public Measurement ToUnit(Unit unit) {
            if (unit.QuantityType != _canonicalUnit.QuantityType) {
                throw new InvalidOperationException($"Incompatible units: cannot convert {_canonicalUnit.Name} into {unit.Name}");
            }
            return new (unit.FromStandard(CanonicalValue), unit);
        } 

        public static Area FromSquareFeet(double sqft) => new(0) { SquareFeet = sqft };
        public static Area FromSquareMiles(double sqmi) => new(0) { SquareMiles = sqmi };
        public static Area FromAcres(double acres) => new(0) { Acres = acres };

        public static explicit operator double(Area l) => l.CanonicalValue;
        public static explicit operator Measurement(Area l) => l.Measurement;
        public static explicit operator Area(string value) => new (value);
        public static Area operator -(Area ar) => new(-ar.CanonicalValue);
        public static Area operator +(Area ti) => ti;
        public static Area operator -(Area x, Area y) => new(x.CanonicalValue - y.CanonicalValue);
        public static Area operator -(Area x, Measurement y) =>
            y.unit.QuantityType == QuantityType.Area ? new Area(x.CanonicalValue - y.Canonical) : throw new ArgumentException("Operand unit not compatible with Area");
        public static Area operator +(Area x, Area y) => new(x.CanonicalValue + y.CanonicalValue);
        public static Area operator +(Area x, Measurement y) => 
            y.unit.QuantityType == QuantityType.Area ? new Area(x.CanonicalValue + y.Canonical) : throw new ArgumentException("Operand unit not compatible with Area");
        public static Area operator *(Area x, double factor) => new(x.CanonicalValue * factor);
        public static Volume operator *(Area x, Length factor) => new(x.SquareMeters * factor.Meters, Volume.CubicMeter);
        public static Area operator /(Area x, double factor) => new(x.CanonicalValue / factor);
        public static Length operator /(Area x, Length factor) => new(x.SquareMeters / factor.Meters, Length.Meter);
        public static bool operator ==(Area x, Area y) => Equals(x, y);
        public static bool operator !=(Area x, Area y) => !Equals(x, y);
        public static bool operator >(Area x, Area y) => x.CanonicalValue > y.CanonicalValue;
        public static bool operator >=(Area x, Area y) => x.CanonicalValue >= y.CanonicalValue;
        public static bool operator <(Area x, Area y) => x.CanonicalValue < y.CanonicalValue;
        public static bool operator <=(Area x, Area y) => x.CanonicalValue <= y.CanonicalValue;
    }
}
