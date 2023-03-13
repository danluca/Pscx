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
            Assert.IsNotNull(res);
            Assert.AreEqual(1, res.Count);
            Assert.IsAssignableFrom(typeof(Measurement), res[0].BaseObject);
            Assert.AreEqual(Length.Kilometer, ((Measurement)res[0].BaseObject).unit);
        }
    }
}
