[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Split-Path -Parent $PSScriptRoot),

    [string] $PackageRoot,

    [switch] $ExpectedWindowsPayload,

    [switch] $CheckUpdates,

    [switch] $FailWhenUpdateAvailable,

    [string] $ResultsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::PlainText

function Get-NormalizedRelativePath {
    param(
        [Parameter(Mandatory)]
        [string] $BasePath,

        [Parameter(Mandatory)]
        [string] $Path
    )

    [IO.Path]::GetRelativePath($BasePath, $Path).Replace('\', '/')
}

$repositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$inventoryPath = Join-Path $repositoryRoot 'Imports/REDISTRIBUTED_BINARIES.psd1'
$inventory = Import-PowerShellDataFile -LiteralPath $inventoryPath
if ($inventory.SchemaVersion -ne 1) {
    throw "Unsupported redistributed-binary inventory schema '$($inventory.SchemaVersion)'."
}

$errors = [Collections.Generic.List[string]]::new()
$artifactResults = [Collections.Generic.List[object]]::new()
$updateResults = [Collections.Generic.List[object]]::new()
$sourcePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$packagePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

foreach ($component in $inventory.Components) {
    foreach ($field in 'Name', 'Version', 'License', 'LicensePaths', 'PackageLicensePaths',
        'SourceUri', 'LatestReleaseApiUri', 'ExpectedReleaseTag', 'UpdateOwner', 'Purpose',
        'Artifacts') {
        if (-not $component[$field]) {
            $errors.Add("Redistributed component is missing required field '$field'.")
        }
    }

    foreach ($licensePath in $component.LicensePaths) {
        if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $licensePath) -PathType Leaf)) {
            $errors.Add("$($component.Name) license is missing: $licensePath")
        }
    }

    if ($PackageRoot) {
        foreach ($packageLicensePath in $component.PackageLicensePaths) {
            $fullPackageLicensePath = Join-Path $PackageRoot $packageLicensePath
            if ($ExpectedWindowsPayload -and
                -not (Test-Path -LiteralPath $fullPackageLicensePath -PathType Leaf)) {
                $errors.Add("$($component.Name) package license is missing: $packageLicensePath")
            }
            elseif (-not $ExpectedWindowsPayload -and
                (Test-Path -LiteralPath $fullPackageLicensePath)) {
                $errors.Add("Core package unexpectedly contains Windows license: $packageLicensePath")
            }
        }
    }

    foreach ($artifact in $component.Artifacts) {
        foreach ($field in 'SourcePath', 'Architecture', 'PackagePaths', 'Size', 'Sha256',
            'SignatureStatus') {
            if ($null -eq $artifact[$field] -or $artifact[$field] -eq '') {
                $errors.Add("$($component.Name) artifact is missing required field '$field'.")
            }
        }
        $sourcePath = [string]$artifact.SourcePath
        $null = $sourcePaths.Add($sourcePath)
        $fullSourcePath = Join-Path $repositoryRoot $sourcePath
        if (-not (Test-Path -LiteralPath $fullSourcePath -PathType Leaf)) {
            $errors.Add("Redistributed source is missing: $sourcePath")
            continue
        }

        $file = Get-Item -LiteralPath $fullSourcePath
        $actualHash = (Get-FileHash -LiteralPath $fullSourcePath -Algorithm SHA256).Hash
        if ($file.Length -ne [long]$artifact.Size) {
            $errors.Add("$sourcePath size is $($file.Length); expected $($artifact.Size).")
        }
        if ($actualHash -ne $artifact.Sha256) {
            $errors.Add("$sourcePath SHA-256 is $actualHash; expected $($artifact.Sha256).")
        }

        $signatureStatus = 'NotChecked'
        $signerThumbprint = $null
        if ($IsWindows) {
            $signature = Get-AuthenticodeSignature -LiteralPath $fullSourcePath
            $signatureStatus = $signature.Status.ToString()
            $signerThumbprint = if ($signature.SignerCertificate) {
                $signature.SignerCertificate.Thumbprint
            }
            else {
                $null
            }
            if ($signatureStatus -ne $artifact.SignatureStatus) {
                $errors.Add(
                    "$sourcePath signature is $signatureStatus; expected $($artifact.SignatureStatus)."
                )
            }
            if ($artifact.SignerThumbprint -and
                $signerThumbprint -ne $artifact.SignerThumbprint) {
                $errors.Add("$sourcePath signer thumbprint is not the reviewed signer.")
            }
        }

        foreach ($packagePath in $artifact.PackagePaths) {
            $null = $packagePaths.Add([string]$packagePath)
            if (-not $PackageRoot) {
                continue
            }

            $fullPackagePath = Join-Path $PackageRoot $packagePath
            if ($ExpectedWindowsPayload) {
                if (-not (Test-Path -LiteralPath $fullPackagePath -PathType Leaf)) {
                    $errors.Add("Windows package payload is missing: $packagePath")
                    continue
                }
                $packageHash = (Get-FileHash -LiteralPath $fullPackagePath -Algorithm SHA256).Hash
                if ($packageHash -ne $artifact.Sha256) {
                    $errors.Add("Packaged $packagePath does not match its reviewed source hash.")
                }
            }
            elseif (Test-Path -LiteralPath $fullPackagePath) {
                $errors.Add("Core package unexpectedly contains Windows payload: $packagePath")
            }
        }

        $artifactResults.Add([ordered]@{
                Component = $component.Name
                Version = $component.Version
                SourcePath = $sourcePath
                Architecture = $artifact.Architecture
                Size = $file.Length
                Sha256 = $actualHash
                SignatureStatus = $signatureStatus
                SignerThumbprint = $signerThumbprint
                PackagePaths = @($artifact.PackagePaths)
            })
    }

    if ($CheckUpdates) {
        $headers = @{
            Accept = 'application/vnd.github+json'
            'User-Agent' = 'PSCX-third-party-audit'
            'X-GitHub-Api-Version' = '2022-11-28'
        }
        if ($env:GITHUB_TOKEN) {
            $headers.Authorization = "Bearer $($env:GITHUB_TOKEN)"
        }
        $release = Invoke-RestMethod -Uri $component.LatestReleaseApiUri -Headers $headers
        $latestTag = [string]$release.tag_name
        $updateAvailable = $latestTag -ne $component.ExpectedReleaseTag
        $updateResults.Add([ordered]@{
                Component = $component.Name
                CurrentVersion = $component.Version
                CurrentTag = $component.ExpectedReleaseTag
                LatestTag = $latestTag
                UpdateAvailable = $updateAvailable
                ReleaseUri = [string]$release.html_url
                UpdateOwner = $component.UpdateOwner
            })
        if ($updateAvailable) {
            Write-Warning "$($component.Name) is pinned to $($component.ExpectedReleaseTag); latest is $latestTag."
        }
    }
}

