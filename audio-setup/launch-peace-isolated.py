"""Launch on a separate Win32 desktop. Never switch the user's input desktop."""
import ctypes as c
from ctypes import wintypes as w
import json
from pathlib import Path
import subprocess
import sys
import uuid

folder = Path('X:/Downloads/MicDrop-EQ-2026-10-05')
u = c.WinDLL('user32', use_last_error=True)
k = c.WinDLL('kernel32', use_last_error=True)
u.GetThreadDesktop.argtypes = [w.DWORD]
u.GetThreadDesktop.restype = w.HANDLE
u.OpenInputDesktop.argtypes = [w.DWORD,w.BOOL,w.DWORD]
u.OpenInputDesktop.restype = w.HANDLE
u.GetUserObjectInformationW.argtypes = [w.HANDLE,c.c_int,w.LPVOID,w.DWORD,c.POINTER(w.DWORD)]
u.GetUserObjectInformationW.restype = w.BOOL
u.CreateDesktopW.argtypes = [w.LPCWSTR,w.LPCWSTR,w.LPVOID,w.DWORD,w.DWORD,w.LPVOID]
u.CreateDesktopW.restype = w.HANDLE
u.CloseDesktop.argtypes = [w.HANDLE]
k.GetCurrentThreadId.restype = w.DWORD
k.CloseHandle.argtypes = [w.HANDLE]
k.WaitForSingleObject.argtypes = [w.HANDLE,w.DWORD]
k.GetExitCodeProcess.argtypes = [w.HANDLE,c.POINTER(w.DWORD)]
u.WaitForInputIdle.argtypes = [w.HANDLE,w.DWORD]

def desktop_name(handle):
    buf = c.create_unicode_buffer(512)
    size = w.DWORD()
    if not u.GetUserObjectInformationW(handle,2,buf,c.sizeof(buf),c.byref(size)):
        raise c.WinError(c.get_last_error())
    return buf.value

def input_name():
    handle = u.OpenInputDesktop(0,False,1)
    if not handle:
        raise c.WinError(c.get_last_error())
    try:
        return desktop_name(handle)
    finally:
        u.CloseDesktop(handle)

if '--probe-child' in sys.argv:
    (folder/'isolated-child-proof.json').write_text(json.dumps({
        'desktop':desktop_name(u.GetThreadDesktop(k.GetCurrentThreadId()))}))
    sys.exit(0)

class Startup(c.Structure):
    _fields_ = [('cb',w.DWORD),('lpReserved',w.LPWSTR),('lpDesktop',w.LPWSTR),('lpTitle',w.LPWSTR),
                ('dwX',w.DWORD),('dwY',w.DWORD),('dwXSize',w.DWORD),('dwYSize',w.DWORD),
                ('dwXCountChars',w.DWORD),('dwYCountChars',w.DWORD),('dwFillAttribute',w.DWORD),
                ('dwFlags',w.DWORD),('wShowWindow',w.WORD),('cbReserved2',w.WORD),
                ('lpReserved2',c.POINTER(w.BYTE)),('hStdInput',w.HANDLE),('hStdOutput',w.HANDLE),('hStdError',w.HANDLE)]

class Process(c.Structure):
    _fields_ = [('hProcess',w.HANDLE),('hThread',w.HANDLE),('dwProcessId',w.DWORD),('dwThreadId',w.DWORD)]

k.CreateProcessW.argtypes = [w.LPCWSTR,w.LPWSTR,w.LPVOID,w.LPVOID,w.BOOL,w.DWORD,w.LPVOID,w.LPCWSTR,c.POINTER(Startup),c.POINTER(Process)]
k.CreateProcessW.restype = w.BOOL
before = input_name()
name = 'MicDropSetup-' + uuid.uuid4().hex
desktop = u.CreateDesktopW(name,None,None,0,0x01ff,None)
if not desktop:
    raise c.WinError(c.get_last_error())
process = Process()
try:
    si = Startup()
    si.cb = c.sizeof(si)
    si.lpDesktop = 'WinSta0\\' + name
    si.dwFlags = 0x81  # STARTF_USESHOWWINDOW | STARTF_FORCEOFFFEEDBACK
    si.wShowWindow = 0
    proof = '--proof' in sys.argv
    args = [sys.executable,str(Path(__file__).resolve()),'--probe-child'] if proof else [
        'C:\\Program Files\\EqualizerAPO\\config\\Peace.exe','TOZO Media','hide']
    command = c.create_unicode_buffer(subprocess.list2cmdline(args))
    if not k.CreateProcessW(args[0],command,None,None,False,0x08000000,None,
                            'C:\\Program Files\\EqualizerAPO\\config',c.byref(si),c.byref(process)):
        raise c.WinError(c.get_last_error())
    if proof:
        if k.WaitForSingleObject(process.hProcess,10000) != 0:
            raise RuntimeError('Isolated child did not finish its proof.')
        child = json.loads((folder/'isolated-child-proof.json').read_text())
        if child['desktop'] != name:
            raise RuntimeError('Child process was not isolated.')
    else:
        # Keep the desktop alive until the GUI process connects to it.
        idle = u.WaitForInputIdle(process.hProcess,10000)
        exit_code = w.DWORD()
        if not k.GetExitCodeProcess(process.hProcess,c.byref(exit_code)):
            raise c.WinError(c.get_last_error())
    after = input_name()
    if after != before:
        raise RuntimeError('Input desktop changed unexpectedly; do not continue.')
    result = {'proof':proof,'desktop':name,'input_before':before,'input_after':after,'process_id':process.dwProcessId}
    if not proof:
        result.update(input_idle_result=idle,process_exit_code=exit_code.value)
    (folder/('isolated-proof.json' if proof else 'peace-isolated-launch.json')).write_text(json.dumps(result,indent=2))
    print(json.dumps(result,indent=2))
finally:
    if process.hThread: k.CloseHandle(process.hThread)
    if process.hProcess: k.CloseHandle(process.hProcess)
    u.CloseDesktop(desktop)
