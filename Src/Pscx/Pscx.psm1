# -----------------------------------------------------------------------
# Desc: This is the PSCX initialization module script that loads nested
#       modules.  Which nested modules are loaded is controlled via
#       $Pscx:Preferences.ModulesToImport.  You can override the default
#       settings by passing either a file containing the appropriate
#       settings in hashtable form as shown in Pscx.Options.ps1 or you
#       can pass in a hashtable with the appropriate settings directly.
# -----------------------------------------------------------------------
Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Returns the last lines of a file and can continue waiting for appended content.
.DESCRIPTION
    Provides the familiar PSCX command name while delegating to Get-Content with
    its modern Tail and Wait parameters.
.PARAMETER Path
    Specifies one or more paths. Wildcards are permitted.
.PARAMETER LiteralPath
    Specifies one or more paths exactly as written. Wildcards are not expanded.
.PARAMETER Count
    Specifies the number of lines returned from the end of each file. The default is 10.
.PARAMETER Wait
    Continues waiting for new content after returning the current tail.
.PARAMETER Encoding
    Specifies the file encoding accepted by Get-Content.
.EXAMPLE
    Get-FileTail -Path ./application.log -Count 20
.EXAMPLE
    Get-FileTail -Path ./application.log -Wait
#>
function Get-FileTail {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Path')]
        [SupportsWildcards()]
        [string[]] $Path,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'LiteralPath')]
        [Alias('PSPath')]
        [string[]] $LiteralPath,

        [Parameter()]
        [Alias('Tail')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Count = 10,

        [Parameter()]
        [Alias('Follow')]
        [switch] $Wait,

        [Parameter()]
        [string] $Encoding
    )

    process {
        $getContentParameters = @{
            Tail = $Count
            Wait = $Wait
        }
        if ($PSCmdlet.ParameterSetName -eq 'LiteralPath') {
            $getContentParameters.LiteralPath = $LiteralPath
        }
        else {
            $getContentParameters.Path = $Path
        }
        if ($PSBoundParameters.ContainsKey('Encoding')) {
            $getContentParameters.Encoding = $Encoding
        }

        Get-Content @getContentParameters
    }
}

<#
.SYNOPSIS
    Creates a filesystem hard link.
.DESCRIPTION
    Provides the familiar PSCX command name while delegating to New-Item with
    ItemType HardLink.
.PARAMETER LiteralPath
    Specifies the path of the link to create.
.PARAMETER TargetPath
    Specifies the existing file that the new link references.
.EXAMPLE
    New-Hardlink -LiteralPath ./copy.txt -TargetPath ./original.txt
#>
function New-Hardlink {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [Alias('Target', 'PSPath')]
        [ValidateNotNullOrEmpty()]
        [string] $TargetPath
    )

    process {
        if ($PSCmdlet.ShouldProcess($LiteralPath, "Create hard link to '$TargetPath'")) {
            New-Item -ItemType HardLink -Path $LiteralPath -Target $TargetPath -Confirm:$false
        }
    }
}

<#
.SYNOPSIS
    Creates a filesystem symbolic link.
.DESCRIPTION
    Provides the familiar PSCX command name while delegating to New-Item with
    ItemType SymbolicLink.
.PARAMETER LiteralPath
    Specifies the path of the link to create.
.PARAMETER TargetPath
    Specifies the file or directory that the new link references.
.EXAMPLE
    New-Symlink -LiteralPath ./current -TargetPath ./releases/latest
#>
function New-Symlink {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.IO.FileSystemInfo])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [Alias('Target', 'PSPath')]
        [ValidateNotNullOrEmpty()]
        [string] $TargetPath
    )

    process {
        if ($PSCmdlet.ShouldProcess($LiteralPath, "Create symbolic link to '$TargetPath'")) {
            New-Item -ItemType SymbolicLink -Path $LiteralPath -Target $TargetPath -Confirm:$false
        }
    }
}

<#
.SYNOPSIS
    Tests the health of the current PSCX installation.
.DESCRIPTION
    Reports structured diagnostics for the loaded PSCX version, the PowerShell
    and .NET runtimes, operating system and architecture, optional modules, editor
    and pager resolution, the archive backend, native tools, the module
    manifest, exported commands, and installed help.

    The command is observational. It does not import optional modules, execute
    native tools, access the network, or modify the session.
.EXAMPLE
    Test-PscxInstallation

    Displays a concise table containing all installation diagnostics.
.EXAMPLE
    Test-PscxInstallation | Where-Object Status -In Warning, Fail

    Returns only diagnostics that may require attention.
.OUTPUTS
    System.Management.Automation.PSCustomObject. Each object has the
    Pscx.InstallationDiagnostic type name.
