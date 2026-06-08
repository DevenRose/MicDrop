<#
  MicDrop.Core.ps1 — shared, testable core logic.
  Dot-sourced by Toggle-Mic.ps1, MicDrop-Tray.ps1, and the Pester tests.
  Pure functions over the Windows PnP layer so they can be mocked/emulated.
#>

Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue

# --- project links (set these after you create the GitHub repo) ---
$script:MicDropRepoUrl = 'https://github.com/DevenRose/MicDrop'
$script:MicDropTipUrl  = 'https://github.com/sponsors/DevenRose'

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

# ---------------------------------------------------------------------------
#  FxSound (and other "router" EQ tools) integration
#
#  FxSound presents itself as the default playback device, processes audio, and
#  renders to a *fixed* target endpoint it stores in its own settings. After a
#  Bluetooth re-enumeration -- which toggling the HFP node triggers -- FxSound
#  can silently fall back to the laptop speakers: audio keeps playing, just not
#  in the headset. MicDrop owns the HFP node, not FxSound's routing, so it can't
#  see this. These functions re-pin FxSound's output to the headset's A2DP
#  stereo endpoint so a toggle (or reconnect) doesn't strand your audio.
# ---------------------------------------------------------------------------

function Resolve-MicDropManageFxSound {
    <# Whether MicDrop should keep FxSound pinned to the headset. Default: $true. #>
    param([string]$ConfigPath)
    if ($ConfigPath -and (Test-Path $ConfigPath)) {
        try {
            $c = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            if ($null -ne $c.manageFxSound) { return [bool]$c.manageFxSound }
        } catch {}
    }
    return $true
}

function ConvertTo-MicDropEndpointId {
    <# AudioEndpoint PnP InstanceId -> the MMDevice endpoint id FxSound stores
       (e.g. 'SWD\MMDEVAPI\{0.0.0.00000000}.{GUID}' -> '{0.0.0.00000000}.{guid}'). #>
    param([string]$InstanceId)
    return ($InstanceId -replace '^SWD\\MMDEVAPI\\', '').ToLowerInvariant()
}

function Get-MicDropRenderEndpoint {
    <#
      The headset's *stereo* (A2DP) render AudioEndpoint -- what media should play
      through. Render endpoints are '{0.0.0.*}' (capture/mic are '{0.0.1.*}').
      When both A2DP ("Headphones") and HFP ("Headset"/"Hands-Free") render nodes
      exist, prefer a present/OK one and the A2DP node. Returns $null if none.
    #>
    param([string]$Pattern = '*')
    $eps = @(Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue | Where-Object {
        $_.InstanceId -like 'SWD\MMDEVAPI\{0.0.0.*' -and
        ($Pattern -eq '*' -or $_.FriendlyName -like "*$Pattern*")
    })
    if ($eps.Count -eq 0) { return $null }
    $eps | Sort-Object `
        @{ Expression = { if ($_.Status -eq 'OK') { 0 } else { 1 } } }, `
        @{ Expression = { if ($_.FriendlyName -match 'Hands-?Free|Headset') { 1 } else { 0 } } } |
        Select-Object -First 1
}

