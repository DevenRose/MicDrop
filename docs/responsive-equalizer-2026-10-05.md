# MicDrop Equalizer — responsive TOZO controls

Captain requires free resizing, maximizing, controls that adapt, working text-size changes, standard frequency bands, full headphone playback range outside calls, a call-specific set based on actual supported formats, and both tray/taskbar icons. He explicitly authorizes rewriting the program as needed. The prior Peace font-only change failed his clipping check.

## Installed replacement

The native Windows app is built from `audio-setup/MicDropEqualizer.cs` using Windows' existing .NET/WPF assemblies. Its controls wrap into additional rows at narrow widths and scroll when needed. Fonts change immediately. Standard graphic layouts have 10, 15 or 31 frequency points. No zero-frequency placeholders are generated. The window has a normal maximize button, resizable borders, taskbar entry and microphone icon. Close hides the window to its tray icon; double-click the tray icon restores it. Tray Exit stops this interface; Equalizer APO remains installed and processing.

The default is the standard 31-band third-octave series, 20 Hz–20 kHz for normal playback. The connected TOZO HT3 is read through Windows Core Audio: actual render mix format 48 kHz; actual microphone mix format 16 kHz. Call/voice layouts retain supported standard centers below half the actual sample rate, resulting in 26 centers through 6.3 kHz on this headset. This is a standard-band selection, not an added low-pass restriction. Windows' Bluetooth transport determines the physical bandwidth. The normal playback curve keeps its full range and switches to the separate call curve only while the TOZO microphone has an active audio session. A quiet simultaneous stream test proved detection of inactive → active → inactive capture sessions.

Standard playback profiles initially have flat gain with -3 dB headroom. Original voice shaping is imported exactly from TOZO Voice.peace (80 Hz high-pass, 250 Hz -2 dB and 2.5 kHz +2 dB on this installation), with the standard graphic points initially flat. Further positive graphic boosts receive additional negative preamp headroom. Existing Peace files and recent user adjustments are preserved in a full local backup before integration. This frontend implements the requested playback/voice/call graphic EQ controls; Peace's other effect, measurement and graph interfaces remain in the preserved original program.

## Installation actions

Home repo: `X:\Repos\MicDrop`. Existing branch and PR #6 are used; main and SOTU are not changed.

Repeated pre-install process observations found no running Peace or MicDropEqualizer process after Captain closed Peace himself. No protected active-app interruption is required for this cutover. The first-install script refuses to act if either app is running, refuses to overwrite a previous installation, and requires exactly one known Peace include.

1. Back up the full installed config folder and existing Peace Start-menu shortcut under `X:\Downloads\MicDrop-EQ-2026-10-05\before-responsive-equalizer-<timestamp>`.
2. Add the locally compiled (unsigned) MicDropEqualizer.exe to `C:\Program Files\EqualizerAPO\config`; leave the original signed Peace.exe intact.
3. Read and verify actual TOZO formats, initialize the new local profiles and `micdrop-eq.txt` without showing a window.
4. Change only the active include in config.txt, from `Include: peace.txt` to `Include: micdrop-eq.txt`; preserve its other text.
5. Replace the Start-menu Peace Equalizer shortcut with MicDrop Equalizer. No automatic startup, service, system reboot, audio restart or desktop activation is introduced.
6. Verify processing through Equalizer APO and a separate-desktop app instance, close only that agent-created test instance, and leave deliberate launch to Captain.

## Preparation verification

Native resize and framework reflow throwaway proofs passed before implementation. The full build passed narrow (360 px), wide (1250 px), 24-point text and maximized window tests, restore, taskbar/tray properties, band-family changes, synchronized slider/numeric gain values, independent normal/call curves and boost headroom. Actual control bounds reported zero clipped frequency/gain labels. Rendered PNGs were visually inspected. Actual Core Audio formats were verified rather than assumed. A separate eight-second read-only mode probe saw 30 inactive and 10 active TOZO capture-session observations during a two-second simultaneous microphone/silent-output test; the streams processed 32,000 input and 96,960 output frames with no flags and no audio retained. All tests ran against throwaway files; input desktop stayed Default and every test process exited.

Installed at `C:\Program Files\EqualizerAPO\config\MicDropEqualizer.exe`, with the Start-menu shortcut available now. Recovery backup: `X:\Downloads\MicDrop-EQ-2026-10-05\before-responsive-equalizer-20261005-164908`. Original Peace.exe remains intact.

