// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System.ComponentModel;
using System.Management.Automation;

namespace Pscx.Commands.EnvironmentBlock {
    [OutputType(typeof(PathVariableChange))]
    [Cmdlet(VerbsCommon.Remove, PscxNouns.PathVariable, SupportsShouldProcess = true), Description("Removes values from an environment variable of type PATH (default is PATH variable)")]
    [RelatedLink(typeof(AddPathVariableCommand))]
    [RelatedLink(typeof(GetPathVariableCommand))]
    [RelatedLink(typeof(SetPathVariableCommand))]
    [RelatedLink(typeof(PopEnvironmentBlockCommand))]
    [RelatedLink(typeof(PushEnvironmentBlockCommand))]
    public class RemovePathVariableCommand : PathVariableMutationCommandBase {
        [Parameter(Position = 0, Mandatory = true, ValueFromPipeline = true)]
        public string[] Value { get; set; }

        [Parameter]
        public override string Name { get; set; }

        protected override void ProcessRecord() {
            CollectValues(Value);
        }

        protected override void EndProcessing() {
            ApplyChange("Remove", variable => variable.Remove(CollectedValues));
        }
    }

}
