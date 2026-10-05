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

## Recovery

Exit MicDrop Equalizer through its tray menu before recovery. Restore the backed-up config.txt and Peace shortcut, then deliberately launch original Peace.exe. The original .peace presets and theme have never been removed. Do not run both frontends together because each manages its own active equalizer configuration.
