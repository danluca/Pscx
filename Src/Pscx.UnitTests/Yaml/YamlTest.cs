using NUnit.Framework;
using System.Linq;

namespace PscxUnitTests.Yaml {
    [TestFixture]
    internal class YamlTest : PscxCmdletTest {
        [Test]
        public void toYaml() {
            string script = @"
$f = convertfrom-yaml -path ./Yaml/file.yml
$f
convertto-yaml $f
            ";

            var result = Invoke(script);
            string yamlOutput = result.Last().ToString();

            Assert.That(yamlOutput, Is.Not.Null);
            //note the output does NOT include comments
            Assert.That(yamlOutput.Contains("    runs-on: windows-latest"), Is.True);
            Assert.That(yamlOutput.Contains("    - name: Checkout"), Is.True);
            Assert.That(yamlOutput.Contains("      run: |"), Is.True);
            Assert.That(yamlOutput.Contains("        .\\Tools\\version_update.ps1 \"$env:Build_Version\""), Is.True);
        }
    }
}
