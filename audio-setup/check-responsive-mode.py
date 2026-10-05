"""Confirm the installed app changes EQ only during actual TOZO capture use."""
import json
from pathlib import Path
import re
import sys
sys.path.insert(0,'X:/Downloads/MicDrop-EQ-2026-10-05/python-audio')
import sounddevice as sd

file=Path('C:/Program Files/EqualizerAPO/config/micdrop-eq.txt')
selector='Device: {b56632b2-8e96-4c11-a623-8e233b195adb}'
def frequencies():
    text=file.read_text().rsplit(selector,1)[1]
    graphic=re.search(r'^GraphicEQ: (.*)$',text,re.M).group(1)
    return [float(point.split()[0]) for point in graphic.split(';')]
def wait_for(count,seconds=4):
    for _ in range(int(seconds*4)):
        if len(frequencies())==count:return True
        sd.sleep(250)
    return False
hosts=sd.query_hostapis()
inputs=[d for d in sd.query_devices() if d['name']=='Headset (TOZO HT3)' and d['max_input_channels'] and hosts[d['hostapi']]['name']=='Windows WASAPI']
if len(inputs)!=1:raise RuntimeError('Expected exactly one TOZO microphone')
frames_seen=0
def discard(_data,frames,_time,_status):
    global frames_seen
    frames_seen+=frames
normal_before=wait_for(31)
if not normal_before:raise RuntimeError('Normal mode not established; no stream opened')
with sd.RawInputStream(device=inputs[0]['index'],samplerate=inputs[0]['default_samplerate'],channels=1,dtype='int16',extra_settings=sd.WasapiSettings(exclusive=False,auto_convert=True),callback=discard):
    call=wait_for(26)
    call_centers=frequencies()
normal_after=wait_for(31)
normal_centers=frequencies()
result={'normal_before':normal_before,'call_during_tozo_capture':call,'normal_restored_after_capture':normal_after,
 'call_band_count':len(call_centers),'call_highest_standard_center':max(call_centers),
 'normal_band_count':len(normal_centers),'normal_highest_standard_center':max(normal_centers),
 'capture_sample_rate':inputs[0]['default_samplerate'],'discarded_capture_frames':frames_seen,
 'passed':normal_before and call and normal_after and max(call_centers)<inputs[0]['default_samplerate']/2 and max(normal_centers)==20000}
Path(__file__).with_name('responsive-mode-verification.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
if not result['passed']:sys.exit(1)
