"""Bounded, aggregate-only TOZO loopback check with microphone mode active."""
import json
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, 'X:/Downloads/MicDrop-EQ-2026-10-05/python-audio')
import numpy as np
import pyaudiowpatch as pa
import sounddevice as sd

config = Path('C:/Program Files/EqualizerAPO/config/config.txt')
original = config.read_bytes()
result = {'status': 'inconclusive', 'recorded_audio': False, 'tone_dbfs': -100}
lock = threading.Lock()
stats = {'n': 0, 'sum': 0j, 'energy': 0.0, 'mic_frames': 0}
phase = {'render': 0, 'loopback': 0}
rate = 48000
freq = 2390
tone_on = False

def microphone(_data, frames, _time, _status):
    stats['mic_frames'] += frames

def render(_data, frames, _time, _status):
    t = (np.arange(frames) + phase['render']) / rate
    phase['render'] += frames
    signal = np.sin(2 * np.pi * freq * t) * (1e-5 if tone_on else 0)
    stereo = np.repeat(signal[:, None], 2, axis=1).astype(np.float32)
    return stereo.tobytes(), pa.paContinue

def loopback(data, frames, _time, _status):
    values = np.frombuffer(data, dtype=np.float32).reshape(-1, 2).mean(axis=1)
    t = (np.arange(len(values)) + phase['loopback']) / rate
    phase['loopback'] += len(values)
    correlation = np.dot(values, np.exp(-2j * np.pi * freq * t))
    with lock:
        stats['sum'] += complex(correlation)
        stats['energy'] += float(np.dot(values, values))
        stats['n'] += len(values)
    return None, pa.paContinue

def measure(seconds=2):
    with lock:
        stats.update(n=0, sum=0j, energy=0.0)
    time.sleep(seconds)
    with lock:
        if stats['n'] < rate:
            raise RuntimeError('Insufficient loopback frames.')
        return {'tone_amplitude': abs(2 * stats['sum'] / stats['n']),
                'rms': float(np.sqrt(stats['energy'] / stats['n'])),
                'frames': stats['n']}

try:
    hosts = sd.query_hostapis()
    microphones = [d for d in sd.query_devices() if d['name'] == 'Headset (TOZO HT3)'
                   and hosts[d['hostapi']]['name'] == 'Windows WASAPI' and d['max_input_channels']]
    if len(microphones) != 1:
        raise RuntimeError('Expected one active TOZO microphone.')
    with pa.PyAudio() as manager:
        outputs = [d for d in manager.get_device_info_generator()
                   if d['name'] == 'Headphones (TOZO HT3)' and d['maxOutputChannels']
                   and manager.get_host_api_info_by_index(d['hostApi'])['type'] == pa.paWASAPI]
        if len(outputs) != 1:
            raise RuntimeError('Expected one active TOZO WASAPI output.')
        output = outputs[0]
        capture = manager.get_wasapi_loopback_analogue_by_dict(output)
        if int(capture['defaultSampleRate']) != rate or capture['maxInputChannels'] != 2:
            raise RuntimeError('Unexpected loopback format.')
        result.update(output=output['name'], loopback=capture['name'])
        with sd.RawInputStream(device=microphones[0]['index'], samplerate=16000, channels=1,
                               dtype='float32', callback=microphone,
                               extra_settings=sd.WasapiSettings(exclusive=False)):
            with manager.open(format=pa.paFloat32, channels=2, rate=rate, output=True,
                              output_device_index=output['index'], stream_callback=render):
                with manager.open(format=pa.paFloat32, channels=2, rate=rate, input=True,
                                  input_device_index=capture['index'], stream_callback=loopback):
                    time.sleep(1)
                    result['existing_playback'] = measure()
                    if result['existing_playback']['rms'] > 1e-4:
                        raise RuntimeError('Existing playback detected; no EQ change made.')
                    tone_on = True
                    time.sleep(1)
                    result['baseline'] = measure()
                    config.write_bytes(original + b'\r\nDevice: {b56632b2-8e96-4c11-a623-8e233b195adb}\r\nChannel: all\r\nPreamp: -6 dB\r\n')
                    time.sleep(1)
                    result['attenuated'] = measure()
                    config.write_bytes(original)
                    time.sleep(1)
                    result['restored'] = measure()
        result['microphone_frames'] = stats['mic_frames']
        before = result['baseline']['tone_amplitude']
        after = result['restored']['tone_amplitude']
        muted = result['attenuated']['tone_amplitude']
        if min(before, after, muted) <= 1e-8:
            raise RuntimeError('Test signal too weak for a decisive measurement.')
        result['attenuation_db'] = float(20 * np.log10(muted / before))
        result['restoration_db'] = float(20 * np.log10(after / before))
        if abs(result['attenuation_db'] + 6) < 0.5 and abs(result['restoration_db']) < 0.5:
            result['status'] = 'passed'
        else:
            result['reason'] = 'Measured level change did not match the applied EQ change.'
except Exception as exc:
    result['error'] = str(exc)
finally:
    config.write_bytes(original)
    result['configuration_restored'] = config.read_bytes() == original
    Path('X:/Downloads/MicDrop-EQ-2026-10-05/live-playback-check.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
sys.exit(0 if result['status'] == 'passed' else 1)
