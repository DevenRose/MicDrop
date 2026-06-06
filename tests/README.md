# Tests

Emulated tests for MicDrop's core logic — **no headset required**. The Windows
PnP cmdlets (`Get-PnpDevice`, `Enable-PnpDevice`, `Disable-PnpDevice`) are mocked,
so each headset "combo" is simulated in three states: **mic on**, **stereo-locked**,
and **disconnected**.

## Run

```powershell
# one-time, if you don't have Pester 5+
Install-Module Pester -Scope CurrentUser -Force

Invoke-Pester -Path .\tests
```

## Add your headset

Open [`MicDrop.Tests.ps1`](MicDrop.Tests.ps1) and add a line to the `-ForEach`
list with your headset's name and the pattern you'd put in `config.json`:

```powershell
@{ Name = 'Your Headset XYZ'; Pattern = 'XYZ' }
```

Then run the tests and, if anything misbehaves on real hardware,
[open a combo report](../.github/ISSUE_TEMPLATE/combo-report.md) — beta reports
drive the fix list.
