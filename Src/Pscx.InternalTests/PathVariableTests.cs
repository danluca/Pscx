// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System;
using System.IO;
using NUnit.Framework;
using Pscx.EnvironmentBlock;

namespace PscxInternalTests {
    [TestFixture]
    public class PathVariableTests {
        private string _name;

        [SetUp]
        public void SetUp() {
            _name = $"PSCX_PATH_TEST_{Guid.NewGuid():N}";
        }

        [TearDown]
        public void TearDown() {
            Environment.SetEnvironmentVariable(_name, null, EnvironmentVariableTarget.Process);
        }

        [Test]
        public void DuplicateRemovalPreservesFirstOccurrenceOrder() {
            SetValue("second", "first", "second", "third", "first");

            var variable = new PathVariable(_name);

            Assert.That(variable.GetValues(), Is.EqualTo(new[] { "second", "first", "third" }));
            Assert.That(variable.DuplicateValues, Is.EqualTo(new[] { "second", "first" }));
        }

        [Test]
        public void DefaultComparisonUsesPlatformPathSemantics() {
            SetValue("CasePath", "casepath");

            var variable = new PathVariable(_name);

            int expectedCount = OperatingSystem.IsWindows() ? 1 : 2;
            Assert.That(variable.GetValues(), Has.Length.EqualTo(expectedCount));
        }

        [Test]
        public void CaseInsensitiveOptionCollapsesCaseVariants() {
            SetValue("CasePath", "casepath");

            var variable = new PathVariable(
                _name,
                EnvironmentVariableTarget.Process,
                caseInsensitive: true,
                normalize: false,
                validate: false,
                retainUnavailable: false);

            Assert.That(variable.GetValues(), Is.EqualTo(new[] { "CasePath" }));
            Assert.That(variable.DuplicateValues, Is.EqualTo(new[] { "casepath" }));
        }

        [Test]
        public void NormalizeProducesCanonicalPaths() {
            string directory = Path.Combine(Path.GetTempPath(), $"pscx-path-{Guid.NewGuid():N}");
            Directory.CreateDirectory(directory);
            try {
                SetValue(directory + Path.DirectorySeparatorChar);
                var variable = new PathVariable(
                    _name,
                    EnvironmentVariableTarget.Process,
                    caseInsensitive: false,
                    normalize: true,
                    validate: false,
                    retainUnavailable: false);

                Assert.That(variable.GetValues(), Is.EqualTo(new[] { Path.GetFullPath(directory) }));
            }
            finally {
                Directory.Delete(directory);
            }
        }

        [TestCase(false, 1)]
        [TestCase(true, 2)]
        public void ValidationCanRemoveOrRetainUnavailableEntries(
            bool retainUnavailable,
            int expectedCount) {
            string available = Path.GetTempPath();
            string unavailable = Path.Combine(Path.GetTempPath(), $"pscx-missing-{Guid.NewGuid():N}");
            SetValue(available, unavailable);
            var variable = new PathVariable(
                _name,
                EnvironmentVariableTarget.Process,
                caseInsensitive: false,
                normalize: true,
                validate: true,
                retainUnavailable: retainUnavailable);

            Assert.That(variable.GetValues(), Has.Length.EqualTo(expectedCount));
            Assert.That(variable.InvalidValues, Is.EqualTo(new[] { Path.GetFullPath(unavailable) }));
        }

        private void SetValue(params string[] values) {
            Environment.SetEnvironmentVariable(
                _name,
                string.Join(Path.PathSeparator, values),
                EnvironmentVariableTarget.Process);
        }
    }
}
