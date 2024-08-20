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

namespace Pscx.Win.Commands.Yaml {
    [Cmdlet(VerbsData.ConvertTo, PscxWinNouns.Yaml)]
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

            var data = ConvertPsObjectToGenericObject(InputObject);

            if (OutputPath == null) {
                var yaml = serializer.Serialize(data);
                WriteObject(yaml);
            } else {
                using var writer = new StreamWriter(OutputPath.ProviderPath);
                serializer.Serialize(writer, data);
            }
        }

        private static object ConvertPsObjectToGenericObject(object data) {
            if (data == null) {
                return null;
            }

            return data switch {
                PSObject psobj => ConvertPsCustomObjectToDictionary(psobj),
                IDictionary dictionary => ConvertDictionaryToDictionary(dictionary),
                IList list => ConvertListToGenericList(list),
                _ => Convert.ChangeType(data, data.GetType()),
            };
        }

        private static Dictionary<string, object> ConvertPsCustomObjectToDictionary(PSObject psObject) {
            return psObject?.BaseObject switch {
                OrderedDictionary orderedDictionary => ConvertDictionaryToDictionary(orderedDictionary),
                IDictionary dictionary => ConvertDictionaryToDictionary(dictionary),
                _ => new Dictionary<string, object>() { { "base", Convert.ChangeType(psObject?.BaseObject, psObject?.BaseObject?.GetType() ?? typeof(string)) } }
            };
        }

        private static Dictionary<string, object> ConvertDictionaryToDictionary(IDictionary dict) {
            return dict.Keys.Cast<string>().ToDictionary(
                key => key,
                key => ConvertPsObjectToGenericObject(dict[key])
            );
        }

        private static List<object> ConvertListToGenericList(IList list) {
            return list.Cast<object>().Select(ConvertPsObjectToGenericObject).ToList();
        }
    }
}