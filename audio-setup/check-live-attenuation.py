"""Verify live capture processing using aggregate levels; never save audio."""
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, 'X:/Downloads/MicDrop-EQ-2026-10-05/python-audio')
import numpy as np
import sounddevice as sd

config = Path('C:/Program Files/EqualizerAPO/config/config.txt')
original = config.read_bytes()
result = {'status': 'inconclusive', 'recorded_audio': False}

def measure(device):
    total = 0.0
    count = 0
    flags = []
    with sd.RawInputStream(device=device, channels=1, dtype='float32',
                           samplerate=16000, extra_settings=sd.WasapiSettings(exclusive=False)) as stream:
        # Discard settling buffers. Only aggregate the subsequent samples.
        stream.read(16000)
        for _ in range(20):
            data, overflow = stream.read(1600)
            values = np.frombuffer(data, dtype=np.float32).astype(np.float64)
            total += float(np.dot(values, values))
            count += len(values)
            if overflow:
                flags.append('overflow')
    if flags:
        raise RuntimeError('Capture overflow; measurement is inconclusive.')
    return float(np.sqrt(total / count))

try:
    hosts = sd.query_hostapis()
    targets = [d for d in sd.query_devices()
               if hosts[d['hostapi']]['name'] == 'Windows WASAPI'
               and d['name'] == 'Headset (TOZO HT3)' and d['max_input_channels']]
    if len(targets) != 1:
        raise RuntimeError('Expected exactly one active TOZO capture endpoint.')
    device = targets[0]['index']
    result['baseline_rms'] = measure(device)
    config.write_bytes(original + b'\r\nDevice: {7c806a74-2036-47d5-b3fe-1a0aa19bb13e}\r\nChannel: all\r\nCopy: C=0*C\r\n')
    time.sleep(1)
    result['attenuated_rms'] = measure(device)
    config.write_bytes(original)
    time.sleep(1)
    result['restored_rms'] = measure(device)
    floor = min(result['baseline_rms'], result['restored_rms'])
    if floor > 1 / 32768 and result['attenuated_rms'] == 0:
        result['status'] = 'passed'
    else:
        result['reason'] = 'No exact digital silence, or insufficient ambient signal.'
except Exception as exc:
    result['error'] = str(exc)
finally:
    config.write_bytes(original)
    result['configuration_restored'] = config.read_bytes() == original
    Path('X:/Downloads/MicDrop-EQ-2026-10-05/live-attenuation-check.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
sys.exit(0 if result['status'] == 'passed' else 1)
