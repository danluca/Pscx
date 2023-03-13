// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Text.RegularExpressions;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Known quantity types handled in the code
    /// <para>If this list changes, remember to update \Src\Pscx\FormatData\Pscx.SIUnits.Format.ps1xml PowerShell data format specification.</para>
    /// </summary>
    public enum QuantityType {
        Length, Area, Volume, Mass, Energy, Speed, TimeInterval, Power, Angle, Temperature, Pressure, FuelEconomy, DataStorage, DataTransfer
    }
    /// <summary>
    /// Extension methods for the QuantityType enumeration
    /// </summary>
    internal static class QuantityTypeExtension {
        /// <summary>
        /// Factory method to create a shell quantity (value of 0)
        /// </summary>
        /// <param name="quantityType">this QuantityType enumeration value</param>
        /// <returns>a quantity of proper type with a value of 0</returns>
        public static IQuantity Quantity(this QuantityType quantityType) {
            return Quantity(quantityType, null);
        }
        /// <summary>
        /// Factory method to create a proper quantity instance based on quantity type
        /// </summary>
        /// <param name="quantityType">this QuantityType enumeration value</param>
        /// <param name="msmt">Measurement instance to create quantity from</param>
        /// <returns>a quantity instance of proper type, using value and unit from the measurement</returns>
        /// <exception cref="NotImplementedException"></exception>
        public static IQuantity Quantity(this QuantityType quantityType, Measurement msmt) {
            return quantityType switch {
                QuantityType.Area => new Area(msmt),
                QuantityType.Energy => new Energy(msmt),
                QuantityType.Temperature => new Temperature(msmt),
                QuantityType.Angle => new Angle(msmt),
                QuantityType.DataStorage => new DataStorage(msmt),
                QuantityType.DataTransfer => new DataTransfer(msmt),
                QuantityType.FuelEconomy => new FuelEconomy(msmt),
                QuantityType.Length => new Length(msmt),
                QuantityType.Mass => new Mass(msmt),
                QuantityType.Power => new Power(msmt),
                QuantityType.Pressure => new Pressure(msmt),
                QuantityType.Speed => new Speed(msmt),
                QuantityType.TimeInterval => new TimeInterval(msmt),
                QuantityType.Volume => new Volume(msmt),
                _ => throw new NotImplementedException($"Translation of quantity type {Enum.GetName(quantityType)} into a IQuantity instance has not been implemented")
            };
        }
    }

    /// <summary>
    /// API for a Quantity instance - e.g. Length, Area, etc.<br/>
    /// For more comprehensive unit management please see <see cref="https://github.com/angularsen/UnitsNet"/> library.
    /// </summary>
    public interface IQuantity : IComparable<IQuantity>, IComparable, IEquatable<IQuantity> {
        public double CanonicalValue { get; }
        public Unit CanonicalUnit { get; }
        public List<Unit> Units { get; }
        public Measurement ToUnit(Unit unit);
        public QuantityType QuantityType { get; }
        public string ToString(Unit unit);
        public Measurement Measurement { get; }
    }
    /// <summary>
    /// A measurement - immutable pair of numeric value and unit. Conveniences for string serialization, parsing, conversion to quantity types.
    /// </summary>
    /// <param name="value">the numeric value held by the measurement</param>
    /// <param name="unit">the unit of the numeric value</param>
    [TypeConverter(typeof(MeasurementConverter))]
    public sealed record Measurement(double value, Unit unit) {
        private static readonly Regex reMsmt = new("([+\\d.,-]+)\\s*([^\\d]+)", RegexOptions.Compiled);
        /// <summary>
        /// Canonical value - read only property that gives the numeric value in standard units for the quantity type.
        /// </summary>
        public double Canonical { get { return unit.ToStandard(value); } }
        /// <summary>
        /// String representation of the measurement
        /// </summary>
        /// <see cref="AsString"/>
        /// <returns>string with unaltered values of numeric and unit values</returns>
        public override string ToString() => AsString();

        /// <summary>
        /// The string representation of this measurement, without any adjustments. The value is displayed with 3 decimal digits.
        /// </summary>
        /// <returns>value with 3 decimal digits and unit</returns>
        public string AsString() {
            return $"{value:F3} {unit.Symbol}";
        }

        /// <summary>
        /// The string representation of this measurement autoscaled to the appropriate unit to render a numeric value "just right"
        /// </summary>
        /// <returns>autoscaled value with 3 decimal digits and unit</returns>
        public string AsAutoScaledString() {
            // return $"{value:F3} {unit.Symbol}";
            return UnitHelper.ToAutoscaledString(this);
        }

        /// <summary>
        /// The string representation of this measurement autoscaled to the appropriate unit to render a numeric value "just right" and formatted for current locale
        /// </summary>
        /// <returns>autoscaled value with 3 decimal digits for current locale and unit</returns>
        public string AsFormattedString() {
            // return $"{value:N3} {unit.Symbol}";
            return UnitHelper.ToFormattedString(this, true);
        }
        /// <summary>
        /// Creates a measurement object from parsing the string value provided - expected to have the format of "[numeric_value] [unit_symbol]"
        /// </summary>
        /// <param name="value">string representation of the measurement - format expected as "[numeric_value] [unit_symbol]"</param>
        /// <returns>measurement object extracted from the string argument; null if the string value does not match expected pattern</returns>
        public static Measurement FromString(string value) {
            Match m = reMsmt.Match(value);
            if (!m.Success) {
                return null;
            }

            string num = m.Groups[1].Value;
            string symbol = m.Groups[2].Value;
            return new Measurement(double.Parse(num), Unit.FromSymbol(symbol));
        }

        /// <summary>
        /// Conversion to a <see cref="IQuantity"/> value
        /// </summary>
        /// <returns>the appropriate quantity type per the measurement's unit</returns>
        /// <exception cref="NotImplementedException"> when a new quantity type is defined but this factory code is not updated</exception>
        public IQuantity Quantity {
            get => unit.QuantityType.Quantity(this);
        }

        public static explicit operator Measurement(string value) => FromString(value);
    };
}