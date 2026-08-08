using System;
using System.Management.Automation;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.TypeResolvers;
using Pscx.Win.Commands.Yaml;
using Pscx;

namespace Pscx.Win.Fwk.TypeAccelerators
{
    public struct Yaml
    {
        private readonly string _value;

        public Yaml(object value)
        {
            var builder = new SerializerBuilder();
            builder.EnsureRoundtrip().DisableAliases().WithTypeResolver(new DynamicTypeResolver()).WithIndentedSequences();
            builder = StringQuotingEmitter.Add(builder);
            var serializer = builder.Build();

            var data = PSObjectHelper.ConvertToGenericObject(value);
            _value = serializer.Serialize(data);
        }

        public override string ToString()
        {
            return _value;
        }
    }
}
