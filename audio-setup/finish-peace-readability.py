"""Restore exact saved EQ files after the isolated font verification is closed."""
import hashlib
import json
from pathlib import Path

stage = Path('X:/Downloads/MicDrop-EQ-2026-10-05')
root = Path('C:/Program Files/EqualizerAPO/config')
applied = json.loads((stage/'peace-readability-applied.json').read_text())
backup = Path(applied['backup'])
if backup.parent.resolve() != stage.resolve():
    raise RuntimeError('Unexpected backup directory')
results = []
for file in backup.iterdir():
    if file.name == 'peace-readability-patched.ini':
        continue
    if file.suffix.lower() not in ('.ini','.txt','.peace'):
        raise RuntimeError('Unexpected backup file')
    target = root/file.name
    desired = (backup/'peace-readability-patched.ini').read_bytes() if file.name == 'peace.ini' else file.read_bytes()
    changed = target.read_bytes() != desired
    if changed:
        target.write_bytes(desired)
    if target.read_bytes() != desired:
        raise RuntimeError('Restoration failed: '+file.name)
    results.append({'file':file.name,'restored_after_test':changed,'verified_exact':True})
result = {'files':results,'font_size':12,
    'patched_ini_verified':hashlib.sha256((root/'peace.ini').read_bytes()).hexdigest() == applied['patched_sha256']}
if not result['patched_ini_verified']:
    raise RuntimeError('Final INI differs from approved patch')
(stage/'peace-readability-finished.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