function Set-MicDropFxSound {
    <#
      Re-pin FxSound's output device to the headset's A2DP stereo endpoint.
      No-op (returns $false) when FxSound isn't installed, no headset render
      endpoint is found, or it's already correct. Returns $true when it re-pins.

      Must run as the real (interactive) user: it reads the user's FxSound
      settings under %APPDATA% and relaunches FxSound via Explorer so it stays
      at the user's integrity level even when called from the elevated tray.
    #>
    param(
        [string]$Pattern = '*',
        [string]$SettingsPath = (Join-Path $env:APPDATA 'FxSound\FxSound.settings'),
        [string]$ExePath
    )
    try {
        if (-not (Test-Path $SettingsPath)) { return $false }   # FxSound not installed

        $ep = Get-MicDropRenderEndpoint -Pattern $Pattern
        if (-not $ep) { return $false }
        $id   = ConvertTo-MicDropEndpointId -InstanceId $ep.InstanceId
        $name = $ep.FriendlyName

        $xml = Get-Content $SettingsPath -Raw
        $cur = if ($xml -match 'name="output_device_id" val="([^"]*)"') { $Matches[1] } else { '' }
        if ($cur -eq $id) { return $false }                     # already on the headset

        $proc = @(Get-Process -Name FxSound -ErrorAction SilentlyContinue)
        if (-not $ExePath) { $ExePath = ($proc | Where-Object Path | Select-Object -First 1).Path }
        if (-not $ExePath) { $ExePath = 'C:\Program Files\FxSound LLC\FxSound\FxSound.exe' }
        $wasRunning = $proc.Count -gt 0
        if ($wasRunning) {
            Stop-Process -Name FxSound -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 600
        }

        # MatchEvaluator scriptblocks avoid '$'-substitution surprises in values.
        $xml = [regex]::Replace($xml, '(?<=name="output_device_id" val=")[^"]*',   { $id }.GetNewClosure())
        $xml = [regex]::Replace($xml, '(?<=name="output_device_name" val=")[^"]*', { [System.Security.SecurityElement]::Escape($name) }.GetNewClosure())
        Set-Content -Path $SettingsPath -Value $xml -Encoding UTF8 -NoNewline

        # Relaunch via Explorer -> runs as the user (non-elevated), not as admin.
        if ($wasRunning -and (Test-Path $ExePath)) {
            Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$ExePath`""
        }
        return $true
    } catch {
        return $false
    }
}

function Restart-MicDropFxSound {
    <#
      Force-restart FxSound to recover a wedged/silent render. Unlike
      Set-MicDropFxSound, this does NOT depend on the stored output device being
      wrong: saving/changing an EQ preset can leave FxSound's render wedged --
      headset silent while the device, power and gain all read correct -- and a
      re-pin no-ops because nothing in the settings is wrong. Only a restart
      recovers it. Relaunches via Explorer so FxSound runs at the user's
      integrity level even when called from the elevated tray.
      Returns $true if it relaunched FxSound, else $false.
    #>
    param([string]$ExePath)
    try {
        $proc = @(Get-Process -Name FxSound -ErrorAction SilentlyContinue)
        if (-not $ExePath) { $ExePath = ($proc | Where-Object Path | Select-Object -First 1).Path }
        if (-not $ExePath) { $ExePath = 'C:\Program Files\FxSound LLC\FxSound\FxSound.exe' }
        if ($proc.Count -gt 0) {
            Stop-Process -Name FxSound -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 600
        }
        if (-not (Test-Path $ExePath)) { return $false }
        Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$ExePath`""
        return $true
    } catch {
        return $false
    }
}

function New-MicDropBitmap {
    <#
      Draws a big, edge-to-edge SM58-style mic ball-grille with an embossed,
      3D diamond mesh, tinted as a soundboard indicator light. No glyph — state
      is conveyed by colour + the tray hover text:
        'Mic'    -> GREEN  (mic ON / available)
        'Stereo' -> RED    (mic OFF / stereo-locked)
        other    -> gray   (headset not connected)
      Returns a System.Drawing.Bitmap (caller converts to Icon / saves as needed).
    #>
    param([string]$State = 'Mic', [int]$Size = 32)

    switch ($State) {
        'Mic'    { $light = [System.Drawing.Color]::FromArgb(225, 255, 170); $dark = [System.Drawing.Color]::FromArgb(40, 255, 70)  }
        'Stereo' { $light = [System.Drawing.Color]::FromArgb(255, 180, 165); $dark = [System.Drawing.Color]::FromArgb(255, 35, 35)  }
        default  { $light = [System.Drawing.Color]::FromArgb(252, 252, 252); $dark = [System.Drawing.Color]::FromArgb(175, 175, 175) }
    }

    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    # near edge-to-edge ball
    $m = [int][math]::Max(1, [math]::Round($Size * 0.03))
    $d = $Size - 2 * $m
    $rect = New-Object System.Drawing.Rectangle $m, $m, $d, $d
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse($rect)

    # spherical base gradient (bright off-centre highlight -> dark edge)
    $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
    $pgb.CenterColor = $light
    $pgb.SurroundColors = [System.Drawing.Color[]]@($dark)
    $pgb.CenterPoint = New-Object System.Drawing.PointF (($m + $d * 0.38), ($m + $d * 0.34))
    $g.FillPath($pgb, $path)

    # embossed 3D grille: dark wires + offset white sheen, clipped to the ball
    $g.SetClip($path)
    $step  = [int][math]::Max(3, [math]::Round($Size / 5))
    $off   = [single][math]::Max(1, $Size / 26)
    $wireW = [single][math]::Max(1.5, $Size / 13)
    $sheenW = [single][math]::Max(1, $Size / 30)
    $wire  = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(60, 25, 25, 25)), $wireW
    $sheen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(120, 255, 255, 255)), $sheenW
    for ($i = -$Size; $i -le ($Size * 2); $i += $step) {
        $g.DrawLine($wire,  $i, 0, ($i + $Size), $Size)
        $g.DrawLine($sheen, ($i - $off), (0 - $off), (($i + $Size) - $off), ($Size - $off))
        $g.DrawLine($wire,  $i, $Size, ($i + $Size), 0)
        $g.DrawLine($sheen, ($i - $off), ($Size - $off), (($i + $Size) - $off), (0 - $off))
    }
    $g.ResetClip(); $wire.Dispose(); $sheen.Dispose()

    # edge vignette to deepen the sphere (only the outer rim darkens)
    $vig = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
    $vig.CenterColor = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
    $vig.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(12, 0, 0, 0))
    $vig.CenterPoint = New-Object System.Drawing.PointF (($m + $d * 0.5), ($m + $d * 0.5))
    $vig.FocusScales = New-Object System.Drawing.PointF (0.45, 0.45)
    $g.FillPath($vig, $path); $vig.Dispose()

    # crisp dark rim
    $rim = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(195, 0, 0, 0)), ([single][math]::Max(1, $Size / 20))
    $g.DrawEllipse($rim, $rect); $rim.Dispose()

    # bright specular highlight (top-left)
    $hw = [int]($d * 0.50); $hh = [int]($hw * 0.62)
    $hl = New-Object System.Drawing.Drawing2D.GraphicsPath
    $hl.AddEllipse(($m + [int]($d * 0.12)), ($m + [int]($d * 0.06)), $hw, $hh)
    $hb = New-Object System.Drawing.Drawing2D.PathGradientBrush($hl)
    $hb.CenterColor = [System.Drawing.Color]::FromArgb(170, 255, 255, 255)
    $hb.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(0, 255, 255, 255))
    $g.FillPath($hb, $hl); $hb.Dispose(); $hl.Dispose()

    $pgb.Dispose(); $path.Dispose(); $g.Dispose()
    return $bmp
}
