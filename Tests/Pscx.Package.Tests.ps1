param(
    [Parameter(Mandatory)]
    [string] $ModulePath,

    [Parameter(Mandatory)]
    [ValidateSet('Core', 'Full')]
    [string] $BuildScope
)

BeforeAll {
    $script:manifestPath = Join-Path $ModulePath 'Pscx.psd1'
    $script:importWarnings = @()
    $script:manifest = Test-ModuleManifest -Path $script:manifestPath -ErrorAction Stop
    Import-Module $script:manifestPath -Force -ErrorAction Stop `
        -WarningVariable 'script:importWarnings'
    $script:commands = @(Get-Command -Module Pscx*)
}

AfterAll {
    Get-Module Pscx* | Remove-Module -Force -ErrorAction SilentlyContinue
}

Describe 'Packaged PSCX smoke contract' {
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

    It 'exports commands from the packaged module' {
        $script:commands.Count | Should -BeGreaterThan 0
    }

    It 'contains the expected platform assembly set' {
        $windowsAssemblyExists = Test-Path -LiteralPath (Join-Path $ModulePath 'Pscx.Win.dll')
        $windowsAssemblyExists | Should -Be ($BuildScope -eq 'Full')
    }
}
