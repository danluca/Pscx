using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Management.Automation;
using NUnit.Framework;

namespace PscxUnitTests.Xml
{
    [TestFixture]
    class TestXmlTests : PscxCmdletTest
    {
        [Test]
        public void SchemaTest_GoodXml()
        {
            string xmlPath = Path.Combine(this.ProjectDir, @"Xml\passes_schema_validation.xml");
            string schemaPath = Path.Combine(this.ProjectDir, @"Xml\test.xsd");

            string script = String.Format("Test-Xml '{0}' -SchemaPath '{1}'", xmlPath, schemaPath);
            Collection<PSObject> results = this.Invoke(script);

            Assert.That(1, Is.EqualTo(results.Count));
            bool result = (bool)results[0].BaseObject;
            Assert.That(result, Is.True);
        }

        [Test]
        public void SchemaTest_BadXml()
        {
            string xmlPath = Path.Combine(this.ProjectDir, @"Xml\fails_schema_validation.xml");
            string schemaPath = Path.Combine(this.ProjectDir, @"Xml\test.xsd");

            string script = String.Format("Test-Xml '{0}' -SchemaPath '{1}'", xmlPath, schemaPath);
            Collection<PSObject> results = this.Invoke(script);

            Assert.That(1, Is.EqualTo(results.Count));
            bool result = (bool)results[0].BaseObject;
            Assert.That(result, Is.False);
        }
    }
}