#>
function Test-PscxInstallation {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $diagnostics = [Collections.Generic.List[object]]::new()

    function Add-PscxInstallationDiagnostic {
        param(
            [Parameter(Mandatory)]
            [ValidateSet('Environment', 'Modules', 'Tools', 'Package')]
            [string] $Category,

            [Parameter(Mandatory)]
            [string] $Name,

            [Parameter(Mandatory)]
            [ValidateSet('Pass', 'Warning', 'Fail', 'Info', 'NotApplicable')]
            [string] $Status,

            [AllowNull()]
            [object] $Value,

            [AllowNull()]
            [object] $Expected,

            [Parameter(Mandatory)]
            [string] $Message,

            [hashtable] $Details = @{}
        )

        $diagnostic = [pscustomobject]@{
            Category = $Category
            Name = $Name
            Status = $Status
            Value = $Value
            Expected = $Expected
            Message = $Message
            Details = $Details
        }
        $diagnostic.PSObject.TypeNames.Insert(0, 'Pscx.InstallationDiagnostic')
        [void] $diagnostics.Add($diagnostic)
    }

    function Resolve-PscxApplication {
        param([AllowNull()][object] $ConfiguredValue)

        if ($null -eq $ConfiguredValue) {
            return $null
        }

        $candidate = if ($ConfiguredValue -is [IO.FileInfo]) {
            $ConfiguredValue.FullName
        }
        else {
            $ConfiguredValue.ToString()
        }
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            return $null
        }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }

        $application = Get-Command -Name $candidate -CommandType Application `
            -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $application) {
            return $application.Source
        }
        return $null
    }

    function Find-PscxOptionalModuleManifest {
        param(
            [Parameter(Mandatory)]
            [string] $Name,

            [Parameter(Mandatory)]
            [version] $Version
        )

        $loadedModule = Get-Module -Name $Name -All | Select-Object -First 1
        if ($null -ne $loadedModule -and -not [string]::IsNullOrWhiteSpace($loadedModule.Path)) {
            return $loadedModule.Path
        }

        $moduleRoot = $PSScriptRoot
        $packageRoot = Split-Path $moduleRoot -Parent
        $candidates = @(
            (Join-Path $packageRoot "$Name\$Name.psd1")
            (Join-Path $packageRoot "$Name\$Version\$Name.psd1")
        )

        $moduleDirectoryName = Split-Path $moduleRoot -Leaf
        $moduleDirectoryVersion = $null
        if ([version]::TryParse($moduleDirectoryName, [ref] $moduleDirectoryVersion)) {
            $modulesRoot = Split-Path (Split-Path $moduleRoot -Parent) -Parent
            $candidates += Join-Path $modulesRoot "$Name\$Version\$Name.psd1"
        }

        foreach ($candidate in $candidates) {
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        }

        $availableModule = Get-Module -Name $Name -ListAvailable |
            Sort-Object Version -Descending | Select-Object -First 1
        if ($null -ne $availableModule -and -not [string]::IsNullOrWhiteSpace($availableModule.Path)) {
            return $availableModule.Path
        }
        return $null
    }

    $module = $ExecutionContext.SessionState.Module
    $manifestPath = Join-Path $PSScriptRoot 'Pscx.psd1'
    $manifestData = $null
    try {
        $manifestData = Import-PowerShellDataFile -LiteralPath $manifestPath
    }
    catch {
        # The dedicated manifest check below reports the actionable failure.
    }

    $prereleaseLabel = $module.PrivateData.PSData.Prerelease
    $pscxVersion = if ([string]::IsNullOrWhiteSpace($prereleaseLabel)) {
        $module.Version.ToString()
    }
    else {
        "$($module.Version)-$prereleaseLabel"
    }
    Add-PscxInstallationDiagnostic -Category Environment -Name 'PSCX version' `
        -Status Pass -Value $pscxVersion -Expected $pscxVersion `
        -Message "PSCX $pscxVersion is loaded from $PSScriptRoot." `
        -Details @{
            ModulePath = $module.Path
            ModuleBase = $module.ModuleBase
            ModuleVersion = $module.Version
            Prerelease = $prereleaseLabel
        }

    $requiredPowerShellVersion = if ($null -ne $manifestData) {
        [version] $manifestData.PowerShellVersion
    }
    else {
        [version] '0.0'
    }
    $powerShellStatus = if ($PSVersionTable.PSVersion -lt $requiredPowerShellVersion) {
        'Fail'
    }
    elseif ($PSVersionTable.PSVersion.Major -ne $requiredPowerShellVersion.Major -or
        $PSVersionTable.PSVersion.Minor -ne $requiredPowerShellVersion.Minor) {
        'Warning'
    }
    else {
        'Pass'
    }
    $supportedPowerShellLine = '{0}.{1}.x (minimum {2})' -f
        $requiredPowerShellVersion.Major,
        $requiredPowerShellVersion.Minor,
        $requiredPowerShellVersion
    Add-PscxInstallationDiagnostic -Category Environment -Name 'PowerShell runtime' `
        -Status $powerShellStatus -Value $PSVersionTable.PSVersion `
        -Expected $supportedPowerShellLine `
        -Message "PowerShell $($PSVersionTable.PSVersion) is running; PSCX supports $supportedPowerShellLine." `
        -Details @{ Edition = $PSVersionTable.PSEdition }

    $targetFramework = [Pscx.Core.PscxContext].Assembly.GetCustomAttributesData() |
        Where-Object AttributeType -EQ ([Runtime.Versioning.TargetFrameworkAttribute]) |
        ForEach-Object { $_.ConstructorArguments[0].Value } |
        Select-Object -First 1
    Add-PscxInstallationDiagnostic -Category Environment -Name '.NET runtime' `
        -Status Pass -Value ([Environment]::Version) -Expected $targetFramework `
        -Message ".NET $([Environment]::Version) is running; the PSCX assembly targets $targetFramework." `
        -Details @{}

    $runtimeInformation = [Runtime.InteropServices.RuntimeInformation]
    $platformValue = [pscustomobject]@{
        OperatingSystem = $runtimeInformation::OSDescription
        OSArchitecture = $runtimeInformation::OSArchitecture
        ProcessArchitecture = $runtimeInformation::ProcessArchitecture
    }
    Add-PscxInstallationDiagnostic -Category Environment -Name 'Platform' `
        -Status Info -Value $platformValue -Expected 'Windows, Linux, or macOS' `
        -Message "$($runtimeInformation::OSDescription); OS $($runtimeInformation::OSArchitecture), process $($runtimeInformation::ProcessArchitecture)." `
        -Details @{ FrameworkDescription = $runtimeInformation::FrameworkDescription }

    $knownOptionalModules = @(
        'Pscx.CD',
        'Pscx.DirectoryServices',
        'Pscx.FileSystem',
        'Pscx.Net',
        'Pscx.TranscribeSession',
        'Pscx.Utility',
        'Pscx.Sudo',
        'Pscx.Archive',
        'Pscx.Time',
        'Pscx.WinAdmin'
    )
    $loadedOptionalModules = @(
        Get-Module -Name $knownOptionalModules -All |
            Sort-Object Name, Version |
            ForEach-Object {
                [pscustomobject]@{
                    Name = $_.Name
                    Version = $_.Version
                    Path = $_.Path
                }
            }
    )
    $loadedModuleNames = @($loadedOptionalModules | ForEach-Object Name)
    $loadedModuleMessage = if ($loadedModuleNames.Count -gt 0) {
        "Loaded optional modules: $($loadedModuleNames -join ', ')."
    }
    else {
        'No optional PSCX modules are loaded.'
    }
    Add-PscxInstallationDiagnostic -Category Modules -Name 'Loaded optional modules' `
        -Status Info -Value $loadedOptionalModules -Expected 'Load only the features needed by this session' `
        -Message $loadedModuleMessage -Details @{ Count = $loadedOptionalModules.Count }

    $optionalPackageNames = @('Pscx.Archive', 'Pscx.Time', 'Pscx.WinAdmin')
    $optionalModuleManifests = @{}
    foreach ($optionalPackageName in $optionalPackageNames) {
        $isPlatformApplicable = $optionalPackageName -ne 'Pscx.WinAdmin' -or $IsWindows
        $optionalManifest = if ($isPlatformApplicable) {
            Find-PscxOptionalModuleManifest -Name $optionalPackageName -Version $module.Version
        }
        else {
            $null
        }
        $optionalModuleManifests[$optionalPackageName] = $optionalManifest
        $loadedOptionalModule = Get-Module -Name $optionalPackageName -All |
            Select-Object -First 1
        if (-not $isPlatformApplicable) {
            $optionalStatus = 'NotApplicable'
            $optionalMessage = "$optionalPackageName is Windows-only and is not applicable on this platform."
        }
        elseif ($null -ne $loadedOptionalModule) {
            $optionalStatus = 'Pass'
            $optionalMessage = "$optionalPackageName $($loadedOptionalModule.Version) is loaded."
        }
        elseif ($null -ne $optionalManifest) {
            $optionalStatus = 'Info'
            $optionalMessage = "$optionalPackageName is available but not loaded."
        }
        else {
            $optionalStatus = 'Info'
            $optionalMessage = "$optionalPackageName is not installed with this PSCX installation."
        }
        Add-PscxInstallationDiagnostic -Category Modules -Name $optionalPackageName `
            -Status $optionalStatus -Value $optionalManifest -Expected 'Optional' `
            -Message $optionalMessage -Details @{ Loaded = $null -ne $loadedOptionalModule }
    }

    $configuredEditor = $Pscx:Preferences['TextEditor']
    $resolvedEditor = Resolve-PscxApplication -ConfiguredValue $configuredEditor
    $editorStatus = if ($null -ne $resolvedEditor) { 'Pass' } else { 'Warning' }
    $editorMessage = if ($null -ne $resolvedEditor) {
        "Configured editor '$configuredEditor' resolves to '$resolvedEditor'."
    }
    else {
        "Configured editor '$configuredEditor' could not be resolved. Edit-File may fail to launch an editor."
    }
    Add-PscxInstallationDiagnostic -Category Tools -Name 'Text editor' `
        -Status $editorStatus -Value $resolvedEditor -Expected $configuredEditor `
        -Message $editorMessage -Details @{ Configured = $configuredEditor }

    $configuredPager = if (-not [string]::IsNullOrWhiteSpace($env:PAGER)) {
        $env:PAGER
    }
    elseif ($Pscx:Preferences['PageHelpUsingLess']) {
        'less'
    }
    elseif ($IsWindows) {
        'more.com'
    }
    else {
        'more'
    }
    $resolvedPager = Resolve-PscxApplication -ConfiguredValue $configuredPager
    $pagerStatus = if ($null -ne $resolvedPager) { 'Pass' } else { 'Warning' }
    $pagerMessage = if ($null -ne $resolvedPager) {
        "Configured pager '$configuredPager' resolves to '$resolvedPager'."
    }
    else {
        "Configured pager '$configuredPager' could not be resolved as an application. Shell pager integration may not be usable."
    }
    Add-PscxInstallationDiagnostic -Category Tools -Name 'Pager' `
        -Status $pagerStatus -Value $resolvedPager -Expected $configuredPager `
        -Message $pagerMessage -Details @{ Configured = $configuredPager }

    $archiveManifest = $optionalModuleManifests['Pscx.Archive']
    if ($null -eq $archiveManifest) {
        Add-PscxInstallationDiagnostic -Category Package -Name 'Archive backend' `
            -Status NotApplicable -Value $null -Expected 'SharpCompress.dll when Pscx.Archive is installed' `
            -Message 'Pscx.Archive is not installed, so no archive backend is required.' `
            -Details @{}
    }
    else {
        $archiveRoot = Split-Path $archiveManifest -Parent
        $archiveBackendPath = Join-Path $archiveRoot 'SharpCompress.dll'
        $archiveLoaded = $null -ne (Get-Module -Name Pscx.Archive -All |
            Select-Object -First 1)
        try {
            $archiveAssemblyName = [Reflection.AssemblyName]::GetAssemblyName($archiveBackendPath)
            Add-PscxInstallationDiagnostic -Category Package -Name 'Archive backend' `
                -Status Pass -Value $archiveBackendPath -Expected 'Readable SharpCompress assembly' `
                -Message "SharpCompress $($archiveAssemblyName.Version) is available to Pscx.Archive." `
                -Details @{ Version = $archiveAssemblyName.Version; LoadedModule = $archiveLoaded }
        }
        catch {
            $archiveStatus = if ($archiveLoaded) { 'Fail' } else { 'Warning' }
            Add-PscxInstallationDiagnostic -Category Package -Name 'Archive backend' `
                -Status $archiveStatus -Value $archiveBackendPath -Expected 'Readable SharpCompress assembly' `
                -Message "Pscx.Archive is present, but its SharpCompress backend is missing or invalid: $($_.Exception.Message)" `
                -Details @{ LoadedModule = $archiveLoaded; Error = $_.Exception.Message }
        }
    }

    $nativeDependencies = @(
        [pscustomobject]@{
            Name = 'less'
            Applicable = $null -ne (Get-Command -Name PscxLess -ErrorAction SilentlyContinue)
            Expected = 'Pager used by PscxLess in ConsoleHost'
        }
        [pscustomobject]@{
            Name = 'gsudo'
            Applicable = $IsWindows -and $null -ne (Get-Module -Name Pscx.Sudo)
            Expected = 'Windows elevation utility used by the Sudo submodule'
        }
    )
    foreach ($dependency in $nativeDependencies) {
        if (-not $dependency.Applicable) {
            Add-PscxInstallationDiagnostic -Category Tools -Name "Native dependency: $($dependency.Name)" `
                -Status NotApplicable -Value $null -Expected $dependency.Expected `
                -Message "$($dependency.Name) is not required by the features loaded in this session." `
                -Details @{}
            continue
        }

        $resolvedDependency = Resolve-PscxApplication -ConfiguredValue $dependency.Name
        $dependencyStatus = if ($null -ne $resolvedDependency) { 'Pass' } else { 'Warning' }
        $dependencyMessage = if ($null -ne $resolvedDependency) {
            "$($dependency.Name) resolves to '$resolvedDependency'."
        }
        else {
            "$($dependency.Name) is required by a loaded feature but could not be resolved."
        }
        Add-PscxInstallationDiagnostic -Category Tools -Name "Native dependency: $($dependency.Name)" `
            -Status $dependencyStatus -Value $resolvedDependency -Expected $dependency.Expected `
            -Message $dependencyMessage -Details @{ ProcessArchitecture = $runtimeInformation::ProcessArchitecture }
    }

    try {
        $validatedManifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop `
            -WarningAction SilentlyContinue
        Add-PscxInstallationDiagnostic -Category Package -Name 'Module manifest' `
            -Status Pass -Value $manifestPath -Expected 'Valid Pscx.psd1' `
            -Message "The PSCX module manifest is valid for version $($validatedManifest.Version)." `
            -Details @{ Guid = $validatedManifest.Guid }
    }
    catch {
        Add-PscxInstallationDiagnostic -Category Package -Name 'Module manifest' `
            -Status Fail -Value $manifestPath -Expected 'Valid Pscx.psd1' `
            -Message "The PSCX module manifest is invalid: $($_.Exception.Message)" `
            -Details @{ Error = $_.Exception.Message }
    }

    $runtimeCommands = @($module.ExportedCommands.Keys | Sort-Object -Unique)
    $declaredCommands = if ($null -ne $manifestData) {
        @($manifestData.FunctionsToExport) + @($manifestData.CmdletsToExport) +
            @($manifestData.AliasesToExport)
    }
    else {
        @()
    }
    $undeclaredCommands = @(
        $runtimeCommands | Where-Object { $_ -notin $declaredCommands }
    )
    $exportStatus = if ($null -ne $manifestData -and $undeclaredCommands.Count -eq 0) {
        'Pass'
    }
    else {
        'Fail'
    }
    $exportMessage = if ($exportStatus -eq 'Pass') {
        "All $($runtimeCommands.Count) runtime exports are declared by the manifest."
    }
    else {
        "Export validation found $($undeclaredCommands.Count) undeclared runtime command(s)."
    }
    Add-PscxInstallationDiagnostic -Category Package -Name 'Command exports' `
        -Status $exportStatus -Value $runtimeCommands.Count -Expected 'Every runtime export is declared' `
        -Message $exportMessage `
        -Details @{ RuntimeCommands = $runtimeCommands; UndeclaredCommands = $undeclaredCommands }

    $commandsRequiringHelp = @(
        $module.ExportedCommands.Values |
            Where-Object CommandType -In Function, Cmdlet |
            Sort-Object Name -Unique
    )
    $missingHelp = [Collections.Generic.List[string]]::new()
    foreach ($command in $commandsRequiringHelp) {
        try {
            $help = Get-Help -Name $command.Name -Full -ErrorAction Stop
            $synopsis = $help.Synopsis
            if ([string]::IsNullOrWhiteSpace($synopsis) -or $synopsis -match '\{\{') {
                [void] $missingHelp.Add($command.Name)
            }
        }
        catch {
            [void] $missingHelp.Add($command.Name)
        }
    }
    $helpStatus = if ($missingHelp.Count -eq 0) { 'Pass' } else { 'Fail' }
    $helpMessage = if ($missingHelp.Count -eq 0) {
        "Installed help is available for all $($commandsRequiringHelp.Count) exported functions and cmdlets."
    }
    else {
        "Installed help is missing or incomplete for: $($missingHelp -join ', ')."
    }
    Add-PscxInstallationDiagnostic -Category Package -Name 'Command help' `
        -Status $helpStatus -Value ($commandsRequiringHelp.Count - $missingHelp.Count) `
        -Expected $commandsRequiringHelp.Count -Message $helpMessage `
        -Details @{ MissingCommands = @($missingHelp) }

    $diagnostics
}

# -----------------------------------------------------------------------
# Displays help usage
# -----------------------------------------------------------------------
function WriteUsage([string]$msg)
{
    $moduleNames = $Pscx:Preferences.ModulesToImport.Keys | Sort

    if ($msg) { Write-Host $msg }

    $OFS = ','
    Write-Host @"

To load all PSCX modules using the default PSCX preferences execute:

    Import-Module Pscx

To load all PSCX modules except a few, pass in a hashtable containing
a nested hashtable called ModulesToImport.  In this nested hashtable
add the module name you want to suppress and set its value to false e.g.:

    Import-Module Pscx -args @{ModulesToImport = @{DirectoryServices = $false}}

To have complete control over which PSCX modules load as well as the PSCX
options, copy the Pscx.UserPreferences.ps1 file to your home dir. Edit this
file and modify the settings as desired.  Then pass the path to this file as
an argument to Import-Module as shown below:

    Import-Module Pscx -arg ~\Pscx.UserPreferences.ps1

The nested module names are:

$moduleNames

"@
}

# -----------------------------------------------------------------------
# Overwrites the default PSCX preferences with user specified preferences
# -----------------------------------------------------------------------
function UpdateDefaultPreferencesWithUserPreferences([hashtable]$userPreferences)
{
    # Walk the user specified settings and overwrite the defaults with them
    foreach ($key in $userPreferences.Keys)
    {
        if (!$Pscx:Preferences.ContainsKey($key))
        {
            Write-Warning "$key is not a recognized PSCX preference"
            continue
        }

        if ($key -eq 'ModulesToImport')
        {
            foreach ($modkey in $userPreferences.ModulesToImport.Keys)
            {
                if ($Pscx:Preferences.ModulesToImport.ContainsKey($modkey))
                {
                    $Pscx:Preferences.ModulesToImport.$modkey = $userPreferences.ModulesToImport.$modkey
                }
                else
                {
                    Write-Warning "$modkey is not a recognized PSCX nested module"
                }
            }
        }
        else
        {
            $Pscx:Preferences.$key = $userPreferences.$key
        }
    }
}

# -----------------------------------------------------------------------
# Process module arguments - allows user to override the default options
# using Import-Module -args
# -----------------------------------------------------------------------
if ($args.Length -gt 0)
{
    if ($args[0] -eq 'help')
    {
        # Display help/usage info
        WriteUsage
        return
    }
    elseif ($args[0] -is [hashtable])
    {
        # Hashtable of settings passed directly
        UpdateDefaultPreferencesWithUserPreferences $args[0]
    }
    elseif (Test-Path $args[0])
    {
        # Attempt to load the user specified settings by executing the specified script
        $userPreferences = & $args[0]
        if ($userPreferences -isnot [hashtable])
        {
            WriteUsage "'$($args[0])' must return a hashtable instead of a $($userPreferences.GetType().FullName)"
            return
        }

        UpdateDefaultPreferencesWithUserPreferences $userPreferences
    }
    else
    {
        # Display help/usage info
        WriteUsage "'$($args[0])' is not recognized as either a hashtable or a valid path"
        return
    }
}

# -----------------------------------------------------------------------
# Load the PscxWin companion module if running on Windows
# -----------------------------------------------------------------------
if ($IsWindows) {
    $subModuleBasePath = "$PSScriptRoot\PscxWin.psd1"
    try {
        # Don't complain about non-standard verbs with nested imports but we will still have one complaint for the final global scope import
        Import-Module $subModuleBasePath -DisableNameChecking
    } catch {
        Write-Warning "Module PscxWin load error: $_"
    }
}

if ($Pscx:Preferences["PageHelpUsingLess"]) {
    if (!(Test-Path Env:PAGER)) {
        # Only set this env var if someone has not defined it themselves
        $env:PAGER = 'less'
        $env:LESS = "-FRsPPage %db?B of %D:.\. Press h for help or q to quit\.$"
    }
}

# -----------------------------------------------------------------------
# Load nested modules selected by user - on Windows, PscxWin must be loaded first
# -----------------------------------------------------------------------
$stopWatch = new-object System.Diagnostics.StopWatch
$keys = @($Pscx:Preferences.ModulesToImport.Keys)
if ($Pscx:Preferences.ShowModuleLoadDetails)
{
    Write-Host "PowerShell Core Community Extensions $($Pscx:Version)`n"
    $totalModuleLoadTimeMs = 0
    $stopWatch.Reset()
    $stopWatch.Start()
    $keys = @($keys | Sort-Object)
}

