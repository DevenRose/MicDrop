<#
  MicDrop.Core.ps1 — shared, testable core logic.
  Dot-sourced by Toggle-Mic.ps1, MicDrop-Tray.ps1, and the Pester tests.
  Pure functions over the Windows PnP layer so they can be mocked/emulated.
#>

Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue

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
        'Mic'    { $light = [System.Drawing.Color]::FromArgb(170, 255, 90);  $dark = [System.Drawing.Color]::FromArgb(40, 215, 70)  }
        'Stereo' { $light = [System.Drawing.Color]::FromArgb(255, 105, 90);  $dark = [System.Drawing.Color]::FromArgb(230, 25, 25)  }
        default  { $light = [System.Drawing.Color]::FromArgb(240, 240, 240); $dark = [System.Drawing.Color]::FromArgb(150, 150, 150) }
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
    $wire  = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(150, 15, 15, 15)), $wireW
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
    $vig.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(70, 0, 0, 0))
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
