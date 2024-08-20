//---------------------------------------------------------------------
// Author: jachymko
//
// Description: DirectoryServices provider tests.
//
// Creation Date: Feb 15, 2007
//---------------------------------------------------------------------
using System;
using System.Collections.Generic;
using System.DirectoryServices;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Security;
using System.Text;

using NUnit.Framework;
using Pscx.Win.Fwk.Providers.DirectoryServices;
using System.Runtime.Versioning;
using EntryInfoList = System.Collections.Generic.List<Pscx.Win.Fwk.Providers.DirectoryServices.DirectoryEntryInfo>;

namespace PscxUnitTests.DirectoryServices
{
    [TestFixture]
    [SupportedOSPlatform("windows")]
    public class ForeignServerTest : DirectoryServicesTest
    {
        public string ForeignServerPath = "LDAP://157.58.88.156/DC=LitwareInc, DC=com";
        public string ForeignServerUsername = "LITWAREINC\\Administrator";
        public string ForeignServerPassword = "pass@word1";
        
        private DirectoryServiceDriveInfo foreignDrive;

        [OneTimeSetUp]
        public override void SetUp()
        {
            base.SetUp();

            foreignDrive = ConnectForeignServer();
        }

        [OneTimeTearDown]
        public override void TearDown()
        {
            RemoveDrive(foreignDrive);
            
            base.TearDown();
        }

        [Test]
        public void P_NewOU()
        {
            RemoveItem(NewOrgUnit(foreignDrive.Name + ":\\"));
        }

        [Test]
        public void P_NewUserTest()
        {
            RemoveItem(NewUser());
        }

        [Test]
        public void P_RenameUser()
        {
            string userPath = NewUser();

            try
            {
                userPath = RenameItem(userPath, GetRandomName("renamedUser"));
            }
            finally
            {
                RemoveItem(userPath);
            }
        }

        [Test]
        public void P_SetPassword()
        {
            string userPath = NewUser();
            string password = "!Pa$$@worD123";

            try
            {
                SetProperty(userPath, "Password", password);

                DirectoryEntryInfo info = GetItem<DirectoryEntryInfo>(userPath);
                Assert.That(info is not null);
                
                string samName = GetProperty<String>(userPath, "SamAccountName");
                Assert.That(info.Name, Is.EqualTo(samName));

                using (DirectoryEntry entry = new DirectoryEntry(ForeignServerPath, samName, password))
                {
                    Assert.That("CN=" + info.Name, Is.EqualTo(entry.Name));
                }
            }
            finally
            {
                RemoveItem(userPath);
            }
        }

        [Test]
        public void P_DisableUser()
        {
            string userPath = NewUser(foreignDrive.Name + ":\\");

            try
            {
                SetProperty(userPath, "Disabled", 1);
                Assert.That(GetProperty<Boolean>(userPath, "Disabled"), Is.True);

                SetProperty(userPath, "Disabled", false);
                Assert.That(GetProperty<Boolean>(userPath, "Disabled"), Is.False);
            }
            finally
            {
                RemoveItem(userPath);
            }
        }

        [Test]
        public void P_NewGroup()
        {
            RemoveItem(NewGroup());
        }

        [Test]
        public void P_AddRemoveGroupMembers()
        {
            string group = NewGroup();
            DirectoryEntryInfo[] users = NewUsers(3);

            try
            {
                AddProperty(group, "Member", users[0].FullName);
                AddProperty(group, "Member", users[0]);
                AddProperty(group, "Member", users[1]);

                EntryInfoList members = GetProperty<EntryInfoList>(group, "Member");
                Assert.That(members, Is.Not.Null);

                Assert.That(members, Contains.Item(users[0]));
                Assert.That(members, Contains.Item(users[1]));
                AssertDoesNotContain(users[2], members);

                RemoveProperty(group, "Member", users[1].FullName);

                members = GetProperty<EntryInfoList>(group, "Member");
                AssertDoesNotContain(users[1], members);
                Assert.That(members, Contains.Item(users[0]));
            }
            finally
            {
                RemoveItem(group);

                foreach (DirectoryEntryInfo u in users)
                {
                    RemoveItem(u.FullName);
                }
            }
        }

        protected DirectoryEntryInfo[] NewUsers(int count)
        {
            DirectoryEntryInfo[] users = new DirectoryEntryInfo[count];

            for (int i = 0; i < count; i++)
            {
                users[i] = GetItem<DirectoryEntryInfo>(NewUser());
            }

            return users;
        }

        protected string NewUser()
        {
            return NewUser(foreignDrive.Name + ":\\");
        }

        protected string NewGroup()
        {
            return NewGroup(foreignDrive.Name + ":\\");
        }

        protected DirectoryServiceDriveInfo ConnectForeignServer()
        {
            SecureString pwd = new SecureString();
            foreach (char c in ForeignServerPassword)
            {
                pwd.AppendChar(c);
            }

            PSCredential credential = new PSCredential(ForeignServerUsername, pwd);
            return NewDrive("Litware", ForeignServerPath, credential);
        }
    }
}
