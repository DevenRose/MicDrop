"""Verify the installed native APO parser/DSP using synthetic offline sweeps."""
import json
from pathlib import Path
import struct
import subprocess
import numpy as np

stage=Path('X:/Downloads/MicDrop-EQ-2026-10-05/responsive-build')
benchmark='C:/Program Files/EqualizerAPO/Benchmark.exe'
cases=[('media','{b56632b2-8e96-4c11-a623-8e233b195adb}',48000,20000,2),
       ('voice','{7c806a74-2036-47d5-b3fe-1a0aa19bb13e}',16000,7000,1),
       ('legacy-call','{50c13f97-8076-409c-8c5d-b95c6a3deedd}',16000,7000,1),
       ('unrelated','{00000000-0000-0000-0000-000000000000}',48000,20000,2)]
results=[]
for name,guid,rate,end,channels in cases:
    output=stage/(name+'-synthetic.wav')
    command=[benchmark,'--nopause','-v','-l','1','-f','20','-t',str(end),'-r',str(rate),'-c',str(channels),'--guid',guid,'-o',str(output)]
    process=subprocess.run(command,capture_output=True,text=True,creationflags=0x08000000)
    if process.returncode or not output.exists():
        raise RuntimeError(process.stdout+process.stderr)
    payload=output.read_bytes();offset=12;data=None;tag=None;bits=None
    while offset+8<=len(payload):
        chunk=payload[offset:offset+4];length=struct.unpack_from('<I',payload,offset+4)[0]
        if chunk==b'fmt ':
            tag,_,_,_,_,bits=struct.unpack_from('<HHIIHH',payload,offset+8)
        if chunk==b'data':data=payload[offset+8:offset+8+length]
        offset+=8+length+(length%2)
    if data is None:raise RuntimeError('Synthetic WAV has no data chunk')
    if tag==1 and bits==16:samples=np.frombuffer(data,dtype='<i2').astype(np.float64)/32768
    elif tag==3 and bits==32:samples=np.frombuffer(data,dtype='<f4')
    else:raise RuntimeError('Unsupported synthetic WAV format')
    peak=float(np.max(np.abs(samples)))
    diagnostic=process.stdout+process.stderr
    bad=[line for line in diagnostic.splitlines() if 'error' in line.lower() or 'invalid' in line.lower() or 'cannot' in line.lower()]
    result={'device':name,'rate':rate,'peak':peak,'peak_db':float(20*np.log10(max(peak,1e-12))),
            'errors':bad,'passed':not bad and peak<=1.00001 and (name=='unrelated' or peak<0.99)}
    results.append(result)
    (stage/(name+'-benchmark.txt')).write_text(diagnostic)
    if output.resolve().parent!=stage.resolve():raise RuntimeError('Unexpected synthetic output path')
    output.unlink()
if not all(row['passed'] for row in results):raise RuntimeError(json.dumps(results))
Path(__file__).with_name('responsive-engine-verification.json').write_text(json.dumps(results,indent=2))
print(json.dumps(results,indent=2))
