Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:PscxRepository = 'danluca/Pscx'
$script:PscxManifestGuid = [guid]'0fab0d39-2f29-4e79-ab9a-fd750c66e6c5'
$script:PscxPackageRoots = @('Pscx', 'Pscx.Archive', 'Pscx.Time', 'Pscx.WinAdmin')
$script:PscxRequiredPackageRoots = @('Pscx', 'Pscx.Archive', 'Pscx.Time')

function ConvertFrom-PscxSemanticVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Version
    )

    process {
        $match = [regex]::Match(
            $Version,
            '^(?:v)?(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)(?:-(?<pre>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+(?<build>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$'
        )
        if (-not $match.Success) {
            throw "'$Version' is not a supported Semantic Version 2.0 value."
        }

        [string[]] $prerelease = @()
        if ($match.Groups['pre'].Success) {
            $prerelease = @($match.Groups['pre'].Value -split '\.')
        }
        foreach ($identifier in $prerelease) {
            if ($identifier -match '^\d+$' -and $identifier.Length -gt 1 -and $identifier[0] -eq '0') {
                throw "'$Version' has a numeric prerelease identifier with a leading zero."
            }
        }

        $normalizedCore = '{0}.{1}.{2}' -f
            $match.Groups['major'].Value,
            $match.Groups['minor'].Value,
            $match.Groups['patch'].Value
        $normalized = $normalizedCore
        if ($prerelease.Count -gt 0) {
            $normalized += '-' + ($prerelease -join '.')
        }
        if ($match.Groups['build'].Success) {
            $normalized += '+' + $match.Groups['build'].Value
        }

        [pscustomobject]@{
            Text = $normalized
            Core = [version]$normalizedCore
            Prerelease = $prerelease
            BuildMetadata = if ($match.Groups['build'].Success) {
                $match.Groups['build'].Value
            }
            else {
                $null
            }
            IsPrerelease = $prerelease.Count -gt 0
        }
    }
}

function Compare-PscxSemanticVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Left,

        [Parameter(Mandatory)]
        [object] $Right
    )

    $leftVersion = if ($Left.PSObject.Properties['Core']) {
        $Left
    }
    else {
        ConvertFrom-PscxSemanticVersion -Version ([string]$Left)
    }
    $rightVersion = if ($Right.PSObject.Properties['Core']) {
        $Right
    }
    else {
        ConvertFrom-PscxSemanticVersion -Version ([string]$Right)
    }

    $coreComparison = $leftVersion.Core.CompareTo($rightVersion.Core)
    if ($coreComparison -ne 0) {
        return [Math]::Sign($coreComparison)
    }
    if (-not $leftVersion.IsPrerelease -and -not $rightVersion.IsPrerelease) {
        return 0
    }
    if (-not $leftVersion.IsPrerelease) {
        return 1
    }
    if (-not $rightVersion.IsPrerelease) {
        return -1
    }

    $maximum = [Math]::Max($leftVersion.Prerelease.Count, $rightVersion.Prerelease.Count)
    for ($index = 0; $index -lt $maximum; $index++) {
        if ($index -ge $leftVersion.Prerelease.Count) {
            return -1
        }
        if ($index -ge $rightVersion.Prerelease.Count) {
            return 1
        }

        $leftIdentifier = $leftVersion.Prerelease[$index]
        $rightIdentifier = $rightVersion.Prerelease[$index]
        $leftIsNumeric = $leftIdentifier -match '^\d+$'
        $rightIsNumeric = $rightIdentifier -match '^\d+$'
        if ($leftIsNumeric -and $rightIsNumeric) {
            if ($leftIdentifier.Length -ne $rightIdentifier.Length) {
                if ($leftIdentifier.Length -lt $rightIdentifier.Length) {
                    return -1
                }
                return 1
            }
            $numericComparison = [string]::CompareOrdinal($leftIdentifier, $rightIdentifier)
            if ($numericComparison -ne 0) {
                return [Math]::Sign($numericComparison)
            }
            continue
        }
        if ($leftIsNumeric) {
            return -1
        }
        if ($rightIsNumeric) {
            return 1
        }

        $identifierComparison = [string]::CompareOrdinal($leftIdentifier, $rightIdentifier)
        if ($identifierComparison -ne 0) {
            return [Math]::Sign($identifierComparison)
        }
    }
    return 0
}

function Select-PscxSemanticVersionDescending {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]] $InputObject)

    $sorted = [Collections.Generic.List[object]]::new()
    foreach ($item in $InputObject) {
        $inserted = $false
        for ($index = 0; $index -lt $sorted.Count; $index++) {
            if ((Compare-PscxSemanticVersion -Left $item.Version -Right $sorted[$index].Version) -gt 0) {
                $sorted.Insert($index, $item)
                $inserted = $true
                break
            }
        }
        if (-not $inserted) {
            $sorted.Add($item)
        }
    }
    return @($sorted)
}

