@{
    # Existing PowerShell debt is recorded by severity. Static validation fails
    # on every analyzer error and on any increase to these totals. The
    # PSUseToExportFieldsInManifest rule is excluded because it crashes while
    # loading the repository's legacy manifests on .NET 10; manifest and export
    # validation are enforced separately against the staged package.
    PSScriptAnalyzer = @{
        Warning = 138
        Information = 215
    }

    # Counts are violations, not permitted style. Reduce them as touched files
    # are cleaned; increases fail the static gate.
    Formatting = @{
        '.cs' = @{ TrailingWhitespace = 670; MissingFinalNewline = 75; LeadingTab = 85 }
        '.md' = @{ TrailingWhitespace = 0; MissingFinalNewline = 0; LeadingTab = 0 }
        '.ps1' = @{ TrailingWhitespace = 122; MissingFinalNewline = 1; LeadingTab = 356 }
        '.ps1xml' = @{ TrailingWhitespace = 31; MissingFinalNewline = 0; LeadingTab = 7 }
        '.psd1' = @{ TrailingWhitespace = 2; MissingFinalNewline = 0; LeadingTab = 2 }
        '.psm1' = @{ TrailingWhitespace = 29; MissingFinalNewline = 0; LeadingTab = 2 }
        '.xml' = @{ TrailingWhitespace = 71; MissingFinalNewline = 8; LeadingTab = 2680 }
        '.yaml' = @{ TrailingWhitespace = 0; MissingFinalNewline = 0; LeadingTab = 0 }
        '.yml' = @{ TrailingWhitespace = 0; MissingFinalNewline = 0; LeadingTab = 0 }
    }
}