Installed-engine verification passed for normal playback, microphone and legacy call playback; an unrelated output was unchanged. The installed interface switched normal → call → normal when the actual TOZO capture session opened and closed. Live playback measured -6.23 dB for a temporary -6 dB test; recovery was within 0.06 dB. Live microphone processing reached exact digital silence under a temporary mute and recovered. Both checks restored the configuration exactly and saved only aggregate measurements. The agent-created interface was closed on its separate desktop; no Captain desktop input or activation occurred.

Captain reported a high-pitched whine during this verification. The playback test emitted a 2,390 Hz tone at -40 dBFS, which is a plausible cause, not a confirmed acoustic diagnosis. That test ended and its streams closed. A subsequent three-second read-only playback observation, without opening output or microphone streams, measured that frequency at -70.83 dBFS against overall RMS 0.169; dominant spectral peaks were around 42–47 Hz. No strong persistent test tone was detected in the Windows output. The loaded playback curve is flat with -3 dB headroom. No further audible test tones will be emitted. Captain's confirmation that the whine has stopped and final listening acceptance remain outstanding; do not claim the overall setup complete.

## Usage

Open Start and search MicDrop Equalizer. Drag the window borders or maximize using the title bar. Editing chooses Normal playback, Call playback or My microphone; Bands chooses 10, 15 or 31; Text size applies immediately. Adjust a slider or enter its gain and press Enter. Changes save automatically. Closing the window keeps the app in the tray, where it can switch between normal and call curves while Captain uses the TOZO microphone. Double-click its tray microphone icon to reopen it; it also appears on the taskbar while open. Keep this interface running in the tray for automatic call-mode switching.

### Find the controls

1. Press the Windows key, type **MicDrop Equalizer**, and select the matching app. The window title is **MicDrop Equalizer · TOZO HT3**; the heading inside is **TOZO HT3 Equalizer**. No automatic launch was added.
2. Immediately below that heading, **Editing** is the first dropdown, **Bands** is next, and **Text size** follows. **Flat bands** and **To tray** are buttons after those dropdowns. On a narrow window they wrap onto another line. The text below reports the active output mode and selected profile's frequency range.
3. Choose **Normal playback** to adjust media when the headset microphone is not in use; choose **Call playback** for what you hear while it is in use; choose **My microphone** for your transmitted voice. Choosing a profile edits it; it does not force a Bluetooth mode or disable the other profiles.
4. Choose **31 · third octave** for the default full set, or **10 · octave** / **15 · two-thirds octave** for fewer controls. Each frequency has a vertical slider and a numeric gain box underneath. Drag the slider or type a gain in that box and press Enter. Gains are decibels; changes save automatically.
5. For larger text choose **Text size**, then **16 pt**, **18 pt** or **24 pt**. Use the square maximize button between the minimize dash and close X at the upper right, or drag any window border. Controls wrap as width changes; scroll downward for remaining bands in a small window.
6. The tray icon is a cyan microphone on a dark square beside the Windows clock. If Windows hides it, click the small up-arrow beside the clock. Double-click that microphone to restore the window. Right-click it for Show/Hide/Exit. Close X and **To tray** hide the window while retaining automatic call detection. **Exit** stops detection and restores the normal playback curve; APO processing remains installed.

### Personal listening check

1. With the TOZO headset connected and no application using its microphone, play familiar music at your usual comfortable volume. The status should say **Active output: normal playback · full range**. Check that the whine is gone and playback sounds acceptable. Opening this app generates no sound.
2. Check resize, maximize and your preferred text size now; confirm frequency labels and gain boxes remain readable. The standard curve starts flat, so adjust it to taste if needed; it is not a measured headphone correction.
3. Start your usual call or its own microphone test. Its microphone must be **Headset (TOZO HT3)** and its speaker **Headphones (TOZO HT3)**. Windows communications defaults already select those devices, but an application using the ordinary input default may choose the laptop mic. The equalizer status should change to **Active output: call playback · TOZO microphone is in use**. Speak and check your voice plus PC media output. End the call/mic test; status should return to normal playback.
4. The original MicDrop tray tool's **Stereo** lock disables the headset microphone. If you previously selected that lock, right-click its separate tray icon and choose **Mic** before calling. Enabling the microphone does not itself select this equalizer's call curve; an active microphone session does.
5. Report whether the whine is gone, whether the window/text controls work, and whether media and your voice are acceptable. If a call app chooses the wrong mic or speaker, provide its name so its exact menus can be inspected before giving UI instructions. No acceptance is inferred from silence or passing automated tests.

## Recovery

Exit MicDrop Equalizer through its tray menu before recovery. Restore the backed-up config.txt and Peace shortcut, then deliberately launch original Peace.exe. The original .peace presets and theme have never been removed. Do not run both frontends together because each manages its own active equalizer configuration.
