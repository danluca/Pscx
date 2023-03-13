// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.ComponentModel;
using System.Globalization;

namespace Pscx.SimpleUnits {
    /// <summary>
    /// Type converter between <see cref="Measurement"/> and <see cref="string"/> types.
    /// Supports automatic value binding in PowerShell cmdlets.
    /// </summary>
    public sealed class MeasurementConverter : TypeConverter {
        
        public override Boolean CanConvertFrom(ITypeDescriptorContext context, Type sourceType) {
            if (sourceType == typeof(string)) {
                return true;
            }

            return base.CanConvertFrom(context, sourceType);
        }

        public override Boolean CanConvertTo(ITypeDescriptorContext context, Type destinationType) {
            if (destinationType == typeof(string)) {
                return true;
            }

            return base.CanConvertTo(context, destinationType);
        }

        public override Object ConvertFrom(ITypeDescriptorContext context, CultureInfo culture, Object value) {
            if (value is string sval) {
                return Measurement.FromString(sval);
            }

            return base.ConvertFrom(context, culture, value);
        }

        public override Object ConvertTo(ITypeDescriptorContext context, CultureInfo culture, Object value, Type destinationType) {
            if (value is Measurement msmt) {
                if (destinationType == typeof(string)) {
                    return msmt.AsString();
                }
            }

            return base.ConvertTo(context, culture, value, destinationType);
        }

    }
}
