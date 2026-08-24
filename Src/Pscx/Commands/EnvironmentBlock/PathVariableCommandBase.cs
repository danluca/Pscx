using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using Pscx.EnvironmentBlock;

namespace Pscx.Commands.EnvironmentBlock {
    public abstract class PathVariableCommandBase : PscxCmdlet {
        [Parameter]
        public EnvironmentVariableTarget Target { get; set; }

        [Parameter]
        public SwitchParameter CaseInsensitive { get; set; }

        [Parameter]
        public SwitchParameter Normalize { get; set; }

        [Parameter]
        public SwitchParameter Validate { get; set; }

        [Parameter]
        public SwitchParameter RetainUnavailable { get; set; }

        public abstract string Name { get; set; }

        protected override void BeginProcessing() {
            if (string.IsNullOrEmpty(Name)) {
                Name = "PATH";
            }
            if (!OperatingSystem.IsWindows() && Target != EnvironmentVariableTarget.Process) {
                var exception = new PlatformNotSupportedException(
                    $"Environment-variable target '{Target}' is supported only on Windows. Use the Process target on this operating system.");
                ThrowTerminatingError(new ErrorRecord(
                    exception,
                    "PathVariableTargetNotSupported",
                    ErrorCategory.NotImplemented,
                    Target));
            }
        }

        protected PathVariable CreatePathVariable(bool stripQuotes = false) {
            return new PathVariable(
                Name,
                Target,
                CaseInsensitive,
                Normalize,
                Validate,
                RetainUnavailable,
                stripQuotes);
        }
    }

    public abstract class PathVariableMutationCommandBase : PathVariableCommandBase {
        private readonly List<string> _values = new();

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        protected string[] CollectedValues => _values.ToArray();

        protected void CollectValues(string[] values) {
            if (values != null) {
                _values.AddRange(values);
            }
        }

        protected void ApplyChange(string operation, Action<PathVariable> mutation) {
            PathVariable variable = CreatePathVariable();
            string[] before = variable.GetOriginalValues();
            variable.GetValues();
            mutation(variable);
            string[] after = variable.GetValues();
            bool changed = !before.SequenceEqual(after, variable.Comparer);
            bool applied = false;
            if (changed && ShouldProcess($"{Name} ({Target})", $"{operation} path entries")) {
                variable.Commit();
                applied = true;
            }

            if (PassThru) {
                WriteObject(new PathVariableChange(operation, Target, variable, before, after, applied));
            }
        }
    }
}
