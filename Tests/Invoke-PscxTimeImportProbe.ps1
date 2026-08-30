param(
    [Parameter(Mandatory)]
    [string] $ModulePath,

    [Parameter(Mandatory)]
    [string] $TimeModulePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$acceleratorsType = [psobject].Assembly.GetType(
    'System.Management.Automation.TypeAccelerators'
)
$names = @('isodate', 'zonedtime', 'offsettime', 'localtime', 'tz', 'tzi')

Import-Module (Join-Path $ModulePath 'Pscx.psd1') -ArgumentList @{
    PageHelpUsingLess = $false
    ModulesToImport = @{
        CD = $false
        DirectoryServices = $false
        FileSystem = $false
        Net = $false
        Sudo = $false
        TranscribeSession = $false
        Utility = $false
    }
} -Force -ErrorAction Stop

$beforeTimeImport = @($names | Where-Object { $acceleratorsType::Get.ContainsKey($_) })
$nodaBeforeTimeImport = @(
    [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'NodaTime' }
).Count

Import-Module (Join-Path $TimeModulePath 'Pscx.Time.psd1') -Force -ErrorAction Stop
$registered = @($names | Where-Object { $acceleratorsType::Get.ContainsKey($_) })
$sample = [localtime]::of(2026, 8, 23, 12, 0, 0).PlusSeconds(1)
$help = Get-Help about_Pscx.Time -ErrorAction Stop
Remove-Module Pscx.Time -Force -ErrorAction Stop
$afterRemoval = @($names | Where-Object { $acceleratorsType::Get.ContainsKey($_) })

[ordered]@{
    BeforeTimeImport = $beforeTimeImport
    NodaAssemblyCountBeforeTimeImport = $nodaBeforeTimeImport
    Registered = $registered
    AfterRemoval = $afterRemoval
    Sample = $sample.ToString()
    HelpName = $help.Name
} | ConvertTo-Json -Compress
