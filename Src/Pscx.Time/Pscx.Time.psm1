# Copyright © 2026 Dan Luca. All rights reserved.
# Licensed under MIT license.

Set-StrictMode -Version Latest

$script:acceleratorsType = [psobject].Assembly.GetType(
    'System.Management.Automation.TypeAccelerators'
)
$script:timeAccelerators = [ordered]@{
    isodate = [Pscx.TypeAccelerators.IsoDateTime]
    zonedtime = [Pscx.Time.ZonedDateTime]
    offsettime = [Pscx.Time.OffsetDateTime]
    localtime = [Pscx.Time.LocalDateTime]
    tz = [NodaTime.DateTimeZone]
    tzi = [System.TimeZoneInfo]
}
$script:ownedAccelerators = [Collections.Generic.List[string]]::new()

foreach ($entry in $script:timeAccelerators.GetEnumerator()) {
    if ($script:acceleratorsType::Get.ContainsKey($entry.Key)) {
        if ($script:acceleratorsType::Get[$entry.Key] -ne $entry.Value) {
            Write-Warning "$($entry.Key) exists already as a TypeAccelerator - NOT overwritten"
        }
        continue
    }

    $script:acceleratorsType::Add($entry.Key, $entry.Value)
    $script:ownedAccelerators.Add($entry.Key)
}

$ExecutionContext.SessionState.Module.OnRemove = {
    foreach ($name in $script:ownedAccelerators) {
        if (
            $script:acceleratorsType::Get.ContainsKey($name) -and
            $script:acceleratorsType::Get[$name] -eq $script:timeAccelerators[$name]
        ) {
            $script:acceleratorsType::Remove($name) | Out-Null
        }
    }
}

Export-ModuleMember -Function @() -Cmdlet @() -Alias @()
