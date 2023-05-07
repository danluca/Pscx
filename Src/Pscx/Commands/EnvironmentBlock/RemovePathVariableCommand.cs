// Copyright © 2023 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

using Pscx.EnvironmentBlock;
using System;
using System.ComponentModel;
using System.Management.Automation;

namespace Pscx.Commands.EnvironmentBlock {
    [Cmdlet(VerbsCommon.Remove, PscxNouns.PathVariable), Description("Removes values from an environment variable of type PATH (default is PATH variable)")]
    [RelatedLink(typeof(AddPathVariableCommand))]
    [RelatedLink(typeof(GetPathVariableCommand))]
    [RelatedLink(typeof(SetPathVariableCommand))]
    [RelatedLink(typeof(PopEnvironmentBlockCommand))]
    [RelatedLink(typeof(PushEnvironmentBlockCommand))]
    public class RemovePathVariableCommand : PathVariableCommandBase {
        [Parameter(Position = 0, Mandatory = true, ValueFromPipeline = true)]
        public string[] Value { get; set; }

        [Parameter]
        public override string Name { get; set; }

        protected override void EndProcessing() {
            if ((Value?.Length ?? 0) == 0) {
                return;
            }

            using PathVariable variable = new(Name, Target);
            variable.Remove(Value);
        }
    }

}