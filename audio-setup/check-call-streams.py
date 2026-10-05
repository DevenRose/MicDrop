"""Short local stream check. Discards microphone data; outputs silence only."""
import json
import sys
from pathlib import Path

sys.path.insert(0, "X:/Downloads/MicDrop-EQ-2026-10-05/python-audio")
import sounddevice as sd

folder = Path("X:/Downloads/MicDrop-EQ-2026-10-05")
stats = {"input_frames": 0, "output_frames": 0, "callback_flags": []}


def capture(_data, frames, _time, status):
    stats["input_frames"] += frames
    if status:
        stats["callback_flags"].append(str(status))


def playback(data, frames, _time, status):
    data[:] = bytes(len(data))
    stats["output_frames"] += frames
    if status:
        stats["callback_flags"].append(str(status))


try:
    hosts = sd.query_hostapis()
    devices = [d for d in sd.query_devices() if hosts[d["hostapi"]]["name"] == "Windows WASAPI"]
    inputs = [d for d in devices if d["name"] == "Headset (TOZO HT3)" and d["max_input_channels"]]
    outputs = [d for d in devices if d["name"] == "Headphones (TOZO HT3)" and d["max_output_channels"]]
    if len(inputs) != 1 or len(outputs) != 1:
        raise RuntimeError("Expected exactly one active TOZO input and output; refusing another microphone or speaker.")
    stats["input_device"] = inputs[0]["name"]
    stats["output_device"] = outputs[0]["name"]
    stats["input_rate"] = inputs[0]["default_samplerate"]
    stats["output_rate"] = outputs[0]["default_samplerate"]
    shared = sd.WasapiSettings(exclusive=False, auto_convert=True)
    with sd.RawInputStream(device=inputs[0]["index"], samplerate=stats["input_rate"],
                           channels=1, dtype="int16", extra_settings=shared, callback=capture):
        with sd.RawOutputStream(device=outputs[0]["index"], samplerate=stats["output_rate"],
                                channels=2, dtype="int16", extra_settings=shared, callback=playback):
            sd.sleep(2000)
    stats["status"] = "passed" if stats["input_frames"] > 0 and stats["output_frames"] > 0 else "failed"
except Exception as exc:
    stats.update(status="failed", error=str(exc))

(folder / "call-stream-check.json").write_text(json.dumps(stats, indent=2), encoding="utf-8")
print(json.dumps(stats, indent=2))
if stats["status"] != "passed":
    sys.exit(1)
