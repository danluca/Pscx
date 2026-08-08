// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Reflection;
using System.Runtime.Versioning;
using NUnit.Framework;
using Pscx.Win.Reflection.DynamicType;
using Wintellect.PowerCollections;

namespace PscxInternalTests.Windows.Database {
    [TestFixture]
    [SupportedOSPlatform("windows")]
    public class DataTypeBuilderTests {
        [Test]
        public void CreateTypeReturnsDistinctTypesForSeparateInvocations() {
            var builder = new DataTypeBuilder("PowerSQL");

            var first = builder.CreateType(Array.Empty<Pair<string, Type>>());
            var second = builder.CreateType(Array.Empty<Pair<string, Type>>());

            Assert.That(second, Is.Not.SameAs(first));
        }

        [Test]
        public void CreateTypeAddsNullablePropertiesForColumns() {
            var schema = new[] { new Pair<string, Type>("Test", typeof(int)) };

            var dynamicType = new DataTypeBuilder("PowerSQL").CreateType(schema);
            var properties = dynamicType.GetProperties(BindingFlags.Public | BindingFlags.Instance);

            Assert.That(properties, Has.Length.EqualTo(1));
            Assert.That(properties[0].Name, Is.EqualTo("Test"));
            Assert.That(properties[0].PropertyType, Is.EqualTo(typeof(int?)));
        }
    }
}
