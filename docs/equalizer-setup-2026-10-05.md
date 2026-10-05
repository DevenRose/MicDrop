# TOZO HT3 equalizer setup — 2026-10-05

## Captain's request

“Work in the micdrop repo. Read about my bluetooth headset and my system and settings---consult PE if needed. Download and install Equalizer APO and Peace Equalizer and configure apprpriately. Confirm before installation that it works with bluetooth and that i can use it in mic mode for calls to eq my voice and the pc media output.”

Captain additionally requested explicit step-by-step instructions if a restriction prevents completion.

## Observed before installation

- Home repo: `X:\Repos\MicDrop`. Constitution, global handoff, PAB-Memory SOTU, roster registry, MicDrop instructions and memory log loaded. MicDrop has no current repository handoff. DRVI-PE instructions and current handoff consulted.
- Windows build 26200.9550, version 25H2; Lenovo model 82XF. The older ProductName registry field still says Windows 10 Home, but the build identifies Windows 11.
- Realtek Bluetooth adapter; TOZO HT3 playback device present and healthy.
- TOZO HT3 Hands-Free device has problem code 22: disabled. No active TOZO capture endpoint appears in the device inventory. This must be enabled before microphone equalization can be configured and verified.
- FxSound running, configured to send to TOZO HT3; its power setting is 0 (processing off). No restart or settings change performed.
- Equalizer APO absent from its default installation directory. Peace not running. This session does not have administrator rights.

## Compatibility finding

Equalizer APO supports playback and capture devices. Its release notes include Windows 11 Bluetooth combined-device fixes in 1.3 and Bluetooth GraphicEQ/Convolution fixes in 1.4.2. Peace's developer confirms microphone equalization is supported. This establishes documented support, **not a successful test on this headset**.

Microsoft documents that this Bluetooth Classic connection switches to concurrent mono microphone and mono playback when the microphone is used. Media can play during a call, but at call-mode quality. Equalization cannot recover the missing stereo quality or frequencies. Actual microphone and playback processing must be tested after installation; some applications can bypass system processing.

Sources checked 2026-10-05:

- https://sourceforge.net/projects/equalizerapo/files/
- https://sourceforge.net/p/equalizerapo/wiki/Documentation/
- https://sourceforge.net/p/equalizerapo/wiki/Configuration%20reference/
- https://sourceforge.net/projects/peace-equalizer-apo-extension/files/
- https://learn.microsoft.com/en-us/windows-hardware/drivers/bluetooth/bluetooth-classic-audio
- https://sourceforge.net/p/equalizerapo/discussion/general/thread/a1ca2e691e/

## Downloads retained for installation

Directory: `X:\Downloads\MicDrop-EQ-2026-10-05`.

| File | Bytes | SHA-256 | Publisher signature |
|---|---:|---|---|
| EqualizerAPO-x64-1.4.2.exe | 11980366 | 7403BE7427BBE1936A40DDED082829B6E217FC4F5990FEE5CBA501F0AE055AFA | Unsigned |
| PeaceSetup.exe | 55657784 | D007A5EFCBE361EFBE5EC88EEA8EFF6191D0188E8C7111354CBB063FBAC26F2C | Valid, Petrus Verbeek |

Downloaded from the projects' SourceForge distribution using its Netix mirror. Initial generic download requests returned HTML pages, not programs; these were replaced and the final files checked for executable headers. Nothing downloaded has been executed. Hashes are local identification records, not independent publisher checksum verification.

## Installation plan, awaiting the exception below

1. Enable only TOZO HT3 Hands-Free; enumerate the resulting recording device.
2. Install Equalizer APO 1.4.2 and Peace 1.6.9.11. Select only the headset playback and headset recording devices for processing. Avoid scheduled update checks and unrelated device changes.
3. Keep microphone and playback settings separate. Start with conservative settings, avoiding unmeasured large boosts; verify processing before tuning.
4. Activate device changes only with the authorized audio interruption. Do not reboot or restart another active application without specific authorization.
5. Verify both directions with the headset microphone in use, then check return to stereo when the microphone is released. Do not claim success from installation alone. Do not record or upload Captain's voice without authorization.

## Pending permission request

Request to Captain, exactly as presented:

“May I allow the Windows administrator prompt and the Equalizer APO/Peace setup and device-selection windows, enable only the TOZO HT3 microphone, and briefly restart Windows audio to activate the changes?”

Disclosure: This affects audio on Lenny, under Captain's Windows account. It installs the two downloaded programs, registers processing for TOZO playback and recording, and enables the disabled headset microphone. Audio can briefly stop during activation. A faulty device-processing setup can cause silence or distortion and would need rollback. Equalizer APO's installer is unsigned; Peace has a valid publisher signature. No computer reboot, other application restart, account change, secret, spend, voice upload or external message is included.

Why asked: Constitution 4.11 says “Do not use popups for anything, ever.” Constitution 4.10 requires explicit permission for the exact active-app/session interruption. The current process lacks administrator rights, and the vendor documents that the device-selection window still opens during silent installation. Captain's install directive is accepted; this asks only for the specific windows and audio interruption needed to carry it out.

How Captain can deliver the permission: Reply in this chat with “Allow setup windows and audio restart.” If Windows later presents its administrator permission screen, verify it is for the installation just described, then choose Yes. No command or password needs to be pasted here. The agent must record the answer before acting and determine whether the available machine tools can operate the permitted installation windows; permission alone does not prove that ability.

Answer received 2026-10-05: “both permitted”. Captain approved the setup windows and audio restart in response to the request above. Installation and live audio changes had not begun when this answer was recorded.