function Get-PscxInstalledVersion {
    $modules = @(
        Get-Module -Name Pscx -All -ErrorAction SilentlyContinue
        Get-Module -Name Pscx -ListAvailable -ErrorAction SilentlyContinue
    )
    $versions = [Collections.Generic.List[object]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($module in $modules) {
        $prerelease = $null
        $privateDataProperty = $module.PSObject.Properties['PrivateData']
        if ($null -ne $privateDataProperty -and $null -ne $privateDataProperty.Value) {
            $privateData = $privateDataProperty.Value
            $psData = if ($privateData -is [Collections.IDictionary]) {
                $privateData['PSData']
            }
            else {
                $psDataProperty = $privateData.PSObject.Properties['PSData']
                if ($null -ne $psDataProperty) { $psDataProperty.Value }
            }
            if ($psData -is [Collections.IDictionary]) {
                $prerelease = $psData['Prerelease']
            }
            elseif ($null -ne $psData) {
                $prereleaseProperty = $psData.PSObject.Properties['Prerelease']
                if ($null -ne $prereleaseProperty) { $prerelease = $prereleaseProperty.Value }
            }
        }
        $text = $module.Version.ToString()
        if (-not [string]::IsNullOrWhiteSpace($prerelease)) {
            $text += "-$prerelease"
        }
        $key = "$text|$($module.Path)"
        if ($seen.Add($key)) {
            $versions.Add([pscustomobject]@{
                    Version = ConvertFrom-PscxSemanticVersion -Version $text
                    Path = $module.Path
                })
        }
    }
    return @($versions)
}

function Get-PscxGitHubRelease {
    $headers = @{
        Accept = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
        'User-Agent' = 'Pscx-Update-Script'
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        $headers.Authorization = "Bearer $($env:GITHUB_TOKEN)"
    }

    try {
        return @(
            Invoke-RestMethod `
                -Uri "https://api.github.com/repos/$script:PscxRepository/releases?per_page=100" `
                -Headers $headers -Method Get -ErrorAction Stop
        )
    }
    catch {
        $responseProperty = $_.Exception.PSObject.Properties['Response']
        $response = if ($null -ne $responseProperty) { $responseProperty.Value } else { $null }
        $statusCode = if ($null -ne $response) { $response.StatusCode } else { $null }
        $statusValue = if ($null -ne $statusCode) { [int]$statusCode } else { 0 }
        if ($statusValue -in 403, 429) {
            $reset = if ($null -ne $response) { $response.Headers['X-RateLimit-Reset'] } else { $null }
            $resetMessage = if ($reset) { " Retry after GitHub's reset value '$reset'." } else { '' }
            throw "GitHub release discovery was rate-limited (HTTP $statusValue).$resetMessage"
        }
        throw "Could not query PSCX GitHub Releases. Check network connectivity and proxy settings. $($_.Exception.Message)"
    }
}

function Select-PscxRelease {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]] $Release,

        [switch] $IncludePrerelease
    )

    $candidates = [Collections.Generic.List[object]]::new()
    foreach ($item in $Release) {
        if ($item.draft) {
            continue
        }
        try {
            $version = ConvertFrom-PscxSemanticVersion -Version ([string]$item.tag_name)
        }
        catch {
            continue
        }
        if ([bool]$item.prerelease -ne $version.IsPrerelease) {
            continue
        }
        if ($version.IsPrerelease -and -not $IncludePrerelease) {
            continue
        }

        $zipName = "Pscx-$($version.Text).zip"
        $checksumName = "Pscx-$($version.Text).sha256"
        $zipAssets = @($item.assets | Where-Object name -EQ $zipName)
        $checksumAssets = @($item.assets | Where-Object name -EQ $checksumName)
        if ($zipAssets.Count -ne 1 -or $checksumAssets.Count -ne 1) {
            continue
        }
        $candidates.Add([pscustomobject]@{
                Version = $version
                Release = $item
                ZipAsset = $zipAssets[0]
                ChecksumAsset = $checksumAssets[0]
                ReleaseNotesUri = [uri]$item.html_url
            })
    }
    return Select-PscxSemanticVersionDescending -InputObject @($candidates)
}

function Save-PscxReleaseAsset {
    param(
        [Parameter(Mandatory)][object] $Candidate,
        [Parameter(Mandatory)][string] $Destination
    )

    $archivePath = Join-Path $Destination $Candidate.ZipAsset.name
    $checksumPath = Join-Path $Destination $Candidate.ChecksumAsset.name
    $headers = @{ 'User-Agent' = 'Pscx-Update-Script' }
    try {
        Invoke-WebRequest -Uri $Candidate.ZipAsset.browser_download_url -Headers $headers `
            -OutFile $archivePath -ErrorAction Stop
        Invoke-WebRequest -Uri $Candidate.ChecksumAsset.browser_download_url -Headers $headers `
            -OutFile $checksumPath -ErrorAction Stop
    }
    catch {
        throw "Could not download PSCX $($Candidate.Version.Text) release assets. Check network, proxy, and GitHub availability. $($_.Exception.Message)"
    }
    return [pscustomobject]@{ ArchivePath = $archivePath; ChecksumPath = $checksumPath }
}

