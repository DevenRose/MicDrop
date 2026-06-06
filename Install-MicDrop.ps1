<#
.SYNOPSIS
  Install MicDrop: auto-start the tray app (elevated) at logon and pin it
  always-visible in the system tray. Self-elevates with one UAC prompt.
  Reverse with Uninstall-MicDrop.ps1.
#>

$TaskName = 'MicDrop-Tray'
$trayPath = Join-Path $PSScriptRoot 'MicDrop-Tray.ps1'

# --- self-elevate ---
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevating (UAC prompt)..." -ForegroundColor Yellow
    Start-Process pwsh -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    return
}

if (-not (Test-Path $trayPath)) { Write-Error "MicDrop-Tray.ps1 not found at $trayPath"; return }

# --- 1. scheduled task: run elevated at logon, no time limit ---
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$trayPath`""
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null
Write-Host "[1/3] Scheduled task '$TaskName' registered (elevated, at logon)." -ForegroundColor Green

# --- 2. start now ---
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 4
Write-Host "[2/3] Tray app started (look for the round S/M icon)." -ForegroundColor Green

# --- 3. pin always-visible (Windows 11 NotifyIconSettings) ---
$base = 'HKCU:\Control Panel\NotifyIconSettings'
$pinned = $false
if (Test-Path $base) {
    Get-ChildItem $base | ForEach-Object {
        $p = Get-ItemProperty $_.PSPath -EA SilentlyContinue
        if ($p.ExecutablePath -like '*powershell.exe' -and $p.InitialTooltip -like 'MicDrop*') {
            Set-ItemProperty $_.PSPath -Name IsPromoted -Value 1 -Type DWord
            $script:pinned = $true
        }
    }
}
Write-Host ("[3/3] Always-visible pin: {0}" -f ($(if ($pinned) { 'set' } else { 'pending' }))) -ForegroundColor Green
if (-not $pinned) {
    Write-Host "    (Re-run this installer once the icon has appeared, or drag the" -ForegroundColor DarkYellow
    Write-Host "     S/M icon from the overflow (^) onto the taskbar to pin it.)" -ForegroundColor DarkYellow
}
Write-Host "`nDone. Remove anytime with Uninstall-MicDrop.ps1" -ForegroundColor Cyan
Start-Sleep -Seconds 2