$committedImportPayloads = @(
    Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'Imports') -Recurse -File |
        Where-Object Extension -In '.exe', '.dll', '.zip', '.nupkg', '.7z' |
        ForEach-Object { Get-NormalizedRelativePath -BasePath $repositoryRoot -Path $_.FullName }
)
$unexpectedImportPayloads = @($committedImportPayloads | Where-Object { -not $sourcePaths.Contains($_) })
if ($unexpectedImportPayloads.Count -gt 0) {
    $errors.Add("Unreviewed binary/archive payloads exist under Imports: $($unexpectedImportPayloads -join ', ')")
}

$trackedOutput = @(& git -C $repositoryRoot ls-files -- Output)
if ($LASTEXITCODE -ne 0) {
    $errors.Add('Could not inspect tracked Output files with Git.')
}
elseif ($trackedOutput.Count -gt 0) {
    $errors.Add("Generated Output files must not be committed: $($trackedOutput -join ', ')")
}

$packageSummary = @()
if ($PackageRoot) {
    $packageRoot = [IO.Path]::GetFullPath($PackageRoot)
    $actualExecutables = @(
        Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Filter *.exe |
            ForEach-Object { Get-NormalizedRelativePath -BasePath $packageRoot -Path $_.FullName }
    )
    $expectedExecutables = if ($ExpectedWindowsPayload) { @($packagePaths) } else { @() }
    $unexpectedExecutables = @($actualExecutables | Where-Object { -not $packagePaths.Contains($_) })
    if ($unexpectedExecutables.Count -gt 0) {
        $errors.Add("Package contains unreviewed native executables: $($unexpectedExecutables -join ', ')")
    }
    $missingExecutables = @(
        $expectedExecutables | Where-Object { $_ -notin $actualExecutables }
    )
    if ($missingExecutables.Count -gt 0 -or $unexpectedExecutables.Count -gt 0) {
        $errors.Add('Packaged executable set does not match the redistributed-binary inventory.')
    }

    $packageSummary = @(
        Get-ChildItem -LiteralPath $packageRoot -Directory | Sort-Object Name | ForEach-Object {
            $files = @(Get-ChildItem -LiteralPath $_.FullName -Recurse -File)
            [ordered]@{
                Module = $_.Name
                FileCount = $files.Count
                UncompressedBytes = [long](($files | Measure-Object Length -Sum).Sum)
            }
        }
    )
}

$report = [ordered]@{
    Status = if ($errors.Count -eq 0) { 'Passed' } else { 'Failed' }
    InventorySchemaVersion = $inventory.SchemaVersion
    Artifacts = @($artifactResults)
    PackageModules = @($packageSummary)
    Updates = @($updateResults)
    Errors = @($errors)
}

if ($ResultsPath) {
    $resultsPath = [IO.Path]::GetFullPath($ResultsPath)
    New-Item -ItemType Directory -Path (Split-Path -Parent $resultsPath) -Force | Out-Null
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultsPath -Encoding utf8
    Write-Host "Redistributed-binary report: $resultsPath"
}

if ($errors.Count -gt 0) {
    throw "Redistributed-binary validation failed: $($errors -join ' | ')"
}
if ($FailWhenUpdateAvailable -and @($updateResults | Where-Object UpdateAvailable).Count -gt 0) {
    throw 'One or more redistributed third-party components have an update available.'
}

Write-Host "Validated $($artifactResults.Count) redistributed source binaries."
