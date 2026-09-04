param(
    [Parameter(Mandatory)]
    [string] $ModulePath,

    [Parameter(Mandatory)]
    [string] $ArchiveModulePath,

    [string] $WinAdminModulePath,

    [Parameter(Mandatory)]
    [ValidateSet('Core', 'Full')]
    [string] $BuildScope,

    [string] $PowerShellPath = 'pwsh'
)

$testContract = Import-PowerShellDataFile -LiteralPath (
    Join-Path $PSScriptRoot 'Pscx.PublicContract.psd1'
)
$optionalFeatures = @($testContract.OptionalFeatures.Core)
if ($BuildScope -eq 'Full') {
    $optionalFeatures += $testContract.OptionalFeatures.Full
}

BeforeAll {
    $script:manifestPath = Join-Path $ModulePath 'Pscx.psd1'
    $script:contract = Import-PowerShellDataFile -LiteralPath (
        Join-Path $PSScriptRoot 'Pscx.PublicContract.psd1'
    )
    $script:manifestData = Import-PowerShellDataFile -LiteralPath $script:manifestPath
    $script:importWarnings = @()
    $script:manifest = Test-ModuleManifest -Path $script:manifestPath -ErrorAction Stop
    Import-Module $script:manifestPath -Force -ErrorAction Stop `
        -WarningVariable 'script:importWarnings'
    $script:module = Get-Module Pscx -ErrorAction Stop
    $script:publicCommands = @(
        $script:module.ExportedCommands.Values |
            Where-Object CommandType -In Function, Cmdlet |
            Sort-Object CommandType, Name
    )
    $script:temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) (
        'Pscx.Package.Tests.{0}' -f [guid]::NewGuid().ToString('N')
    )
    New-Item -ItemType Directory -Path $script:temporaryRoot -Force | Out-Null
}

AfterAll {
    Get-Module Pscx* | Remove-Module -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $script:temporaryRoot) {
        Remove-Item -LiteralPath $script:temporaryRoot -Recurse -Force
    }
}

Describe 'Packaged PSCX module contract' {
    It 'has a valid root manifest' {
        $script:manifest | Should -Not -BeNullOrEmpty
    }

    It 'imports without warnings' {
        if ($BuildScope -eq 'Core' -and $IsWindows) {
            Set-ItResult -Skipped -Because 'Core packages target Linux and macOS; Windows CI uses the Full package.'
            return
        }
        $script:importWarnings | Should -HaveCount 0
    }

    It 'ships the explicitly invoked updater without loading its support module' {
        Test-Path -LiteralPath (Join-Path $ModulePath 'Update-Pscx.ps1') -PathType Leaf |
            Should -BeTrue
        Test-Path -LiteralPath (Join-Path $ModulePath 'Pscx.Update.psm1') -PathType Leaf |
            Should -BeTrue
        Get-Module -Name Pscx.Update | Should -BeNullOrEmpty
        Get-Command -Name Invoke-PscxUpdate -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }

    It 'preserves the content hashes of packaged Authenticode signatures' {
        if (-not $IsWindows) {
            Set-ItResult -Skipped -Because 'Authenticode validation is available only on Windows.'
            return
        }

        $signedFiles = @(
            Get-ChildItem -LiteralPath $ModulePath -Recurse -File |
                Where-Object Extension -In '.ps1', '.psm1', '.psd1', '.ps1xml' |
                Where-Object {
                    Select-String -LiteralPath $_.FullName `
                        -SimpleMatch '# SIG # Begin signature block' -Quiet
                }
        )
        $invalidSignatures = @(
            foreach ($file in $signedFiles) {
                $signature = Get-AuthenticodeSignature -LiteralPath $file.FullName
                if ($signature.Status -in 'HashMismatch', 'NotSigned' -or
                    $null -eq $signature.SignerCertificate) {
                    '{0}: {1} ({2})' -f
                        $file.FullName,
                        $signature.Status,
                        $signature.StatusMessage
                }
            }
        )

        $signedFiles | Should -Not -BeNullOrEmpty
        $invalidSignatures | Should -BeNullOrEmpty
    }

    It 'ships the expected public code-signing root certificate' {
        $certificatePath = Join-Path $ModulePath 'Certificates/Lucas-Code-Root-CA.cer'
        Test-Path -LiteralPath $certificatePath -PathType Leaf | Should -BeTrue
        (Get-FileHash -LiteralPath $certificatePath -Algorithm SHA256).Hash |
            Should -Be '9D01089FC819FF438660307BB0E47F3C06D4C855AA6DCE25CC201DD16A09F33A'

        $certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new(
            $certificatePath
        )
        try {
            $certificate.Thumbprint | Should -Be 'DF7BF0334508703832E01D8E223ECBD3C4A160F8'
            $certificate.Subject | Should -Be $certificate.Issuer
            $certificate.GetNameInfo(
                [Security.Cryptography.X509Certificates.X509NameType]::SimpleName,
                $false
            ) | Should -Be 'Lucas Code Root CA'
            $certificate.HasPrivateKey | Should -BeFalse
        }
        finally {
            $certificate.Dispose()
        }
    }

    It 'contains the expected platform assembly set' {
        $windowsAssemblyExists = Test-Path -LiteralPath (Join-Path $ModulePath 'Pscx.Win.dll')
        $windowsAssemblyExists | Should -Be ($BuildScope -eq 'Full')
    }

    It 'ships YAML support from the cross-platform assembly' {
        Test-Path -LiteralPath (Join-Path $ModulePath 'YamlDotNet.dll') | Should -BeTrue
        foreach ($name in 'ConvertFrom-Yaml', 'ConvertTo-Yaml') {
            $command = Get-Command -Name $name -CommandType Cmdlet -ErrorAction Stop
            $command.ImplementingType.Assembly.GetName().Name | Should -Be 'Pscx'
        }

        if ($BuildScope -eq 'Full') {
            $windowsManifest = Import-PowerShellDataFile -LiteralPath (
                Join-Path $ModulePath 'PscxWin.psd1'
            )
            @($windowsManifest.CmdletsToExport) | Should -Not -Contain 'ConvertFrom-Yaml'
            @($windowsManifest.CmdletsToExport) | Should -Not -Contain 'ConvertTo-Yaml'
        }
    }

    It 'keeps Stop-RemoteProcess in the Windows companion module' {
        $utilityManifest = Import-PowerShellDataFile -LiteralPath (
            Join-Path $ModulePath 'Modules/Utility/Pscx.Utility.psd1'
        )
        @($utilityManifest.FunctionsToExport) | Should -Not -Contain 'Stop-RemoteProcess'

        if ($BuildScope -eq 'Full') {
            $windowsManifest = Import-PowerShellDataFile -LiteralPath (
                Join-Path $ModulePath 'PscxWin.psd1'
            )
            @($windowsManifest.FunctionsToExport) | Should -Contain 'Stop-RemoteProcess'
        }
    }

    It 'does not create a remote session for Stop-RemoteProcess WhatIf' {
        if ($BuildScope -ne 'Full') {
            Set-ItResult -Skipped -Because 'Stop-RemoteProcess is supplied by the Windows companion module.'
            return
        }

        $unreachableComputer = 'invalid.invalid'
        { Stop-RemoteProcess -ComputerName $unreachableComputer -Name 'notepad.exe' -WhatIf } |
            Should -Not -Throw
    }

    It 'resolves every command exported by each loaded PSCX module' {
        $exportedCommands = @($script:module.ExportedCommands.Values)
        $exportedCommands.Count | Should -BeGreaterThan 0

        foreach ($command in $exportedCommands) {
            Get-Command -Name $command.Name -CommandType $command.CommandType `
                -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty `
                -Because "$($command.CommandType) $($command.Name) is exported by a loaded PSCX module"
        }
    }

    It 'does not leak undeclared functions or cmdlets' {
        $declared = @(
            $script:manifestData.FunctionsToExport
            $script:manifestData.CmdletsToExport
        )
        $leaks = @(
            $script:publicCommands |
                Where-Object CommandType -In Function, Cmdlet |
                Where-Object Name -NotIn $declared |
                ForEach-Object Name
        )
        $leaks | Should -BeNullOrEmpty
    }

    It 'exports only the documented provider set for this package scope' {
        $expectedProviders = @($script:contract.Providers.Core)
        if ($BuildScope -eq 'Full') {
            $expectedProviders += $script:contract.Providers.Full
        }
        $actualProviders = @(
            Get-PSProvider |
                Where-Object { $_.ImplementingType.Assembly.GetName().Name -Like 'Pscx*' } |
                ForEach-Object Name |
                Sort-Object -Unique
        )
        Compare-Object $expectedProviders $actualProviders | Should -BeNullOrEmpty
    }

    It 'uses explicit manifest and script-module exports' {
        foreach ($manifestFile in Get-ChildItem -LiteralPath $ModulePath -Recurse -Filter *.psd1 -File) {
            $manifestContent = Get-Content -LiteralPath $manifestFile.FullName -Raw
            if ($manifestContent -notmatch '(?m)^\s*ModuleVersion\s*=') {
                continue
            }
            $manifestData = Import-PowerShellDataFile -LiteralPath $manifestFile.FullName
            @($manifestData.FunctionsToExport) | Should -Not -Contain '*'
            @($manifestData.CmdletsToExport) | Should -Not -Contain '*'
            @($manifestData.AliasesToExport) | Should -Not -Contain '*'
        }
        foreach ($scriptModule in Get-ChildItem -LiteralPath $ModulePath -Recurse -Filter *.psm1 -File) {
            (Get-Content -LiteralPath $scriptModule.FullName -Raw) |
                Should -Not -Match 'Export-ModuleMember[^\r\n]*(?:-Alias|-Function|-Cmdlet)\s+\*'
        }
    }
}