function Test-PscxReleaseChecksum {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $ArchivePath,
        [Parameter(Mandatory)][string] $ChecksumPath
    )

    $archiveName = [IO.Path]::GetFileName($ArchivePath)
    $matchingLines = @(
        Get-Content -LiteralPath $ChecksumPath |
            ForEach-Object {
                if ($_ -match '^(?<hash>[0-9A-Fa-f]{64})\s+\*?(?<name>.+?)\s*$' -and
                    $Matches.name -eq $archiveName) {
                    $Matches.hash.ToLowerInvariant()
                }
            }
    )
    if ($matchingLines.Count -ne 1) {
        throw "Checksum asset must contain exactly one SHA-256 entry for '$archiveName'."
    }
    $actual = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $matchingLines[0]) {
        throw "SHA-256 verification failed for '$archiveName'. The package was not installed."
    }
    return $true
}

function Test-PscxArchiveEntryPath {
    param(
        [Parameter(Mandatory)][string] $EntryName,
        [Parameter(Mandatory)][string] $DestinationRoot
    )

    $normalized = $EntryName.Replace('\', '/')
    if ([string]::IsNullOrWhiteSpace($normalized) -or
        $normalized.StartsWith('/') -or
        $normalized -match '^[A-Za-z]:' -or
        [IO.Path]::IsPathRooted($normalized)) {
        throw "The release archive contains a rooted or empty path: '$EntryName'."
    }
    $segments = @($normalized -split '/' | Where-Object Length -GT 0)
    if ($segments.Count -eq 0 -or $segments -contains '..' -or $segments -contains '.') {
        throw "The release archive contains an unsafe path: '$EntryName'."
    }

    $root = [IO.Path]::GetFullPath($DestinationRoot).TrimEnd('\', '/')
    $target = [IO.Path]::GetFullPath((Join-Path $root ($segments -join [IO.Path]::DirectorySeparatorChar)))
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $target.StartsWith("$root$([IO.Path]::DirectorySeparatorChar)", $comparison)) {
        throw "The release archive path escapes its extraction directory: '$EntryName'."
    }
    return [pscustomobject]@{ NormalizedName = $segments -join '/'; TargetPath = $target }
}

function Expand-PscxSafeArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $ArchivePath,
        [Parameter(Mandatory)][string] $DestinationPath
    )

    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        if ($archive.Entries.Count -gt 10000) {
            throw "The release archive contains too many entries ($($archive.Entries.Count))."
        }
        $expandedLength = [long]0
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $validatedEntries = [Collections.Generic.List[object]]::new()
        foreach ($entry in $archive.Entries) {
            $path = Test-PscxArchiveEntryPath -EntryName $entry.FullName -DestinationRoot $DestinationPath
            if (-not $seen.Add($path.NormalizedName)) {
                throw "The release archive contains a duplicate path: '$($entry.FullName)'."
            }
            $unixType = ($entry.ExternalAttributes -shr 16) -band 0xF000
            $dosAttributes = $entry.ExternalAttributes -band 0xFFFF
            if ($unixType -eq 0xA000 -or
                ($dosAttributes -band [int][IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "The release archive contains a symbolic-link or reparse-point entry: '$($entry.FullName)'."
            }
            if ($entry.Length -gt 256MB) {
                throw "The release archive entry is unexpectedly large: '$($entry.FullName)'."
            }
            $expandedLength += $entry.Length
            if ($expandedLength -gt 512MB) {
                throw 'The release archive expands beyond the 512 MB safety limit.'
            }
            $validatedEntries.Add([pscustomobject]@{ Entry = $entry; Path = $path })
        }

        foreach ($validated in $validatedEntries) {
            $entry = $validated.Entry
            $targetPath = $validated.Path.TargetPath
            $isDirectory = $entry.FullName.EndsWith('/') -or [string]::IsNullOrEmpty($entry.Name)
            if ($isDirectory) {
                New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
                continue
            }
            $parent = Split-Path $targetPath -Parent
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
            $inputStream = $entry.Open()
            try {
                $outputStream = [IO.File]::Open(
                    $targetPath,
                    [IO.FileMode]::CreateNew,
                    [IO.FileAccess]::Write
                )
                try {
                    $inputStream.CopyTo($outputStream)
                }
                finally {
                    $outputStream.Dispose()
                }
            }
            finally {
                $inputStream.Dispose()
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}

function Get-PscxManifestSemanticVersion {
    param([Parameter(Mandatory)][hashtable] $Manifest)

    $core = ([version]$Manifest.ModuleVersion).ToString(3)
    $prerelease = $Manifest.PrivateData.PSData.Prerelease
    if (-not [string]::IsNullOrWhiteSpace($prerelease)) {
        return ConvertFrom-PscxSemanticVersion -Version "$core-$prerelease"
    }
    return ConvertFrom-PscxSemanticVersion -Version $core
}

function Test-PscxPackageCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $PackageRoot,
        [Parameter(Mandatory)][object] $ExpectedVersion
    )

    $directories = @(Get-ChildItem -LiteralPath $PackageRoot -Directory)
    $rootFiles = @(Get-ChildItem -LiteralPath $PackageRoot -File)
    if ($rootFiles.Count -gt 0) {
        throw "The release archive contains unexpected files at its installation root: $($rootFiles.Name -join ', ')."
    }
    $unexpected = @($directories.Name | Where-Object { $_ -notin $script:PscxPackageRoots })
    if ($unexpected.Count -gt 0) {
        throw "The release archive contains unexpected module roots: $($unexpected -join ', ')."
    }
    foreach ($requiredRoot in $script:PscxRequiredPackageRoots) {
        if ($requiredRoot -notin $directories.Name) {
            throw "The release archive is missing the required '$requiredRoot' module root."
        }
    }

    $modules = [Collections.Generic.List[object]]::new()
    foreach ($directory in $directories) {
        $moduleRootFiles = @(Get-ChildItem -LiteralPath $directory.FullName -File)
        if ($moduleRootFiles.Count -gt 0) {
            throw "The '$($directory.Name)' module contains files outside its version directory: $($moduleRootFiles.Name -join ', ')."
        }
        $expectedVersionDirectory = $ExpectedVersion.Core.ToString(3)
        $versionDirectories = @(Get-ChildItem -LiteralPath $directory.FullName -Directory)
        if ($versionDirectories.Count -ne 1 -or $versionDirectories[0].Name -ne $expectedVersionDirectory) {
            throw "The '$($directory.Name)' module must contain exactly the '$expectedVersionDirectory' version directory."
        }
        $versionRoot = $versionDirectories[0].FullName
        $manifestPath = Join-Path $versionRoot "$($directory.Name).psd1"
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            throw "The '$($directory.Name)' module has no manifest in its version directory."
        }
        try {
            $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
        }
        catch {
            throw "The '$($directory.Name)' manifest could not be read safely: $($_.Exception.Message)"
        }
        $manifestVersion = Get-PscxManifestSemanticVersion -Manifest $manifest
        if ((Compare-PscxSemanticVersion -Left $manifestVersion -Right $ExpectedVersion) -ne 0) {
            throw "The '$($directory.Name)' manifest version '$($manifestVersion.Text)' does not match release '$($ExpectedVersion.Text)'."
        }
        if ($directory.Name -eq 'Pscx' -and [guid]$manifest.GUID -ne $script:PscxManifestGuid) {
            throw "The release archive has an unexpected Pscx module GUID '$($manifest.GUID)'."
        }
        $modules.Add([pscustomobject]@{
                Name = $directory.Name
                SourcePath = $versionRoot
                ManifestPath = $manifestPath
            })
    }

    $mainManifest = Import-PowerShellDataFile -LiteralPath (
        $modules.Where({ $_.Name -eq 'Pscx' }, 'First')[0].ManifestPath
    )
    $requiredPowerShell = [version]$mainManifest.PowerShellVersion
    $compatible = $PSVersionTable.PSEdition -eq 'Core' -and
        $PSVersionTable.PSVersion -ge $requiredPowerShell
    $reason = if ($PSVersionTable.PSEdition -ne 'Core') {
        'PSCX requires PowerShell Core.'
    }
    elseif ($PSVersionTable.PSVersion -lt $requiredPowerShell) {
        "PSCX $($ExpectedVersion.Text) requires PowerShell $requiredPowerShell or later; this session is $($PSVersionTable.PSVersion)."
    }
    else {
        $null
    }

    return [pscustomobject]@{
        Compatible = $compatible
        IncompatibilityReason = $reason
        Version = $ExpectedVersion
        ModuleVersion = ([version]$mainManifest.ModuleVersion).ToString(3)
        RequiredPowerShellVersion = $requiredPowerShell
        Modules = @($modules)
    }
}

