using System;
using System.Management.Automation.Language;

namespace Pscx.Commands
{
    /// <summary>
    /// Represents the structured result of parsing one PowerShell script.
    /// </summary>
    public sealed class ScriptTestResult
    {
        internal ScriptTestResult(string path, ParseError[] errors)
        {
            Path = path;
            Errors = errors ?? Array.Empty<ParseError>();
        }

        /// <summary>
        /// Gets the source path, or null when the script was supplied directly.
        /// </summary>
        public string Path { get; }

        /// <summary>
        /// Gets a value indicating whether the script parsed without errors.
        /// </summary>
        public bool IsValid => Errors.Length == 0;

        /// <summary>
        /// Gets the structured parser errors.
        /// </summary>
        public ParseError[] Errors { get; }
    }
}
