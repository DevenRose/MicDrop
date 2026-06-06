<#
.SYNOPSIS
  Remove MicDrop (scheduled task + running tray process). Leaves the headset
  mic ENABLED. Self-elevates with one UAC prompt.
#>
$TaskName = 'MicDrop-Tray'

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevating (UAC prompt)..." -ForegroundColor Yellow
    Start-Process pwsh -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    return
}

# stop the running tray process
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -EA SilentlyContinue |
    Where-Object { $_.CommandLine -like '*MicDrop-Tray.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }

# remove the scheduled task
if (Get-ScheduledTask -TaskName $TaskName -EA SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed scheduled task '$TaskName'." -ForegroundColor Green
} else {
    Write-Host "No scheduled task '$TaskName' found." -ForegroundColor DarkYellow
}

# re-enable any Bluetooth hands-free device left disabled
Get-PnpDevice -Class MEDIA -EA SilentlyContinue |
    Where-Object { $_.InstanceId -like 'BTHHFENUM*' -and $_.Status -ne 'OK' } |
    ForEach-Object { $_ | Enable-PnpDevice -Confirm:$false; Write-Host "Re-enabled mic: $($_.FriendlyName)" -ForegroundColor Green }

Write-Host "Done. Mic left enabled." -ForegroundColor Cyan
Start-Sleep -Seconds 2