Describe 'Phase 5 command disposition inventory' {
    It 'classifies every declared public command exactly once' {
        if ($BuildScope -ne 'Full') {
            Set-ItResult -Skipped -Because 'The repository-wide disposition includes Windows-only package roots absent from Core artifacts.'
            return
        }

        $dispositionPath = Join-Path (Split-Path $PSScriptRoot -Parent) `
            'PSCX_COMMAND_DISPOSITION.psd1'
        $disposition = Import-PowerShellDataFile -LiteralPath $dispositionPath
        $classifiedCommands = @(
            foreach ($category in $disposition.Categories.Keys) {
                @($disposition.Categories[$category])
            }
        )
        $archiveManifest = Import-PowerShellDataFile -LiteralPath (
            Join-Path $ArchiveModulePath 'Pscx.Archive.psd1'
        )
        $winAdminManifest = if ($BuildScope -eq 'Full') {
            Import-PowerShellDataFile -LiteralPath (
                Join-Path $WinAdminModulePath 'Pscx.WinAdmin.psd1'
            )
        }
        $declaredCommands = @(
            $script:manifestData.FunctionsToExport
            $script:manifestData.CmdletsToExport
            $archiveManifest.FunctionsToExport
            $archiveManifest.CmdletsToExport
            if ($winAdminManifest) {
                $winAdminManifest.FunctionsToExport
                $winAdminManifest.CmdletsToExport
            }
        ) | Sort-Object -Unique

        $duplicates = @(
            $classifiedCommands | Group-Object | Where-Object Count -GT 1 |
                ForEach-Object Name
        )
        $duplicates | Should -BeNullOrEmpty
        Compare-Object $declaredCommands @($classifiedCommands | Sort-Object -Unique) |
            Should -BeNullOrEmpty
    }

    It 'documents every retained command contract exactly once' {
        $repositoryRoot = Split-Path $PSScriptRoot -Parent
        $disposition = Import-PowerShellDataFile -LiteralPath (
            Join-Path $repositoryRoot 'PSCX_COMMAND_DISPOSITION.psd1'
        )
        $audit = Import-PowerShellDataFile -LiteralPath (
            Join-Path $repositoryRoot 'PSCX_RETAINED_COMMAND_AUDIT.psd1'
        )
        $retainedCommands = @(
            $disposition.Categories.RetainCore
            $disposition.Categories.RetainWindowsCore
        ) | Sort-Object -Unique
        $groupedCommands = @(
            $audit.Groups | ForEach-Object { $_.Commands }
        )

        @($groupedCommands | Group-Object | Where-Object Count -GT 1) |
            Should -BeNullOrEmpty
        Compare-Object $retainedCommands @($groupedCommands | Sort-Object -Unique) |
            Should -BeNullOrEmpty
        Compare-Object $retainedCommands @($audit.OutputContracts.Keys | Sort-Object) |
            Should -BeNullOrEmpty
        $audit.Status | Should -Be 'Complete'
        foreach ($group in $audit.Groups) {
            $group.Differentiation | Should -Not -BeNullOrEmpty
        }
        foreach ($commandName in $retainedCommands) {
            $audit.OutputContracts[$commandName] | Should -Not -BeNullOrEmpty
        }
    }

    It 'enforces retained command metadata, help, naming, and path contracts' {
        $repositoryRoot = Split-Path $PSScriptRoot -Parent
        $disposition = Import-PowerShellDataFile -LiteralPath (
            Join-Path $repositoryRoot 'PSCX_COMMAND_DISPOSITION.psd1'
        )
        $audit = Import-PowerShellDataFile -LiteralPath (
            Join-Path $repositoryRoot 'PSCX_RETAINED_COMMAND_AUDIT.psd1'
        )
        $commandNames = @($disposition.Categories.RetainCore)
        if ($BuildScope -eq 'Full') {
            $commandNames += $disposition.Categories.RetainWindowsCore
        }
        foreach ($optionalCommand in $audit.OptionalCommands.Keys) {
            $optionalModulePath = Join-Path $ModulePath $audit.OptionalCommands[$optionalCommand]
            Import-Module $optionalModulePath -Force -ErrorAction Stop
        }
        $commandNames = @($commandNames | Sort-Object -Unique)
        $approvedVerbs = @(Get-Verb | ForEach-Object Verb)

        foreach ($commandName in $commandNames) {
            $command = Get-Command -Name $commandName -ErrorAction Stop |
                Where-Object { $_.ModuleName -Like 'Pscx*' } |
                Select-Object -First 1
            $command | Should -Not -BeNullOrEmpty -Because "$commandName is retained"

            $help = Get-Help -Name $commandName -Full -ErrorAction Stop
            @($help.Examples.Example).Count | Should -BeGreaterThan 0 `
                -Because "$commandName needs a realistic example"

            if (-not $audit.OutputMetadataExceptions.ContainsKey($commandName)) {
                @($command.OutputType).Count | Should -BeGreaterThan 0 `
                    -Because "$commandName has a documented output contract"
            }
            if (-not $audit.CommonParameterExceptions.ContainsKey($commandName)) {
                $command.Parameters.ContainsKey('Verbose') | Should -BeTrue `
                    -Because "$commandName should support common parameters"
            }
            if (-not $audit.NamingExceptions.ContainsKey($commandName)) {
                $commandName | Should -Match '^[^-]+-.+$'
                $command.Verb | Should -BeIn $approvedVerbs `
                    -Because "$commandName should use an approved verb"
            }
            if ($command.Parameters.ContainsKey('Path') -and
                -not $audit.LiteralPathExceptions.ContainsKey($commandName)) {
                $command.Parameters.ContainsKey('LiteralPath') | Should -BeTrue `
                    -Because "$commandName exposes wildcard-capable Path"
            }
        }
    }
}

Describe 'Path-variable mutation' {
    It 'returns a structured removal preview without changing the environment' {
        $name = 'PSCX_TEST_PATH_{0}' -f [guid]::NewGuid().ToString('N')
        $values = @(
            (Join-Path $script:temporaryRoot 'first'),
            (Join-Path $script:temporaryRoot 'second')
        )
        $initialValue = $values -join [IO.Path]::PathSeparator
        try {
            [Environment]::SetEnvironmentVariable($name, $initialValue)
            $preview = Remove-PathVariable -Name $name -Value $values[0] -PassThru -WhatIf
            [Environment]::GetEnvironmentVariable($name) | Should -Be $initialValue
            $preview.GetType().FullName |
                Should -Be 'Pscx.Commands.EnvironmentBlock.PathVariableChange'
            $preview.Operation | Should -Be 'Remove'
            $preview.Changed | Should -BeTrue
            $preview.Applied | Should -BeFalse
            $preview.Removed | Should -Be @($values[0])
            $preview.Retained | Should -Be @($values[1])
            $preview.After | Should -Be @($values[1])

            $change = Remove-PathVariable -Name $name -Value $values[0] `
                -PassThru -Confirm:$false
            [Environment]::GetEnvironmentVariable($name) | Should -Be $values[1]
            $change.Applied | Should -BeTrue
        }
        finally {
            [Environment]::SetEnvironmentVariable($name, $null)
        }
    }

    It 'accumulates pipeline input and reports added values' {
        $name = 'PSCX_TEST_PATH_{0}' -f [guid]::NewGuid().ToString('N')
        $values = @(
            (Join-Path $script:temporaryRoot 'pipeline-first'),
            (Join-Path $script:temporaryRoot 'pipeline-second')
        )
        try {
            $change = $values | Add-PathVariable -Name $name -PassThru -Confirm:$false

            $change.Added | Should -Be $values
            $change.After | Should -Be $values
            [Environment]::GetEnvironmentVariable($name) |
                Should -Be ($values -join [IO.Path]::PathSeparator)
        }
        finally {
            [Environment]::SetEnvironmentVariable($name, $null)
        }
    }

    It 'normalizes, validates, and optionally retains unavailable entries' {
        $name = 'PSCX_TEST_PATH_{0}' -f [guid]::NewGuid().ToString('N')
        $available = Join-Path $script:temporaryRoot 'available-path'
        $unavailable = Join-Path $script:temporaryRoot 'unavailable-path'
        New-Item -ItemType Directory -Path $available | Out-Null
        try {
            $filtered = Set-PathVariable -Name $name -Value $available, $unavailable `
                -Normalize -Validate -PassThru -Confirm:$false

            $filtered.After | Should -Be @([IO.Path]::GetFullPath($available))
            $filtered.Invalid | Should -Be @([IO.Path]::GetFullPath($unavailable))

            $retained = Set-PathVariable -Name $name -Value $available, $unavailable `
                -Normalize -Validate -RetainUnavailable -PassThru -Confirm:$false
            $retained.After | Should -Be @(
                [IO.Path]::GetFullPath($available)
                [IO.Path]::GetFullPath($unavailable)
            )
            $retained.Invalid | Should -Be @([IO.Path]::GetFullPath($unavailable))
        }
        finally {
            [Environment]::SetEnvironmentVariable($name, $null)
        }
    }

    It 'uses native case comparison by default and supports an explicit insensitive comparison' {
        $name = 'PSCX_TEST_PATH_{0}' -f [guid]::NewGuid().ToString('N')
        $values = @('CasePath', 'casepath')
        try {
            $native = Set-PathVariable -Name $name -Value $values -PassThru -Confirm:$false
            $expectedCount = if ($IsWindows) { 1 } else { 2 }
            $native.After | Should -HaveCount $expectedCount

            $insensitive = Set-PathVariable -Name $name -Value $values `
                -CaseInsensitive -PassThru -Confirm:$false
            $insensitive.After | Should -Be @('CasePath')
            $insensitive.Duplicate | Should -Contain 'casepath'
        }
        finally {
            [Environment]::SetEnvironmentVariable($name, $null)
        }
    }

    It 'supports cleaned read-only PATH output without changing the variable' {
        $name = 'PSCX_TEST_PATH_{0}' -f [guid]::NewGuid().ToString('N')
        $values = @('CasePath', 'casepath', 'CasePath')
        $initialValue = $values -join [IO.Path]::PathSeparator
        try {
            [Environment]::SetEnvironmentVariable($name, $initialValue)
            $native = @(Get-PathVariable -Name $name -Unique)
            $expectedCount = if ($IsWindows) { 1 } else { 2 }
            $native | Should -HaveCount $expectedCount
            @(Get-PathVariable -Name $name -Unique -CaseInsensitive) |
                Should -Be @('CasePath')
            [Environment]::GetEnvironmentVariable($name) | Should -Be $initialValue
        }
        finally {
            [Environment]::SetEnvironmentVariable($name, $null)
        }
    }

    It 'rejects persistent target scopes explicitly on non-Windows platforms' {
        if ($IsWindows) {
            Set-ItResult -Skipped -Because 'User and Machine environment targets are supported on Windows.'
            return
        }

        $caught = $null
        try {
            Get-PathVariable -Name PATH -Target User -ErrorAction Stop
        }
        catch {
            $caught = $_
        }
        $caught | Should -Not -BeNullOrEmpty
        $caught.FullyQualifiedErrorId | Should -Match '^PathVariableTargetNotSupported'
    }
}

