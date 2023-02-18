using NodaTime;
using NodaTime.Text;
using System;
using System.Globalization;

namespace Pscx.TypeAccelerators {
    public struct IsoDateTime {
        private readonly string _value;

        public IsoDateTime(DateTime value) {
            _value = value.ToString("yyyy-MM-dd'T'HH:mm:ss.fffK");
        }

        public IsoDateTime(DateTimeOffset value) {
            _value = value.ToString("yyyy-MM-dd'T'HH:mm:ss.fffK");
        }

        public IsoDateTime(ZonedDateTime value) {
            _value = value.ToString("G", DateTimeFormatInfo.InvariantInfo);
        }
        public IsoDateTime(Pscx.Time.ZonedDateTime value) : this(value.DateTime) {}

        public IsoDateTime(OffsetDateTime value) {
            _value = value.ToString("G", DateTimeFormatInfo.InvariantInfo);
        }
        public IsoDateTime(Pscx.Time.OffsetDateTime value) : this(value.DateTime) {}

        public IsoDateTime(OffsetTime value) {
            _value = value.ToString("G", DateTimeFormatInfo.InvariantInfo);
        }

        public IsoDateTime(OffsetDate value) {
            _value = value.ToString("G", DateTimeFormatInfo.InvariantInfo);
        }

        public IsoDateTime(LocalDateTime value) {
            _value = value.ToString("G", DateTimeFormatInfo.InvariantInfo);
        }

        public IsoDateTime(Pscx.Time.LocalDateTime value) : this(value.DateTime) {}

        public IsoDateTime(LocalDate value) {
            _value = value.ToString("G", DateTimeFormatInfo.InvariantInfo);
        }

        public IsoDateTime(LocalTime value) {
            _value = value.ToString("G", DateTimeFormatInfo.InvariantInfo);
        }

        public override string ToString() {
            return _value;
        }

        public static TimeZoneInfo GetTimeZone(string id) => TimeZoneInfo.FindSystemTimeZoneById(id);

        public static DateTimeZone GetDateTimeZone(string id) => DateTimeZoneProviders.Tzdb.GetZoneOrNull(id);

        public static DateTime ParseDateTime(string strDT) => DateTime.Parse(strDT, DateTimeFormatInfo.InvariantInfo);

        public static ZonedDateTime? ParseZonedDateTime(string strDT) {
            ParseResult<ZonedDateTime> parseResult = ZonedDateTimePattern.GeneralFormatOnlyIso.Parse(strDT);
            if (parseResult.Success) {
                return parseResult.Value;
            }

            return null;
        }

        public static OffsetDateTime? ParseOffsetDateTime(string strDT) {
            ParseResult<OffsetDateTime> parseResult = OffsetDateTimePattern.GeneralIso.Parse(strDT);
            if (parseResult.Success) {
                return parseResult.Value;
            }

            return null;
        }

        public static OffsetDate? ParseOffsetDate(string strDT) {
            ParseResult<OffsetDate> parseResult = OffsetDatePattern.GeneralIso.Parse(strDT);
            if (parseResult.Success) {
                return parseResult.Value;
            }

            return null;
        }

        public static OffsetTime? ParseOffsetTime(string strDT) {
            ParseResult<OffsetTime> parseResult = OffsetTimePattern.GeneralIso.Parse(strDT);
            if (parseResult.Success) {
                return parseResult.Value;
            }

            return null;
        }

        public static LocalDateTime? ParseLocalDateTime(string strDT) {
            ParseResult<LocalDateTime> parseResult = LocalDateTimePattern.GeneralIso.Parse(strDT);
            if (parseResult.Success) {
                return parseResult.Value;
            }

            return null;
        }

        public static LocalTime? ParseLocalTime(string strDT) {
            ParseResult<LocalTime> parseResult = LocalTimePattern.GeneralIso.Parse(strDT);
            if (parseResult.Success) {
                return parseResult.Value;
            }

            return null;
        }

        public static LocalDate? ParseLocalDate(string strDT) {
            ParseResult<LocalDate> parseResult = LocalDatePattern.Iso.Parse(strDT);
            if (parseResult.Success) {
                return parseResult.Value;
            }

            return null;
        }

    }
}
