// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Time interval quantities and units. See <see cref="TimeSpan"/> type as it is fully inter-operable.
    /// </summary>
    /// <see href="https://github.com/angularsen/UnitsNet">Units.Net library</see>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    [Serializable]
    public struct TimeInterval : IQuantity {
        public const int DaysInWeek = 7;
        public const int DaysInMonth = 30;
        public const int DaysInYear = 365;

        public static readonly Unit Millisecond = Unit.GetUnit("Millisecond", "ms", QuantityType.TimeInterval, 1e-3);
        public static readonly Unit Microsecond = Unit.GetUnit("Microsecond", "μs, us", QuantityType.TimeInterval, 1e-6);
        public static readonly Unit Minute = Unit.GetUnit("Minute", "min", QuantityType.TimeInterval, 60);
        public static readonly Unit Hour = Unit.GetUnit("Hour", "h", QuantityType.TimeInterval, 3600);
        public static readonly Unit Day = Unit.GetUnit("Day", "d", QuantityType.TimeInterval, 86400);
        public static readonly Unit Week = Unit.GetUnit("Week", "w", QuantityType.TimeInterval, 604800);
        public static readonly Unit Month = Unit.GetUnit("Month", "mo", QuantityType.TimeInterval, 2592e+3);    //standard 30 days month
        public static readonly Unit Year = Unit.GetUnit("Year", "yr,y", QuantityType.TimeInterval, 31.536e+6);  //standard 365 days year
        public static readonly Unit Second = Unit.GetStandardUnit("Second", "s", QuantityType.TimeInterval);
        public static readonly Unit _canonicalUnit = Second;
        private TimeSpan _interval;

        public TimeInterval(TimeSpan interval) {
            _interval = interval;
            QuantityType = QuantityType.TimeInterval;
        }
        public TimeInterval(double value) : this(TimeSpan.FromSeconds(value)) {}
        public TimeInterval(Measurement msmt) : this(msmt?.Canonical ?? 0) {
            if (msmt != null && msmt.unit.QuantityType != QuantityType.TimeInterval) {
                throw new ArgumentException($"Unit {msmt.unit.Name} is not a Digital TimeInterval type unit");
            }
        }
        public TimeInterval(double value, Unit unit) : this(new Measurement(value, unit)) {}
        public TimeInterval(string value) : this((Measurement)value) {}
        public TimeInterval(int hours, int minutes, int seconds) : this(new TimeSpan(hours, minutes, seconds)) {}
        public TimeInterval(int days, int hours, int minutes, int seconds) : this(new TimeSpan(days, hours, minutes, seconds)) {}
        public TimeInterval(int days, int hours, int minutes, int seconds, int milliseconds) : this(new TimeSpan(days, hours, minutes, seconds, milliseconds)) {}

        public Measurement ToUnit(Unit unit) {
            if (unit.QuantityType != _canonicalUnit.QuantityType) {
                throw new InvalidOperationException($"Incompatible units: cannot convert {_canonicalUnit.Name} into {unit.Name}");
            }
            return new (unit.FromStandard(CanonicalValue), unit);
        } 
        public QuantityType QuantityType { get; private set; }
        public Unit CanonicalUnit => _canonicalUnit;
        public Measurement Measurement => new (CanonicalValue, _canonicalUnit);
        public List<Unit> Units { get; } = UnitHelper.GetQuantityUnits(QuantityType.TimeInterval);

        public double CanonicalValue { get => _interval.TotalSeconds; }

        public double Milliseconds {
            get => Microsecond.FromStandard(_interval.TotalSeconds); set => _interval = TimeSpan.FromMilliseconds(value);
        }

        public double Microseconds {
            get => Microsecond.FromStandard(CanonicalValue); set => _interval = TimeSpan.FromMilliseconds(value/1000);
        }

        public double Minutes {
            get => Minute.FromStandard(CanonicalValue); set => _interval = TimeSpan.FromMinutes(value);
        }

        public double Hours {
            get => Hour.FromStandard(CanonicalValue); set => _interval = TimeSpan.FromHours(value);
        }

        public double Days {
            get => Day.FromStandard(CanonicalValue); set => _interval = TimeSpan.FromDays(value);
        }

        public double Weeks {
            get => Week.FromStandard(CanonicalValue); set => _interval = TimeSpan.FromDays(value * DaysInWeek);
        }

        public double Months {
            get => Month.FromStandard(CanonicalValue); set => _interval = TimeSpan.FromDays(value * DaysInMonth);
        }

        public double Years {
            get => Year.FromStandard(CanonicalValue); set => _interval = TimeSpan.FromDays(value * DaysInYear);
        }

        public double Seconds {
            get => _interval.TotalSeconds; set => _interval = TimeSpan.FromSeconds(value);
        }

        public TimeSpan TimeSpan { get => _interval; set => _interval = value; }

        public int CompareTo(IQuantity other) => CompareTo(other);
        public bool Equals(IQuantity other) {
            if (other is TimeInterval data) {
                //use a tolerance approach due to uncertainty in double represenation - e.g. 0.33333 is not equal with 1/3
                return Math.Abs(CanonicalValue - data.CanonicalValue) <= (Unit.Precision * CanonicalValue);
            }
            return false;
        }
        public int CompareTo(object obj) {
            if (obj is TimeInterval data) {
                return CanonicalValue.CompareTo(data.CanonicalValue);
            }
            throw PscxArgumentException.ObjectMustBeOfType("obj", typeof(TimeInterval));
        }

        public override string ToString() => Measurement.AsAutoScaledString();
        public string ToString(Unit unit) => ToUnit(unit).AsString();

        public static TimeInterval FromMilliseconds(double ms) => new(0) { Milliseconds = ms };
        public static TimeInterval FromMinutes(double min) => new(0) { Minutes = min };
        public static TimeInterval FromHours(double hours) => new(0) { Hours = hours };
        public static TimeInterval FromDays(double days) => new(0) { Days = days };
        public static TimeInterval FromMonths(double months) => new(0) { Months = months };
        public static TimeInterval FromYears(double years) => new(0) { Years = years };

        public static explicit operator double(TimeInterval e) => e.CanonicalValue;
        public static explicit operator Measurement(TimeInterval l) => l.Measurement;
        public static explicit operator TimeSpan(TimeInterval l) => l._interval;
        public static explicit operator TimeInterval(string value) => new (value);
        public static explicit operator TimeInterval(TimeSpan value) => new (value);

        public static TimeInterval operator -(TimeInterval ti) => new(-ti.TimeSpan);
        public static TimeInterval operator +(TimeInterval ti) => ti;
        public static TimeInterval operator -(TimeInterval x, TimeInterval y) => new(x.TimeSpan - y.TimeSpan);
        public static TimeInterval operator -(TimeSpan x, TimeInterval y) => new(x - y.TimeSpan);
        public static TimeInterval operator -(TimeInterval x, Measurement y) =>
            y.unit.QuantityType == QuantityType.TimeInterval ? new TimeInterval(x.TimeSpan.TotalSeconds - y.Canonical) : throw new ArgumentException("Operand unit not compatible with TimeInterval");
        public static TimeInterval operator +(TimeInterval x, TimeInterval y) => new(x.TimeSpan + y.TimeSpan);
        public static TimeInterval operator +(TimeSpan x, TimeInterval y) => new(x + y.TimeSpan);
        public static TimeInterval operator +(TimeInterval x, Measurement y) => 
            y.unit.QuantityType == QuantityType.TimeInterval ? new TimeInterval(x.TimeSpan.TotalSeconds + y.Canonical) : throw new ArgumentException("Operand unit not compatible with TimeInterval");
        public static TimeInterval operator *(TimeInterval x, double factor) => new(x.TimeSpan * factor);
        public static TimeInterval operator /(TimeInterval x, double factor) => new(x.TimeSpan / factor);
        public static bool operator ==(TimeInterval x, TimeInterval y) => Equals(x, y);
        public static bool operator !=(TimeInterval x, TimeInterval y) => !Equals(x, y);
        public static bool operator >(TimeInterval x, TimeInterval y) => x.TimeSpan > y.TimeSpan;
        public static bool operator >=(TimeInterval x, TimeInterval y) => x.TimeSpan >= y.TimeSpan;
        public static bool operator <(TimeInterval x, TimeInterval y) => x.TimeSpan < y.TimeSpan;
        public static bool operator <=(TimeInterval x, TimeInterval y) => x.TimeSpan <= y.TimeSpan;

    }
}
