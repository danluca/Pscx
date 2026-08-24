using System.ComponentModel;
using System.Management.Automation;

namespace Pscx.Commands.EnvironmentBlock {
    [OutputType(typeof(PathVariableChange))]
    [Cmdlet(VerbsCommon.Set, PscxNouns.PathVariable, SupportsShouldProcess = true), Description("Sets/overrides a path-like variable (defaults to PATH) to the value specified")]
    [RelatedLink(typeof(AddPathVariableCommand))]
    [RelatedLink(typeof(RemovePathVariableCommand))]
    [RelatedLink(typeof(GetPathVariableCommand))]
    [RelatedLink(typeof(PopEnvironmentBlockCommand))]
    [RelatedLink(typeof(PushEnvironmentBlockCommand))]
    public sealed class SetPathVariableCommand : PathVariableMutationCommandBase {
        [Parameter(Position = 0, Mandatory = true, ValueFromPipeline = true, HelpMessage = "Value for the variable")]
        public string[] Value { get; set; }

        [Parameter]
        public override string Name { get; set; }

        protected override void ProcessRecord() {
            CollectValues(Value);
        }

        protected override void EndProcessing() {
            ApplyChange("Set", variable => variable.Set(CollectedValues));
        }
    }
}
