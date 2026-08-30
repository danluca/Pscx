using Pscx.Commands;
using Pscx.Core.IO;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.ComponentModel;
using System.IO;
using System.Management.Automation;
using System.Text;
using System.Linq;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.TypeResolvers;
using Pscx;

namespace Pscx.Commands.Yaml {
    [Cmdlet(VerbsData.ConvertTo, PscxNouns.Yaml)]
    [Description("Converts YAML document or PowerShell structured objects into YAML file (leverages YamlDotNet library).")]
    [RelatedLink(typeof(ConvertFromYamlCommand))]
    public class ConvertToYamlCommand : PscxCmdlet {
        [Parameter(ParameterSetName = PscxInputObjectPathCommandBase.ParameterSetObject, Mandatory = true, Position = 0, ValueFromPipeline = true,
            HelpMessage =
                "Accepts an object as input to the cmdlet; best bet is for objects returned by ConvertFrom-Yaml cmdlet. Enter a variable that contains the objects or type a command or expression that gets the objects.")]
        [AllowNull]
        [AllowEmptyString]
        public PSObject InputObject { get; set; }

        [Parameter(Position = 1, HelpMessage = "Output file where YAML content is written, optional (YAML string sent to object stream if not specified)")]
        [PscxPath(NoGlobbing = true)]
        public PscxPathInfo OutputPath { get; set; }

        protected override void BeginProcessing() {
            base.BeginProcessing();
            if (OutputPath != null) {
                var path = OutputPath.ProviderPath;
                //error out if file already exists
                if (new FileInfo(path).Exists) {
                    throw new ArgumentException($"Output file {path} already exists, will not overwrite");
                }

                //ensure parent directory exists
                string parentOutDir = Path.GetDirectoryName(path);
                if (!Directory.Exists(parentOutDir) && !string.IsNullOrEmpty(parentOutDir)) {
                    Directory.CreateDirectory(parentOutDir);
                }
            }
        }

        protected override void ProcessRecord() {
            base.ProcessRecord();

            var builder = new SerializerBuilder();
            builder.EnsureRoundtrip().DisableAliases().WithTypeResolver(new DynamicTypeResolver()).WithIndentedSequences();
            builder = StringQuotingEmitter.Add(builder);
            var serializer = builder.Build();

            var data = PSObjectHelper.ConvertToGenericObject(InputObject);

            if (OutputPath == null) {
                var yaml = serializer.Serialize(data);
                WriteObject(yaml);
            } else {
                using var writer = new StreamWriter(OutputPath.ProviderPath);
                serializer.Serialize(writer, data);
            }
        }
    }
}