foreach ($key in $keys)
{
    if ($Pscx:Preferences.ShowModuleLoadDetails)
    {
        $stopWatch.Reset()
        $stopWatch.Start()
        Write-Host " $key $(' ' * (20 - $key.length))[ " -NoNewline
    }

    if (!$Pscx:Preferences.ModulesToImport.$key)
    {
        # Not selected for loading by user
        if ($Pscx:Preferences.ShowModuleLoadDetails)
        {
            Write-Host "Skipped" -nonew
        }
    }
    else
    {
        $subModuleBasePath = "$PSScriptRoot\Modules\{0}\Pscx.{0}" -f $key

        # Check for PSD1 first
        $path = "$subModuleBasePath.psd1"
        if (!(Test-Path -PathType Leaf $path))
        {
            # Assume PSM1 only
            $path = "$subModuleBasePath.psm1"
            if (!(Test-Path -PathType Leaf $path))
            {
                # Missing/invalid module
                if ($Pscx:Preferences.ShowModuleLoadDetails)
                {
                    Write-Host "Module $path is missing ]"
                }
                else
                {
                    Write-Warning "Module $path is missing."
                }
                continue
            }
        }

        try
        {
            # Don't complain about non-standard verbs with nested imports but
            # we will still have one complaint for the final global scope import
            Import-Module $path -DisableNameChecking

            if ($Pscx:Preferences.ShowModuleLoadDetails)
            {
                $stopWatch.Stop()
                $totalModuleLoadTimeMs += $stopWatch.ElapsedMilliseconds
                $loadTimeMsg = "Loaded in {0,4} mS" -f $stopWatch.ElapsedMilliseconds
                Write-Host $loadTimeMsg -nonew
            }
        }
        catch
        {
            # Problem in module
            if ($Pscx:Preferences.ShowModuleLoadDetails)
            {
                Write-Host "Module $key load error: $_" -nonew
            }
            else
            {
                Write-Warning "Module $key load error: $_"
            }
        }
    }

    if ($Pscx:Preferences.ShowModuleLoadDetails)
    {
        Write-Host " ]"
    }
}

