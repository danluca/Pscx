param(
    [Parameter(Mandatory)]
    [string] $ArchiveModulePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'Packaged Pscx.Archive module' {
    BeforeAll {
        $script:archiveModulePath = (Resolve-Path -LiteralPath $ArchiveModulePath).Path
        $script:archiveManifestPath = Join-Path $script:archiveModulePath 'Pscx.Archive.psd1'
        Import-Module $script:archiveManifestPath -Force -ErrorAction Stop
    }

    AfterAll {
        Remove-Module Pscx.Archive -Force -ErrorAction SilentlyContinue
    }

    It 'exports only the three archive cmdlets' {
        @(Get-Command -Module Pscx.Archive).Name | Sort-Object | Should -Be @(
            'Expand-PscxArchive'
            'Read-PscxArchive'
            'Write-PscxArchive'
        )
    }

    It 'ships the approved managed backend without native or legacy archive binaries' {
        (Get-Item (Join-Path $script:archiveModulePath 'SharpCompress.dll')).VersionInfo.FileVersion |
            Should -BeLike '0.50.4*'
        @(Get-ChildItem -LiteralPath $script:archiveModulePath -Recurse -File |
            Where-Object Name -Match '^(7z|7zz)|SevenZipSharp|\.(so|dylib)$') | Should -HaveCount 0
    }

    It 'round trips <Extension> archives' -ForEach @(
        @{ Extension = '.zip' }
        @{ Extension = '.7z' }
        @{ Extension = '.tar' }
        @{ Extension = '.tar.gz' }
        @{ Extension = '.tar.bz2' }
    ) {
        $caseRoot = Join-Path $TestDrive ([IO.Path]::GetRandomFileName())
        $source = Join-Path $caseRoot 'source'
        $destination = Join-Path $caseRoot 'expanded'
        $archive = Join-Path $caseRoot "sample$Extension"
        New-Item -ItemType Directory -Path (Join-Path $source 'nested') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $source 'nested/content.txt') -Value 'portable archive content'

        $created = Write-PscxArchive -LiteralPath $source -OutputPath $archive
        $created.FullName | Should -Be ([IO.Path]::GetFullPath($archive))
        $entries = @(Read-PscxArchive -LiteralPath $archive)
        $entries.Path | Should -Contain 'source/nested/content.txt'

        $expanded = @(Expand-PscxArchive -LiteralPath $archive -OutputPath $destination -PassThru)
        $expanded.Name | Should -Contain 'content.txt'
        Get-Content -LiteralPath (Join-Path $destination 'source/nested/content.txt') -Raw |
            Should -BeLike 'portable archive content*'
    }

    It 'supports pipeline input and LiteralPath without wildcard expansion' {
        $source = Join-Path $TestDrive 'literal[1].txt'
        $archive = Join-Path $TestDrive 'literal.zip'
        Set-Content -LiteralPath $source -Value 'literal'

        Get-Item -LiteralPath $source | Write-PscxArchive -OutputPath $archive | Should -Not -BeNullOrEmpty
        @(Read-PscxArchive -LiteralPath $archive).Path | Should -Be @('literal[1].txt')
    }

    It 'honors WhatIf and requires Force before replacing output' {
        $source = Join-Path $TestDrive 'whatif.txt'
        $archive = Join-Path $TestDrive 'whatif.zip'
        Set-Content -LiteralPath $source -Value 'first'

        Write-PscxArchive -LiteralPath $source -OutputPath $archive -WhatIf
        $archive | Should -Not -Exist
        Write-PscxArchive -LiteralPath $source -OutputPath $archive | Out-Null
        { Write-PscxArchive -LiteralPath $source -OutputPath $archive } | Should -Throw '*-Force*'
        { Write-PscxArchive -LiteralPath $source -OutputPath $archive -Force } | Should -Not -Throw
    }

    It 'rejects traversal entries before writing outside the destination' {
        $archive = Join-Path $TestDrive 'traversal.zip'
        $stream = [IO.File]::Open($archive, [IO.FileMode]::Create)
        try {
            $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
            $entry = $zip.CreateEntry('../outside.txt')
            $writer = [IO.StreamWriter]::new($entry.Open())
            $writer.Write('unsafe')
            $writer.Dispose()
            $zip.Dispose()
        }
        finally {
            $stream.Dispose()
        }

        $destination = Join-Path $TestDrive 'safe'
        { Expand-PscxArchive -LiteralPath $archive -OutputPath $destination } | Should -Throw '*path traversal*'
        Join-Path $TestDrive 'outside.txt' | Should -Not -Exist
    }

    It 'rejects symbolic-link archive entries' {
        $archive = Join-Path $TestDrive 'symlink.tar'
        $stream = [IO.File]::Open($archive, [IO.FileMode]::Create)
        try {
            $writer = [System.Formats.Tar.TarWriter]::new($stream, $false)
            $entry = [System.Formats.Tar.PaxTarEntry]::new(
                [System.Formats.Tar.TarEntryType]::SymbolicLink,
                'link')
            $entry.LinkName = '../outside.txt'
            $writer.WriteEntry($entry)
            $writer.Dispose()
        }
        finally {
            $stream.Dispose()
        }

        { Expand-PscxArchive -LiteralPath $archive -OutputPath (Join-Path $TestDrive 'links') } |
            Should -Throw '*Symbolic-link*'
    }

    It 'rejects extraction through an existing filesystem link' {
        $destination = Join-Path $TestDrive 'link-destination'
        $outside = Join-Path $TestDrive 'outside-directory'
        New-Item -ItemType Directory -Path $destination, $outside | Out-Null
        try {
            New-Item -ItemType SymbolicLink -Path (Join-Path $destination 'linked') `
                -Target $outside -ErrorAction Stop | Out-Null
        }
        catch {
            Set-ItResult -Skipped -Because "This test environment cannot create symbolic links: $($_.Exception.Message)"
            return
        }

        $archive = Join-Path $TestDrive 'link-traversal.zip'
        $stream = [IO.File]::Open($archive, [IO.FileMode]::Create)
        try {
            $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
            $entry = $zip.CreateEntry('linked/escaped.txt')
            $writer = [IO.StreamWriter]::new($entry.Open())
            $writer.Write('unsafe')
            $writer.Dispose()
            $zip.Dispose()
        }
        finally {
            $stream.Dispose()
        }

        { Expand-PscxArchive -LiteralPath $archive -OutputPath $destination } |
            Should -Throw '*filesystem link*'
        Join-Path $outside 'escaped.txt' | Should -Not -Exist
    }

    It 'does not restore executable permission bits on Unix' -Skip:$IsWindows {
        $archive = Join-Path $TestDrive 'mode.tar'
        $stream = [IO.File]::Open($archive, [IO.FileMode]::Create)
        try {
            $writer = [System.Formats.Tar.TarWriter]::new($stream, $false)
            $entry = [System.Formats.Tar.PaxTarEntry]::new(
                [System.Formats.Tar.TarEntryType]::RegularFile,
                'script.sh')
            $entry.Mode = [Convert]::ToInt32('777', 8)
            $entry.DataStream = [IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes('#!/bin/sh'))
            $writer.WriteEntry($entry)
            $writer.Dispose()
        }
        finally {
            $stream.Dispose()
        }

        $destination = Join-Path $TestDrive 'mode'
        Expand-PscxArchive -LiteralPath $archive -OutputPath $destination
        ([IO.File]::GetUnixFileMode((Join-Path $destination 'script.sh')) -band
            [IO.UnixFileMode]::UserExecute) | Should -Be 0
    }
}