function Get-PscxDefaultModuleRoot {
    if ($IsWindows) {
        $documents = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
        if ([string]::IsNullOrWhiteSpace($documents)) {
            throw 'Could not resolve the current-user Documents directory. Specify DestinationRoot explicitly.'
        }
        return Join-Path $documents 'PowerShell/Modules'
    }
    if ([string]::IsNullOrWhiteSpace($HOME)) {
        throw 'Could not resolve the current-user home directory. Specify DestinationRoot explicitly.'
    }
    return Join-Path $HOME '.local/share/powershell/Modules'
}

function Test-PscxManagedInstallTarget {
    param(
        [Parameter(Mandatory)][string] $DestinationRoot,
        [Parameter(Mandatory)][string] $RelativePath
    )

    $normalized = $RelativePath.Replace('\', '/')
    $segments = @($normalized -split '/')
    if ($segments.Count -ne 2 -or
        $segments[0] -notin $script:PscxPackageRoots -or
        $segments[1] -notmatch '^\d+\.\d+\.\d+$') {
        throw "The interrupted-install journal contains an unsafe target '$RelativePath'."
    }
    $root = [IO.Path]::GetFullPath($DestinationRoot).TrimEnd('\', '/')
    $target = [IO.Path]::GetFullPath((Join-Path $root $RelativePath))
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $target.StartsWith("$root$([IO.Path]::DirectorySeparatorChar)", $comparison)) {
        throw "The interrupted-install target escapes DestinationRoot: '$RelativePath'."
    }
    return $target
}

function Repair-PscxInterruptedInstall {
    param([Parameter(Mandatory)][string] $DestinationRoot)

    if (-not (Test-Path -LiteralPath $DestinationRoot -PathType Container)) {
        return
    }
    $transactions = @(
        Get-ChildItem -LiteralPath $DestinationRoot -Directory -Force -Filter '.pscx-install-*'
    )
    foreach ($transaction in $transactions) {
        if ($transaction.Name -notmatch '^\.pscx-install-[0-9a-f]{32}$') {
            continue
        }
        $journalPath = Join-Path $transaction.FullName 'transaction.json'
        if (-not (Test-Path -LiteralPath $journalPath -PathType Leaf)) {
            throw "An incomplete PSCX installation staging directory requires manual review: $($transaction.FullName)"
        }
        try {
            $journal = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "An interrupted PSCX installation journal is invalid: $journalPath"
        }
        $targets = @(
            $journal.Targets | ForEach-Object {
                Test-PscxManagedInstallTarget -DestinationRoot $DestinationRoot -RelativePath $_
            }
        )
        if ($journal.State -eq 'Committing') {
            foreach ($target in $targets) {
                if (Test-Path -LiteralPath $target) {
                    Remove-Item -LiteralPath $target -Recurse -Force
                }
            }
        }
        elseif ($journal.State -ne 'Complete') {
            throw "An interrupted PSCX installation has an unknown state '$($journal.State)': $journalPath"
        }
        Remove-Item -LiteralPath $transaction.FullName -Recurse -Force
    }
}

function Write-PscxTransactionJournal {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][ValidateSet('Committing', 'Complete')][string] $State,
        [Parameter(Mandatory)][string[]] $Target
    )

    [ordered]@{ State = $State; Targets = $Target } | ConvertTo-Json |
        Set-Content -LiteralPath $Path -Encoding utf8
}

