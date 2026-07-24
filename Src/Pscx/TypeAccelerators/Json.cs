using System;
using System.Management.Automation;
using System.Text.Json;
using System.Text.Json.Serialization;
using Pscx;

namespace Pscx.TypeAccelerators
{
    public struct Json
    {
        private readonly string _value;

        public Json(object value)
        {
            object obj = PSObjectHelper.ConvertToGenericObject(value);
            _value = JsonSerializer.Serialize(obj, new JsonSerializerOptions
            {
                WriteIndented = true
            });
        }

        public override string ToString()
        {
            return _value;
        }
    }
}
