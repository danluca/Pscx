//---------------------------------------------------------------------
//
// Description: Common class to store all cmdlet nouns.
//
//---------------------------------------------------------------------

using System;

namespace Pscx
{
    internal static class PscxNouns
    {
        public const string Unit = "Unit";
        public const string Base64 = "Base64";
        public const string File = "File";
        public const string FileVersionInfo = "FileVersionInfo";
        public const string TextFileInfo = "TextFileInfo";
        public const string Hash = "PscxHash";
        public const string Object = "Object";
        public const string Script = "Script";
        public const string TypeName = "TypeName";
        public const string Xml = "Xml";
        public const string Yaml = "Yaml";
        public const string UnixLineEnding = "UnixLineEnding";
        public const string WindowsLineEnding = "WindowsLineEnding";
        public const string ForegroundWindow = "ForegroundWindow";

        // FileSystem
        public const string DriveInfo = "DriveInfo";
        public const string FileTime = "FileTime";

        // Formatting
        public const string Byte = "Byte";

        // EnvironmentBlock
        public const string EnvironmentBlock = "EnvironmentBlock";
        public const string PathVariable = "PathVariable";

        // Reflection
        public const string Assembly = "Assembly";
        public const string PEHeader = "PEHeader";
    }
}
