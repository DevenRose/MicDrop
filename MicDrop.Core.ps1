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
      Draws an SM58-style mic ball-grille (sphere + diamond mesh), tinted as a
      soundboard indicator light, with a power-style glyph:
        'Mic'    -> GREEN grille, glyph "I"  (mic ON / available)
        'Stereo' -> RED   grille, glyph "0"  (mic OFF / stereo-locked)
        other    -> gray  grille             (headset not connected)
      Returns a System.Drawing.Bitmap (caller converts to Icon / saves as needed).
    #>
    param([string]$State = 'Mic', [int]$Size = 32)

    switch ($State) {
        'Mic'    { $light = [System.Drawing.Color]::FromArgb(175, 255, 150); $dark = [System.Drawing.Color]::FromArgb(20, 130, 38); $glyph = 'I' }
        'Stereo' { $light = [System.Drawing.Color]::FromArgb(255, 150, 130); $dark = [System.Drawing.Color]::FromArgb(155, 16, 16); $glyph = '0' }
        default  { $light = [System.Drawing.Color]::FromArgb(205, 205, 205); $dark = [System.Drawing.Color]::FromArgb(95, 95, 95);  $glyph = ''  }
    }

    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    $m = [int][math]::Round($Size * 0.06)
    $d = $Size - 2 * $m
    $rect = New-Object System.Drawing.Rectangle $m, $m, $d, $d

    # spherical metallic gradient (highlight offset up-left)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse($rect)
    $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
    $pgb.CenterColor = $light
    $pgb.SurroundColors = [System.Drawing.Color[]]@($dark)
    $pgb.CenterPoint = New-Object System.Drawing.PointF (($m + $d * 0.36), ($m + $d * 0.32))
    $g.FillPath($pgb, $path)

    # SM58 grille: diamond cross-hatch mesh, clipped to the ball
    $g.SetClip($path)
    $mesh = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(70, 0, 0, 0)), ([single][math]::Max(1, $Size / 26))
    $step = [int][math]::Max(3, $Size / 8)
    for ($i = -$Size; $i -le ($Size * 2); $i += $step) {
        $g.DrawLine($mesh, $i, 0, ($i + $Size), $Size)
        $g.DrawLine($mesh, $i, $Size, ($i + $Size), 0)
    }
    $g.ResetClip(); $mesh.Dispose()

    # dark rim for definition
    $rim = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(165, 0, 0, 0)), ([single][math]::Max(1, $Size / 22))
    $g.DrawEllipse($rim, $rect); $rim.Dispose()

    # gloss highlight (soft white)
    $gw = [int]($d * 0.42); $gh = [int]($gw * 0.7)
    $gloss = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gloss.AddEllipse(($m + [int]($d * 0.17)), ($m + [int]($d * 0.11)), $gw, $gh)
    $gb = New-Object System.Drawing.Drawing2D.PathGradientBrush($gloss)
    $gb.CenterColor = [System.Drawing.Color]::FromArgb(140, 255, 255, 255)
    $gb.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(0, 255, 255, 255))
    $g.FillPath($gb, $gloss); $gb.Dispose(); $gloss.Dispose()

    # power-style glyph on top: I (on) / 0 (off), white with a soft dark shadow
    $cx = $Size / 2.0; $cy = $Size / 2.0
    if ($glyph -eq 'I') {
        $bw = [int][math]::Max(2, [math]::Round($Size * 0.12))
        $bh = [int][math]::Round($d * 0.46)
        $bx = [int]($cx - $bw / 2.0); $by = [int]($cy - $bh / 2.0)
        $sh = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(130, 0, 0, 0))
        $g.FillRectangle($sh, $bx + 1, $by + 1, $bw, $bh); $sh.Dispose()
        $wh = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(245, 255, 255, 255))
        $g.FillRectangle($wh, $bx, $by, $bw, $bh); $wh.Dispose()
    } elseif ($glyph -eq '0') {
        $ow = [int][math]::Round($d * 0.36); $oh = [int][math]::Round($d * 0.52)
        $ox = [int]($cx - $ow / 2.0); $oy = [int]($cy - $oh / 2.0)
        $pw = [single][math]::Max(2, $Size * 0.11)
        $shp = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(130, 0, 0, 0)), $pw
        $g.DrawEllipse($shp, $ox + 1, $oy + 1, $ow, $oh); $shp.Dispose()
        $whp = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(245, 255, 255, 255)), $pw
        $g.DrawEllipse($whp, $ox, $oy, $ow, $oh); $whp.Dispose()
    }

    $pgb.Dispose(); $path.Dispose(); $g.Dispose()
    return $bmp
}