function Install-PscxPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object] $Package,
        [Parameter(Mandatory)][string] $DestinationRoot
    )

    $destination = [IO.Path]::GetFullPath($DestinationRoot)
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Repair-PscxInterruptedInstall -DestinationRoot $destination
    $modules = @($Package.Modules | Where-Object { $_.Name -ne 'Pscx.WinAdmin' -or $IsWindows })
    $relativeTargets = @($modules | ForEach-Object { "$($_.Name)/$($Package.ModuleVersion)" })
    $finalTargets = @(
        $relativeTargets | ForEach-Object {
            Test-PscxManagedInstallTarget -DestinationRoot $destination -RelativePath $_
        }
    )
    foreach ($target in $finalTargets) {
        if (Test-Path -LiteralPath $target) {
            throw "PSCX will not overwrite the existing module version directory '$target'. Remove it only through a separate explicit rollback/cleanup decision."
        }
    }

    $transactionRoot = Join-Path $destination ('.pscx-install-' + [guid]::NewGuid().ToString('N'))
    $journalPath = Join-Path $transactionRoot 'transaction.json'
    $installed = [Collections.Generic.List[string]]::new()
    $createdParents = [Collections.Generic.List[string]]::new()
    $preserveTransaction = $false
    try {
        New-Item -ItemType Directory -Path $transactionRoot -Force | Out-Null
        for ($index = 0; $index -lt $modules.Count; $index++) {
            $stageVersion = Join-Path $transactionRoot $relativeTargets[$index]
            New-Item -ItemType Directory -Path $stageVersion -Force | Out-Null
            Get-ChildItem -LiteralPath $modules[$index].SourcePath -Force |
                Copy-Item -Destination $stageVersion -Recurse -Force
        }
        Write-PscxTransactionJournal -Path $journalPath -State Committing -Target $relativeTargets

        for ($index = 0; $index -lt $modules.Count; $index++) {
            $moduleParent = Split-Path $finalTargets[$index] -Parent
            if (-not (Test-Path -LiteralPath $moduleParent)) {
                New-Item -ItemType Directory -Path $moduleParent -Force | Out-Null
                $createdParents.Add($moduleParent)
            }
            $stageVersion = Join-Path $transactionRoot $relativeTargets[$index]
            Move-Item -LiteralPath $stageVersion -Destination $finalTargets[$index]
            $installed.Add($finalTargets[$index])
        }
        Write-PscxTransactionJournal -Path $journalPath -State Complete -Target $relativeTargets
    }
    catch {
        $installError = $_
        $rollbackErrors = [Collections.Generic.List[string]]::new()
        foreach ($target in $installed) {
            try {
                if (Test-Path -LiteralPath $target) {
                    Remove-Item -LiteralPath $target -Recurse -Force
                }
            }
            catch {
                $rollbackErrors.Add($_.Exception.Message)
            }
        }
        if ($rollbackErrors.Count -gt 0) {
            $preserveTransaction = $true
            throw "PSCX installation failed and rollback was incomplete. Review '$transactionRoot' and these targets: $($installed -join ', '). Rollback errors: $($rollbackErrors -join '; '). Original error: $($installError.Exception.Message)"
        }
        throw "PSCX installation failed; all newly installed version directories were rolled back. Confirm that DestinationRoot is writable and try again. $($installError.Exception.Message)"
    }
    finally {
        if (-not $preserveTransaction -and (Test-Path -LiteralPath $transactionRoot)) {
            Remove-Item -LiteralPath $transactionRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        foreach ($parent in $createdParents) {
            if ((Test-Path -LiteralPath $parent) -and
                @(Get-ChildItem -LiteralPath $parent -Force).Count -eq 0) {
                Remove-Item -LiteralPath $parent -Force -ErrorAction SilentlyContinue
            }
        }
    }
    return @($installed)
}

