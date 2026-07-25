// Copyright © 2026 PowerShell Core Community Extensions Team. All rights reserved.
// Licensed under MIT license.

Console.WriteLine("Command Arguments passed in:");
echoArgs(args);
//checkDictionary();

static void checkDictionary() {
    Dictionary<string, Dictionary<string, List<string>>> arTypeExtensions = new() {
        { "Tar", new Dictionary<string, List<string>> { { "GZip", new List<string> { ".tar", ".tgz" } } } },
        { "GZip", new Dictionary<string, List<string>> { { "GZip", new List<string> { ".gzip", ".gz" } } } },
        //{ArchiveType.SevenZip, new() { { CompressionType.GZip, new() { ".7z", ".7zip" } } } },    // not supported yet
        {
            "Zip",
            new Dictionary<string, List<string>> {
                { "Deflate", new List<string> { ".zip" } },
                { "BZip2", new List<string> { ".bz2", "bzip2" } },
                { "LZMA", new List<string> { ".lzm", ".lz" } },
                { "PPMd", new List<string> { ".pzip", ".pz" } }
            }
        }
    };
    string ext = "gz";
    var foundType = arTypeExtensions.FirstOrDefault(e => e.Value.Any(c => c.Value.Contains(ext)));
    string? fndArchiveType = foundType.Key;
    Console.Write(fndArchiveType);
}

// Echoes the command line arguments passed to the application.
static void echoArgs(string[] args) {
    for (int i = 0; i < args.Length; i++) {
        Console.WriteLine("Arg {0} is <{1}>", i, args[i]);
    }

    Console.WriteLine("\nCommand line:");
    Console.WriteLine(Environment.CommandLine);
    Console.WriteLine();
}