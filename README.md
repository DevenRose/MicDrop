# MicDrop 🎤⤵️

**Stop your Bluetooth headset audio from dying the moment an app touches the mic.**

MicDrop is a tiny Windows tray tool that locks a Bluetooth headset into **stereo
(A2DP)** on demand — and flips the mic back on with one click when you need it.
Works with **any** Bluetooth headset (AirPods, Sony, Bose, Jabra, …).

---

## The problem

A Bluetooth headset can only be in **one** audio profile at a time:

| Profile | Quality | Used for |
|---------|---------|----------|
| **A2DP** | Stereo, full quality | Music, video |
| **HFP** (Hands-Free) | Mono + microphone | Calls, voice input |

The instant *any* app opens the mic — Teams, Discord, a browser tab, a background
process — Windows flips the headset from A2DP stereo to **HFP mono**. Symptoms:

- Audio suddenly goes **silent** while the video/song is still "playing."
- Sound drops to **tinny / muffled** mono.
- EQ/router tools (FxSound, Equalizer APO, …) keep playing into a now-dead
  endpoint → **silence with the meter still moving**.

It often won't recover until you reconnect the headset. → [Full explanation](docs/how-it-works.md).

## The fix

MicDrop **disables the headset's Hands-Free (HFP) node**, forcing it to stay in
A2DP stereo. Nothing can switch it to mono, so your audio can't be hijacked. One
click restores the mic.

> **Trade-off:** while stereo-locked, the **mic is off** — that's the point, and
> it's instantly reversible. Flip back to "Mic" mode before a call.

No drivers, no audio-stack hacks — just one standard Windows device, toggled.

---

## Install

Requires **Windows 10/11** + **PowerShell**. Device toggling needs admin, so the
scripts self-elevate (one UAC prompt).

```powershell
# 1. (optional) target a specific headset
copy config.example.json config.json      # then set "deviceNamePattern", e.g. "TOZO HT3"
#    leave it empty to target ALL connected Bluetooth hands-free devices

# 2. install the tray app + auto-start at logon
.\Install-MicDrop.ps1
```

A mic-grille tray icon appears — soundboard-style indicator light:

| Icon | State | |
|------|-------|---|
| 🟢 **I** | **Mic ON** — normal | |
| 🔴 **0** | **Mic OFF** — stereo-locked, can't be hijacked | |
| ⚫ | headset not connected | |

**Double-click** = flip. **Right-click** = menu (Stereo / Mic / feedback / tip / Exit).

## Use without the tray (CLI)

```powershell
.\Toggle-Mic.ps1 -Mode Stereo                 # lock stereo, mic OFF
.\Toggle-Mic.ps1 -Mode Mic                     # restore the mic
.\Toggle-Mic.ps1                               # flip current state
.\Toggle-Mic.ps1 -DeviceNamePattern "WH-1000XM4"
```

## Uninstall

```powershell
.\Uninstall-MicDrop.ps1     # removes tray + auto-start, leaves your mic ENABLED
```

---

## Headsets

Headset-agnostic — works with anything that connects over Bluetooth with a mic.
See the [compatibility list](docs/headsets.md) and tell us how yours did with a
[combo report](.github/ISSUE_TEMPLATE/combo-report.md).

## Tests

Emulated — **no hardware needed**. The PnP layer is mocked, so every headset combo
is simulated in mic-on / stereo-locked / disconnected states:

```powershell
Install-Module Pester -Scope CurrentUser -Force   # one-time
Invoke-Pester -Path .\tests
```

## Not on Windows?

The automated fix is Windows-only (it relies on the Windows PnP layer). The same
*problem* has manual fixes elsewhere — quick pointers in
[how-it-works.md](docs/how-it-works.md#why-its-windows-only) (iOS: revoke app mic
permission · Android: turn off the device's "Phone calls" profile · macOS: set
input to the built-in mic).

## Roadmap & feedback

Solved your problem? **Tell us what's broken next** — the tray's *"Got another
tech problem?"* item and [Discussions](https://github.com/OWNER/MicDrop/discussions)
feed the [roadmap](docs/roadmap.md).

## Support

MicDrop is free and stays free. Tips optional, never required — **Sponsor** button
/ [FUNDING.yml](.github/FUNDING.yml).

## License

[MIT](LICENSE).

---
*Repo URLs and tip handles contain `OWNER` placeholders — replace them after you
create the GitHub repo (`MicDrop.Core.ps1`, `.github/FUNDING.yml`, docs).*
