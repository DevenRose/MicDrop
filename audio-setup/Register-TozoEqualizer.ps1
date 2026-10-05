param([switch]$Proof)
$ErrorActionPreference = 'Stop'
$staging = 'X:\Downloads\MicDrop-EQ-2026-10-05'
$statusPath = Join-Path $staging 'registration-status.json'
$slotPrefix = '{d04e05a6-594b-4fb6-a80d-01af5eed7d1d}'
$slotNames = @(1,2,5,6,7 | ForEach-Object { "$slotPrefix,$_" })
$pre = '{EACD2258-FCAC-4FF4-B36D-419E924A6D79}'
$post = '{EC1CC9CE-FAED-4822-828A-82A81A6F018F}'
$mode = '{C18E2F7E-933D-4965-B7D1-1EEF228D2AF3}'
$disable = '{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5'
$targets = @(
    @{Flow='Render';Id='{b56632b2-8e96-4c11-a623-8e233b195adb}'},
    @{Flow='Render';Id='{50c13f97-8076-409c-8c5d-b95c6a3deedd}'},
    @{Flow='Capture';Id='{7c806a74-2036-47d5-b3fe-1a0aa19bb13e}'}
)
$hive = [Microsoft.Win32.Registry]::LocalMachine
$audioRoot = 'SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio'
$backupRoot = 'SOFTWARE\EqualizerAPO\Child APOs'
$snapshots = @()
$changed = @()

function Open-EffectKey($Path) {
    # These keys permit setting values, not creating subkeys. Request only
    # the existing ReadKey and SetValue rights; never change their permissions.
    return $hive.OpenSubKey($Path, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
        ([Security.AccessControl.RegistryRights]::ReadKey -bor [Security.AccessControl.RegistryRights]::SetValue))
}

function Snapshot-Key($Key) {
    $result = @{}
    foreach ($name in $Key.GetValueNames()) {
        $result[$name] = @{Value=$Key.GetValue($name);Kind=$Key.GetValueKind($name).ToString()}
    }
    return $result
}

