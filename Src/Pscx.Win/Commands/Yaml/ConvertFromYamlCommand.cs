using Pscx.Commands;
using Pscx.Core.IO;
using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.ComponentModel;
using System.IO;
using System.Management.Automation;
using System.Text;
using YamlDotNet.Core;
using YamlDotNet.RepresentationModel;

namespace Pscx.Win.Commands.Yaml {
    [Cmdlet(VerbsData.ConvertFrom, PscxWinNouns.Yaml)]
    [Description("Converts YAML string/file to PowerShell structured objects (leverages YamlDotNet library).")]
    [RelatedLink(typeof(ConvertToYamlCommand))]
    public class ConvertFromYamlCommand : PscxInputObjectPathCommandBase {

        [Parameter]
        public SwitchParameter AllDocuments { get; set; }

        protected override void BeginProcessing() {
            base.BeginProcessing();
            RegisterInputType<string>(stringToYaml);
        }

        protected override void ProcessPath(PscxPathInfo pscxPath) {
            var file = new FileInfo(pscxPath.ProviderPath);
            var text = File.ReadAllText(file.FullName, Encoding.UTF8);
            stringToYaml(text);
        }

        private void stringToYaml(string text) {
            using var strReader = new StringReader(text);
            var yaml = new YamlStream();
            var coreParser = new Parser(strReader);
            var parser = new MergingParser(coreParser);
            yaml.Load(parser);
            if (AllDocuments) {
                foreach (var document in yaml.Documents) {
                    var rootNode = document.RootNode;
                    var result = ConvertFromYaml(rootNode);
                    WriteObject(result, enumerateCollection: true);
                }
            } else {
                var rootNode = yaml.Documents[0].RootNode;
                var result = ConvertFromYaml(rootNode);
                WriteObject(result, enumerateCollection: true);
            }
        }

        private object ConvertFromYaml(YamlNode node) {
            if (node == null) {
                return null;
            }

            switch (node.NodeType) {
                case YamlNodeType.Scalar:
                    return (node as YamlScalarNode)?.Value;
                case YamlNodeType.Sequence:
                    var list = new List<object>();
                    foreach (var item in (node as YamlSequenceNode)?.Children ?? []) {
                        list.Add(ConvertFromYaml(item));
                    }

                    return list;
                case YamlNodeType.Mapping:
                    var dict = new Dictionary<string, object>();
                    foreach (var item in (node as YamlMappingNode)?.Children) {
                        dict.Add((item.Key as YamlScalarNode).Value, ConvertFromYaml(item.Value));
                    }

                    return dict;
                case YamlNodeType.Alias:
                default:
                    throw new NotImplementedException($"Unsupported YAML node type: {node.NodeType}");
            }
        }
    }
}
