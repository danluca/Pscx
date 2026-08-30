using System;
using System.ComponentModel;
using System.Management.Automation;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;

namespace Pscx.Commands.UIAutomation
{
    [Cmdlet(VerbsCommon.Get, PscxWinAdminNouns.ForegroundWindow)]
    [Description("Returns the handle of the window in the foreground on the current desktop.")]
    [OutputType(typeof(IntPtr))]
    [SupportedOSPlatform("windows")]
    public sealed class GetForegroundWindowCommand : Cmdlet
    {
        protected override void ProcessRecord()
        {
            WriteObject(GetForegroundWindow());
        }

        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();
    }
}
