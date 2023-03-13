using Pscx.SimpleUnits;
using System;
using System.ComponentModel;
using System.Management.Automation;

namespace Pscx.Commands {
    [Cmdlet(VerbsData.ConvertTo, PscxNouns.Unit), Description("Converts units into different compatible units - e.g. metric to non-metric, different multiplier, etc.")]
    [OutputType(typeof(Measurement))]
    public class ConvertToUnitCommand : PscxCmdlet {
        [Parameter(Position = 0, Mandatory = true, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "Numeric",
            HelpMessage = "Numeric value to convert")]
        public double Value {
            get;
            set;
        }

        [ValidateNotNull]
        [Parameter(Position = 1, Mandatory = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "Numeric", HelpMessage = "Unit of the numeric value")]
        public Unit FromUnit {
            get;
            set;
        }

        [ValidateNotNull]
        [Parameter(Position = 0, Mandatory = true, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, ParameterSetName = "String",
            HelpMessage = "Measurement (value-unit pair) to convert")]
        public Measurement Measurement {
            get;
            set;
        }

        [ValidateNotNull]
        [Parameter(Position = 1, Mandatory = true, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, HelpMessage = "Unit to convert into")]
        public Unit ToUnit {
            get;
            set;
        }

        protected override void ProcessRecord() {
            Measurement msmt = ParameterSetName == "Numeric" ? new Measurement(Value, FromUnit) : Measurement;
            WriteObject(msmt.Quantity.ToUnit(ToUnit));
        }
    }
}
