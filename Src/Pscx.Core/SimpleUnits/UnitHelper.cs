// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Collections.Generic;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Various utilities for units - in particular autoscaling values for string serialization, such that the numeric value is meaningful (human friendly)
    /// </summary>
    /// <remarks>Author: Dan Luca; Since: v3.6, Feb 2023</remarks>
    internal static class UnitHelper {

        public static string ToFormattedString(Measurement msmt, bool bLocale) {
            if (msmt.value != 0) {
                var log10 = Math.Log10(msmt.value);

                if (log10 < 0) {
                    msmt = MakeLarger(msmt, GetQuantityUnits(msmt.unit.QuantityType));
                } else if (log10 > 0) {
                    msmt = MakeSmaller(msmt, GetQuantityUnits(msmt.unit.QuantityType));
                }
            }

            return bLocale ? $"{msmt.value:N3} {msmt.unit.Symbol}" : $"{msmt.value:F3} {msmt.unit.Symbol}";
        }

        public static string ToAutoscaledString(Measurement msmt) {
            return ToFormattedString(msmt, false);
        }

        private static Measurement MakeSmaller(Measurement msmt, List<Unit> units) {
            int index = units.FindIndex(u => u.Name == msmt.unit.Name);

            for (var x = index; x < units.Count; x++) {
                Measurement m = new(units[x].FromStandard(msmt.unit.ToStandard(msmt.value)), units[x]);
                var log10 = Math.Log10(m.value);
                if (log10 < 3) {
                    return m;
                }
            }

            return msmt;
        }

        private static Measurement MakeLarger(Measurement msmt, List<Unit> units) {
            int index = units.FindIndex(u => u.Name == msmt.unit.Name);

            for (var x = index; x < units.Count; x--) {
                Measurement m = new(units[x].FromStandard(msmt.unit.ToStandard(msmt.value)), units[x]);
                if (Math.Log10(m.value) >= 0) {
                    return m;
                }
            }

            return msmt;
        }

        public static List<Unit> GetQuantityUnits(QuantityType quantityType) {
            List<Unit> allUnits = Unit.Units.FindAll(u => u.QuantityType == quantityType);
            allUnits.Sort(Unit.ComparisonAscending);
            return allUnits;
        }
    }
}
