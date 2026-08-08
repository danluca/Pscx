// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.Data;
using System.Runtime.Versioning;
using NUnit.Framework;
using Pscx.Win.Reflection.DynamicType;

namespace PscxInternalTests.Windows.Database {
    [TestFixture]
    [SupportedOSPlatform("windows")]
    public class DataTypeSetterTests {
        public class TestClass {
            public int? I { get; set; }
            public string S { get; set; }
        }

        [TestCase(false)]
        [TestCase(true)]
        public void SetValuesMapsDatabaseValues(bool useDatabaseNull) {
            var table = new DataTable();
            table.Columns.Add(new DataColumn("I", typeof(int)));
            table.Columns.Add(new DataColumn("S", typeof(string)));
            var row = table.Rows.Add(useDatabaseNull ? DBNull.Value : 10, "Value");
            var target = new TestClass();

            new PropertySetter(typeof(TestClass)).SetValues(target, new DataRowIndexer(row), false);

            Assert.That(target.I, Is.EqualTo(useDatabaseNull ? null : 10));
            Assert.That(target.S, Is.EqualTo("Value"));
        }
    }
}
