using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;

namespace Pscx
{
    public static class PSObjectHelper
    {
        public static object ConvertToGenericObject(object data)
        {
            if (data == null) return null;

            if (data is PSObject psObject)
            {
                var baseObject = psObject.BaseObject;
                if (baseObject is IDictionary dictionary)
                {
                    return ConvertDictionaryToDictionary(dictionary);
                }
                if (baseObject is IList baseList && !(baseObject is string))
                {
                    return ConvertListToGenericList(baseList);
                }
                
                if (baseObject is PSCustomObject || IsSimpleType(baseObject.GetType()))
                {
                     var result = new Dictionary<string, object>();
                     bool hasProperties = false;
                     foreach (var prop in psObject.Properties)
                     {
                         if (prop.IsGettable)
                         {
                             try
                             {
                                 result[prop.Name] = ConvertToGenericObject(prop.Value);
                                 hasProperties = true;
                             }
                             catch { }
                         }
                     }
                     if (hasProperties && (baseObject is PSCustomObject || result.Count > 0))
                     {
                         return result;
                     }
                     return baseObject;
                }
                
                return baseObject;
            }

            if (data is IDictionary dict)
            {
                return ConvertDictionaryToDictionary(dict);
            }

            if (data is IList dataList && !(data is string))
            {
                return ConvertListToGenericList(dataList);
            }

            return data;
        }

        private static bool IsSimpleType(Type type)
        {
            return type.IsPrimitive || type == typeof(string) || type == typeof(decimal) || type == typeof(DateTime) || type == typeof(Guid);
        }

        private static Dictionary<string, object> ConvertDictionaryToDictionary(IDictionary dict)
        {
            var result = new Dictionary<string, object>();
            foreach (DictionaryEntry entry in dict)
            {
                result[entry.Key.ToString()] = ConvertToGenericObject(entry.Value);
            }
            return result;
        }

        private static List<object> ConvertListToGenericList(IList list)
        {
            var result = new List<object>();
            foreach (var item in list)
            {
                result.Add(ConvertToGenericObject(item));
            }
            return result;
        }
    }
}