Describe 'Packaged PSCX help and examples' {
    It 'ships localized external help for the package scope' {
        $culturePath = Join-Path $ModulePath 'en-US'
        Test-Path -LiteralPath (Join-Path $culturePath 'Pscx.dll-Help.xml') |
            Should -BeTrue
        Test-Path -LiteralPath (Join-Path $culturePath 'about_Pscx.help.txt') |
            Should -BeTrue
        Test-Path -LiteralPath (Join-Path $culturePath 'Pscx.Win.dll-Help.xml') |
            Should -Be ($BuildScope -eq 'Full')
        (Get-Help about_Pscx).Name | Should -Be 'about_Pscx'
    }

    It 'renders compiled-command examples without Markdown or control-character artifacts' {
        $culturePath = Join-Path $ModulePath 'en-US'
        $helpFiles = @(Get-ChildItem -LiteralPath $culturePath -Filter '*-Help.xml' -File)
        $helpFiles | Should -Not -BeNullOrEmpty
        foreach ($helpFile in $helpFiles) {
            [xml] $helpDocument = Get-Content -LiteralPath $helpFile.FullName -Raw
            $namespaceManager = [Xml.XmlNamespaceManager]::new($helpDocument.NameTable)
            $namespaceManager.AddNamespace(
                'command',
                'http://schemas.microsoft.com/maml/dev/command/2004/10'
            )
            $examples = @($helpDocument.SelectNodes('//command:example', $namespaceManager))
            foreach ($example in $examples) {
                $example.InnerText | Should -Not -Match '```'
                $example.InnerText.Contains([string][char]0x80) | Should -BeFalse
            }
        }

        $exampleText = Get-Help Add-PathVariable -Examples | Out-String
        $exampleText | Should -Match ([regex]::Escape(
                "Add-PathVariable -Name LIB -Value '/opt/example/lib', '/opt/project/lib'"
            ))
        $exampleText | Should -Not -Match '```'
    }

    It 'provides usable help and an example for every public function and cmdlet' {
        $gaps = @(
            $script:publicCommands |
                Where-Object CommandType -In Function, Cmdlet |
                ForEach-Object {
                    $help = Get-Help $_.Name -Full
                    $examplesProperty = $help.PSObject.Properties['examples']
                    $exampleCount = 0
                    if ($null -ne $examplesProperty -and $null -ne $examplesProperty.Value) {
                        $exampleProperty = $examplesProperty.Value.PSObject.Properties['example']
                        if ($null -ne $exampleProperty) {
                            $exampleCount = @($exampleProperty.Value).Count
                        }
                    }
                    if (
                        [string]::IsNullOrWhiteSpace([string]$help.Synopsis) -or
                        $help.Synopsis -like '*proper help content*' -or
                        $exampleCount -eq 0
                    ) {
                        $_.Name
                    }
                }
        )
        $gaps | Should -BeNullOrEmpty
    }

    It 'provides full local help for the explicitly invoked updater script' {
        $updateScript = Join-Path $ModulePath 'Update-Pscx.ps1'
        $help = Get-Help -Name $updateScript -Full -ErrorAction Stop

        [string]::IsNullOrWhiteSpace([string]$help.Synopsis) | Should -BeFalse
        @($help.Examples.Example).Count | Should -BeGreaterThan 0
        @($help.returnValues.returnValue.type.name) | Should -Contain 'Pscx.UpdateResult'
    }

    It 'runs safe deterministic examples from canonical command help' {
        $repositoryRoot = Split-Path -Parent $PSScriptRoot
        $examples = @(
            @{ Command = 'Format-Byte'; Validate = { param($result) [string]$result | Should -Match '10.*KB' } }
            @{ Command = 'ConvertTo-Base64'; Validate = {
                param($result)
                [Convert]::FromBase64String(($result -join '')).Count | Should -Be 127
            } }
            @{ Command = 'Get-TypeName'; Validate = { param($result) $result | Should -Be 'DateTime' } }
        )

        foreach ($example in $examples) {
            $markdownPath = Join-Path $repositoryRoot "docs/commands/Pscx/$($example.Command).md"
            $markdown = Get-Content -LiteralPath $markdownPath -Raw
            $codeMatch = [regex]::Match(
                $markdown,
                '(?ms)^## EXAMPLES.*?^```powershell\s*\r?\n(?<code>.*?)^```\s*$'
            )
            $codeMatch.Success | Should -BeTrue -Because "$($example.Command) has a PowerShell example"

            $result = & ([scriptblock]::Create($codeMatch.Groups['code'].Value))
            & $example.Validate $result
        }
    }

    It 'keeps every PowerShell example block in README syntactically valid' {
        $readmePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'README.md'
        $readme = Get-Content -LiteralPath $readmePath -Raw
        $blocks = [regex]::Matches(
            $readme,
            '(?ms)^```powershell\s*\r?\n(?<code>.*?)^```\s*$'
        )
        $blocks.Count | Should -BeGreaterThan 0

        $parseErrors = foreach ($block in $blocks) {
            $tokens = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseInput(
                $block.Groups['code'].Value,
                [ref]$tokens,
                [ref]$errors
            ) | Out-Null
            $errors
        }
        @($parseErrors) | Should -HaveCount 0
    }

    It 'keeps the task and migration guides linked with valid PowerShell examples' {
        $repositoryRoot = Split-Path -Parent $PSScriptRoot
        $readme = Get-Content -LiteralPath (Join-Path $repositoryRoot 'README.md') -Raw
        $relativeGuidePaths = @(
            'docs/COMMAND_DISCOVERY.md'
            'docs/MIGRATING_TO_4.0.md'
        )

        foreach ($relativeGuidePath in $relativeGuidePaths) {
            $readme | Should -Match ([regex]::Escape("($relativeGuidePath)"))
            $guidePath = Join-Path $repositoryRoot $relativeGuidePath
            Test-Path -LiteralPath $guidePath -PathType Leaf | Should -BeTrue

            $guide = Get-Content -LiteralPath $guidePath -Raw
            $blocks = [regex]::Matches(
                $guide,
                '(?ms)^```powershell\s*\r?\n(?<code>.*?)^```\s*$'
            )
            $blocks.Count | Should -BeGreaterThan 0

            $parseErrors = foreach ($block in $blocks) {
                $tokens = $null
                $errors = $null
                [System.Management.Automation.Language.Parser]::ParseInput(
                    $block.Groups['code'].Value,
                    [ref]$tokens,
                    [ref]$errors
                ) | Out-Null
                $errors
            }
            @($parseErrors) | Should -HaveCount 0 -Because "$relativeGuidePath examples must parse"
        }
    }

    It 'documents every approved PSCX 4.0 command removal' {
        $repositoryRoot = Split-Path -Parent $PSScriptRoot
        $disposition = Import-PowerShellDataFile -LiteralPath (
            Join-Path $repositoryRoot 'PSCX_COMMAND_DISPOSITION.psd1'
        )
        $migrationGuide = Get-Content -LiteralPath (
            Join-Path $repositoryRoot 'docs/MIGRATING_TO_4.0.md'
        ) -Raw

        $removedCommands = @(
            $disposition.RemovedCommands.Values | ForEach-Object { $_ }
        )
        foreach ($removedCommand in $removedCommands) {
            $migrationGuide | Should -Match ([regex]::Escape($removedCommand)) `
                -Because "$removedCommand needs migration guidance"
        }
    }

    It 'ships task-oriented discovery and migration pointers in about help' {
        $aboutHelp = Get-Help about_Pscx -Full | Out-String

        $aboutHelp | Should -Match 'Test-PscxInstallation'
        $aboutHelp | Should -Match 'Pscx\.Archive'
        $aboutHelp | Should -Match 'Migrating to PSCX 4\.0'
    }
}

Describe 'Representative public command behavior' {
    It 'extends the public RegexLib through AddRegex' {
        AddRegex -name Phase23SemanticVersion -regex '^\d+\.\d+\.\d+$'
        $Pscx:RegexLib.Phase23SemanticVersion | Should -Be '^\d+\.\d+\.\d+$'
    }

    It 'binds pipeline input and emits the documented object type' {
        $encoded = 1, 2, 3 | ConvertTo-Base64 -NoLineBreak
        $encoded | Should -BeOfType ([string])
        $encoded | Should -Be 'AQID'
    }

    It 'reports Base64 file progress only through the verbose stream' {
        $path = Join-Path $script:temporaryRoot 'base64-input.bin'
        [IO.File]::WriteAllBytes($path, [byte[]](1, 2, 3))

        $result = @(ConvertTo-Base64 -LiteralPath $path -NoLineBreak -Verbose 4>&1)
        $output = @($result | Where-Object { $_ -isnot [Management.Automation.VerboseRecord] })
        $verbose = @($result | Where-Object { $_ -is [Management.Automation.VerboseRecord] })

        $output | Should -HaveCount 1
        $output[0] | Should -Be 'AQID'
        $verbose.Message | Should -Contain "Processing file: $path"
    }

    It 'returns structured parser diagnostics from Test-Script on request' {
        $warnings = @()
        $result = 'function Broken {' | Test-Script -PassThru -WarningVariable warnings

        $result.GetType().FullName | Should -Be 'Pscx.Commands.ScriptTestResult'
        $result.Path | Should -BeNullOrEmpty
        $result.IsValid | Should -BeFalse
        $result.Errors.Count | Should -BeGreaterThan 0
        $result.Errors[0].GetType().FullName |
            Should -Be 'System.Management.Automation.Language.ParseError'
        $warnings | Should -BeNullOrEmpty
        ('1 + 1' | Test-Script) | Should -BeTrue
    }

    It 'returns structured error details with formatted text available explicitly' {
        try {
            Get-Item -LiteralPath (Join-Path $script:temporaryRoot 'not-present') `
                -ErrorAction Stop
        }
        catch {
            $errorRecord = $_
        }

        $detail = $errorRecord | Resolve-ErrorRecord
        $text = @($errorRecord | Resolve-ErrorRecord -AsText)

        $detail.PSTypeNames | Should -Contain 'Pscx.ErrorRecordDetail'
        [object]::ReferenceEquals($detail.ErrorRecord, $errorRecord) | Should -BeTrue
        $detail.FullyQualifiedErrorId | Should -Be $errorRecord.FullyQualifiedErrorId
        $detail.ExceptionChain | Should -Not -BeNullOrEmpty
        $detail.ExceptionChain[0].PSTypeNames | Should -Contain 'Pscx.ExceptionDetail'
        $text | Should -Not -BeNullOrEmpty
        ($text -join "`n") | Should -Match ([regex]::Escape($errorRecord.FullyQualifiedErrorId))
    }

    It 'returns PathInfo from Set-PscxLocation PassThru' {
        $startingLocation = Get-Location
        try {
            $result = Set-PscxLocation -LiteralPath $script:temporaryRoot -PassThru
            $result | Should -BeOfType ([Management.Automation.PathInfo])
            $result.Path | Should -Be (Get-Item -LiteralPath $script:temporaryRoot).FullName
        }
        finally {
            Set-Location -LiteralPath $startingLocation.Path
        }
    }

    It 'treats wildcard characters literally in Get-ViewDefinition LiteralPath' {
        $sourceFormatPath = Join-Path $ModulePath 'FormatData/Pscx.Format.ps1xml'
        $literalFormatPath = Join-Path $script:temporaryRoot 'views[1].format.ps1xml'
        Copy-Item -LiteralPath $sourceFormatPath -Destination $literalFormatPath

        $views = @(Get-ViewDefinition -LiteralPath $literalFormatPath)

        $views | Should -Not -BeNullOrEmpty
        $views[0].PSTypeNames |
            Should -Contain 'Pscx.Commands.Modules.Utility.ViewDefinition'
        $views[0].Path | Should -Be (Resolve-Path -LiteralPath $literalFormatPath).Path
    }

    It 'registers the Base64 accelerator in the imported session' {
        $encoded = [base64][byte[]](1, 2, 3)

        $encoded.ToString() | Should -Be 'AQID'
    }

    It 'hashes pipeline byte input with the documented default algorithm' {
        $hash = [byte[]](97, 98, 99) | Get-PscxHash

        $hash.Algorithm | Should -Be 'SHA256'
        $hash.HashString | Should -Be 'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD'
        $hash.Hash | Should -HaveCount 32
    }

    It 'hashes a file received from the pipeline' {
        $path = Join-Path $script:temporaryRoot 'hash-input.txt'
        [IO.File]::WriteAllText($path, 'PSCX', [Text.UTF8Encoding]::new($false))

        $hash = Get-Item -LiteralPath $path | Get-PscxHash -Algorithm SHA512

        $hash.Algorithm | Should -Be 'SHA512'
        $hash.Path | Should -Be (Get-Item -LiteralPath $path).FullName
        $hash.Hash | Should -HaveCount 64
    }

    It 'converts numeric units through the public cmdlet contract' {
        $measurement = ConvertTo-Unit -Value 320287.65 -FromUnit m -ToUnit km

        $measurement.GetType().FullName | Should -Be 'Pscx.SimpleUnits.Measurement'
        [math]::Abs($measurement.value - 320.28765) | Should -BeLessThan 0.000001
        $measurement.unit.Symbol | Should -Be 'km'
    }

    It 'round-trips structured YAML through the packaged cross-platform commands' {
        $source = "project:`n  name: PSCX`n  active: true"
        $object = $source | ConvertFrom-Yaml
        $yaml = $object | ConvertTo-Yaml
        $roundTrip = $yaml | ConvertFrom-Yaml

        $object.project.name | Should -Be 'PSCX'
        $yaml | Should -Match 'name: PSCX'
        $yaml | Should -Match 'active: "true"'
        $roundTrip.project.active | Should -Be 'true'
    }

    It 'creates a hard link in an isolated temporary directory' {
        $target = Join-Path $script:temporaryRoot 'target.txt'
        $link = Join-Path $script:temporaryRoot 'target-link.txt'
        Set-Content -LiteralPath $target -Value 'linked content'

        New-Hardlink -LiteralPath $link -Target $target | Out-Null

        Get-Content -LiteralPath $link -Raw | Should -Be (Get-Content -LiteralPath $target -Raw)
    }

    It 'returns the requested file tail through the compatibility wrapper' {
        $path = Join-Path $script:temporaryRoot 'tail.txt'
        Set-Content -LiteralPath $path -Value @('one', 'two', 'three', 'four')

        @(Get-FileTail -LiteralPath $path -Count 2) | Should -Be @('three', 'four')
    }

    It 'honors WhatIf for the link compatibility wrappers' {
        $target = Join-Path $script:temporaryRoot 'whatif-target.txt'
        Set-Content -LiteralPath $target -Value 'linked content'

        foreach ($commandName in 'New-Hardlink', 'New-Symlink') {
            $link = Join-Path $script:temporaryRoot "$commandName.txt"
            & $commandName -LiteralPath $link -TargetPath $target -WhatIf
            Test-Path -LiteralPath $link | Should -BeFalse
        }

        if ($BuildScope -eq 'Full') {
            $junctionTarget = Join-Path $script:temporaryRoot 'junction-target'
            $junction = Join-Path $script:temporaryRoot 'junction'
            New-Item -ItemType Directory -Path $junctionTarget | Out-Null
            New-Junction -LiteralPath $junction -TargetPath $junctionTarget -WhatIf
            Test-Path -LiteralPath $junction | Should -BeFalse
        }
    }

    It 'supports wildcard Path input and emits Boolean results' {
        $pathRoot = Join-Path $script:temporaryRoot 'wildcards'
        New-Item -ItemType Directory -Path $pathRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $pathRoot 'one.xml') -Value '<one />'
        Set-Content -LiteralPath (Join-Path $pathRoot 'two.xml') -Value '<two />'

        $result = @(Test-Xml -Path (Join-Path $pathRoot '*.xml'))
        $result | Should -HaveCount 2
        $result | ForEach-Object { $_ | Should -BeOfType ([bool]); $_ | Should -BeTrue }
    }

    It 'treats wildcard characters literally for LiteralPath' {
        $literalPath = Join-Path $script:temporaryRoot '[literal].xml'
        Set-Content -LiteralPath $literalPath -Value '<literal />'

        $result = Test-Xml -LiteralPath $literalPath
        $result | Should -BeOfType ([bool])
        $result | Should -BeTrue
    }

    It 'honors WhatIf without creating a file' {
        $path = Join-Path $script:temporaryRoot 'whatif.txt'
        Set-FileTime -LiteralPath $path -WhatIf
        Test-Path -LiteralPath $path | Should -BeFalse
    }

    It 'honors an explicit non-interactive Confirm choice' {
        $path = Join-Path $script:temporaryRoot 'confirm.txt'
        $expected = [datetime]'2024-01-02T03:04:05'

        Set-FileTime -LiteralPath $path -Time $expected -Modified -Confirm:$false
        Test-Path -LiteralPath $path | Should -BeTrue
        (Get-Item -LiteralPath $path).LastWriteTime | Should -Be $expected
    }

    It 'emits a stable non-terminating error for a missing literal path' {
        $missing = Join-Path $script:temporaryRoot 'missing.xml'
        $errors = @()
        Test-Xml -LiteralPath $missing -ErrorAction Continue -ErrorVariable errors | Out-Null

        $errors | Should -HaveCount 1
        $errors[0].FullyQualifiedErrorId | Should -Be 'FileError,Pscx.Commands.Xml.TestXmlCommand'
        $errors[0].CategoryInfo.Category | Should -Be ([System.Management.Automation.ErrorCategory]::ObjectNotFound)
    }

    It 'promotes the same error to terminating when ErrorAction is Stop' {
        $missing = Join-Path $script:temporaryRoot 'missing-stop.xml'
        { Test-Xml -LiteralPath $missing -ErrorAction Stop } | Should -Throw
    }

    It 'reports structured encoding and mixed line-ending information' {
        $path = Join-Path $script:temporaryRoot 'mixed-line-endings.txt'
        [IO.File]::WriteAllBytes(
            $path,
            [Text.Encoding]::ASCII.GetBytes("one`r`ntwo`nthree`rfour`n"))

        $info = Get-TextFileInfo -LiteralPath $path

        $info.GetType().FullName | Should -Be 'Pscx.Commands.Text.TextFileInfo'
        $info.Encoding.ToString() | Should -Be 'Ascii'
        $info.Bom.ToString() | Should -Be 'None'
        $info.HasBom | Should -BeFalse
        $info.IsValidText | Should -BeTrue
        $info.LineEnding.ToString() | Should -Be 'Mixed'
        $info.HasMixedLineEndings | Should -BeTrue
        $info.CrLfCount | Should -Be 1
        $info.LfCount | Should -Be 2
        $info.CrCount | Should -Be 1
        $info.HasFinalNewline | Should -BeTrue

        $pipelineInfo = Get-Item -LiteralPath $path | Get-TextFileInfo
        $pipelineInfo.Path | Should -Be (Get-Item -LiteralPath $path).FullName
    }

    It 'checks line-ending conversion without writing a file' {
        $path = Join-Path $script:temporaryRoot 'check-line-endings.txt'
        $original = [Text.Encoding]::ASCII.GetBytes("one`ntwo")
        [IO.File]::WriteAllBytes($path, $original)

        $result = ConvertTo-WindowsLineEnding -LiteralPath $path -Check

        $result.GetType().FullName | Should -Be 'Pscx.Commands.Text.LineEndingCheckResult'
        $result.NeedsConversion | Should -BeTrue
        $result.TargetLineEnding.ToString() | Should -Be 'CrLf'
        $result.FinalNewline.ToString() | Should -Be 'Preserve'
        [IO.File]::ReadAllBytes($path) | Should -Be $original
    }

    It 'preserves a BOM-less encoding and final-newline state by default' {
        $source = Join-Path $script:temporaryRoot 'source-line-endings.txt'
        $destination = Join-Path $script:temporaryRoot 'converted-line-endings.txt'
        [IO.File]::WriteAllBytes($source, [Text.Encoding]::ASCII.GetBytes("one`ntwo"))

        ConvertTo-WindowsLineEnding -LiteralPath $source -Destination $destination

        [IO.File]::ReadAllBytes($destination) |
            Should -Be ([Text.Encoding]::ASCII.GetBytes("one`r`ntwo"))
        $info = Get-TextFileInfo -LiteralPath $destination
        $info.Bom.ToString() | Should -Be 'None'
        $info.HasFinalNewline | Should -BeFalse
        $info.LineEnding.ToString() | Should -Be 'CrLf'
    }

    It 'supports explicit final-newline control and WhatIf' {
        $source = Join-Path $script:temporaryRoot 'final-newline-source.txt'
        $added = Join-Path $script:temporaryRoot 'final-newline-added.txt'
        $notWritten = Join-Path $script:temporaryRoot 'final-newline-whatif.txt'
        [IO.File]::WriteAllBytes($source, [Text.Encoding]::ASCII.GetBytes('one'))

        ConvertTo-UnixLineEnding -LiteralPath $source -Destination $added -FinalNewline Add
        [IO.File]::ReadAllBytes($added) |
            Should -Be ([Text.Encoding]::ASCII.GetBytes("one`n"))

        ConvertTo-UnixLineEnding -LiteralPath $source -Destination $notWritten -WhatIf
        Test-Path -LiteralPath $notWritten | Should -BeFalse
    }

    It 'reports structured installation diagnostics without changing module state' {
        $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $ModulePath 'Pscx.psd1')
        $expectedVersion = ([version]$manifest.ModuleVersion).ToString(3)
        $prerelease = [string]$manifest.PrivateData.PSData.Prerelease
        if ($prerelease) {
            $expectedVersion = "$expectedVersion-$prerelease"
        }

        $loadedModulesBefore = @(
            Get-Module -All | ForEach-Object { "$($_.Name)|$($_.Path)" } |
                Sort-Object -Unique
        )
        $pagerBefore = $env:PAGER
        $editorBefore = $Pscx:Preferences.TextEditor

        $diagnostics = @(Test-PscxInstallation)

        $diagnostics | Should -Not -BeNullOrEmpty
        $diagnostics | ForEach-Object {
            $_.PSTypeNames | Should -Contain 'Pscx.InstallationDiagnostic'
            $_.Category | Should -BeIn Environment, Modules, Tools, Package
            $_.Status | Should -BeIn Pass, Warning, Fail, Info, NotApplicable
            $_.Name | Should -Not -BeNullOrEmpty
            $_.Message | Should -Not -BeNullOrEmpty
            $_.Details | Should -BeOfType ([hashtable])
        }

        $expectedNames = @(
            'PSCX version'
            'PowerShell runtime'
            '.NET runtime'
            'Platform'
            'Loaded optional modules'
            'Pscx.Archive'
            'Pscx.Time'
            'Pscx.WinAdmin'
            'Text editor'
            'Pager'
            'Archive backend'
            'Native dependency: less'
            'Native dependency: gsudo'
            'Module manifest'
            'Command exports'
            'Command help'
        )
        $diagnostics.Name | Should -Be $expectedNames
        ($diagnostics | Where-Object Name -EQ 'PSCX version').Value |
            Should -Be $expectedVersion
        $diagnostics | Where-Object Name -In 'Module manifest', 'Command exports', 'Command help' |
            ForEach-Object { $_.Status | Should -Be 'Pass' }

        $loadedModulesAfter = @(
            Get-Module -All | ForEach-Object { "$($_.Name)|$($_.Path)" } |
                Sort-Object -Unique
        )
        $loadedModulesAfter | Should -Be $loadedModulesBefore
        $env:PAGER | Should -Be $pagerBefore
        $Pscx:Preferences.TextEditor | Should -Be $editorBefore

        $format = Get-FormatData -TypeName Pscx.InstallationDiagnostic
        $format.FormatViewDefinition.Name | Should -Contain 'PscxInstallationDiagnostic'
    }

    It 'warns when configured editor and pager applications cannot be resolved' {
        $editorBefore = $Pscx:Preferences.TextEditor
        $pagerBefore = $env:PAGER
        try {
            $Pscx:Preferences.TextEditor = 'pscx-editor-that-does-not-exist'
            $env:PAGER = 'pscx-pager-that-does-not-exist'

            $diagnostics = @(Test-PscxInstallation)

            ($diagnostics | Where-Object Name -EQ 'Text editor').Status |
                Should -Be 'Warning'
            ($diagnostics | Where-Object Name -EQ 'Pager').Status |
                Should -Be 'Warning'
        }
        finally {
            $Pscx:Preferences.TextEditor = $editorBefore
            if ($null -eq $pagerBefore) {
                Remove-Item Env:PAGER -ErrorAction SilentlyContinue
            }
            else {
                $env:PAGER = $pagerBefore
            }
        }
    }
}

