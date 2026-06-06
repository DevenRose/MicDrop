# How MicDrop works

## The root cause

A Bluetooth headset can run in only one audio profile at a time:

| Profile | Quality | Carries mic? | Windows endpoint |
|---------|---------|--------------|------------------|
| **A2DP** | Stereo, full bandwidth | No | "Headphones (Your Headset)" |
| **HFP** (Hands-Free) | Mono, low bandwidth | Yes | "Headset (Your Headset Hands-Free)" |

When any app opens the microphone, Windows switches the headset to **HFP** so the
mic works — which drops it out of **A2DP stereo**. If your output was pinned to
the A2DP endpoint (directly, or via an EQ/router like FxSound or Equalizer APO),
that endpoint goes inactive and you get **silence with the meter still moving**,
or a sudden drop to tinny mono. It often won't recover until you reconnect.

## What MicDrop does

The HFP function enumerates as a **MEDIA**-class PnP device whose instance ID
begins with `BTHHFENUM\BTHHFPAUDIO`. MicDrop simply:

```powershell
Get-PnpDevice -Class MEDIA | Where-Object InstanceId -like 'BTHHFENUM*' | Disable-PnpDevice
```

With the HFP node disabled, Windows has no mono path to switch to, so the headset
**stays in A2DP stereo** no matter what grabs the mic. Re-enabling it restores
the microphone. That's the whole trick — one standard device, toggled.

## Why this is safe

- It touches **one** standard Windows device node — no audio drivers, no system
  files, no changes to your default-device or EQ setup.
- Disable/enable is exactly what Device Manager does; fully reversible.
- If MicDrop isn't running, your headset behaves like stock Windows.

## Why it's Windows-only

The fix depends on Windows exposing the HFP profile as a toggleable PnP device.
Other OSes don't allow that from userland:

- **iOS/iPadOS** — no device-profile scripting at all. Manual equivalent: revoke
  Microphone permission from the offending app (Settings → Privacy → Microphone).
- **Android** — no script needed: per paired device, turn **off "Phone calls"**
  (HFP/HSP) under Bluetooth device settings to keep it media-only.
- **macOS** — set the system **input** to the built-in mic so apps don't pull the
  headset into HFP (`SwitchAudioSource -t input -s "MacBook Pro Microphone"`).
