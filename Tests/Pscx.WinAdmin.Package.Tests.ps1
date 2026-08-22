param(
    [Parameter(Mandatory)]
    [string] $ModulePath,

    [Parameter(Mandatory)]
    [string] $WinAdminModulePath
)

Describe 'Packaged Pscx.WinAdmin module contract' {
    BeforeAll {
        $script:mainManifestPath = Join-Path $ModulePath 'Pscx.psd1'
        $script:adminManifestPath = Join-Path $WinAdminModulePath 'Pscx.WinAdmin.psd1'
        $script:expectedCommands = @(
            'Add-ShortPath'
            'Get-AdoConnection'
            'Get-AdoDataProvider'
            'Get-ForegroundWindow'
            'Get-OleDbData'
            'Get-OleDbDataSet'
            'Invoke-AdoCommand'
            'Invoke-BatchFile'
            'Invoke-OleDbCommand'
        )
        $script:previousModulePath = $env:PSModulePath
        $env:PSModulePath = "$(Split-Path -Parent $ModulePath)$([IO.Path]::PathSeparator)$env:PSModulePath"
    }

    AfterEach {
        Remove-Module Pscx.WinAdmin, Pscx -Force -ErrorAction SilentlyContinue
    }

    AfterAll {
        $env:PSModulePath = $script:previousModulePath
    }

    It 'is not nested, required, or bundled by the default PSCX module' {
        $mainManifest = Import-PowerShellDataFile -LiteralPath $script:mainManifestPath
        @($mainManifest['NestedModules']) | Should -Not -Contain 'Pscx.WinAdmin.dll'
        @($mainManifest['RequiredModules']) | Should -Not -Contain 'Pscx.WinAdmin'
        @(Get-ChildItem -LiteralPath $ModulePath -Recurse -File -Filter 'Pscx.WinAdmin*') |
            Should -HaveCount 0
    }

    It 'exports exactly the nine classified optional Windows commands' {
        Import-Module $script:adminManifestPath -Force -ErrorAction Stop
        $actualCommands = @(
            Get-Module Pscx.WinAdmin -All |
                ForEach-Object { $_.ExportedCommands.Values } |
                Where-Object CommandType -In Cmdlet, Function |
                ForEach-Object Name |
                Sort-Object -Unique
        )
        Compare-Object $script:expectedCommands $actualCommands | Should -BeNullOrEmpty
    }

    It 'retains environment changes made by an arbitrary batch file' {
        $variableName = "PSCX_BATCH_TEST_$([guid]::NewGuid().ToString('N'))"
        $batchPath = Join-Path $TestDrive 'set-environment.cmd'
        "@set $variableName=retained" | Set-Content -LiteralPath $batchPath -Encoding ascii
        try {
            Import-Module $script:adminManifestPath -Force -ErrorAction Stop
            Invoke-BatchFile -Path $batchPath -WhatIf
            [Environment]::GetEnvironmentVariable($variableName, 'Process') |
                Should -BeNullOrEmpty
            Invoke-BatchFile -Path $batchPath
            [Environment]::GetEnvironmentVariable($variableName, 'Process') |
                Should -Be 'retained'
        }
        finally {
            [Environment]::SetEnvironmentVariable($variableName, $null, 'Process')
        }
    }
}
