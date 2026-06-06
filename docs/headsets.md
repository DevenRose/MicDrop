# Headset compatibility

MicDrop is **headset-agnostic**. It targets the Bluetooth Hands-Free node
(`BTHHFENUM\BTHHFPAUDIO`), which **every** Bluetooth headset/earbud exposes on
Windows — so if your headset connects over Bluetooth and has a mic, MicDrop can
lock it to stereo.

Set `deviceNamePattern` in `config.json` to your headset's name (or leave it
empty to target all connected Bluetooth hands-free devices).

## Reported combos

> This table grows from beta reports. Tested one? File a
> [combo report](../.github/ISSUE_TEMPLATE/combo-report.md).

| Headset | `deviceNamePattern` | Status |
|---------|---------------------|--------|
| TOZO HT3 | `TOZO HT3` | ✅ Verified |
| Apple AirPods / AirPods Pro | `AirPods` | 🧪 Emulated test only |
| Sony WH-1000XM series | `WH-1000XM4` | 🧪 Emulated test only |
| Bose QuietComfort | `Bose` | 🧪 Emulated test only |
| Jabra Elite | `Jabra` | 🧪 Emulated test only |
| Samsung Galaxy Buds | `Galaxy Buds` | 🧪 Emulated test only |

**Legend:** ✅ confirmed on real hardware · 🧪 covered by emulated tests, awaiting
a real-hardware report.

## Find your headset's exact name

```powershell
Get-PnpDevice -Class MEDIA | Where-Object InstanceId -like 'BTHHFENUM*' |
  Select-Object Status, FriendlyName
```

Use any unique part of the `FriendlyName` (minus the "Hands-Free" suffix) as your
pattern.