if ($Pscx:Preferences.ShowModuleLoadDetails)
{
    Write-Host "`nTotal module load time: $totalModuleLoadTimeMs mS"
}

$aliasesToExport = @()
$pscxAliases = [ordered]@{
    cvxml = 'Pscx\Convert-Xml'
    fxml  = 'Pscx\Format-Xml'
    gtn   = 'Pscx\Get-TypeName'
    skip  = 'Pscx\Skip-Object'
    tail  = 'Pscx\Get-FileTail'
    touch = 'Pscx\Set-FileTime'
}
$previousAutoLoadingPreference = Get-Variable -Name PSModuleAutoLoadingPreference `
    -Scope Global -ErrorAction Ignore
# Get-Command otherwise auto-loads PSCX again from the discovery cache while
# this module is still initializing its advertised aliases.
$global:PSModuleAutoLoadingPreference = 'None'
try {
    foreach ($aliasName in $pscxAliases.Keys) {
        $commands = @(Get-Command -Name $aliasName -ErrorAction Ignore)
        $existingCommand = if ($commands.Count -gt 0) { $commands[0] } else { $null }
        if ($Pscx:Preferences.OverrideExistingAliases -or $null -eq $existingCommand) {
            $target = $pscxAliases[$aliasName]
            Set-Alias -Name $aliasName -Value $target -Scope Local -Force `
                -Description 'PSCX compatibility alias'
            $aliasesToExport += $aliasName
        }
    }
}
finally {
    if ($null -ne $previousAutoLoadingPreference) {
        $global:PSModuleAutoLoadingPreference = $previousAutoLoadingPreference.Value
    }
    else {
        Remove-Variable -Name PSModuleAutoLoadingPreference -Scope Global
    }
}

