$ErrorActionPreference = 'Stop'
$hive = [Microsoft.Win32.Registry]::LocalMachine
$targets = @('{b56632b2-8e96-4c11-a623-8e233b195adb}', '{50c13f97-8076-409c-8c5d-b95c6a3deedd}', '{7c806a74-2036-47d5-b3fe-1a0aa19bb13e}')
$slots = @(1,2,5,6,7 | ForEach-Object { "{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},$_" })
$effects = @('{EACD2258-FCAC-4FF4-B36D-419E924A6D79}', '{EC1CC9CE-FAED-4822-828A-82A81A6F018F}')
$rows = @()
$backup = $hive.OpenSubKey('SOFTWARE\EqualizerAPO\Child APOs')
try {
    foreach ($id in $backup.GetSubKeyNames()) {
        if ($id -in $targets) { continue }
        $original = $backup.OpenSubKey($id)
        try {
            foreach ($flow in @('Render','Capture')) {
                $path = "SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\$flow\$id\FxProperties"
                $key = $hive.OpenSubKey($path)
                if (-not $key) { continue }
                try {
                    $values = @{}
                    foreach ($slot in $slots) {
                        $before = $key.GetValue($slot,$null)
                        $restore = $original.GetValue($slot,$null)
                        if ($restore -eq $null -or $restore -eq '!KEY') { throw "Missing supported backup for $id" }
                        if ($before -ne $restore -and $before -ne $null -and $before -notin $effects) { throw "Unexpected effect on $id" }
                        $values[$slot] = @{Before=$before;Original=$restore}
                    }
                    $rows += @{Path=$path;Id=$id;Values=$values}
                } finally { $key.Dispose() }
            }
        } finally { $original.Dispose() }
    }
} finally { $backup.Dispose() }
if ($rows.Count -ne 10) { throw "Expected ten installation leftovers, found $($rows.Count); no changes made." }
$rows | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath 'X:\Downloads\MicDrop-EQ-2026-10-05\non-target-effects-before.json'
foreach ($row in $rows) {
    $key = $hive.OpenSubKey($row.Path,[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
        ([Security.AccessControl.RegistryRights]::ReadKey -bor [Security.AccessControl.RegistryRights]::SetValue))
    try {
        foreach ($slot in $slots) {
            $value = $row.Values[$slot].Original
            if ($value -eq '!VALUE') { $key.DeleteValue($slot,$false) }
            else { $key.SetValue($slot,$value,[Microsoft.Win32.RegistryValueKind]::String) }
        }
        foreach ($slot in $slots) {
            $expected = $row.Values[$slot].Original
            if ($expected -eq '!VALUE') { $expected = $null }
            if ($key.GetValue($slot,$null) -ne $expected) { throw "Restore verification failed on $($row.Id)" }
        }
    } finally { $key.Dispose() }
}
@{Status='restored';Devices=$rows.Count;BackupMetadataRetained=$true} | ConvertTo-Json |
    Tee-Object -FilePath 'X:\Downloads\MicDrop-EQ-2026-10-05\non-target-effects-restored.json'
