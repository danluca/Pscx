//---------------------------------------------------------------------
// Author: jachymko
//
// Description: Class describing DirectoryEntry property which can have
//              more values.
//
// Creation Date: 20 Feb 2007
//---------------------------------------------------------------------

using System.DirectoryServices;

namespace Pscx.Win.Fwk.DirectoryServices.DirectoryEntryProperties
{
    public class ListDirectoryEntryProperty : SimpleDirectoryEntryProperty
    {
        private const int ERROR_OBJECT_ALREADY_EXISTS = unchecked((int)(0x80071392));

        public ListDirectoryEntryProperty(string name, string attribute, DirectoryEntryPropertyAccess access)
            : base(name, attribute, access)
        {
        }

        public override bool CanAdd
        {
            get { return CanWrite; }
        }

        public override bool CanRemove
        {
            get { return CanWrite; }
        }

        public override bool CanSet
        {
            get { return false; }
        }

        protected override void OnAddValue(object value)
        {
            object[] array = value as object[];

            if (array == null)
            {
                array = new object[] { value };
            }

            PropertyValueCollection values =
                DirectoryUtils.GetPropertyValues(Entry, AttributeName);

            foreach (object val in array)
            {
                if (!values.Contains(val))
                {
                    values.Add(val);
                }
            }

            Entry.CommitChanges();
        }

        protected override void OnRemoveValue(object value)
        {
            object[] array = value as object[];

            if (array == null)
            {
                array = new object[] { value };
            }

            PropertyValueCollection values = DirectoryUtils.GetPropertyValues(Entry, AttributeName);

            foreach (object val in array)
            {
                if (values.Contains(val))
                {
                    values.Remove(val);
                }
            }

            Entry.CommitChanges();
        }
    }
}
