---
name: Headset combo report
about: Tell us whether MicDrop worked with your headset (beta feedback)
title: "[combo] <headset name>"
labels: ["combo-report"]
---

<!-- Beta feedback drives the fix list. Even "it just worked" reports help! -->

**Headset**: <!-- e.g. Sony WH-1000XM4 -->
**config.json pattern you used**: <!-- e.g. "WH-1000XM4", or empty/all -->
**Windows version**: <!-- Win + R -> winver -->
**Result**:
- [ ] ✅ Worked — stereo lock held, mic toggled back fine
- [ ] ⚠️ Partly worked (explain below)
- [ ] ❌ Didn't work (explain below)

**What happened / anything weird?**


**Output of this command (helps a lot):**
```powershell
Get-PnpDevice -Class MEDIA | Where-Object InstanceId -like 'BTHHFENUM*' |
  Select-Object Status, FriendlyName, InstanceId | Format-Table -Auto
```

---
*Got a different tech problem you'd like solved next? Mention it — we're
collecting what to build after MicDrop.*
