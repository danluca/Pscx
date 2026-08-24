// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using System.ComponentModel;
using System.Management.Automation;

namespace Pscx.Commands.EnvironmentBlock {
    [OutputType(typeof(PathVariableChange))]
    [Cmdlet(VerbsCommon.Add, PscxNouns.PathVariable, SupportsShouldProcess = true), Description("Adds values to an environment variable of type PATH (default is PATH variable)")]
    [RelatedLink(typeof(GetPathVariableCommand))]
    [RelatedLink(typeof(SetPathVariableCommand))]
    [RelatedLink(typeof(PopEnvironmentBlockCommand))]
    [RelatedLink(typeof(PushEnvironmentBlockCommand))]
    public sealed class AddPathVariableCommand : PathVariableMutationCommandBase {
        [Parameter(Position = 0, Mandatory = true, ValueFromPipeline = true)]
        public string[] Value { get; set; }

        [Parameter]
        public override string Name { get; set; }

        [Parameter]
        public SwitchParameter Prepend { get; set; }

        protected override void ProcessRecord() {
            CollectValues(Value);
        }

        protected override void EndProcessing() {
            ApplyChange("Add", variable => {
                if (Prepend) {
                    variable.Prepend(CollectedValues);
                } else {
                    variable.Append(CollectedValues);
                }
            });
        }
    }
}
