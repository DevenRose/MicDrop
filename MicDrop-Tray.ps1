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
$script:ConfigPath = Join-Path $PSScriptRoot 'config.json'
$script:Pattern = Resolve-MicDropPattern -ConfigPath $script:ConfigPath
$script:ManageFxSound = Resolve-MicDropManageFxSound -ConfigPath $script:ConfigPath
$script:askedForFeedback = $false
$script:prevState = $null

function Repair-MicDropFxSound {
    # Snap FxSound's output back to the headset (no-op if FxSound isn't installed
    # or already correct). Best-effort: never let it break the tray.
    if (-not $script:ManageFxSound) { return }
    try { [void](Set-MicDropFxSound -Pattern $script:Pattern) } catch {}
}

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
$miFixSnd = $menu.Items.Add('Fix silent headset  (restart FxSound)')
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

    # Headset just (re)connected (or tray just started) -> FxSound may have drifted
    # to the speakers; snap it back.
    if ($connected -and $script:prevState -in @($null, 'Disconnected')) { Repair-MicDropFxSound }
    $script:prevState = $state
}

function Invoke-Stereo {
    Set-MicDropStereo -Pattern $script:Pattern
    Start-Sleep -Milliseconds 800
    Repair-MicDropFxSound
    Update-Ui
    # one-time gentle nudge at the "solved" moment
    if (-not $script:askedForFeedback) {
        $script:askedForFeedback = $true
        $ni.BalloonTipTitle = 'Audio locked to stereo 🎧'
        $ni.BalloonTipText  = 'Got another tech problem? Right-click the icon to tell us.'
        $ni.ShowBalloonTip(6000)
    }
}
function Invoke-Mic { Set-MicDropMic -Pattern $script:Pattern; Start-Sleep -Milliseconds 800; Repair-MicDropFxSound; Update-Ui }

function Invoke-FixSilentHeadset {
    # Manual recovery for a wedged/silent FxSound render (e.g. right after saving an
    # EQ preset): a restart is the only thing that fixes it -- a re-pin can't, since
    # the stored device is still correct. User-invoked, so run regardless of the
    # manageFxSound setting.
    $restarted = $false
    try { $restarted = [bool](Restart-MicDropFxSound) } catch {}
    $ni.BalloonTipTitle = if ($restarted) { 'Restarting FxSound 🎧' } else { 'FxSound not found' }
    $ni.BalloonTipText  = if ($restarted) { 'Headset sound should return in a second.' } else { "Couldn't find FxSound to restart." }
    $ni.ShowBalloonTip(4000)
}

$miStereo.add_Click({ Invoke-Stereo })
$miMic.add_Click({ Invoke-Mic })
$miFixSnd.add_Click({ Invoke-FixSilentHeadset })
$miMore.add_Click({ Start-Process "$script:MicDropRepoUrl/discussions" })
$miTip.add_Click({ Start-Process $script:MicDropTipUrl })
$miExit.add_Click({
    $timer.Stop()
    if ($script:fxTimer) { $script:fxTimer.Stop() }
    if ($script:devWatcher) { $script:devWatcher.Dispose() }
    $ni.Visible = $false; $ni.Dispose(); [System.Windows.Forms.Application]::Exit()
})
$ni.add_MouseDoubleClick({
    $s = Get-MicDropState -Pattern $script:Pattern
    if ($s -eq 'Mic') { Invoke-Stereo } elseif ($s -eq 'Stereo') { Invoke-Mic }
})

# refresh every 5s to catch connect/disconnect & external changes
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.add_Tick({ Update-Ui })
$timer.Start()

# --- FxSound drift heal on device-change ---------------------------------------
# FxSound silently drifts its output off the headset when USB/Bluetooth devices
# come or go (e.g. unplugging a phone) -- but the headset itself stays connected,
# so the reconnect heal in Update-Ui never sees it. A hidden message-only window
# receives WM_DEVICECHANGE on the UI thread; we record the time and let a debounced
# timer re-pin once the audio endpoints settle. Only fires on real device events,
# never on a steady-state poll, so it won't fight a deliberate speaker choice.
$script:devWatcher = $null
$script:fxTimer    = $null
if ($script:ManageFxSound) {
    try {
        Add-Type -ReferencedAssemblies 'System.Windows.Forms' -TypeDefinition @'
using System;
using System.Windows.Forms;
public class MicDropDeviceWatcher : NativeWindow, IDisposable {
    public DateTime LastChange = DateTime.MinValue;
    public MicDropDeviceWatcher() { CreateHandle(new CreateParams()); }
    protected override void WndProc(ref Message m) {
        if (m.Msg == 0x0219) { LastChange = DateTime.Now; } // WM_DEVICECHANGE
        base.WndProc(ref m);
    }
    public void Dispose() { if (Handle != IntPtr.Zero) DestroyHandle(); }
}
'@ -ErrorAction SilentlyContinue

        $script:devWatcher = New-Object MicDropDeviceWatcher

        $script:fxTimer = New-Object System.Windows.Forms.Timer
        $script:fxTimer.Interval = 1000
        $script:fxTimer.add_Tick({
            if (Test-MicDropFxRepairDue -LastChange $script:devWatcher.LastChange -Now (Get-Date)) {
                $script:devWatcher.LastChange = [datetime]::MinValue
                Repair-MicDropFxSound
                Update-Ui
            }
        })
        $script:fxTimer.Start()
    } catch {
        # best-effort: a watcher failure must never keep the tray from starting
        $script:devWatcher = $null; $script:fxTimer = $null
    }
}

Update-Ui
[System.Windows.Forms.Application]::Run()
