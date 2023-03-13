// See https://aka.ms/new-console-template for more information
Console.WriteLine("Command Arguments passed in:");
echoArgs(args);
//checkDictionary();

static void checkDictionary() {
    Dictionary<string, Dictionary<string, List<string>>> arTypeExtensions = new() {
        {"Tar", new() { {"GZip" , new () {".tar", ".tgz"}}}},
        {"GZip", new() { { "GZip", new() { ".gzip", ".gz" } } }},
        //{ArchiveType.SevenZip, new() { { CompressionType.GZip, new() { ".7z", ".7zip" } } } },    // not supported yet
        {"Zip", new() {
            { "Deflate", new() { ".zip" } },
            { "BZip2", new() { ".bz2", "bzip2"} },
            { "LZMA", new() { ".lzm", ".lz" } },
            { "PPMd", new() { ".pzip", ".pz" } }
        } }
    };
    string ext = "gz";
    var foundType = arTypeExtensions.FirstOrDefault(e => e.Value.Any(c => c.Value.Contains(ext)));
    string? fndArchiveType = foundType.Key;
    Console.Write(fndArchiveType);
}

/// <summary>
/// Outputs to the console the arguments passed-in as is - helps in troubleshooting argument transfer
/// </summary>
static void echoArgs(string[] args) {

    for (int i = 0; i < args.Length; i++) {
        Console.WriteLine("Arg {0} is <{1}>", i, args[i]);
    }

    Console.WriteLine("\nCommand line:");
    Console.WriteLine(Environment.CommandLine);
    Console.WriteLine();
}