function ConvertTo-PscxUpdateResult {
    param(
        [Parameter(Mandatory)][string] $Status,
        [AllowNull()][string] $CurrentVersion,
        [AllowNull()][string] $AvailableVersion,
        [AllowNull()][uri] $ReleaseNotesUri,
        [AllowNull()][string] $DestinationRoot,
        [string[]] $InstalledPath = @(),
        [AllowNull()][string] $ImportCommand,
        [Parameter(Mandatory)][string] $Message
    )

    $result = [pscustomobject]@{
        Status = $Status
        CurrentVersion = $CurrentVersion
        AvailableVersion = $AvailableVersion
        ReleaseNotesUri = $ReleaseNotesUri
        DestinationRoot = $DestinationRoot
        InstalledPath = $InstalledPath
        ImportCommand = $ImportCommand
        Message = $Message
    }
    $result.PSObject.TypeNames.Insert(0, 'Pscx.UpdateResult')
    return $result
}

function Invoke-PscxUpdate {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [switch] $CheckOnly,
        [switch] $IncludePrerelease,
        [ValidateNotNullOrEmpty()][string] $DestinationRoot = (Get-PscxDefaultModuleRoot)
    )

    $installedVersions = @(Get-PscxInstalledVersion)
    $current = if ($installedVersions.Count -gt 0) {
        (Select-PscxSemanticVersionDescending -InputObject @(
                $installedVersions | ForEach-Object {
                    [pscustomobject]@{ Version = $_.Version; Installed = $_ }
                }
            ))[0].Version
    }
    else {
        $null
    }

    $releases = Get-PscxGitHubRelease
    $candidates = @(Select-PscxRelease -Release $releases -IncludePrerelease:$IncludePrerelease)
    $newerCandidates = @(
        $candidates | Where-Object {
            $null -eq $current -or
            (Compare-PscxSemanticVersion -Left $_.Version -Right $current) -gt 0
        }
    )
    if ($newerCandidates.Count -eq 0) {
        $currentText = if ($null -ne $current) { $current.Text } else { $null }
        return ConvertTo-PscxUpdateResult -Status Current -CurrentVersion $currentText `
            -AvailableVersion $currentText -ReleaseNotesUri $null -DestinationRoot $DestinationRoot `
            -ImportCommand $null -Message 'No newer PSCX release is available under the selected release policy.'
    }

    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) (
        'Pscx.Update.{0}' -f [guid]::NewGuid().ToString('N')
    )
    $selectedCandidate = $null
    $selectedPackage = $null
    try {
        New-Item -ItemType Directory -Path $temporaryRoot -Force -WhatIf:$false | Out-Null
        foreach ($candidate in $newerCandidates) {
            $candidateRoot = Join-Path $temporaryRoot $candidate.Version.Text
            $extractRoot = Join-Path $candidateRoot 'expanded'
            New-Item -ItemType Directory -Path $candidateRoot -Force -WhatIf:$false | Out-Null
            $assets = Save-PscxReleaseAsset -Candidate $candidate -Destination $candidateRoot
            Test-PscxReleaseChecksum -ArchivePath $assets.ArchivePath `
                -ChecksumPath $assets.ChecksumPath | Out-Null
            Expand-PscxSafeArchive -ArchivePath $assets.ArchivePath -DestinationPath $extractRoot
            $package = Test-PscxPackageCandidate -PackageRoot $extractRoot `
                -ExpectedVersion $candidate.Version
            if ($package.Compatible) {
                $selectedCandidate = $candidate
                $selectedPackage = $package
                break
            }
            Write-Warning $package.IncompatibilityReason
        }

        $currentText = if ($null -ne $current) { $current.Text } else { $null }
        if ($null -eq $selectedCandidate) {
            return ConvertTo-PscxUpdateResult -Status NoCompatibleRelease -CurrentVersion $currentText `
                -AvailableVersion $null -ReleaseNotesUri $null -DestinationRoot $DestinationRoot `
                -ImportCommand $null -Message 'Newer releases exist, but none are compatible with this PowerShell runtime.'
        }
        $availableText = $selectedCandidate.Version.Text
        $importCommand = "Import-Module Pscx -RequiredVersion $($selectedPackage.ModuleVersion) -Force"
        if ($CheckOnly) {
            return ConvertTo-PscxUpdateResult -Status UpdateAvailable -CurrentVersion $currentText `
                -AvailableVersion $availableText -ReleaseNotesUri $selectedCandidate.ReleaseNotesUri `
                -DestinationRoot $DestinationRoot -ImportCommand $importCommand `
                -Message "PSCX $availableText is compatible and available."
        }

        $action = "Install PSCX $availableText side by side; keep all existing versions"
        if (-not $PSCmdlet.ShouldProcess($DestinationRoot, $action)) {
            $status = if ($WhatIfPreference) { 'WouldInstall' } else { 'Declined' }
            return ConvertTo-PscxUpdateResult -Status $status -CurrentVersion $currentText `
                -AvailableVersion $availableText -ReleaseNotesUri $selectedCandidate.ReleaseNotesUri `
                -DestinationRoot $DestinationRoot -ImportCommand $importCommand `
                -Message "PSCX $availableText was validated but not installed."
        }

        $installedPaths = @(Install-PscxPackage -Package $selectedPackage -DestinationRoot $DestinationRoot)
        return ConvertTo-PscxUpdateResult -Status Installed -CurrentVersion $currentText `
            -AvailableVersion $availableText -ReleaseNotesUri $selectedCandidate.ReleaseNotesUri `
            -DestinationRoot $DestinationRoot -InstalledPath $installedPaths `
            -ImportCommand $importCommand -Message "PSCX $availableText was installed. Existing versions were retained."
    }
    finally {
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -WhatIf:$false `
                -ErrorAction SilentlyContinue
        }
    }
}