try {
    if ($Proof) {
        $hive = [Microsoft.Win32.Registry]::CurrentUser
        $audioRoot = 'Software\DRVI\MicDrop-Registration-Proof\Audio'
        $backupRoot = 'Software\DRVI\MicDrop-Registration-Proof\Backups'
        foreach ($target in $targets) {
            $key = $hive.CreateSubKey("$audioRoot\$($target.Flow)\$($target.Id)\FxProperties")
            $key.SetValue($slotNames[2], 'original-stream', [Microsoft.Win32.RegistryValueKind]::String)
            $key.SetValue($slotNames[3], 'original-mode', [Microsoft.Win32.RegistryValueKind]::String)
            $key.SetValue($slotNames[4], 'original-endpoint', [Microsoft.Win32.RegistryValueKind]::String)
            $key.SetValue('Unrelated', 42, [Microsoft.Win32.RegistryValueKind]::DWord)
            $key.SetValue($disable, 1, [Microsoft.Win32.RegistryValueKind]::DWord)
            $key.Dispose()
        }
    } else {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        if (-not ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'Administrator execution required; no change made.'
        }
    }

    # Read and validate all targets before making any registration change.
    foreach ($target in $targets) {
        $path = "$audioRoot\$($target.Flow)\$($target.Id)\FxProperties"
        $key = Open-EffectKey $path
        if (-not $key) { throw "Existing writable target key required: $path" }
        try { $values = Snapshot-Key $key } finally { $key.Dispose() }
        if (-not $Proof) {
            $properties = $hive.OpenSubKey("$audioRoot\$($target.Flow)\$($target.Id)\Properties")
            try {
                if (-not $properties -or -not ($properties.GetValueNames() | Where-Object { [string]$properties.GetValue($_) -match 'TOZO HT3' })) {
                    throw "Target no longer identifies TOZO HT3: $path"
                }
            } finally { if ($properties) { $properties.Dispose() } }
        }
        foreach ($slot in $slotNames) {
            if ($values.ContainsKey($slot) -and ($values[$slot].Kind -ne 'String' -or $values[$slot].Value -in @($pre,$post))) {
                throw "Unexpected or already installed slot: $path $slot"
            }
        }
        $existingBackup = $hive.OpenSubKey("$backupRoot\$($target.Id)")
        if ($existingBackup) { $existingBackup.Dispose(); throw "Existing backup: $($target.Id); refusing to overwrite." }
        $snapshots += @{Path=$path;Target=$target;Values=$values}
    }
    if (-not $Proof) {
        $snapshotFile = Join-Path $staging ('tozo-registry-before-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '.json')
        $snapshots | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $snapshotFile -Encoding utf8
    }

    foreach ($snapshot in $snapshots) {
        $target = $snapshot.Target
        $values = $snapshot.Values
        $backup = $hive.CreateSubKey("$backupRoot\$($target.Id)")
        $changed += $snapshot
        $key = Open-EffectKey $snapshot.Path
        try {
            foreach ($slot in $slotNames) {
                $saved = if ($values.ContainsKey($slot)) { $values[$slot].Value } else { '!VALUE' }
                $backup.SetValue($slot, $saved, [Microsoft.Win32.RegistryValueKind]::String)
            }
            $originalPre = if ($values.ContainsKey($slotNames[2])) { $values[$slotNames[2]].Value } else { '' }
            $originalPost = if ($values.ContainsKey($slotNames[3])) { $values[$slotNames[3]].Value } else { '' }
            if (-not $originalPre -and -not $originalPost) {
                $originalPre = if ($values.ContainsKey($slotNames[0])) { $values[$slotNames[0]].Value } else { '' }
                $originalPost = if ($values.ContainsKey($slotNames[1])) { $values[$slotNames[1]].Value } else { '' }
            }
            $backup.SetValue('PreMixChild', $originalPre, [Microsoft.Win32.RegistryValueKind]::String)
            $backup.SetValue('PostMixChild', $originalPost, [Microsoft.Win32.RegistryValueKind]::String)
            $backup.SetValue('AllowSilentBufferModification', 'false', [Microsoft.Win32.RegistryValueKind]::String)
            $backup.SetValue('Version', '2', [Microsoft.Win32.RegistryValueKind]::String)
            $key.DeleteValue($slotNames[0], $false)
            $key.DeleteValue($slotNames[1], $false)
            $key.SetValue($slotNames[2], $pre, [Microsoft.Win32.RegistryValueKind]::String)
            $modeKey = '{d3993a3f-99c2-4402-b5ec-a92a0367664b},5'
            if ($modeKey -notin $key.GetValueNames()) { $key.SetValue($modeKey, [string[]]@($mode), [Microsoft.Win32.RegistryValueKind]::MultiString) }
            if ($target.Flow -eq 'Render') {
                $key.SetValue($slotNames[3], $post, [Microsoft.Win32.RegistryValueKind]::String)
                $modeKey = '{d3993a3f-99c2-4402-b5ec-a92a0367664b},6'
                if ($modeKey -notin $key.GetValueNames()) { $key.SetValue($modeKey, [string[]]@($mode), [Microsoft.Win32.RegistryValueKind]::MultiString) }
            }
            $key.DeleteValue($disable, $false)
            if ($key.GetValue($slotNames[2]) -ne $pre) { throw 'Registration verification failed.' }
            if ($Proof -and ($key.GetValue($slotNames[4]) -ne 'original-endpoint' -or $key.GetValue('Unrelated') -ne 42 -or $backup.GetValue('PreMixChild') -ne 'original-stream' -or $backup.GetValue('PostMixChild') -ne 'original-mode')) {
                throw 'Original processing or unrelated value preservation failed.'
            }
        } finally { $key.Dispose(); $backup.Dispose() }
    }
    if ($Proof) {
        'PASS: all three fixture devices registered; original processors, unrelated values and typed processing modes preserved.'
    } else {
        @{Status='registered';Targets=$targets;Snapshot=$snapshotFile;AudioRestarted=$false} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statusPath
        # Only the audio interruption explicitly permitted by Captain.
        Restart-Service -Name Audiosrv -Force
        @{Status='registered';Targets=$targets;Snapshot=$snapshotFile;AudioRestarted=$true} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statusPath
    }
} catch {
    $failure = $_.Exception.Message
    # Restore only keys this invocation changed, preserving original types.
    foreach ($snapshot in $changed) {
        $key = Open-EffectKey $snapshot.Path
        try {
            foreach ($name in @($key.GetValueNames())) { if (-not $snapshot.Values.ContainsKey($name)) { $key.DeleteValue($name, $false) } }
            foreach ($name in $snapshot.Values.Keys) {
                $key.SetValue($name, $snapshot.Values[$name].Value, [Microsoft.Win32.RegistryValueKind]::$($snapshot.Values[$name].Kind))
            }
        } finally { $key.Dispose() }
        $hive.DeleteSubKeyTree("$backupRoot\$($snapshot.Target.Id)", $false)
    }
    if (-not $Proof) { @{Status='failed';Error=$failure} | ConvertTo-Json | Set-Content -LiteralPath $statusPath }
    throw
} finally {
    if ($Proof) { $hive.DeleteSubKeyTree('Software\DRVI\MicDrop-Registration-Proof', $false) }
}
