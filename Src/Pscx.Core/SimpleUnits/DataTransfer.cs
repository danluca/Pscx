// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Data transfer rates and units
    /// </summary>
    /// <see href="https://github.com/angularsen/UnitsNet">Units.Net library</see>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    [Serializable]
    public struct DataTransfer : IQuantity {
        public static readonly Unit KilobitPerSecond = Unit.GetUnit("Kilobit per Second", "kbps, Kbps", QuantityType.DataTransfer, 1e+3);
        public static readonly Unit MegabitPerSecond = Unit.GetUnit("Megabit per Second", "Mbps", QuantityType.DataTransfer, 1e+6);
        public static readonly Unit GigabitPerSecond = Unit.GetUnit("Gigabit per Second", "Gbps", QuantityType.DataTransfer, 1e+9);
        public static readonly Unit TerabitPerSecond = Unit.GetUnit("Terabit per Second", "Tbps", QuantityType.DataTransfer, 1e+12);
        public static readonly Unit KilobytePerSecond = Unit.GetUnit("Kilobyte per Second", "KBps", QuantityType.DataTransfer, 8e+3);
        public static readonly Unit MegabytePerSecond = Unit.GetUnit("Megabyte per Second", "MBps", QuantityType.DataTransfer, 8e+6);
        public static readonly Unit GigabytePerSecond = Unit.GetUnit("Gigabyte per Second", "GBps", QuantityType.DataTransfer, 8e+9);
        public static readonly Unit TerabytePerSecond = Unit.GetUnit("Terabyte per Second", "TBps", QuantityType.DataTransfer, 8e+12);
        public static readonly Unit BitPerSecond = Unit.GetStandardUnit("Bit per Second", "bps", QuantityType.DataTransfer);
        public static readonly Unit _canonicalUnit = BitPerSecond;

        public DataTransfer(double value) {
            CanonicalValue = value;
            QuantityType = QuantityType.DataTransfer;
        }

        public DataTransfer(double value, Unit unit) : this(new Measurement(value, unit)) {}
        public DataTransfer(string value) : this((Measurement)value) {}

        public DataTransfer(Measurement msmt) : this(msmt?.Canonical ?? 0) {
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

        public double KilobytesPerSecond {
            get => KilobytePerSecond.FromStandard(CanonicalValue); set => CanonicalValue = KilobytePerSecond.ToStandard(value);
        }

        public double KilobitsPerSecond {
            get => KilobitPerSecond.FromStandard(CanonicalValue); set => CanonicalValue = KilobitPerSecond.ToStandard(value);
        }

        public double MegabytesPerSecond {
            get => MegabytePerSecond.FromStandard(CanonicalValue); set => CanonicalValue = MegabytePerSecond.ToStandard(value);
        }

        public double MegabitsPerSecond {
            get => MegabitPerSecond.FromStandard(CanonicalValue); set => CanonicalValue = MegabitPerSecond.ToStandard(value);
        }

        public double GigabytesPerSecond {
            get => GigabytePerSecond.FromStandard(CanonicalValue); set => CanonicalValue = GigabytePerSecond.ToStandard(value);
        }

        public double GigabitsPerSecond {
            get => GigabitPerSecond.FromStandard(CanonicalValue); set => CanonicalValue = GigabitPerSecond.ToStandard(value);
        }

        public double BitsPerSecond {
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

        public static DataTransfer FromKilobytesPerSecond(double kilobytes) => new(0) { KilobytesPerSecond = kilobytes };
        public static DataTransfer FromMegabytesPerSecond(double megabytes) => new(0) { MegabytesPerSecond = megabytes };
        public static DataTransfer FromGigabytesPerSecond(double gigabytes) => new(0) { GigabytesPerSecond = gigabytes };
        public static DataTransfer FromKilobitsPerSecond(double kilobytes) => new(0) { KilobitsPerSecond = kilobytes };
        public static DataTransfer FromMegabitsPerSecond(double megabytes) => new(0) { MegabitsPerSecond = megabytes };
        public static DataTransfer FromGigabitsPerSecond(double gigabytes) => new(0) { GigabitsPerSecond = gigabytes };

        public static explicit operator double(DataTransfer e) => e.CanonicalValue;
        public static explicit operator Measurement(DataTransfer l) => l.Measurement;
        public static explicit operator DataTransfer(string value) => new (value);
        public static DataTransfer operator -(DataTransfer ar) => new(-ar.CanonicalValue);
        public static DataTransfer operator +(DataTransfer ti) => ti;
        public static DataTransfer operator -(DataTransfer x, DataTransfer y) => new(x.CanonicalValue - y.CanonicalValue);
        public static DataTransfer operator -(DataTransfer x, Measurement y) =>
            y.unit.QuantityType == QuantityType.DataTransfer ? new DataTransfer(x.CanonicalValue - y.Canonical) : throw new ArgumentException("Operand unit not compatible with DataTransfer");
        public static DataTransfer operator +(DataTransfer x, DataTransfer y) => new(x.CanonicalValue + y.CanonicalValue);
        public static DataTransfer operator +(DataTransfer x, Measurement y) => 
            y.unit.QuantityType == QuantityType.DataTransfer ? new DataTransfer(x.CanonicalValue + y.Canonical) : throw new ArgumentException("Operand unit not compatible with DataTransfer");
        public static DataTransfer operator *(DataTransfer x, double factor) => new(x.CanonicalValue * factor);
        public static DataStorage operator *(DataTransfer x, TimeInterval factor) => new(x.KilobytesPerSecond * factor.Seconds, DataStorage.Kilobyte10);
        public static DataTransfer operator /(DataTransfer x, double factor) => new(x.CanonicalValue / factor);
        public static bool operator ==(DataTransfer x, DataTransfer y) => Equals(x, y);
        public static bool operator !=(DataTransfer x, DataTransfer y) => !Equals(x, y);
        public static bool operator >(DataTransfer x, DataTransfer y) => x.CanonicalValue > y.CanonicalValue;
        public static bool operator >=(DataTransfer x, DataTransfer y) => x.CanonicalValue >= y.CanonicalValue;
        public static bool operator <(DataTransfer x, DataTransfer y) => x.CanonicalValue < y.CanonicalValue;
        public static bool operator <=(DataTransfer x, DataTransfer y) => x.CanonicalValue <= y.CanonicalValue;
    }
}
