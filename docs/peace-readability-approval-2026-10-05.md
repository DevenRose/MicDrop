# Peace readability fix — exact interruption request

Captain requested: “Why can't I adjust the size of the window or maximize it? Can you fix tht?” and “Selecting font size does fucking nothing. Fix it”. Themes are already resolved and will not be changed.

Prepared changes to `C:\Program Files\EqualizerAPO\config\peace.ini`, General section:

| Setting | Before | After |
|---|---:|---:|
| Font Size | 8.5 | 12 |
| Slider X Space | 2 | 4 |
| Slider Thumb Width | 22 | 32 |
| Device List Width | 185 | 260 |
| Configurations Width | 200 | 280 |
| Configurations Height | 165 | 220 |
| dB Slider Height | 300 | 350 |

All EQ presets, audio routing, theme, volume and other preferences stay as saved. Back up the existing INI locally before applying the prepared patch, and verify every changed setting afterward.

Request to be presented, recorded before asking:

“May I close only Peace, apply the prepared 12-point text and larger-control settings, and verify them on a separate desktop?”

Disclosure: this closes Captain's current Peace settings window and can discard unsaved edits. It does not close another app, switch desktops, restart audio, or stop Equalizer APO processing. The verified GUI will be closed on the separate desktop; Captain then deliberately opens Peace from Start to see the result. Normal drag-resizing and maximizing are not added by this preference patch.

Why approval is needed: Constitution says “Never reset, restart, reload, relaunch, close, terminate, replace, or abandon the active app, IDE, session, task, or conversation without Captain's explicit permission for that exact interruption.” The font/layout fix is authorized, but closing the current Peace settings window is the specific interruption now requiring permission.

Answer: Captain replied “yes” on 2026-10-05 (America/Denver), approving this exact interruption and prepared patch. Record written before closing Peace or changing its installed preferences.

Result: applied and verified. Peace PID 5164 closed through its vendor MainActions API (normal exit verified). All seven approved settings changed. The isolated test PID 42064 loaded 12-point fonts on 208 controls; its main window measured 856×734 versus 776×674 before. Input desktop remained Default throughout. The isolated test copy then closed normally. All saved EQ, preset and configuration files were byte-identical after the test; the final INI exactly matched the approved patch. Windows audio and Bluetooth services remained running. Captain can open Peace from Start to see the larger interface.

Local recovery backup: `X:\Downloads\MicDrop-EQ-2026-10-05\peace-readability-before-20261005-161839`. Actual loaded-font evidence: `audio-setup/peace-readability-verification.json`. This fixes the saved font size and enlarges the supported layout dimensions; native drag-resizing and maximizing remain unavailable in the vendor interface.
