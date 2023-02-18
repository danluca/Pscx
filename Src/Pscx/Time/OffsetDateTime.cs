using NodaTime;
using NodaTime.Extensions;
using System;

namespace Pscx.Time {
    /// <summary>
    /// Surrogate <see cref="NodaTime.OffsetDateTime"/> but with a better API than what Noda project decided to provide.
    /// Most API will delegate back to Noda's wrapped type or integrate seamlessly with original type API
    /// </summary>
    public sealed class OffsetDateTime {
        private NodaTime.OffsetDateTime dateTime;

        public NodaTime.OffsetDateTime DateTime {
            get { return dateTime;  }
        }

        public long UnixEpochMillis {
            get { return dateTime.ToInstant().ToUnixTimeMilliseconds();  }
        }

        #region Constructors
        public OffsetDateTime() => dateTime = now();

        public OffsetDateTime(DateTime dt, TimeSpan ofs) => dateTime = of((int)ofs.TotalMinutes, dt);

        public OffsetDateTime(DateTimeOffset dto) => dateTime = of((int)dto.Offset.TotalMinutes, dto.LocalDateTime);
        
        public OffsetDateTime(LocalDateTime dto, int ofsMinutes) => dateTime = of(ofsMinutes, dto.ToDateTime());

        public OffsetDateTime(NodaTime.OffsetDateTime dt) => dateTime = dt;

        #endregion
        #region static utils
        public static NodaTime.OffsetDateTime of(int ofsMinutes, params int[] fields) => of(getOffset(ofsMinutes), fields);

        public static NodaTime.OffsetDateTime of(NodaTime.Offset ofs, params int[] fields) {
            NodaTime.LocalDateTime local = fields.Length switch {
                0 => new NodaTime.LocalDateTime(),
                1 => new NodaTime.LocalDate(fields[0], 1, 1).AtMidnight(),
                2 => new NodaTime.LocalDate(fields[0], fields[1], 1).AtMidnight(),
                3 => new NodaTime.LocalDate(fields[0], fields[1], fields[2]).AtMidnight(),
                4 => new NodaTime.LocalDateTime(fields[0], fields[1], fields[2], fields[3], 0),
                5 => new NodaTime.LocalDateTime(fields[0], fields[1], fields[2], fields[3], fields[4]),
                6 => new NodaTime.LocalDateTime(fields[0], fields[1], fields[2], fields[3], fields[4], fields[5]),
                >= 7 => new NodaTime.LocalDateTime(fields[0], fields[1], fields[2], fields[3], fields[4], fields[5], fields[6])
            };

            return local.WithOffset(ofs);
        }

        public static NodaTime.OffsetDateTime of(params int[] fields) => of(DateTimeZoneProviders.Tzdb.GetSystemDefault().GetUtcOffset(SystemClock.Instance.GetCurrentInstant()), fields);

        public static NodaTime.OffsetDateTime of(NodaTime.Offset zone, DateTime dateTime) => dateTime.ToLocalDateTime().WithOffset(zone);

        public static NodaTime.OffsetDateTime of(DateTime dateTime) => of(DateTimeZoneProviders.Tzdb.GetSystemDefault().GetUtcOffset(dateTime.ToInstant()), dateTime);

        public static NodaTime.OffsetDateTime of(int ofsMinutes, DateTime dateTime) => of(getOffset(ofsMinutes), dateTime);

        public static NodaTime.OffsetDateTime of(TimeZoneInfo zone, DateTime dateTime) => of(getOffset(zone, dateTime), dateTime);

        public static NodaTime.OffsetDateTime of(NodaTime.LocalDateTime localTime) => localTime.WithOffset(DateTimeZoneProviders.Tzdb.GetSystemDefault().GetUtcOffset(localTime.InUtc().ToInstant()));

        public static NodaTime.OffsetDateTime of(DateTimeZone zone, NodaTime.LocalDateTime localTime) => localTime.WithOffset(zone.GetUtcOffset(localTime.InUtc().ToInstant()));

        public static NodaTime.OffsetDateTime of(int ofsMinutes, NodaTime.LocalDateTime localTime) => of(getOffset(ofsMinutes), localTime.ToDateTimeUnspecified().ToLocalTime());

        public static NodaTime.OffsetDateTime now() => now(DateTimeZoneProviders.Tzdb.GetSystemDefault());

        public static NodaTime.OffsetDateTime now(DateTimeZone zone) => now(zone.GetUtcOffset(SystemClock.Instance.GetCurrentInstant()));

        public static NodaTime.OffsetDateTime now(TimeZoneInfo zone) => now(getOffset(zone));

        public static NodaTime.OffsetDateTime now(Offset ofs) => SystemClock.Instance.GetCurrentInstant().WithOffset(ofs);

        public static NodaTime.OffsetDateTime now(int ofsMinutes) => now(getOffset(ofsMinutes));

        public static NodaTime.OffsetDateTime utcNow() => now(Offset.Zero);

        public static NodaTime.OffsetDateTime operator +(OffsetDateTime time) => time.dateTime;
        
        public static NodaTime.OffsetDateTime operator +(OffsetDateTime time1, Duration dur) => time1.dateTime.Plus(dur);
        #endregion

        #region instance utils
        public NodaTime.OffsetDateTime Plus(Duration dur) => dateTime.Plus(dur);

        public NodaTime.OffsetDateTime PlusHours(int hours) => dateTime.PlusHours(hours);

        public NodaTime.OffsetDateTime PlusMinutes(int minutes) => dateTime.PlusMinutes(minutes);

        public NodaTime.OffsetDateTime PlusSeconds(int seconds) => dateTime.PlusMinutes(seconds);

        public NodaTime.OffsetDateTime PlusMilliseconds(int milliseconds) => dateTime.PlusMinutes(milliseconds);

        public NodaTime.OffsetDateTime Minus(Duration dur) => dateTime.Minus(dur);

        public NodaTime.Duration Minus(OffsetDateTime dTime) => dateTime.Minus(dTime.dateTime);

        public NodaTime.Duration Minus(NodaTime.OffsetDateTime dTime) => dateTime.Minus(dTime);

        public override string ToString() {
            return dateTime.ToString();
        }

        #endregion

        #region Converters
        public Instant ToInstant() => dateTime.ToInstant();

        public DateTime ToDateTime() => dateTime.ToDateTimeOffset().LocalDateTime;

        public DateTimeOffset ToDateTimeOffset() => dateTime.ToDateTimeOffset();

        public DateTime ToDateTime(out TimeSpan zone) {
            zone = new TimeSpan(dateTime.Offset.Ticks);
            return dateTime.ToDateTimeOffset().LocalDateTime;
        }

        private static Offset getOffset(int ofsMinutes) => Offset.FromSeconds(ofsMinutes * 60);

        private static Offset getOffset(TimeZoneInfo tzi) => Offset.FromTimeSpan(tzi.GetUtcOffset(DateTimeOffset.UtcNow));

        private static Offset getOffset(TimeZoneInfo tzi, DateTime dateTime) => Offset.FromTimeSpan(tzi.GetUtcOffset(dateTime));

        #endregion

    }
}
