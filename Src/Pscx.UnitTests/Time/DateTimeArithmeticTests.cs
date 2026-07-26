// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using NodaTime;
using NUnit.Framework;
using PscxLocalDateTime = Pscx.Time.LocalDateTime;
using PscxOffsetDateTime = Pscx.Time.OffsetDateTime;
using PscxZonedDateTime = Pscx.Time.ZonedDateTime;

namespace PscxUnitTests.Time {
    [TestFixture]
    public sealed class DateTimeArithmeticTests {
        [TestCase(1)]
        [TestCase(0)]
        [TestCase(-1)]
        [TestCase(60)]
        public void LocalDateTime_PlusMethodsForwardTheRequestedUnit(int amount) {
            var source = new NodaTime.LocalDateTime(2024, 12, 31, 23, 59, 59, 999);
            var subject = new PscxLocalDateTime(source);

            Assert.That(subject.PlusSeconds(amount), Is.EqualTo(source.PlusSeconds(amount)));
            Assert.That(subject.PlusMilliseconds(amount), Is.EqualTo(source.PlusMilliseconds(amount)));
        }

        [TestCase(1)]
        [TestCase(0)]
        [TestCase(-1)]
        [TestCase(60)]
        public void OffsetDateTime_PlusMethodsForwardTheRequestedUnit(int amount) {
            var source = new NodaTime.LocalDateTime(2024, 12, 31, 23, 59, 59, 999)
                .WithOffset(Offset.FromHours(-5));
            var subject = new PscxOffsetDateTime(source);

            Assert.That(subject.PlusSeconds(amount), Is.EqualTo(source.PlusSeconds(amount)));
            Assert.That(subject.PlusMilliseconds(amount), Is.EqualTo(source.PlusMilliseconds(amount)));
        }

        [TestCase(1)]
        [TestCase(0)]
        [TestCase(-1)]
        [TestCase(60)]
        public void ZonedDateTime_PlusMethodsForwardTheRequestedUnit(int amount) {
            var source = (Instant.FromUtc(2024, 12, 31, 23, 59, 59) + Duration.FromMilliseconds(999))
                .InUtc();
            var subject = new PscxZonedDateTime(source);

            Assert.That(subject.PlusSeconds(amount), Is.EqualTo(source.PlusSeconds(amount)));
            Assert.That(subject.PlusMilliseconds(amount), Is.EqualTo(source.PlusMilliseconds(amount)));
        }

        [Test]
        public void ZonedDateTime_PlusSecondsCrossesDaylightSavingTransition() {
            DateTimeZone zone = DateTimeZoneProviders.Tzdb["America/New_York"];
            ZonedDateTime source = Instant.FromUtc(2024, 3, 10, 6, 59, 59).InZone(zone);
            var subject = new PscxZonedDateTime(source);

            ZonedDateTime actual = subject.PlusSeconds(1);
            ZonedDateTime expected = Instant.FromUtc(2024, 3, 10, 7, 0, 0).InZone(zone);

            Assert.That(actual, Is.EqualTo(expected));
            Assert.That(actual.Hour, Is.EqualTo(3));
        }

        [Test]
        public void ZonedDateTime_PlusMillisecondsCrossesDaylightSavingTransition() {
            DateTimeZone zone = DateTimeZoneProviders.Tzdb["America/New_York"];
            ZonedDateTime source = (Instant.FromUtc(2024, 3, 10, 6, 59, 59) +
                Duration.FromMilliseconds(999)).InZone(zone);
            var subject = new PscxZonedDateTime(source);

            ZonedDateTime actual = subject.PlusMilliseconds(1);
            ZonedDateTime expected = Instant.FromUtc(2024, 3, 10, 7, 0, 0).InZone(zone);

            Assert.That(actual, Is.EqualTo(expected));
            Assert.That(actual.Hour, Is.EqualTo(3));
        }
    }
}
