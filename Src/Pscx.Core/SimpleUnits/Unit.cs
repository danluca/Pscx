// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;
using System.ComponentModel;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Basic information of a unit of measure, with awareness of international system of units (SI) and conversion abilities.
    /// Conversion is expressed generically as functions to and from canonical (SI) value, and supports more complex conversions (e.g. temperature Fahrenheit &lt;-&gt; Celsius).
    /// <para>Supports equality check performed within a tolerance, defined as <see cref="Precision"/> since the measurement values are using floating point representation.</para>
    /// <para>There is no public constructor - each unit, identified by name, is defined only once (virtually a singleton) in the context of the quantity type it serves.
    /// APIs for lookup and conversion are provided.</para>
    /// </summary>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    [TypeConverter(typeof(UnitConverter))]
    public sealed class Unit {
        public const double Precision = 1e-5;
        public static readonly List<Unit> Units = new();
        public static readonly List<Unit> StandardUnits = new();
        private readonly Func<double, double> convToStandard;
        private readonly Func<double, double> convFromStandard;
        private readonly string[] _symbols;

        public static readonly Comparison<Unit> ComparisonAscending = (a, b) => a.ToStandard(1).CompareTo(b.ToStandard(1));


        private Unit(string name, string symbol, QuantityType qType, bool isSI, Func<double, double> funcToStandard, Func<double, double> funcFromStandard) {
            Name = name;
            _symbols = symbol.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            QuantityType = qType;
            IsStandard = isSI;
            if (IsStandard) {
                convFromStandard = identity;
                convToStandard = identity;
            } else {
                convFromStandard = funcFromStandard;
                convToStandard = funcToStandard;
            }

            Units.Add(this);
            if (IsStandard) {
                StandardUnits.Add(this);
            }
        }

        internal static Unit GetUnit(string name, string symbol, QuantityType qType, Func<double, double> toStandard, Func<double, double> fromStandard) {
            if (Units.Find(u => u.Name.Equals(name)) is { } u) {
                return u;
            }

            return new Unit(name, symbol, qType, false, toStandard, fromStandard);
        }

        internal static Unit GetUnit(string name, string symbol, QuantityType qType, double factor) {
            if (Units.Find(u => u.Name.Equals(name)) is { } u) {
                return u;
            }

            return new Unit(name, symbol, qType, false, d => d * factor, d=> d/factor); 
        }

        internal static Unit GetStandardUnit(string name, string symbol, QuantityType qType) {
            if (Units.Find(u => u.Name.Equals(name)) is { } u) {
                return u;
            }
            return new Unit(name, symbol, qType, true, null, null);
        }

        private static T identity<T>(T value) { return value; }


        public bool IsStandard { get; }
        public QuantityType QuantityType { get; }
        public string Name { get; }
        public string Symbol => _symbols[0];
        public List<string> Symbols => new (_symbols);

        public override string ToString() => Symbol;

        public static double ToStandard(double value, Unit unit) => unit.convToStandard(value);
        public double ToStandard(double value) => convToStandard(value);

        public static double FromStandard(double value, Unit unit) => unit.convFromStandard(value);
        public double FromStandard(double value) => convFromStandard(value);

        public static Unit FromSymbol(string symbol) {
            string lowSym = symbol.ToLower();
            Unit unit = StandardUnits.Find(u => Array.Exists(u._symbols, s => s.ToLower().Equals(lowSym)));
            
            if (unit == null) {
                unit = Units.Find(u => Array.Exists(u._symbols, s => s.ToLower().Equals(lowSym)));
            }
            return unit;
        }

        public static explicit operator Unit(string symbol) => FromSymbol(symbol);

        internal static void Initialize() {
            if (StandardUnits.Count == 0 || Units.Count == 0) {
                foreach (QuantityType qt in Enum.GetValues(typeof(QuantityType))) {
                    IQuantity q = qt.Quantity(); 
                    //force a method call such that the compiler optimizer doesn't remove/skip the block above due to variable q not being used
                    q.ToString();
                }
            }
        }

        
    }
}