if ($Pscx:Preferences.ModulesToImport.CD -and (Get-Module Pscx.CD)) {
    # PowerShell's built-in cd alias is AllScope and cannot be shadowed and
    # exported by a module. Importing Pscx.CD explicitly selects its enhanced
    # location-stack behavior, so replace cd for the session and restore the
    # previous alias when PSCX is removed.
    $script:previousCdAlias = Get-Alias -Name cd -ErrorAction SilentlyContinue
    Set-Alias -Name cd -Value 'Pscx\Set-PscxLocation' -Scope Global `
        -Option AllScope -Force -Description 'PSCX enhanced location alias'
    $ExecutionContext.SessionState.Module.OnRemove = {
        $cdAlias = Get-Alias -Name cd -ErrorAction SilentlyContinue
        if ($cdAlias.Definition -eq 'Pscx\Set-PscxLocation') {
            if ($null -ne $script:previousCdAlias) {
                Set-Alias -Name cd -Value $script:previousCdAlias.Definition -Scope Global `
                    -Option $script:previousCdAlias.Options -Force `
                    -Description $script:previousCdAlias.Description
            }
            else {
                Remove-Alias -Name cd -Scope Global -Force
            }
        }
    }
}
if ($Pscx:Preferences.ModulesToImport.Utility -and (Get-Module Pscx.Utility)) {
    $aliasesToExport += @(Get-Module Pscx.Utility).ExportedAliases.Keys
}
if ($IsWindows -and (Get-Module PscxWin)) {
    $aliasesToExport += @(Get-Module PscxWin).ExportedAliases.Keys
}

Remove-Item Function:\WriteUsage
Remove-Item Function:\UpdateDefaultPreferencesWithUserPreferences
$publicContract = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'Pscx.psd1')
Export-ModuleMember -Alias $aliasesToExport `
    -Function $publicContract.FunctionsToExport `
    -Cmdlet $publicContract.CmdletsToExport

# SIG # Begin signature block
# MIInmgYJKoZIhvcNAQcCoIInizCCJ4cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAJ7E4CwHv4JvM+
# K3eqXfqcFtUQ8hhsu8w9tgMShRI86aCCIHEwggWNMIIEdaADAgECAhAOmxiO+dAt
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
# MQ4wDAYKKwYBBAGCNwIBFjAvBgkqhkiG9w0BCQQxIgQgppED04yWPf4VdOzEHuoD
# xMRnCx5gp5JOaMFfisQ/IVYwDQYJKoZIhvcNAQEBBQAEggIAiOixfFlHrTY61QTt
# NH15Rk9qbH7oRGhbNlhEQj7gemA9JLqiYNTXivEFCSLFUQtasVCgjt4zXz7XZPY/
# WlIEhfuHvyWyVg554vvV9ItAxQztBKkJxS8aOb1uCQDXw7lyDt8hoGifUH8VATKw
# 3ciuzXcZ5ngmnEoaNLEXnvqIFA8815ODIzkGCd7Sw4USS8f9PkADKVfwWD+cj8VA
# Ccz2x6Kk1chdtDhYIIyrhLz9Nuaa4sY9knfmijB78OALe7hU7VUs6Qv1tAiPWt/8
# w6YW2ChpttTOwF9KVz8Wzkuqf2nID/UiPlkiN8KJ2YN6ecfGBgcJIn3DtKTXAZau
# hCPsVspWqy9WixAqG3+JcPul3HCtqNfIsgsDr09hyd4N74NI1c50shb9PbcRvIlA
# qbi2JB/yWRM+XP/PYCdbnZjZCKAO/Uqy320BMb17O8n6Sp8Jk753UPysU64ZRM0G
# Yjo0aOHxeMRLFieHHVoQt1nWDjh2LHqHOMyL268gVYKQs4B7AtfCXpGzXCmW8eLO
# bYPi9ENMcWi7QgEOy8UmGcUgciYPyfrafzO6a9j6wo47hMhrMmQbhWRbTBcMGgid
# pzNm3y2c0qAXRYuHWtHlkv9bkJjZAPVVCJUPPDZFTTuvh29pSu4U4MJljPVpm6EH
# gAHUy1MkvSzwiatkEbCwxcJF0eOhggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8C
# AQEwfTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/
# BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYg
# U0hBMjU2IDIwMjUgQ0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUA
# oGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYw
# ODI5MDM1MzM4WjAvBgkqhkiG9w0BCQQxIgQgPIf8LGb87VAg/EADrxtvmF2xp9hh
# RCWCkSsOiFXrcN8wDQYJKoZIhvcNAQEBBQAEggIAsV/xfEs8OnAMcdhsvSDnoPEF
# eOkfjWXhX2rXKdlI5qnuA2G/bofeshwzLZby0EJma88ojRiK3OHJlcx5ytSKOki0
# MeM2Bz3UzGZYYmG0cC2UffhKsxG0KRYt/DdZzw+Kt/g6eUslNysxp0fn1ZleVI9M
# 7D6F0Z0mH2Xx/fvXYC9a6lFlfPpzTMG/YRvcFPU+fl7qusBgqphJ3BSreZI5JYjG
# 6gbea4LIHYD1t3/PgRVRoOh37V3LU7F76pgkqQNQ21iPZT1lKxrFBgB1fwTtA/6x
# xXtKLgm6QSocdG6sUbx7NBhArEmd6zDqwnIV4EU7J+U/dsVP0vm9sxL4j6WNhA0u
# 7U0Z2RuWH00sPLWQi5HMxozx/l6rh6jMNbhR7bF4hQGHF/+JTDxwLexemUgeIaTK
# gHRyASrQlfc1yrsevQSMftRK9TFRAzxPS1WZpKkz28dqBcvnhImEUQTo9V3VtOst
# mUyv9dvJNmwEP6I8+S9fS/ll5f6OoGw0Z2djflfg5dHOz6/tOqyzVehHdj6NwWEY
# bsWTy+N6QkNCRIJHa8z4A6fJ84MGQS4Xs5DKp5A9qMBq+Ir68FuNGHqDxyT1Mk4f
# eg3vt+9gLef5yNhTUDe6mgBZBPNQzNa6I2w3EaKU66ihp1i6jn5Vpr89bCj6pxUS
# 2t+hId563zZk03bIc+Y=
# SIG # End signature block