Describe 'Cross-platform local build installer' {
    It 'installs and replaces staged Core modules only within an explicit destination' {
        $repositoryRoot = Split-Path -Parent $PSScriptRoot
        $installerPath = Join-Path $repositoryRoot 'Tools/Local-Install.ps1'
        $artifactsRoot = Join-Path $TestDrive 'local-install-artifacts'
        $destinationRoot = Join-Path $TestDrive 'local-modules'
        $whatIfRoot = Join-Path $TestDrive 'whatif-modules'
        $moduleNames = @('Pscx', 'Pscx.Archive', 'Pscx.Time')

        foreach ($moduleName in $moduleNames) {
            $sourcePath = Join-Path $artifactsRoot "module/$moduleName"
            New-Item -ItemType Directory -Path $sourcePath -Force | Out-Null
            @"
@{
    RootModule = '$moduleName.psm1'
    ModuleVersion = '4.2.0'
    PrivateData = @{ PSData = @{ Prerelease = 'local.1' } }
}
"@ | Set-Content -LiteralPath (Join-Path $sourcePath "$moduleName.psd1") -Encoding utf8
            '# local installer fixture' |
                Set-Content -LiteralPath (Join-Path $sourcePath "$moduleName.psm1") -Encoding utf8
        }

        $installOutput = & $PowerShellPath -NoLogo -NoProfile -NonInteractive `
            -File $installerPath -SkipBuild -BuildScope Core `
            -ArtifactsPath $artifactsRoot -DestinationRoot $destinationRoot 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($installOutput -join [Environment]::NewLine)
        foreach ($moduleName in $moduleNames) {
            $installedPath = Join-Path $destinationRoot "$moduleName/4.2.0"
            Test-Path -LiteralPath (Join-Path $installedPath "$moduleName.psd1") |
                Should -BeTrue
            'old local content' | Set-Content -LiteralPath (Join-Path $installedPath 'old.txt')
        }

        $replaceOutput = & $PowerShellPath -NoLogo -NoProfile -NonInteractive `
            -File $installerPath -SkipBuild -BuildScope Core `
            -ArtifactsPath $artifactsRoot -DestinationRoot $destinationRoot 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($replaceOutput -join [Environment]::NewLine)
        foreach ($moduleName in $moduleNames) {
            Test-Path -LiteralPath (Join-Path $destinationRoot "$moduleName/4.2.0/old.txt") |
                Should -BeFalse
        }

        $whatIfOutput = & $PowerShellPath -NoLogo -NoProfile -NonInteractive `
            -File $installerPath -SkipBuild -BuildScope Core `
            -ArtifactsPath $artifactsRoot -DestinationRoot $whatIfRoot -WhatIf 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($whatIfOutput -join [Environment]::NewLine)
        Test-Path -LiteralPath $whatIfRoot | Should -BeFalse

        $defaultWhatIfOutput = & $PowerShellPath -NoLogo -NoProfile -NonInteractive `
            -File $installerPath -SkipBuild -BuildScope Core `
            -ArtifactsPath $artifactsRoot -WhatIf 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($defaultWhatIfOutput -join [Environment]::NewLine)
    }
}

