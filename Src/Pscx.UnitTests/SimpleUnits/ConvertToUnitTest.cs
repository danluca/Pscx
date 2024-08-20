using NUnit.Framework;
using Pscx.SimpleUnits;
using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

namespace PscxUnitTests.SimpleUnits {
    [TestFixture]
    public class ConvertToUnitTest : PscxCmdletTest {
        [Test]
        public void testUnitConversion1() {
            Command cmd = new("ConvertTo-Unit");
            cmd.Parameters.Add("Value", 320287.65);
            cmd.Parameters.Add("FromUnit", "m");
            cmd.Parameters.Add("ToUnit", "km");

            Collection<PSObject> res = Invoke(cmd);
            Assert.That(res, Is.Not.Null);
            Assert.That(1, Is.EqualTo(res.Count));
            Assert.That(res[0].BaseObject, Is.AssignableTo(typeof(Measurement)));
            Assert.That(Length.Kilometer, Is.EqualTo((res[0].BaseObject as Measurement).unit));
        }
    }
}
