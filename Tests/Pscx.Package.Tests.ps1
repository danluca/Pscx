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
}

Describe 'Optional feature imports' {
    It 'imports with default preferences in a clean process' {
        $result = & (Join-Path $PSScriptRoot 'Invoke-PscxImportProbe.ps1') `
            -ModulePath $ModulePath -BuildScope $BuildScope -PowerShellPath $PowerShellPath
        $result.Imported | Should -BeTrue
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