Describe 'Optional feature imports' {
    It 'imports with default preferences in a clean process' {
        $result = & (Join-Path $PSScriptRoot 'Invoke-PscxImportProbe.ps1') `
            -ModulePath $ModulePath -BuildScope $BuildScope -PowerShellPath $PowerShellPath
        $result.Imported | Should -BeTrue
        $result.ImportErrors | Should -BeNullOrEmpty
        $result.Warnings | Should -BeNullOrEmpty
    }

    It 'imports with the <Name> feature enabled in a clean process' -ForEach $optionalFeatures {
        param($Name, $ModuleName)

        $result = & (Join-Path $PSScriptRoot 'Invoke-PscxImportProbe.ps1') `
            -ModulePath $ModulePath -BuildScope $BuildScope -Feature $Name `
            -PowerShellPath $PowerShellPath
        $result.Imported | Should -BeTrue
        $result.LoadedModules | Should -Contain $ModuleName
        $result.Warnings | Should -BeNullOrEmpty
    }

    It 'resolves every function and cmdlet declared by the Full manifest when all features are enabled' {
        if ($BuildScope -ne 'Full') {
            Set-ItResult -Skipped -Because 'The shared legacy manifest includes Windows exports that are intentionally absent from Core packages.'
            return
        }

        $result = & (Join-Path $PSScriptRoot 'Invoke-PscxImportProbe.ps1') `
            -ModulePath $ModulePath -BuildScope $BuildScope -EnableAllOptionalFeatures `
            -PowerShellPath $PowerShellPath
        $declaredCommands = @(
            $script:manifestData.FunctionsToExport
            $script:manifestData.CmdletsToExport
        ) | Sort-Object -Unique
        Compare-Object $declaredCommands @($result.ExportedCommands) | Should -BeNullOrEmpty
        $result.Warnings | Should -BeNullOrEmpty
    }

    It 'does not replace collisions when optional features are disabled' {
        $result = & (Join-Path $PSScriptRoot 'Invoke-PscxImportProbe.ps1') `
            -ModulePath $ModulePath -BuildScope $BuildScope -DisableOptionalFeatures `
            -PowerShellPath $PowerShellPath
        $result.Imported | Should -BeTrue
        $result.ChangedAliases | Should -Not -Contain 'cd'
        $result.ChangedAliases | Where-Object { $_ -in $result.PreexistingCommandNames } |
            Should -BeNullOrEmpty
        $result.ChangedAliasesAfterRemoval | Should -BeNullOrEmpty
        $result.Warnings | Should -BeNullOrEmpty
    }

    It 'preserves a pre-existing command name without the override preference' {
        $result = & (Join-Path $PSScriptRoot 'Invoke-PscxImportProbe.ps1') `
            -ModulePath $ModulePath -BuildScope $BuildScope -CollisionAliasName tail `
            -PowerShellPath $PowerShellPath
        $result.ChangedAliases | Should -Not -Contain 'tail'
        $result.ExportedAliases | Should -Not -Contain 'tail'
        $result.CollisionAliasDefinition | Should -Be 'Get-Date'
        $result.CdAliasDefinition | Should -Be 'Pscx\Set-PscxLocation'
        $result.ChangedAliasesAfterRemoval | Should -BeNullOrEmpty
        $result.Warnings | Should -BeNullOrEmpty
    }

    It 'overrides every documented alias collision only when explicitly enabled' {
        $expectedAliases = @($script:contract.Aliases.Core)
        if ($BuildScope -eq 'Full') {
            $expectedAliases += $script:contract.Aliases.Full
        }
        $result = & (Join-Path $PSScriptRoot 'Invoke-PscxImportProbe.ps1') `
            -ModulePath $ModulePath -BuildScope $BuildScope -OverrideExistingAliases `
            -CollisionAliasName tail `
            -PowerShellPath $PowerShellPath
        $expectedExportedAliases = @($expectedAliases | Where-Object { $_ -ne 'cd' })
        Compare-Object ($expectedExportedAliases | Sort-Object) @($result.ExportedAliases) |
            Should -BeNullOrEmpty
        Compare-Object ($expectedAliases | Sort-Object) @($result.ChangedAliases) |
            Should -BeNullOrEmpty
        $result.CdAliasDefinition | Should -Be 'Pscx\Set-PscxLocation'
        $result.CollisionAliasDefinition | Should -Be 'Pscx\Get-FileTail'
        $result.ChangedAliasesAfterRemoval | Should -BeNullOrEmpty
        $result.ExportedAliases | Should -Not -Contain 'help'
        $result.Warnings | Should -BeNullOrEmpty
    }
}


