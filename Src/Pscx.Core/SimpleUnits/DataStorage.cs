// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Data storage quantities and units
    /// </summary>
    /// <see href="https://github.com/angularsen/UnitsNet">Units.Net library</see>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    [Serializable]
    public struct DataStorage : IQuantity {
        public static readonly Unit Kilobyte = Unit.GetUnit("Kibibyte", "KiB", QuantityType.DataStorage, 1024);
        public static readonly Unit Megabyte = Unit.GetUnit("Mebibyte", "MiB", QuantityType.DataStorage, 1.048576e+6);
        public static readonly Unit Gigabyte = Unit.GetUnit("Gibibyte", "GiB", QuantityType.DataStorage, 1.073741824e+9);
        public static readonly Unit Terabyte = Unit.GetUnit("Tebibyte", "TiB", QuantityType.DataStorage, 1.099511627776e+12);
        public static readonly Unit Petabyte = Unit.GetUnit("Pebibyte", "PiB", QuantityType.DataStorage, 1.125899906842624e+15);
        public static readonly Unit Kilobyte10 = Unit.GetUnit("Kilobyte", "KB", QuantityType.DataStorage, 1e+3);
        public static readonly Unit Megabyte10 = Unit.GetUnit("Megabyte", "MB", QuantityType.DataStorage, 1e+6);
        public static readonly Unit Gigabyte10 = Unit.GetUnit("Gigabyte", "GB", QuantityType.DataStorage, 1e+9);
        public static readonly Unit Terabyte10 = Unit.GetUnit("Terabyte", "TB", QuantityType.DataStorage, 1e+12);
        public static readonly Unit Petabyte10 = Unit.GetUnit("Petabyte", "PB", QuantityType.DataStorage, 1e+15);
        public static readonly Unit Byte = Unit.GetStandardUnit("Byte", "B", QuantityType.DataStorage);
        public static readonly Unit _canonicalUnit = Byte;

        public DataStorage(double value) {
            CanonicalValue = value;
            QuantityType = QuantityType.DataStorage;
        }

        public DataStorage(double value, Unit unit) : this(new Measurement(value, unit)) {}
        public DataStorage(string value) : this((Measurement)value) {}
        public DataStorage(Measurement msmt) : this(msmt?.Canonical ?? 0) {
            if (msmt != null && msmt.unit.QuantityType != QuantityType.DataStorage) {
                throw new ArgumentException($"Unit {msmt.unit.Name} is not a Digital DataStorage type unit");
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
        public List<Unit> Units { get; } = UnitHelper.GetQuantityUnits(QuantityType.DataStorage);

        public double Kilobytes {
            get => Kilobyte.FromStandard(CanonicalValue); set => CanonicalValue = Kilobyte.ToStandard(value);
        }

        public double Kilobytes10 {
            get => Kilobyte10.FromStandard(CanonicalValue); set => CanonicalValue = Kilobyte10.ToStandard(value);
        }

        public double Megabytes {
            get => Megabyte.FromStandard(CanonicalValue); set => CanonicalValue = Megabyte.ToStandard(value);
        }

        public double Megabytes10 {
            get => Megabyte10.FromStandard(CanonicalValue); set => CanonicalValue = Megabyte10.ToStandard(value);
        }

        public double Gigabytes {
            get => Gigabyte.FromStandard(CanonicalValue); set => CanonicalValue = Gigabyte.ToStandard(value);
        }

        public double Gigabytes10 {
            get => Gigabyte10.FromStandard(CanonicalValue); set => CanonicalValue = Gigabyte10.ToStandard(value);
        }

        public double Terabytes {
            get => Terabyte.FromStandard(CanonicalValue); set => CanonicalValue = Terabyte.ToStandard(value);
        }

        public double Terabytes10 {
            get => Terabyte10.FromStandard(CanonicalValue); set => CanonicalValue = Terabyte10.ToStandard(value);
        }

        public double Petabytes {
            get => Petabyte.FromStandard(CanonicalValue); set => CanonicalValue = Petabyte.ToStandard(value);
        }

        public double Petabytes10 {
            get => Petabyte10.FromStandard(CanonicalValue); set => CanonicalValue = Petabyte10.ToStandard(value);
        }

        public double Bytes {
            get => CanonicalValue; set => CanonicalValue = value;
        }

        public override int GetHashCode() => CanonicalValue.GetHashCode();
        public bool Equals(IQuantity other) => Equals((object)other);
        public override bool Equals(object other) {
            if (other is DataStorage data) {
                //use a tolerance approach due to uncertainty in double represenation - e.g. 0.33333 is not equal with 1/3
                return Math.Abs(CanonicalValue - data.CanonicalValue) <= (Unit.Precision * CanonicalValue);
            }
            return false;
        }
        public int CompareTo(IQuantity other) => CompareTo((object)other);
        public int CompareTo(object obj) {
            if (obj is DataStorage data) {
                return CanonicalValue.CompareTo(data.CanonicalValue);
            }
            throw PscxArgumentException.ObjectMustBeOfType("obj", typeof(DataStorage));
        }

        public override string ToString() => Measurement.AsAutoScaledString();
        public string ToString(Unit unit) => ToUnit(unit).AsString();

        public static DataStorage FromKilobytes(double kilobytes) => new(0) { Kilobytes = kilobytes };
        public static DataStorage FromMegabytes(double megabytes) => new(0) { Megabytes = megabytes };
        public static DataStorage FromGigabytes(double gigabytes) => new(0) { Gigabytes = gigabytes };
        public static DataStorage FromTerabytes(double terabytes) => new(0) { Terabytes = terabytes };
        public static DataStorage FromPetabytes(double petabytes) => new(0) { Petabytes = petabytes };
        public static DataStorage FromKilobytes10(double kilobytes) => new(0) { Kilobytes10 = kilobytes };
        public static DataStorage FromMegabytes10(double megabytes) => new(0) { Megabytes10 = megabytes };
        public static DataStorage FromGigabytes10(double gigabytes) => new(0) { Gigabytes10 = gigabytes };
        public static DataStorage FromTerabytes10(double terabytes) => new(0) { Terabytes10 = terabytes };
        public static DataStorage FromPetabytes10(double petabytes) => new(0) { Petabytes10 = petabytes };

        public static explicit operator double(DataStorage e) => e.CanonicalValue;
        public static explicit operator Measurement(DataStorage l) => l.Measurement;
        public static explicit operator DataStorage(string value) => new (value);
        public static DataStorage operator -(DataStorage ar) => new(-ar.CanonicalValue);
        public static DataStorage operator +(DataStorage ti) => ti;
        public static DataStorage operator -(DataStorage x, DataStorage y) => new(x.CanonicalValue - y.CanonicalValue);
        public static DataStorage operator -(DataStorage x, Measurement y) =>
            y.unit.QuantityType == QuantityType.DataStorage ? new DataStorage(x.CanonicalValue - y.Canonical) : throw new ArgumentException("Operand unit not compatible with DataStorage");
        public static DataStorage operator +(DataStorage x, DataStorage y) => new(x.CanonicalValue + y.CanonicalValue);
        public static DataStorage operator +(DataStorage x, Measurement y) => 
            y.unit.QuantityType == QuantityType.DataStorage ? new DataStorage(x.CanonicalValue + y.Canonical) : throw new ArgumentException("Operand unit not compatible with DataStorage");
        public static DataStorage operator *(DataStorage x, double factor) => new(x.CanonicalValue * factor);
        public static DataStorage operator /(DataStorage x, double factor) => new(x.CanonicalValue / factor);
        public static DataTransfer operator /(DataStorage x, TimeInterval factor) => new(x.Bytes * 8 / factor.Seconds, DataTransfer.BitPerSecond);
        public static bool operator ==(DataStorage x, DataStorage y) => Equals(x, y);
        public static bool operator !=(DataStorage x, DataStorage y) => !Equals(x, y);
        public static bool operator >(DataStorage x, DataStorage y) => x.CanonicalValue > y.CanonicalValue;
        public static bool operator >=(DataStorage x, DataStorage y) => x.CanonicalValue >= y.CanonicalValue;
        public static bool operator <(DataStorage x, DataStorage y) => x.CanonicalValue < y.CanonicalValue;
        public static bool operator <=(DataStorage x, DataStorage y) => x.CanonicalValue <= y.CanonicalValue;
    }
}
