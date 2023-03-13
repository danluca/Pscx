using NodaTime;
using NodaTime.Extensions;
using System;

namespace Pscx.Time {
    /// <summary>
    /// Surrogate <see cref="NodaTime.ZonedDateTime"/> but with a better API than what Noda project decided to provide.
    /// Most API will delegate back to Noda's wrapped type or integrate seamlessly with original type API
    /// </summary>
    public sealed class ZonedDateTime {
        private NodaTime.ZonedDateTime dateTime;

        public NodaTime.ZonedDateTime DateTime {
            get { return dateTime; }
        }

        public long UnixEpochMillis {
            get { return dateTime.ToInstant().ToUnixTimeMilliseconds();  }
        }

        #region Constructors

        public ZonedDateTime() => dateTime = now();

        public ZonedDateTime(DateTime dt, TimeZoneInfo tz) => dateTime = of(tz, dt);

        public ZonedDateTime(NodaTime.ZonedDateTime dt) => dateTime = dt;

        public ZonedDateTime(LocalDateTime lt, string zoneId) => dateTime = of(zoneId, lt.ToDateTime());

        public ZonedDateTime(OffsetDateTime lt, string zoneId) => dateTime = of(zoneId, lt.ToDateTime());

        #endregion
        #region static utils

        public static NodaTime.ZonedDateTime of(string zoneId, params int[] fields) => of(getZone(zoneId), fields);

        public static NodaTime.ZonedDateTime of(DateTimeZone zone, params int[] fields) {
            NodaTime.LocalDateTime local = fields.Length switch {
                0 => SystemClock.Instance.GetCurrentInstant().InUtc().LocalDateTime,
                1 => new NodaTime.LocalDate(fields[0], 1, 1).AtMidnight(),
                2 => new NodaTime.LocalDate(fields[0], fields[1], 1).AtMidnight(),
                3 => new NodaTime.LocalDate(fields[0], fields[1], fields[2]).AtMidnight(),
                4 => new NodaTime.LocalDateTime(fields[0], fields[1], fields[2], fields[3], 0),
                5 => new NodaTime.LocalDateTime(fields[0], fields[1], fields[2], fields[3], fields[4]),
                6 => new NodaTime.LocalDateTime(fields[0], fields[1], fields[2], fields[3], fields[4], fields[5]),
                >= 7 => new NodaTime.LocalDateTime(fields[0], fields[1], fields[2], fields[3], fields[4], fields[5], fields[6])
            };

            return local.InZoneLeniently(zone);
        }

        public static NodaTime.ZonedDateTime of(params int[] fields) => of(DateTimeZoneProviders.Tzdb.GetSystemDefault(), fields);

        public static NodaTime.ZonedDateTime of(DateTimeZone zone, DateTime dateTime) => dateTime.ToLocalDateTime().InZoneLeniently(zone);

        public static NodaTime.ZonedDateTime of(DateTime dateTime) => of(DateTimeZoneProviders.Tzdb.GetSystemDefault(), dateTime);

        public static NodaTime.ZonedDateTime of(string zoneId, DateTime dateTime) => of(getZone(zoneId), dateTime);

        public static NodaTime.ZonedDateTime of(TimeZoneInfo zone, DateTime dateTime) => of(getZone(zone), dateTime);

        public static NodaTime.ZonedDateTime of(NodaTime.LocalDateTime localTime) => localTime.InZoneLeniently(DateTimeZoneProviders.Tzdb.GetSystemDefault());

        public static NodaTime.ZonedDateTime of(DateTimeZone zone, NodaTime.LocalDateTime localTime) => localTime.InZoneLeniently(zone);
        
        public static NodaTime.ZonedDateTime of(string zoneId, NodaTime.LocalDateTime localTime) => of(getZone(zoneId), localTime);

        public static NodaTime.ZonedDateTime now() => now(DateTimeZoneProviders.Tzdb.GetSystemDefault());

        public static NodaTime.ZonedDateTime now(DateTimeZone zone) => SystemClock.Instance.GetCurrentInstant().InZone(zone);

        public static NodaTime.ZonedDateTime now(TimeZoneInfo zone) => now(getZone(zone));

        public static NodaTime.ZonedDateTime now(string zoneId) => now(getZone(zoneId));

        public static NodaTime.ZonedDateTime utcNow() => now(DateTimeZone.Utc);

        public static NodaTime.ZonedDateTime operator +(ZonedDateTime time) => time.dateTime;
        
        public static NodaTime.ZonedDateTime operator +(ZonedDateTime time1, Duration dur) => time1.dateTime.Plus(dur);
        #endregion

        #region instance utils
        public NodaTime.ZonedDateTime Plus(Duration dur) => dateTime.Plus(dur);

        public NodaTime.ZonedDateTime PlusHours(int hours) => dateTime.PlusHours(hours);

        public NodaTime.ZonedDateTime PlusMinutes(int minutes) => dateTime.PlusMinutes(minutes);

        public NodaTime.ZonedDateTime PlusSeconds(int seconds) => dateTime.PlusMinutes(seconds);

        public NodaTime.ZonedDateTime PlusMilliseconds(int milliseconds) => dateTime.PlusMinutes(milliseconds);

        public NodaTime.ZonedDateTime Minus(Duration dur) => dateTime.Minus(dur);

        public NodaTime.Duration Minus(ZonedDateTime dTime) => dateTime.Minus(dTime.dateTime);

        public NodaTime.Duration Minus(NodaTime.ZonedDateTime dTime) => dateTime.Minus(dTime);

        public override string ToString() {
            return dateTime.ToString();
        }
        #endregion

        #region Converters
        public Instant ToInstant() => dateTime.ToInstant();

        public DateTime ToDateTime() => dateTime.ToDateTimeUnspecified();

        public DateTime ToDateTime(out TimeZoneInfo zone) {
            zone = TimeZoneInfo.FindSystemTimeZoneById(dateTime.Zone.Id);
            return dateTime.ToDateTimeUtc();
        }

        private static DateTimeZone getZone(string zoneId) {
            DateTimeZone zone = DateTimeZoneProviders.Tzdb.GetZoneOrNull(zoneId);
            if (zone == null) 
                throw new ArgumentException($"Invalid time zone ID - {zoneId}");
            return zone;
        }

        private static DateTimeZone getZone(TimeZoneInfo tzi) {
            if (tzi.HasIanaId) {
                return getZone(tzi.Id);
            }

            throw new ArgumentException($"The native TimeZoneInfo object with id {tzi.Id} is not supported by IANA TZDB");
        }
        #endregion

    }
}
