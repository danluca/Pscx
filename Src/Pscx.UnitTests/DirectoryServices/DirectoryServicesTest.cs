// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using NUnit.Framework;
using Pscx.Win.Fwk.Providers.DirectoryServices;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Runtime.Versioning;

namespace PscxUnitTests.DirectoryServices {
    [TestFixture]
    [SupportedOSPlatform("windows")]
    public class DirectoryServicesTest : PscxProviderTest {
        [OneTimeSetUp]
        public override void SetUp() {
            base.SetUp();

            trustedDrive = ConnectTrustedServer();
            defaultDrive = ConnectDefaultNamingContext();
        }

        [OneTimeTearDown]
        public override void TearDown() {
            RemoveDrive(trustedDrive);
            RemoveDrive(defaultDrive);

            base.TearDown();
        }

        public string DefaultDomainNetBiosName = "EUROPE";

        public string TrustedServerPath = "LDAP://mijavm:389/CN=Partition, DC=mijavm, DC=com";

        private DirectoryServiceDriveInfo trustedDrive;
        private DirectoryServiceDriveInfo defaultDrive;

        [Test]
        public void TrustedServerNewContainer() {
            RemoveItem(NewContainer(trustedDrive.Name + ":\\"));
        }


        protected void AddProperty(string path, string property, object value) {
            SetProperty(path, property, value, "Add");
        }

        protected void RemoveProperty(string path, string property, object value) {
            SetProperty(path, property, value, "Remove");
        }

        protected void SetProperty(string path, string property, object value, params string[] switchParams) {
            Command set = new("Set-ItemProperty");
            set.Parameters.Add("LiteralPath", path);
            set.Parameters.Add("Name", property);
            set.Parameters.Add("Value", value);

            foreach (string swp in switchParams) {
                set.Parameters.Add(swp);
            }

            Invoke(set);
        }

        protected T GetProperty<T>(string path, string property) {
            object retval = GetProperty(path, property);

            if (retval != null) {
                return (T)retval;
            }

            return default;
        }

        private object GetProperty(string path, string property) {
            PSObject obj = GetProperty(path);
            PSPropertyInfo prop = obj.Properties[property];

            return prop?.Value;
        }

        protected PSObject GetProperty(string path) {
            Command get = new("Get-ItemProperty");
            get.Parameters.Add("LiteralPath", path);

            return InvokeReturnOne(get);
        }

        [SupportedOSPlatform("windows")]
        protected string NewUser(string parent) {
            using DirectoryEntryInfo user = NewItem(parent, "user", out string path);
            return path;
        }

        [SupportedOSPlatform("windows")]
        protected string NewOrgUnit(string parent) {
            using DirectoryEntryInfo orgUnit = NewItem(parent, "organizationalUnit", out string path);
            return path;
        }

        [SupportedOSPlatform("windows")]
        protected string NewContainer(string parent) {
            using DirectoryEntryInfo container = NewItem(parent, "container", out string path);
            return path;
        }


        [SupportedOSPlatform("windows")]
        protected string NewGroup(string parent) {
            using DirectoryEntryInfo container = NewItem(parent, "group", out string path);
            return path;
        }

        [SupportedOSPlatform("windows")]
        protected DirectoryEntryInfo NewItem(string parent, string type, out string path) {
            return NewItem<DirectoryEntryInfo>(parent, type, out path);
        }

        [SupportedOSPlatform("windows")]
        protected DirectoryServiceDriveInfo NewDrive(string name, string root) {
            return NewDrive(name, root, null);
        }

        [SupportedOSPlatform("windows")]
        protected DirectoryServiceDriveInfo NewDrive(string name, string root, PSCredential credential) {
            return NewDrive<DirectoryServiceDriveInfo>(name, "DirectoryServices", root, credential);
        }

        [SupportedOSPlatform("windows")]
        protected DirectoryServiceDriveInfo ConnectDefaultNamingContext() {
            Command get = new("Get-PSDrive");
            get.Parameters.Add("Name", DefaultDomainNetBiosName);

            return InvokeReturnOne<DirectoryServiceDriveInfo>(get);
        }

        [SupportedOSPlatform("windows")]
        protected DirectoryServiceDriveInfo ConnectTrustedServer() {
            return NewDrive("ADAM", TrustedServerPath);
            ;
        }
    }
}