//---------------------------------------------------------------------
// Author: Harley Green
//
// Description: Cmdlet to get data from Sql Server databases
//
// Creation Date: 2008/3/8
//---------------------------------------------------------------------
using System;
using System.Reflection;
using NUnit.Framework;
using Pscx.Win.Reflection.DynamicType;
using Wintellect.PowerCollections;

namespace PscxUnitTests.Database
{
    [TestFixture]
    public class TypeBuilderTest
    {
        [Test]
        public void CreateType_ReturnsNewType()
        {
            var builder = new DataTypeBuilder("PscxDb");
            Type type = builder.CreateType(new Pair<string, Type>[0]);
            Assert.That(type, Is.Not.Null);
        }

        [Test]        
        public void CreateType_MultipleInvocationsReturnDifferentTypes()
        {
            var dt1 = new Pair<string, Type>[0];
            var dt2 = new Pair<string, Type>[0];
            var builder = new DataTypeBuilder("PowerSQL");
            var lhs = builder.CreateType(dt1);
            var rhs = builder.CreateType(dt2);
            Assert.That(lhs, Is.EqualTo(rhs));
        }

        [Test]
        public void CreateType_AddsPropertiesForDataTableColumns()
        {
            var dt = new Pair<string, Type>[1];
            dt[0] = new Pair<string, Type>("Test", typeof(int));
            var builder = new DataTypeBuilder("PowerSQL");
            var dynamic = builder.CreateType(dt);
            var properties = dynamic.GetProperties(BindingFlags.Public | BindingFlags.Instance);
            Assert.That(1, Is.EqualTo(properties.Length));
            Assert.That("Test", Is.EqualTo(properties[0].Name));
            Assert.That(typeof(int?), Is.EqualTo(properties[0].PropertyType));
        }               
    }
}