Export-ModuleMember -Function Invoke-PscxUpdate

# SIG # Begin signature block
# MIInmgYJKoZIhvcNAQcCoIInizCCJ4cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAc7qYYk0up0VFL
# HHrAX5qZwCVlwUiI5E1h1WX/Ovodq6CCIHEwggWNMIIEdaADAgECAhAOmxiO+dAt
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
# EA+8hcpSM9LHJmyrxaFtoza2zNaQ9k+5t1wwggbtMIIE1aADAgECAhAKgO8YS43x
# BYLRxHanlXRoMA0GCSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQK
# Ew5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBU
# aW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwHhcNMjUwNjA0MDAw
# MDAwWhcNMzYwOTAzMjM1OTU5WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGln
# aUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFNIQTI1NiBSU0E0MDk2IFRp
# bWVzdGFtcCBSZXNwb25kZXIgMjAyNSAxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEA0EasLRLGntDqrmBWsytXum9R/4ZwCgHfyjfMGUIwYzKomd8U1nH7
# C8Dr0cVMF3BsfAFI54um8+dnxk36+jx0Tb+k+87H9WPxNyFPJIDZHhAqlUPt281m
# HrBbZHqRK71Em3/hCGC5KyyneqiZ7syvFXJ9A72wzHpkBaMUNg7MOLxI6E9RaUue
# HTQKWXymOtRwJXcrcTTPPT2V1D/+cFllESviH8YjoPFvZSjKs3SKO1QNUdFd2adw
# 44wDcKgH+JRJE5Qg0NP3yiSyi5MxgU6cehGHr7zou1znOM8odbkqoK+lJ25LCHBS
# ai25CFyD23DZgPfDrJJJK77epTwMP6eKA0kWa3osAe8fcpK40uhktzUd/Yk0xUvh
# DU6lvJukx7jphx40DQt82yepyekl4i0r8OEps/FNO4ahfvAk12hE5FVs9HVVWcO5
# J4dVmVzix4A77p3awLbr89A90/nWGjXMGn7FQhmSlIUDy9Z2hSgctaepZTd0ILIU
# bWuhKuAeNIeWrzHKYueMJtItnj2Q+aTyLLKLM0MheP/9w6CtjuuVHJOVoIJ/DtpJ
# RE7Ce7vMRHoRon4CWIvuiNN1Lk9Y+xZ66lazs2kKFSTnnkrT3pXWETTJkhd76CID
# BbTRofOsNyEhzZtCGmnQigpFHti58CSmvEyJcAlDVcKacJ+A9/z7eacCAwEAAaOC
# AZUwggGRMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFOQ7/PIx7f391/ORcWMZUEPP
# YYzoMB8GA1UdIwQYMBaAFO9vU0rp5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB/wQE
# AwIHgDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgwgYUw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEFBQcw
# AoZRaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0
# VGltZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRYMFYw
# VKBSoFCGTmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRH
# NFRpbWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAEGTAX
# MAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBAGUqrfEc
# JwS5rmBB7NEIRJ5jQHIh+OT2Ik/bNYulCrVvhREafBYF0RkP2AGr181o2YWPoSHz
# 9iZEN/FPsLSTwVQWo2H62yGBvg7ouCODwrx6ULj6hYKqdT8wv2UV+Kbz/3ImZlJ7
# YXwBD9R0oU62PtgxOao872bOySCILdBghQ/ZLcdC8cbUUO75ZSpbh1oipOhcUT8l
# D8QAGB9lctZTTOJM3pHfKBAEcxQFoHlt2s9sXoxFizTeHihsQyfFg5fxUFEp7W42
# fNBVN4ueLaceRf9Cq9ec1v5iQMWTFQa0xNqItH3CPFTG7aEQJmmrJTV3Qhtfparz
# +BW60OiMEgV5GWoBy4RVPRwqxv7Mk0Sy4QHs7v9y69NBqycz0BZwhB9WOfOu/CIJ
# nzkQTwtSSpGGhLdjnQ4eBpjtP+XB3pQCtv4E5UCSDag6+iX8MmB10nfldPF9SVD7
# weCC3yXZi/uuhqdwkgVxuiMFzGVFwYbQsiGnoa9F5AaAyBjFBtXVLcKtapnMG3VH
# 3EmAp/jsJ3FVF3+d1SVDTmjFjLbNFZUWMXuZyvgLfgyPehwJVxwC+UpX2MSey2ue
# Iu9THFVkT+um1vshETaWyQo8gmBto/m3acaP9QsuLj3FNwFlTxq25+T4QwX9xa6I
# Ls84ZPvmpovq90K8eWyG2N01c4IhSOxqt81nMYIGfzCCBnsCAQEwgaIwgZUxCzAJ
# BgNVBAYTAlVTMQswCQYDVQQIEwJNTjEUMBIGA1UEBxMLTWlubmVhcG9saXMxEjAQ
# BgNVBAoTCUx1Y2EgSG9tZTEPMA0GA1UECxMGT2ZmaWNlMRowGAYDVQQDExFMdWNh
# cyBDb2RlIFJTQSBDQTEiMCAGCSqGSIb3DQEJARYTZGFubHVjYUBjb21jYXN0Lm5l
# dAIIBtflh7Az5TYwDQYJYIZIAWUDBAIBBQCggYQwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFjAvBgkqhkiG9w0BCQQxIgQgB9iJIV5Xop5kGkDixEbl
# 99mEDDYK+kRrHPmwwM1L7t8wDQYJKoZIhvcNAQEBBQAEggIAPHJ4gIHn5l4OLI4H
# k4dFdglnQkE1wj3/voVqLxNn1BAfoqbvVI9485cYc4nLSE5F67I+yo/6CYIjzsAQ
# k9mVmghDdK+3QRZYPBigv6BZlAM5bn2459tc6/JAgO9wygssBAZqLiSaPykwexYN
# EmXGg8PajcvFfntVXLikViD7bZJ2abLQxVDzYr7+7wI8xrfJu2GQqh/46pXknpgp
# n8ZtN8wO3+y48mRrISZkbDJlhaL3mvYRmA2RTwjQv0TczH39ki2nk8ljgGNtIwiD
# ZSK2Ej+c6tNYt/Kdvgk3VcSJjyPhUZAKUm+pHiVottbdeIbCpdRY6C6EvTaCRFd3
# qnZDo7fltX8G8PhLgWpyuu5/i/9pJyo38dMkzUleSgwH3Wl/yZk0gRMnDs9RLJQx
# I0NOdLiy6jLDLab+CDkXvyFwhMEBvI+8nVDJGVZtQSpAcrOdv9jqIVegfhRp9u4K
# X+1b6DBXQDySjFzpDs1xvyhOIGd66UXADdK13UZjyR+nwoI931H3bq66gHE6/NYX
# xVoQxlTTzAmAbnUWa3hMiFCFZbV/Bn+aHTEmnQ6bvG+y9Lj+aD3P6NqrT1E7H8ey
# tmRo0kgXpbOLpang4M1HUrZ1H1uOdCqGyenkk1wlknzCn8tnyeZWbPJdzKlnRqKP
# nlY+LvP3C+fV+e+mdTN00QHuM5KhggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8C
# AQEwfTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/
# BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYg
# U0hBMjU2IDIwMjUgQ0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUA
# oGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYw
# ODI5MDM1MzM4WjAvBgkqhkiG9w0BCQQxIgQgS6u0QRliVmNfSPYkEZgeRYUv9SRZ
# RInneidziv6SB1kwDQYJKoZIhvcNAQEBBQAEggIAyaKN0iufoXRTiFeBmYBMDl1L
# SJrXAIudTk48RkH5y0DwjnjpCBqzXs4GCyFkjUw9A+BZcWNLFVkjN+4Ub+Qe3cKU
# OUhQI9BnrfJ9aIs8wp+Nd2oWjxPbHugR9nwfcowexsC3MbtauL++qwOxg7lXBQ60
# bFWB9M2PFdTjRrsvG5ZaoK0S2G7PYcG0MdEyDtr2RwY14rWcPTOPCMQw0ATjgnK6
# e17lN0bz7Nd1kHQSkOp9Z7XWrIHueISMvRwbwJV69zojlDKiUb33odJNnGz62iFj
# /e4p3LTOd4c/Be82tn31LtpnUK3GkZbOZxwaFSsiDy+rIWkeGp54QUi8+nmbKHx7
# lKr/7ZSdFoFVH7ISfPhM5NcEiVkOL9Y6W52t1EzBw6n/wQVcVOq9JoVImDaOYbjZ
# 5BqJOdvBJK50ezHFxtZiJB1hAG4QcDvXJxeCRNvRauDZ3NZWCExiisb8PYWlWHGC
# xI43vjFcKyhXaE2DLc4eMRGaKX310vMYw1uEnZ1YfRzwwLZIVX+XDiJzlXKqdIsp
# biKT8Xe0YOr++9u9WqC6Etf9iRxWE8h5NLgHiOgVydfCl2jidBPReDaf6r7u3uNu
# w+CcWpjfWsY1ph9p6XgM57NmtrcKSPRcWIPwiTy2tybW4p6btVevhdIBK8GBLTRN
# izurzBa6SotB6GMfgk4=
# SIG # End signature block