# SIG # Begin signature block
# MIInmgYJKoZIhvcNAQcCoIInizCCJ4cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAjbvrE6g3TZttC
# 8Cl5lc1wGJrGE3ognut7PJ7ljREcZKCCIHEwggWNMIIEdaADAgECAhAOmxiO+dAt
# 5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBa
# Fw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lD
# ZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3E
# MB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKy
# unWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsF
# xl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU1
# 5zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJB
# MtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObUR
# WBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6
# nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxB
# YKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5S
# UUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+x
# q4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIB
# NjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwP
# TzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMC
# AYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0Nc
# Vec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnov
# Lbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65Zy
# oUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFW
# juyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPF
# mCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9z
# twGpn1eqXijiuZQwggaUMIIEfKADAgECAgh1RsL97PvpATANBgkqhkiG9w0BAQsF
# ADCBljELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAk1OMRQwEgYDVQQHEwtNaW5uZWFw
# b2xpczESMBAGA1UEChMJTHVjYSBIb21lMQ8wDQYDVQQLEwZPZmZpY2UxGzAZBgNV
# BAMTEkx1Y2FzIENvZGUgUm9vdCBDQTEiMCAGCSqGSIb3DQEJARYTZGFubHVjYUBj
# b21jYXN0Lm5ldDAeFw0yMjAzMjYwMDAwMDBaFw00OTAzMjUyMzU5NTlaMIGVMQsw
# CQYDVQQGEwJVUzELMAkGA1UECBMCTU4xFDASBgNVBAcTC01pbm5lYXBvbGlzMRIw
# EAYDVQQKEwlMdWNhIEhvbWUxDzANBgNVBAsTBk9mZmljZTEaMBgGA1UEAxMRTHVj
# YXMgQ29kZSBSU0EgQ0ExIjAgBgkqhkiG9w0BCQEWE2Rhbmx1Y2FAY29tY2FzdC5u
# ZXQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDNxe4oUxTG+YdtMgDm
# PStZVzsgBoBPBD/2Y9Zsxaaj26ZknpP22kONwySOjVcqMolJwWAOyJtKyzxCCT2c
# bOdwS1ZoAZKpUjmB3HJeMmdhwlTth4irqmK5C/8lxB0Va+jelxEMXTceCd7I6YkW
# w4l23Yq1+Y1Qv+dIifsm7BOYidWzR9aSuGrSdizNk1giewDAYo8l5RhOEoRgWFHx
# vuM0lHcTmT+6U1IgBE+06I7FS/uQ8g/ajQJVm6QAXlCkNeFg3EbEtEyQbdUEKcDS
# a7O88OpnA5j3/UAfEXZfizr9d2GY86gMjE3QDiGr51I4uWcA2gmecZxXUpc2XWFu
# UBu3ikOAJTOTMq9Pi5tN7ZQwKzJQLESdJ8So73dJcI/hW6Bf2k2x17ldY/GO3KEf
# t8KtxSr9kLQ4fYiIhLdHDtje0Zm8QSQFabrE94ci8kB0tFM+7FuQ51E8YiU9fhk3
# eh1sHLwEXg1m7uea6YPFdlpSbx17EpfSnBeeWiH/LNkttTg2Mb7oogVDlecv31Ng
# TqbZzQ7MPRdjrW3L9HxU6YvKo7/cxzGRltmG1daA4pKc0KVUQ6RXL9WRKLQyEbdg
# uTfkXKS9jMtr0h52Zvw7fW3qCGyqI8BhANjPYiCsftckkx0KPefmsQNT/w+m4Qu/
# 97qycOhyLKfpndb9IJkEOcAu0wIDAQABo4HkMIHhMA8GA1UdEwEB/wQFMAMBAf8w
# HQYDVR0OBBYEFIBmtZ8QfiC4XB0vz9YiGsofRq8hMA4GA1UdDwEB/wQEAwIBxjAz
# BgNVHSUELDAqBggrBgEFBQcDAwYIKwYBBQUHAwgGCisGAQQBgjcCARUGCCsGAQUF
# BwMJMDEGA1UdEQQqMCiBEXNsdWNhQGNvbWNhc3QubmV0gRNkYW5sdWNhQGNvbWNh
# c3QubmV0MBEGCWCGSAGG+EIBAQQEAwIAATAkBglghkgBhvhCAQ0EFxYVTHVjYXMg
# Q29kZSBTaWduaW5nIENBMA0GCSqGSIb3DQEBCwUAA4ICAQByKgofmdGXu4v40lYW
# DUL7otFJstfYcp0S7SQpSMIGwNj89kdWENU9ciYYq70qy781kLLIDwyGSwwAju3w
# MqtbiAWhjKGuEXKQROHTs/HtPBEZ9NL99IVdhc+/DT9UzP/fpPk6N/TOaTGQQsmw
# vWovGtnprAxWcGwyDS/jtRrWv1MaiYjtoOFOIAwcsOdkd3sNl5P+VJLTRlQAnrgi
# 55vkFyibH5cgbXvcYg3SLOw9HEi5hUpQ76DdzqCa/CX4sqPstWNlKjQ8ehfi6AGa
# guFC25HcOhhoNZjjlgOP7a5i8KG/Gh2JuYmu8SkWivHJwMswLy3M6Vpd9euNXNSr
# 46EQ4iafNlij5rRxRQuPsjT/q4A4g3HCJZUBCN0HlXmJwiG/yRNJSvjsKGabW2qQ
# NilU2blO9JVRZKPnLGaKai6aRRHQ225kopalRPK4oTtkBjnJzbnXfECHNh0C3qIl
# 0MmgJ7Yf1HrGfj425zC56bH8jCJv3H3G3B4DdDDpRAQbW3/vsypPSce7YoB0JCYt
# UU95KI09G5Dl9GuGtupIaMfs05ECAQTGXvF6Olq6sRTyf7JROTmKBpiJO62a8xEg
# kTmJ9ZLrzBHNqVNzoljx+Zaa+5I3K5a1y6nccG26Th2+m/42kGm1XqfEyUbZybXB
# E5FC/7m39/hu0d703lrl32FtozCCBpswggSDoAMCAQICCAbX5YewM+U2MA0GCSqG
# SIb3DQEBCwUAMIGVMQswCQYDVQQGEwJVUzELMAkGA1UECBMCTU4xFDASBgNVBAcT
# C01pbm5lYXBvbGlzMRIwEAYDVQQKEwlMdWNhIEhvbWUxDzANBgNVBAsTBk9mZmlj
# ZTEaMBgGA1UEAxMRTHVjYXMgQ29kZSBSU0EgQ0ExIjAgBgkqhkiG9w0BCQEWE2Rh
# bmx1Y2FAY29tY2FzdC5uZXQwHhcNMjIwMzI2MDAwMDAwWhcNNDcwMzI1MjM1OTU5
# WjCBjDELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAk1OMRQwEgYDVQQHEwtNaW5uZWFw
# b2xpczESMBAGA1UEChMJTHVjYSBIb21lMQ8wDQYDVQQLEwZPZmZpY2UxETAPBgNV
# BAMTCERhbiBMdWNhMSIwIAYJKoZIhvcNAQkBFhNkYW5sdWNhQGNvbWNhc3QubmV0
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAt5i4r1HEGsNrSWsxNzkV
# A/opuBv3Xisr1Km43wuCW9BKaM73FlgPbPrOo1ynxsWAmvrOv2RKctcxqaEdhvY1
# aioK9HYu/OhCOwIbINnJFUDp3ecdJOFloUC7bE1eccGHRv40fUjLTNT7wcFaYjv7
# G+7jUhvL88BGSneBjyS2RXCn1EpFU0MmJ055tNyAL3zCBfGdtGqilMttfE63Nxf4
# uQfvT5Nloub5V2z07lx/uwA1ZE7pKXiHkZh4auLsb74d+nRKZhwUfKB9c42qfJMU
# iA9wlBbxMZ2Yxb9r+COJsB/TOGGyC1kdDgJ1M1XbxERgsf0FnUJOFCy/n5aozgW6
# hwM/UXxzAQKwLaRkjrk06G7MyYegL6XvHN0EFTFVg1VDFlFOvQ4OCNEtuEcMEfsN
# LFPxiVrfJf3NxcuX3VNMoJwXT716H4cVmvl3z8zWdWikRfUpkDuk17/lN+61KLss
# DMGaj3uGC8xxOWiUCR5Lg9P5dUIIjgGqNhFKiHJE7LvXZ7H63/yh1967P/C1h7mf
# u+3/vZ98H4nXfLCJ4jmAigUYG6jVZffeeogbcfgGR8v9c15binUdD3lWMQ3/PpdI
# GLsENA8MHqXVC/SAnvKm5pqVpFWOXqyBX3u2BJ9utF27Nsb2RoJqCFt7bB2engxM
# adPGGdJc2GbnuSMtdSV5chECAwEAAaOB9TCB8jAMBgNVHRMBAf8EAjAAMB0GA1Ud
# DgQWBBQZJ4PIxOjVfCmSYMBKp3+E/s/h4zAOBgNVHQ8BAf8EBAMCBsAwNQYDVR0l
# BC4wLAYIKwYBBQUHAwMGCCsGAQUFBwMIBgorBgEEAYI3AgEVBgorBgEEAYI3AgEW
# MDMGA1UdEQQsMCqBE2Rhbmx1Y2FAY29tY2FzdC5uZXSBE2Rhbmx1Y2EyMkBnbWFp
# bC5jb20wEQYJYIZIAYb4QgEBBAQDAgQQMDQGCWCGSAGG+EIBDQQnFiVEYW4gTHVj
# YSBjZXJ0aWZpY2F0ZSBmb3IgY29kZSBzaWduaW5nMA0GCSqGSIb3DQEBCwUAA4IC
# AQBIoCyjFppNigfzbRKb48zLEm3Imhuui2cJzAjYdex2WxWgcMbnklGvFuMwP6+K
# HtCMg2Q/vkEh3vM2iyh/fmKlYMGcJtTjzeE3bkStHl6AuYwBEC7xofNAg1SQBWGK
# iOeANeGJj88J8vLpMtKFMTAwf824EJzItZPpxLybdpv14XIeo9Gku6yd/hWticee
# xHbH5cXmBNkMlUPhaP8XpgnF4mF1QKRFNi3OmM36o/r2uVg2M5GXMRb9/FRTjeOz
# ApCmLhee0xF+42iAeYCYpkveMZra0CIcYnViyWeJi+xyx1OP7ZL8cVuIwDXvv3tk
# luAVwobgmwFz6tAMLzblQfUlE9WTdQrA0pzEg1jniWt2O95I+7JDieTP1CM1KxRw
# s2u8vJoxzls47ZmdiIoHcRO9exVUrfUF8rKIORaanY4fUwIiUQiie8GrUMTKrQCk
# Ly8/qN/YJyKxQmlKJxCqyfjoH7FvmaDqtdHaOhweiqF18HhymnHMblrIgctoEPqh
# 3/GURELo9yAhgZRTorw3jS8+uY2b2JRC7+EIbf4GS6rOYvgbdUBpGHRiaA0AeY7F
# 7J0DZncUy1yL1jj1/UzngrC7FIZXVF0WT3b59T5wm7fBo2642lRgD2eVXyj5Ygn4
# EebBYhHzbPbXhSUfdKFro6bVrzSp+a3MY+E0GlDUeLf6rjCCBrQwggScoAMCAQIC
# EA3HrFcF/yGZLkBDIgw6SYYwDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMx
# FTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNv
# bTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTI1MDUwNzAw
# MDAwMFoXDTM4MDExNDIzNTk1OVowaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRp
# Z2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVT
# dGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBALR4MdMKmEFyvjxGwBysddujRmh0tFEXnU2tjQ2UtZmW
# gyxU7UNqEY81FzJsQqr5G7A6c+Gh/qm8Xi4aPCOo2N8S9SLrC6Kbltqn7SWCWgzb
# NfiR+2fkHUiljNOqnIVD/gG3SYDEAd4dg2dDGpeZGKe+42DFUF0mR/vtLa4+gKPs
# YfwEu7EEbkC9+0F2w4QJLVSTEG8yAR2CQWIM1iI5PHg62IVwxKSpO0XaF9DPfNBK
# S7Zazch8NF5vp7eaZ2CVNxpqumzTCNSOxm+SAWSuIr21Qomb+zzQWKhxKTVVgtmU
# PAW35xUUFREmDrMxSNlr/NsJyUXzdtFUUt4aS4CEeIY8y9IaaGBpPNXKFifinT7z
# L2gdFpBP9qh8SdLnEut/GcalNeJQ55IuwnKCgs+nrpuQNfVmUB5KlCX3ZA4x5HHK
# S+rqBvKWxdCyQEEGcbLe1b8Aw4wJkhU1JrPsFfxW1gaou30yZ46t4Y9F20HHfIY4
# /6vHespYMQmUiote8ladjS/nJ0+k6MvqzfpzPDOy5y6gqztiT96Fv/9bH7mQyogx
# G9QEPHrPV6/7umw052AkyiLA6tQbZl1KhBtTasySkuJDpsZGKdlsjg4u70EwgWbV
# RSX1Wd4+zoFpp4Ra+MlKM2baoD6x0VR4RjSpWM8o5a6D8bpfm4CLKczsG7ZrIGNT
# AgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBTvb1NK
# 6eQGfHrK4pBW9i/USezLTjAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qYrhwP
# TzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYBBQUH
# AQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYI
# KwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRy
# dXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZMBcw
# CAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAF877FoAc
# /gc9EXZxML2+C8i1NKZ/zdCHxYgaMH9Pw5tcBnPw6O6FTGNpoV2V4wzSUGvI9NAz
# aoQk97frPBtIj+ZLzdp+yXdhOP4hCFATuNT+ReOPK0mCefSG+tXqGpYZ3essBS3q
# 8nL2UwM+NMvEuBd/2vmdYxDCvwzJv2sRUoKEfJ+nN57mQfQXwcAEGCvRR2qKtntu
# jB71WPYAgwPyWLKu6RnaID/B0ba2H3LUiwDRAXx1Neq9ydOal95CHfmTnM4I+ZI2
# rVQfjXQA1WSjjf4J2a7jLzWGNqNX+DF0SQzHU0pTi4dBwp9nEC8EAqoxW6q17r0z
# 0noDjs6+BFo+z7bKSBwZXTRNivYuve3L2oiKNqetRHdqfMTCW/NmKLJ9M+MtucVG
# yOxiDf06VXxyKkOirv6o02OoXN4bFzK0vlNMsvhlqgF2puE6FndlENSmE+9JGYxO
# GLS/D284NHNboDGcmWXfwXRy4kbu4QFhOm0xJuF2EZAOk5eCkhSxZON3rGlHqhpB
# /8MluDezooIs8CVnrpHMiD2wL40mm53+/j7tFaxYKIqL0Q4ssd8xHZnIn/7GELH3
# IdvG2XlM9q7WP/UwgOkw/HQtyRN62JK4S1C8uw3PdBunvAZapsiI5YKdvlarEvf8
# EA+8hcpSM9LHJmyrxaFtoza2zNaQ9k+5t1wwggbtMIIE1aADAgECAhAIT9wzT35F
# TtvDD4/5khg1MA0GCSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQK
# Ew5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBU
# aW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwHhcNMjYwODA1MDAw
# MDAwWhcNMzcxMTA0MjM1OTU5WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGln
# aUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFNIQTI1NiBSU0E0MDk2IFRp
# bWVzdGFtcCBSZXNwb25kZXIgMjAyNiAxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAtnum8sn+zUr41JtMZbP9OMYw+HwJDpG5xkIu/lqcfNYmMX81YmsU
# iHLbh9ykpeWBGKTLhYBrAN9Tdg/QEzG32XcObmgIblnr0CoQ3WSAeDZ6nH6X6VkF
# yYkJw3QBJREwvm4UhLzSxmwPA7cFKRTEOMsmEEj6qJk/dqLEAL+oQYuOwE2UuiX1
# Vnul8YReIyWd4kgLn9gq6LNXM0UplkR6jL/QHxmb6fMoGBJYbnaUI7XD6cKDpekK
# 2SVMld4iDbzeHDtOaaxldH5IxuNusQ69nd8/ZXEiB5Hbxj3RlK13cX1W4DlFXKdv
# /CEhM8Cj1vvlmvhNroyPdRGbbpBlgyf8Wdu5N6ByhFwURn0U6ozlPoxN22v+fviU
# hP+6DR547OZnpBMWDfei1f5sVGwiiW/KQTWOK97g+4RJpPzPNV4VYMAwO2jM2Aty
# 2QYPVmOQTJm0msuXnJrSbl2gf9JylpkJlWXqk1Q4LJsxz+TELoQCZIljbgvTJgoP
# U2R12ydv8i1UqL/adelA0y7U9Pmmtbze9Xx3rtajC5SzQd1jgfwAwsa90v9YcSPd
# meoyoBBA/27cCL237l5DTYYPDLQ4ON3OLTGWnvRb6jDrf/T75gMRfUzSLCBQfBus
# m9+mSWRlC/Df6S/e9Q8i13CuhzOT2Jx+V/nlbXM4QoBwlUAhelwwJT0CAwEAAaOC
# AZUwggGRMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFBTJY4owLtRK+26U8+bjQH71
# 7M3iMB8GA1UdIwQYMBaAFO9vU0rp5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB/wQE
# AwIHgDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgwgYUw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEFBQcw
# AoZRaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0
# VGltZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRYMFYw
# VKBSoFCGTmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRH
# NFRpbWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAEGTAX
# MAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBAI3FOmEe
# nVIK35msCYB+fShAsWvSYvLBItoNdAgQ2jIqrGsVsluXMJU/+mRebBc52s6lbKAv
# OVPXaizmKkMLLflEEKDZQx4CkS2t8aHPjkXha3hYZ010htFa3dhNgmalH5vuWvh3
# tTCf4frTS7gPtGc4Z/xaPhQ2AB1mR8eEe/WbH0RWHvVIl6VwQ3+g5FKNfN2N/DWJ
# kf13w2H+2GfqEfbd35Ww8CvoYBjLNIDTadcPWdgsjsiOaK/7EsKJgLjUNIVgvcaF
# OLLQ/GlrA+0ZHJoFUbOr5SJN8zykPspXIXlpDJY/gqFUZRROeab9GVgmhbdOJcD/
# 63RhxPahFUGbckRONqMe6DYAv6/mOG0pWd3cPStsdcS7buj5DyniwRY8yooMH6pt
# x5vpP/pZzBPBeZD2U4IsthyxB5Jaa8qrOkB5z160TXiM5ADMspZ0TfD9MJoq0tFp
# FPssKRFhWeEDYPvcUuN7U7lvcdHl4ezQ3NT/7Ffs1sR1yh/LRbdZ3B3Vc6q2WmD8
# mDC0p9kzl2o73iVtS946IkEj7FkRsZGww1teYxERROC745xrtjvcw9ZyyUjHZWGR
# IpJeMNsPquCDf0fkyHtB+J4AiNZqCQk23rxh+KbpyMTNVKItJ5l92Svl20U9NbqM
# BOVYl1h54NEYLJq1/xHWFKPNK903zJZA9P2DMYIGfzCCBnsCAQEwgaIwgZUxCzAJ
# BgNVBAYTAlVTMQswCQYDVQQIEwJNTjEUMBIGA1UEBxMLTWlubmVhcG9saXMxEjAQ
# BgNVBAoTCUx1Y2EgSG9tZTEPMA0GA1UECxMGT2ZmaWNlMRowGAYDVQQDExFMdWNh
# cyBDb2RlIFJTQSBDQTEiMCAGCSqGSIb3DQEJARYTZGFubHVjYUBjb21jYXN0Lm5l
# dAIIBtflh7Az5TYwDQYJYIZIAWUDBAIBBQCggYQwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFjAvBgkqhkiG9w0BCQQxIgQgQNPT7oENAOmY2oykVbKA
# 5j8asrplEC1+PZcdKtzRqxYwDQYJKoZIhvcNAQEBBQAEggIAqMv/xuFDOiKoNBNk
# n8gU+O6vuw5sh5jLSf32oiOm4DBBMuMlS8CwdGJUEMwi0evoOyg9c1WSaYyuf332
# uJdOeeOZRlBxHZVwSBGqZCI/a3Bgo1t3zS4ier4Of9erN55eR1Kvjrl6F1yEwW+k
# K9UeAXDpsgOKZGgQVTAHFR6hH2BkZsScLZI8O5kjNokiDRkWwG3bkM1DEcXxAXUs
# kJ3A5HnGMLdlUW4HjT5J8Z7FuplX1omS/Npp5Mvi25PE6r/OusLYp/5AOiO89C+j
# JEqU/7L4zzWWqCHwAOuWi5ivOFlYX0/GuVt2oc7DEfP2v63FeOT1xFWIQxFYqGkq
# QsfY66eMoWl5VVN/S5OSFlq0lS6bhdr8vIOdOqpMAorcBLLVUnG+H3YUxRSTfKX6
# CAD+hLVMN3xjQ/sojhZd7A7M2sDxgLmqSH/wRGglNo6ndhBVjdoM+G9wEhSXs7Pb
# jHy5v3xM6ty2Zj6H5LqsPCC39ZrpO+Fqd+kEy87Z5T4cLMR+cCUj4En/pieD8y/n
# aYc2b2QweDjdbfrMWRDTOOshFtIDr1Fjn4zlBF1p4oLXoEoKk+KFZiqwVIziC0Ib
# rzvJ4ZwkhcnPorcP/zTMyHsq1TRloz5jXIK6zPPZmeV7lZ8pVKmmLr3tmxTfaRj6
# AIt5gsiuIfoEtzY2Zf+8jsEzSXyhggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8C
# AQEwfTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/
# BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYg
# U0hBMjU2IDIwMjUgQ0ExAhAIT9wzT35FTtvDD4/5khg1MA0GCWCGSAFlAwQCAQUA
# oGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYw
# OTA0MjEwMzQ3WjAvBgkqhkiG9w0BCQQxIgQg3cp+qcCFNYzVNB0fVpowfv/+wl87
# 2j5p+0PxC1HOjZ0wDQYJKoZIhvcNAQEBBQAEggIATythScPKiKAtsO9flppbFf1l
# DSYjSGRnu8FyPsFdmlxUcXKyLqXJ/CbUWFbGU5GOBNhWlJ8rXcbmidXHO6KfkAeY
# XXrj2pe8C1++xlfsU5puhVmFrHn1SFijq/vOO/9qN+yBAxGoo4AdLcuDQK1/b7np
# giSPpn4llCEo4DOk7VRdNtuAbkK1WHsdWVrMiQNAWZhP3PniHH1fojfNYFQpOo9r
# b3Se3kZQt8AvNf7etYdYQFeI18FEvBXNrh2AlNwI0iTP4IFnIjp+HLsVqkkYVk5z
# RxU+yBLkUfDQAqagkWoSkV3+pA2eY64MS7OQ4dV8W52tlJWOtcMU3Y1wrdGxxrHu
# zDfs5NV9pC25PRWTq6DuOVd6pglfqVZQe4msL0xKYWUQ23axtXrs6AT7Rcty/Orc
# WuQDvl+RNnxdtLdwgHJR4yrBOcKk1GdE0pv4yev471kspORqPM0phWflyLoiTgu9
# 3Z+HmdpwFPL64jxFCApQyiTPvNHimVevsrVQ8dBMUNcG7M6+cZpkX1oaAxzVUYOg
# qadMcMcUwlj1E2AA3OgE0srhfz+vm44RWKYZp2FmFdJSw0gpvVhb2G2vl/1edHsT
# TemR5qnmcXkpKR00jecESMYZy6JUs2E6CJqRtyYAbpHYpemTfc+cw/kXGykzOteF
# dP3euNUg9voCUsK0NNM=
# SIG # End signature block
