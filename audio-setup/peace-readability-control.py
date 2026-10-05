"""Peace vendor control endpoint and read-only font metadata; never focus/input.

Uses MainActions WM_APP documented by Peace16911.au3, not simulated UI input.
Close requires the separately recorded Captain approval. Desktop must be explicit.
"""
import argparse
import collections
import ctypes as c
from ctypes import wintypes as w
import json

u = c.WinDLL('user32', use_last_error=True)
g = c.WinDLL('gdi32', use_last_error=True)
k = c.WinDLL('kernel32', use_last_error=True)
CB = c.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)
u.OpenDesktopW.argtypes = [w.LPCWSTR,w.DWORD,w.BOOL,w.DWORD]
u.OpenDesktopW.restype = w.HANDLE
u.CloseDesktop.argtypes = [w.HANDLE]
u.EnumDesktopWindows.argtypes = [w.HANDLE,CB,w.LPARAM]
u.EnumChildWindows.argtypes = [w.HWND,CB,w.LPARAM]
u.GetWindowThreadProcessId.argtypes = [w.HWND,c.POINTER(w.DWORD)]
u.GetWindowTextW.argtypes = [w.HWND,w.LPWSTR,c.c_int]
u.GetWindowRect.argtypes = [w.HWND,c.POINTER(w.RECT)]
u.GetDpiForWindow.argtypes = [w.HWND]
u.GetDpiForWindow.restype = w.UINT
u.SendMessageTimeoutW.argtypes = [w.HWND,w.UINT,w.WPARAM,w.LPARAM,w.UINT,w.UINT,c.POINTER(c.c_size_t)]
u.SendMessageTimeoutW.restype = w.LPARAM
g.GetObjectW.argtypes = [w.HANDLE,c.c_int,w.LPVOID]
k.OpenProcess.argtypes = [w.DWORD,w.BOOL,w.DWORD]
k.OpenProcess.restype = w.HANDLE
k.WaitForSingleObject.argtypes = [w.HANDLE,w.DWORD]
k.CloseHandle.argtypes = [w.HANDLE]

class LogFont(c.Structure):
    _fields_ = [('height',w.LONG),('width',w.LONG),('escapement',w.LONG),
        ('orientation',w.LONG),('weight',w.LONG),('italic',w.BYTE),
        ('underline',w.BYTE),('strikeout',w.BYTE),('charset',w.BYTE),
        ('outprecision',w.BYTE),('clipprecision',w.BYTE),('quality',w.BYTE),
        ('pitch',w.BYTE),('face',w.WCHAR*32)]

def message(hwnd,msg,param=0):
    value = c.c_size_t()
    if not u.SendMessageTimeoutW(hwnd,msg,param,0,2,3000,c.byref(value)):
        raise c.WinError(c.get_last_error())
    return c.c_ssize_t(value.value).value

def title(hwnd):
    value = c.create_unicode_buffer(512)
    u.GetWindowTextW(hwnd,value,len(value))
    return value.value

def windows(desktop,pid):
    matches = []
    @CB
    def visit(hwnd,unused):
        found = w.DWORD()
        u.GetWindowThreadProcessId(hwnd,c.byref(found))
        if found.value == pid:
            matches.append(hwnd)
        return True
    u.EnumDesktopWindows(desktop,visit,0)
    return matches

def snapshot(desktop,pid):
    found = windows(desktop,pid)
    endpoints = [h for h in found if title(h) == 'Peace window messages']
    if len(endpoints) != 1:
        raise RuntimeError(f'Expected one vendor endpoint for PID {pid}, found {len(endpoints)}')
    fonts = collections.Counter()
    sizes = []
    @CB
    def inspect(hwnd,unused):
        handle = message(hwnd,0x0031)  # WM_GETFONT: read only
        if handle:
            font = LogFont()
            if g.GetObjectW(handle,c.sizeof(font),c.byref(font)):
                dpi = u.GetDpiForWindow(hwnd)
                fonts[(font.face,font.height,round(abs(font.height)*72/dpi,2))] += 1
        return True
    for hwnd in found:
        if title(hwnd) == 'Peace window messages':
            continue
        rectangle = w.RECT()
        u.GetWindowRect(hwnd,c.byref(rectangle))
        sizes.append({'title':title(hwnd),'width':rectangle.right-rectangle.left,
                      'height':rectangle.bottom-rectangle.top})
        u.EnumChildWindows(hwnd,inspect,0)
    return endpoints[0], {'pid':pid,'state':message(endpoints[0],0x8000),
        'fonts':[{'face':face,'pixel_height':height,'points':points,'controls':count}
                 for (face,height,points),count in fonts.items()], 'windows':sizes}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action',choices=['inspect','close'])
    parser.add_argument('--pid',type=int,required=True)
    parser.add_argument('--desktop',required=True)
    args = parser.parse_args()
    desktop = u.OpenDesktopW(args.desktop,0,False,0x41)  # enumerate/read objects only
    if not desktop:
        raise c.WinError(c.get_last_error())
    try:
        hwnd,result = snapshot(desktop,args.pid)
        result['desktop'] = args.desktop
        if args.action == 'close':
            process = k.OpenProcess(0x100000,False,args.pid)  # synchronization only
            if not process:
                raise c.WinError(c.get_last_error())
            try:
                result['close_result'] = message(hwnd,0x8000,1)
                result['process_exited'] = k.WaitForSingleObject(process,10000) == 0
                if not result['process_exited']:
                    raise RuntimeError('Peace did not exit; no forced termination attempted')
            finally:
                k.CloseHandle(process)
        print(json.dumps(result,indent=2))
    finally:
        u.CloseDesktop(desktop)

if __name__ == '__main__':
    main()
