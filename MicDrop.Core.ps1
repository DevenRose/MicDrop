<#
  MicDrop.Core.ps1 — shared, testable core logic.
  Dot-sourced by Toggle-Mic.ps1, MicDrop-Tray.ps1, and the Pester tests.
  Pure functions over the Windows PnP layer so they can be mocked/emulated.
#>

# --- project links (set these after you create the GitHub repo) ---
$script:MicDropRepoUrl = 'https://github.com/OWNER/MicDrop'
$script:MicDropTipUrl  = 'https://github.com/sponsors/OWNER'

function Resolve-MicDropPattern {
    <# Returns the headset name pattern: explicit override > config.json > '*' (all). #>
    param([string]$Override, [string]$ConfigPath)
    if (-not [string]::IsNullOrWhiteSpace($Override)) { return $Override }
    if ($ConfigPath -and (Test-Path $ConfigPath)) {
        try {
            $p = (Get-Content $ConfigPath -Raw | ConvertFrom-Json).deviceNamePattern
            if (-not [string]::IsNullOrWhiteSpace($p)) { return $p }
        } catch {}
    }
    return '*'
}

function Get-MicDropHfpDevice {
    <# All Bluetooth Hands-Free (HFP) audio nodes matching the pattern. #>
    param([string]$Pattern = '*')
    Get-PnpDevice -Class MEDIA -ErrorAction SilentlyContinue | Where-Object {
        $_.InstanceId -like 'BTHHFENUM*' -and
        ($Pattern -eq '*' -or $_.FriendlyName -like "*$Pattern*")
    }
}

function Get-MicDropState {
    <# 'Mic' = HFP enabled (mic on), 'Stereo' = HFP disabled (locked), 'Disconnected' = none. #>
    param([string]$Pattern = '*')
    $d = @(Get-MicDropHfpDevice -Pattern $Pattern)
    if ($d.Count -eq 0) { return 'Disconnected' }
    if (@($d | Where-Object { $_.Status -eq 'OK' }).Count -gt 0) { return 'Mic' }
    return 'Stereo'
}

function Set-MicDropStereo {
    <# Disable HFP -> headset is held in A2DP stereo. Mic OFF. #>
    param([string]$Pattern = '*')
    Get-MicDropHfpDevice -Pattern $Pattern | Disable-PnpDevice -Confirm:$false -ErrorAction SilentlyContinue
}

function Set-MicDropMic {
    <# Enable HFP -> microphone restored (normal behaviour). #>
    param([string]$Pattern = '*')
    Get-MicDropHfpDevice -Pattern $Pattern | Enable-PnpDevice -Confirm:$false -ErrorAction SilentlyContinue
}
