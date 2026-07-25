// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using NUnit.Framework;
using Pscx.Win.Reflection.DynamicType;
using System;
using System.Data;
using System.Runtime.Versioning;

namespace PscxUnitTests.Database {
    [TestFixture]
    [SupportedOSPlatform("windows")]
    public class DataTypeSetterTest {
        public class TestClass {
            public int? I { get; set; }

            public string S { get; set; }
        }

        [Test]
        public void SetValues_SetsProperties() {
            var table = new DataTable();
            table.Columns.Add(new DataColumn("I", typeof(int)));
            table.Columns.Add(new DataColumn("S", typeof(string)));
            DataRow row = table.Rows.Add(10, "Value");

            var setter = new PropertySetter(typeof(TestClass));
            var testClass = new TestClass();
            setter.SetValues(testClass, new DataRowIndexer(row), false);
            Assert.That(10, Is.EqualTo(testClass.I));
            Assert.That("Value", Is.EqualTo(testClass.S));
        }

        [Test]
        public void SetValues_SetsDBNull() {
            var table = new DataTable();
            table.Columns.Add(new DataColumn("I", typeof(int)));
            table.Columns.Add(new DataColumn("S", typeof(string)));
            DataRow row = table.Rows.Add(DBNull.Value, "Value");

            var setter = new PropertySetter(typeof(TestClass));
            var testClass = new TestClass();
            setter.SetValues(testClass, new DataRowIndexer(row), false);
            Assert.That(null, Is.EqualTo(testClass.I));
            Assert.That("Value", Is.EqualTo(testClass.S));
        }
    }
}