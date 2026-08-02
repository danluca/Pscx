param(
    [Parameter(Mandatory)]
    [string] $ModulePath,

    [Parameter(Mandatory)]
    [ValidateSet('Core', 'Full')]
    [string] $BuildScope
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
    $script:aliasesBeforeImport = @{}
    Get-Alias | ForEach-Object {
        $script:aliasesBeforeImport[$_.Name] = $_.Definition
    }
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

    It 'creates or changes only documented PSCX aliases' {
        $expectedAliases = @($script:contract.Aliases.Core)
        if ($BuildScope -eq 'Full') {
            $expectedAliases += $script:contract.Aliases.Full
        }
        $changedAliases = @(
            Get-Alias | Where-Object {
                -not $script:aliasesBeforeImport.ContainsKey($_.Name) -or
                $script:aliasesBeforeImport[$_.Name] -ne $_.Definition
            } | ForEach-Object Name | Sort-Object -Unique
        )
        $undeclaredAliases = @($changedAliases | Where-Object { $_ -NotIn $expectedAliases })
        $undeclaredAliases | Should -BeNullOrEmpty
    }
}

Describe 'Packaged PSCX help and examples' {
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
                        ($exampleCount -eq 0 -and $_.Name -ne 'PscxHelp')
                    ) {
                        $_.Name
                    }
                }
        )
        $gaps | Should -BeNullOrEmpty
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

    It 'round-trips structured YAML through the packaged Windows commands' {
        if ($BuildScope -ne 'Full') {
            Set-ItResult -Skipped -Because 'YAML commands are supplied by the Windows module.'
            return
        }

        $source = "project:`n  name: PSCX`n  active: true"
        $object = $source | ConvertFrom-Yaml
        $yaml = $object | ConvertTo-Yaml
        $roundTrip = $yaml | ConvertFrom-Yaml

        $object.project.name | Should -Be 'PSCX'
        $yaml | Should -Match 'name: PSCX'
        $yaml | Should -Match 'active: "true"'
        $roundTrip.project.active | Should -Be 'true'
    }

    It 'creates a Windows hard link in an isolated temporary directory' {
        if ($BuildScope -ne 'Full') {
            Set-ItResult -Skipped -Because 'NTFS link commands are supplied by the Windows module.'
            return
        }

        $target = Join-Path $script:temporaryRoot 'target.txt'
        $link = Join-Path $script:temporaryRoot 'target-link.txt'
        Set-Content -LiteralPath $target -Value 'linked content'

        New-Hardlink -LiteralPath $link -Target $target | Out-Null

        Get-Content -LiteralPath $link -Raw | Should -Be (Get-Content -LiteralPath $target -Raw)
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
}

Describe 'Optional feature imports' {
    It 'imports with default preferences in a clean process' {
        $result = & (Join-Path $PSScriptRoot 'Invoke-PscxImportProbe.ps1') `
            -ModulePath $ModulePath -BuildScope $BuildScope
        $result.Imported | Should -BeTrue
        $result.Warnings | Should -BeNullOrEmpty
    }

    It 'imports with the <Name> feature enabled in a clean process' -ForEach $optionalFeatures {
        param($Name, $ModuleName)

        $result = & (Join-Path $PSScriptRoot 'Invoke-PscxImportProbe.ps1') `
            -ModulePath $ModulePath -BuildScope $BuildScope -Feature $Name
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
            -ModulePath $ModulePath -BuildScope $BuildScope -EnableAllOptionalFeatures
        $declaredCommands = @(
            $script:manifestData.FunctionsToExport
            $script:manifestData.CmdletsToExport
        ) | Sort-Object -Unique
        Compare-Object $declaredCommands @($result.ExportedCommands) | Should -BeNullOrEmpty
        $result.Warnings | Should -BeNullOrEmpty
    }

    It 'does not replace a pre-existing global alias when optional features are disabled' {
        $result = & (Join-Path $PSScriptRoot 'Invoke-PscxImportProbe.ps1') `
            -ModulePath $ModulePath -BuildScope $BuildScope -DisableOptionalFeatures
        $result.Imported | Should -BeTrue
        $result.CdAliasBefore | Should -Be $result.CdAliasAfter
        $result.Warnings | Should -BeNullOrEmpty
    }
}
