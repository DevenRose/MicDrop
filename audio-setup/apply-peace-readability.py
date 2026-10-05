"""Apply the reviewed native preferences with byte-preserving INI edits.

Run only after the approved close. Saves all top-level text/preset files locally
for verification recovery, without recording audio or changing EQ preferences.
"""
import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil

root = Path('C:/Program Files/EqualizerAPO/config')
stage = Path('X:/Downloads/MicDrop-EQ-2026-10-05')
proposal = json.loads(Path(__file__).with_name('peace-readability-proposal.json').read_text())
ini = root/'peace.ini'
original = ini.read_bytes()
general = re.search(rb'(?ms)^\[General\]\r?\n(.*?)(?=^\[|\Z)',original)
if not general:
    raise RuntimeError('General section missing')
section = general.group(1)
for change in proposal['Changes']:
    pattern = rb'(?m)^'+re.escape(change['Key'].encode())+rb'=([^\r\n]*)'
    matches = list(re.finditer(pattern,section))
    if len(matches) != 1 or matches[0].group(1).decode() != change['Before']:
        raise RuntimeError('Unexpected saved value for '+change['Key'])
    section = re.sub(pattern,change['Key'].encode()+b'='+change['After'].encode(),section)
patched = original[:general.start(1)]+section+original[general.end(1):]
backup = stage/('peace-readability-before-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
backup.mkdir()
for file in root.iterdir():
    if file.is_file() and file.suffix.lower() in ('.ini','.txt','.peace'):
        shutil.copy2(file,backup/file.name)
ini.write_bytes(patched)
if ini.read_bytes() != patched:
    raise RuntimeError('INI write verification failed')
# The isolated verification may rewrite persisted runtime state. Keep exact patched
# bytes to restore after that process is cleanly closed.
(backup/'peace-readability-patched.ini').write_bytes(patched)
result = {'backup':str(backup),'changes':proposal['Changes'],
          'original_sha256':hashlib.sha256(original).hexdigest(),
          'patched_sha256':hashlib.sha256(patched).hexdigest()}
(stage/'peace-readability-applied.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
