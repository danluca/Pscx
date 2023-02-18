using NodaTime;
using NodaTime.Extensions;
using System;

namespace Pscx.Time {
    /// <summary>
    /// Surrogate <see cref="NodaTime.LocalDateTime"/> but with a better API than what Noda project decided to provide.
    /// Most API will delegate back to Noda's wrapped type or integrate seamlessly with original type API
    /// </summary>
    public sealed class LocalDateTime {
        private NodaTime.LocalDateTime dateTime;

        public NodaTime.LocalDateTime DateTime {
            get { return dateTime;  }
        }

        public long UnixEpochMillis {
            get { return ToInstant().ToUnixTimeMilliseconds();  }
        }

        #region Constructors
        public LocalDateTime() => dateTime = now();

        public LocalDateTime(DateTime dt) => dateTime = of(dt);

        public LocalDateTime(NodaTime.LocalDateTime dt) => dateTime = dt;

        #endregion
        #region static utils
        public static NodaTime.LocalDateTime of(params int[] fields) {
            return fields.Length switch {
                0 => SystemClock.Instance.GetCurrentInstant().InUtc().LocalDateTime,
                1 => new LocalDate(fields[0], 1, 1).AtMidnight(),
                2 => new LocalDate(fields[0], fields[1], 1).AtMidnight(),
                3 => new LocalDate(fields[0], fields[1], fields[2]).AtMidnight(),
                4 => new NodaTime.LocalDateTime(fields[0], fields[1], fields[2], fields[3], 0),
                5 => new NodaTime.LocalDateTime(fields[0], fields[1], fields[2], fields[3], fields[4]),
                6 => new NodaTime.LocalDateTime(fields[0], fields[1], fields[2], fields[3], fields[4], fields[5]),
                >= 7 => new NodaTime.LocalDateTime(fields[0], fields[1], fields[2], fields[3], fields[4], fields[5], fields[6])
            };
        }

        public static NodaTime.LocalDateTime of(DateTime dateTime) => dateTime.ToLocalDateTime();

        public static NodaTime.LocalDateTime now() => SystemClock.Instance.GetCurrentInstant().InZone(DateTimeZoneProviders.Tzdb.GetSystemDefault()).LocalDateTime;

        public static NodaTime.LocalDateTime operator +(LocalDateTime time) => time.dateTime;
        
        public static NodaTime.LocalDateTime operator +(LocalDateTime time1, Period dur) => time1.dateTime.Plus(dur);
        #endregion

        #region instance utils
        public NodaTime.LocalDateTime Plus(Period dur) => dateTime.Plus(dur);

        public NodaTime.LocalDateTime PlusHours(int hours) => dateTime.PlusHours(hours);

        public NodaTime.LocalDateTime PlusMinutes(int minutes) => dateTime.PlusMinutes(minutes);

        public NodaTime.LocalDateTime PlusSeconds(int seconds) => dateTime.PlusMinutes(seconds);

        public NodaTime.LocalDateTime PlusMilliseconds(int milliseconds) => dateTime.PlusMinutes(milliseconds);

        public NodaTime.LocalDateTime Minus(Period dur) => dateTime.Minus(dur);

        public NodaTime.Period Minus(LocalDateTime dTime) => dateTime.Minus(dTime.dateTime);

        public NodaTime.Period Minus(NodaTime.LocalDateTime dTime) => dateTime.Minus(dTime);

        public override string ToString() {
            return dateTime.ToString();
        }

        #endregion

        #region Converters

        public Instant ToInstant() => dateTime.InUtc().ToInstant();

        public DateTime ToDateTime() => dateTime.ToDateTimeUnspecified().ToLocalTime();
        #endregion

    }
}
