pushd $PSScriptRoot

trap {
    popd
    Write-Error "An error occurred during the local install process."
    Write-Error $_.Exception.Message
    exit 1
}

Write-Host "Building and packaging PSCX modules for local install..." -ForegroundColor Blue
Write-Host "Ensure no Posh sessions are running with PSCX module loaded..." -ForegroundColor Yellow

$commit = git rev-parse --short HEAD
../build.ps1 -Task Package -Configuration Release -BuildNumber 0 -CommitSha $commit -Release

$modules = @(
    "Pscx",
    "Pscx.Archive",
    "Pscx.Time",
    "Pscx.WinAdmin"
)
$paths = @(
    "$env:USERPROFILE\Documents\PowerShell\Modules",
    "$env:USERPROFILE\OneDrive\Documents\PowerShell\Modules"
)

$paths | ForEach-Object {
    $path = $_
    $modules | ForEach-Object {
        $module = $_
        if (get-module -Name $module) {
            Write-Host "Unloading existing $module module..." -ForegroundColor Yellow
            Remove-Module -Name $module -Force
        }

        if (Test-Path "$path\$module\4.0.0") {
            Write-Host "Removing $path\$module\4.0.0"
            Remove-Item "$path\$module\4.0.0\*" -Recurse -Force
        } else {
            Write-Host "Creating $path\$module\4.0.0"
            New-Item -ItemType Directory -Path "$path\$module\4.0.0" | Out-Null
        }
        Write-Host "Copying $module to $path\$module\4.0.0"
        Copy-Item "../artifacts/module/$module/*" "$path\$module\4.0.0\" -Recurse -Force
    }
}

Write-Host "Local install complete. You may need to restart your PowerShell session for changes to take effect." -ForegroundColor Green

popd