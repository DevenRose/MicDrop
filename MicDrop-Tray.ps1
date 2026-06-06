<#
.SYNOPSIS
  MicDrop system-tray app. Toggles a Bluetooth headset between stereo-lock
  (mic off) and normal (mic on).

  Icon:  S (green)=stereo-locked/mic off   M (blue)=mic on   - (gray)=not connected
  Double-click flips state. Right-click for menu.

  MUST run elevated + STA. Launch via Install-MicDrop.ps1.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

. (Join-Path $PSScriptRoot 'MicDrop.Core.ps1')
$script:Pattern = Resolve-MicDropPattern -ConfigPath (Join-Path $PSScriptRoot 'config.json')
$script:askedForFeedback = $false

$script:lastIcon = $null
function New-StateIcon([string]$state) {
    # SM58-style grille bitmap from the shared core
    $bmp = New-MicDropBitmap -State $state -Size 32
    $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    $bmp.Dispose()
    return $icon
}

$ni = New-Object System.Windows.Forms.NotifyIcon
$ni.Text = 'MicDrop'   # becomes InitialTooltip -> installer uses it to pin the icon
$ni.Visible = $true

$menu     = New-Object System.Windows.Forms.ContextMenuStrip
$miStereo = $menu.Items.Add('Stereo-only  (mic OFF, no dropouts)')
$miMic    = $menu.Items.Add('Mic available  (normal)')
$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
$miMore   = $menu.Items.Add('Got another tech problem? Tell us')
$miTip    = $menu.Items.Add('Tip the developer  (it''s free - tips optional)')
$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
$miExit   = $menu.Items.Add('Exit')
$ni.ContextMenuStrip = $menu

function Update-Ui {
    $state = Get-MicDropState -Pattern $script:Pattern
    $icon = New-StateIcon $state
    $ni.Icon = $icon
    if ($script:lastIcon) { $script:lastIcon.Dispose() }
    $script:lastIcon = $icon
    switch ($state) {
        'Stereo' { $ni.Text = 'MicDrop: STEREO-LOCKED (mic off)' }
        'Mic'    { $ni.Text = 'MicDrop: mic available' }
        default  { $ni.Text = 'MicDrop: headset not connected' }
    }
    $connected = $state -ne 'Disconnected'
    $miStereo.Checked = ($state -eq 'Stereo'); $miStereo.Enabled = $connected
    $miMic.Checked    = ($state -eq 'Mic');    $miMic.Enabled    = $connected
}

function Invoke-Stereo {
    Set-MicDropStereo -Pattern $script:Pattern
    Start-Sleep -Milliseconds 800
    Update-Ui
    # one-time gentle nudge at the "solved" moment
    if (-not $script:askedForFeedback) {
        $script:askedForFeedback = $true
        $ni.BalloonTipTitle = 'Audio locked to stereo 🎧'
        $ni.BalloonTipText  = 'Got another tech problem? Right-click the icon to tell us.'
        $ni.ShowBalloonTip(6000)
    }
}
function Invoke-Mic { Set-MicDropMic -Pattern $script:Pattern; Start-Sleep -Milliseconds 800; Update-Ui }

$miStereo.add_Click({ Invoke-Stereo })
$miMic.add_Click({ Invoke-Mic })
$miMore.add_Click({ Start-Process "$script:MicDropRepoUrl/discussions" })
$miTip.add_Click({ Start-Process $script:MicDropTipUrl })
$miExit.add_Click({ $timer.Stop(); $ni.Visible = $false; $ni.Dispose(); [System.Windows.Forms.Application]::Exit() })
$ni.add_MouseDoubleClick({
    $s = Get-MicDropState -Pattern $script:Pattern
    if ($s -eq 'Mic') { Invoke-Stereo } elseif ($s -eq 'Stereo') { Invoke-Mic }
})

# refresh every 5s to catch connect/disconnect & external changes
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.add_Tick({ Update-Ui })
$timer.Start()

Update-Ui
[System.Windows.Forms.Application]::Run()
