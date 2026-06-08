<#
.SYNOPSIS
  MicDrop — lock a Bluetooth headset into stereo (disable Hands-Free/mic) or
  restore the mic, so Windows can't flip it to mono HFP and kill your audio.

.PARAMETER Mode
  Stereo = mic OFF, stereo-locked.  Mic = mic on.  Toggle (default) = flip.

.PARAMETER DeviceNamePattern
  Headset name substring to target. Overrides config.json. Omit to use
  config.json (or all Bluetooth hands-free devices if none configured).

.EXAMPLE
  .\Toggle-Mic.ps1 -Mode Stereo
.EXAMPLE
  .\Toggle-Mic.ps1 -DeviceNamePattern "WH-1000XM4"
#>
[CmdletBinding()]
param(
    [ValidateSet('Toggle', 'Stereo', 'Mic')]
    [string]$Mode = 'Toggle',
    [string]$DeviceNamePattern,
    # Internal: set on the elevated child so only the user-context parent re-pins
    # FxSound (the toggle needs admin; the FxSound fix must run as the real user).
    [switch]$NoFxSound
)

. (Join-Path $PSScriptRoot 'MicDrop.Core.ps1')
$configPath = Join-Path $PSScriptRoot 'config.json'
$pattern    = Resolve-MicDropPattern -Override $DeviceNamePattern -ConfigPath $configPath

function Repair-FxSound {
    if ($NoFxSound) { return }
    if (-not (Resolve-MicDropManageFxSound -ConfigPath $configPath)) { return }
    if (Set-MicDropFxSound -Pattern $pattern) {
        Write-Host "==> FxSound output re-pinned to the headset." -ForegroundColor Cyan
    }
}

# --- self-elevate (Enable/Disable-PnpDevice needs admin) ---
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Elevate just the toggle and wait, then fix FxSound here as the real user.
    $argl = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Mode', $Mode, '-NoFxSound')
    if ($DeviceNamePattern) { $argl += @('-DeviceNamePattern', "`"$DeviceNamePattern`"") }
    Start-Process pwsh -Verb RunAs -ArgumentList $argl -Wait
    Repair-FxSound
    return
}

$state = Get-MicDropState -Pattern $pattern
if ($state -eq 'Disconnected') {
    Write-Warning "No Bluetooth Hands-Free device found (pattern: '$pattern'). Is the headset connected?"
    [void](Read-Host "Press Enter to close"); return
}

$wantStereo = switch ($Mode) { 'Stereo' { $true } 'Mic' { $false } 'Toggle' { $state -eq 'Mic' } }

if ($wantStereo -and $state -eq 'Stereo') {
    Write-Host "Already stereo-locked (mic off). Nothing to do." -ForegroundColor Green
} elseif (-not $wantStereo -and $state -eq 'Mic') {
    Write-Host "Mic already available. Nothing to do." -ForegroundColor Green
} elseif ($wantStereo) {
    Set-MicDropStereo -Pattern $pattern
    Write-Host "==> STEREO-LOCKED. Headset held on A2DP stereo. Mic is OFF." -ForegroundColor Green
} else {
    Set-MicDropMic -Pattern $pattern
    Write-Host "==> Microphone restored." -ForegroundColor Green
}

Get-MicDropHfpDevice -Pattern $pattern | Select-Object Status, FriendlyName | Format-Table -AutoSize

# When run from an already-elevated shell there's no user-context parent, so
# re-pin here best-effort. The child we spawn ourselves passes -NoFxSound.
Repair-FxSound
