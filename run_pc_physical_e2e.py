# -*- coding: utf-8 -*-
"""
Mellow Music - Windows Physical Client Real GUI E2E Automation Suite
"""

import os
import sys
import time
import subprocess
import ctypes
from ctypes import wintypes
from PIL import ImageGrab

try:
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
except Exception:
    pass

HERE = os.path.dirname(os.path.abspath(__file__))
APP_ROOT = HERE
EXE_PATH = os.path.join(APP_ROOT, "release_windows", "app.exe")
EVIDENCE_DIR = os.path.join(APP_ROOT, "docs", "evidence", "pc-e2e-verified")

os.makedirs(EVIDENCE_DIR, exist_ok=True)

user32 = ctypes.WinDLL("user32", use_last_error=True)
gdi32 = ctypes.WinDLL("gdi32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

SW_RESTORE = 9

VK = {
    "space": 0x20, "enter": 0x0D, "esc": 0x1B, "tab": 0x09,
    "ctrl": 0x11, "alt": 0x12, "shift": 0x10,
    "k": 0x4B, "m": 0x4D, "l": 0x4C, "q": 0x51
}

def find_flutter_windows(pid=None):
    res = []
    def cb(hwnd, lparam):
        if not user32.IsWindowVisible(hwnd):
            return True
        wpid = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(wpid))
        buf = ctypes.create_unicode_buffer(512)
        user32.GetWindowTextW(hwnd, buf, 512)
        cls = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(hwnd, cls, 256)
        
        if pid is not None and wpid.value != pid:
            return True
        
        if cls.value == "FLUTTER_RUNNER_WIN32_WINDOW" or "app" in buf.value.lower() or "mellow" in buf.value.lower():
            res.append((hwnd, wpid.value, buf.value, cls.value))
        return True

    EnumProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)(cb)
    user32.EnumWindows(EnumProc, 0)
    return res

def rect_of(hwnd):
    r = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(r))
    return (r.left, r.top, r.right, r.bottom)

def bring_to_front(hwnd):
    user32.ShowWindow(hwnd, SW_RESTORE)
    user32.keybd_event(0x12, 0, 0, 0)
    user32.keybd_event(0x12, 0, 2, 0)
    user32.SetForegroundWindow(hwnd)
    user32.BringWindowToTop(hwnd)
    time.sleep(0.4)

class BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [
        ('biSize', wintypes.DWORD),
        ('biWidth', wintypes.LONG),
        ('biHeight', wintypes.LONG),
        ('biPlanes', wintypes.WORD),
        ('biBitCount', wintypes.WORD),
        ('biCompression', wintypes.DWORD),
        ('biSizeImage', wintypes.DWORD),
        ('biXPelsPerMeter', wintypes.LONG),
        ('biYPelsPerMeter', wintypes.LONG),
        ('biClrUsed', wintypes.DWORD),
        ('biClrImportant', wintypes.DWORD)
    ]

# PrintWindow flag: PW_RENDERFULLCONTENT (0x00000002).
# Flutter on Windows renders through ANGLE/D3D into a DWM-composited surface, so a
# plain desktop-DC BitBlt returns a BLANK (white) client area. PrintWindow with
# PW_RENDERFULLCONTENT asks the window's own compositor to redraw its content and
# is the supported way to capture such windows.
PW_RENDERFULLCONTENT = 0x00000002

# Captures that came back blank; a non-empty list fails the run (no false "PASSED").
BLANK_CAPTURES = []

# Bind correct pointer-width signatures. Without argtypes/restype ctypes truncates
# HWND/HDC/HBITMAP handles to 32-bit C ints, which silently corrupts the capture.
user32.GetWindowDC.argtypes = [wintypes.HWND]
user32.GetWindowDC.restype = wintypes.HDC
user32.GetDC.argtypes = [wintypes.HWND]
user32.GetDC.restype = wintypes.HDC
user32.ReleaseDC.argtypes = [wintypes.HWND, wintypes.HDC]
user32.PrintWindow.argtypes = [wintypes.HWND, wintypes.HDC, wintypes.UINT]
user32.PrintWindow.restype = wintypes.BOOL
gdi32.CreateCompatibleDC.argtypes = [wintypes.HDC]
gdi32.CreateCompatibleDC.restype = wintypes.HDC
gdi32.CreateCompatibleBitmap.argtypes = [wintypes.HDC, ctypes.c_int, ctypes.c_int]
gdi32.CreateCompatibleBitmap.restype = wintypes.HBITMAP
gdi32.SelectObject.argtypes = [wintypes.HDC, wintypes.HGDIOBJ]
gdi32.SelectObject.restype = wintypes.HGDIOBJ
gdi32.BitBlt.argtypes = [wintypes.HDC, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, wintypes.HDC, ctypes.c_int, ctypes.c_int, wintypes.DWORD]
gdi32.BitBlt.restype = wintypes.BOOL
gdi32.DeleteObject.argtypes = [wintypes.HGDIOBJ]
gdi32.DeleteDC.argtypes = [wintypes.HDC]


def frame_is_blank(img, tolerance=6):
    """Return True when the captured frame is a single uniform colour.

    A blank frame means the capture path failed (or the app truly rendered
    nothing). Callers must treat this as an evidence failure, never as a pass.
    """
    small = img.convert('RGB').resize((32, 32))
    pixels = list(small.getdata())
    first = pixels[0]
    for px in pixels[1:]:
        if (abs(px[0] - first[0]) > tolerance or
                abs(px[1] - first[1]) > tolerance or
                abs(px[2] - first[2]) > tolerance):
            return False
    return True


def capture_window(hwnd, out_path):
    bring_to_front(hwnd)
    time.sleep(0.5)
    l, t, r, b = rect_of(hwnd)
    w = max(1, r - l)
    h = max(1, b - t)

    hwndDC = user32.GetWindowDC(hwnd)
    memDC = gdi32.CreateCompatibleDC(hwndDC)
    hbmp = gdi32.CreateCompatibleBitmap(hwndDC, w, h)
    gdi32.SelectObject(memDC, hbmp)

    # 1) Primary path: the window's own compositor (works for Flutter/ANGLE windows).
    captured = bool(user32.PrintWindow(hwnd, memDC, PW_RENDERFULLCONTENT))

    # 2) Fallback path: desktop-DC BitBlt (SRCCOPY|CAPTUREBLT). Kept only as a
    #    last resort; it yields a blank frame for hardware-composited windows.
    if not captured:
        deskDC = user32.GetDC(0)
        gdi32.BitBlt(memDC, 0, 0, w, h, deskDC, l, t, 0x40CC0020)
        user32.ReleaseDC(0, deskDC)

    bmi = BITMAPINFOHEADER()
    bmi.biSize = ctypes.sizeof(BITMAPINFOHEADER)
    bmi.biWidth = w
    bmi.biHeight = -h
    bmi.biPlanes = 1
    bmi.biBitCount = 32
    bmi.biCompression = 0

    buf = (ctypes.c_char * (w * h * 4))()
    gdi32.GetDIBits(memDC, hbmp, 0, h, buf, ctypes.byref(bmi), 0)

    gdi32.DeleteObject(hbmp)
    gdi32.DeleteDC(memDC)
    user32.ReleaseDC(hwnd, hwndDC)

    from PIL import Image
    img = Image.frombuffer('RGBA', (w, h), buf, 'raw', 'BGRA', 0, 1)
    rgb = img.convert('RGB')
    rgb.save(out_path)

    if frame_is_blank(rgb):
        BLANK_CAPTURES.append(out_path)
        print("  [WARN] Blank/uniform frame captured (capture path failed, do NOT treat as evidence): %s" % out_path)
        return (0, 0)
    return (w, h)

def click_client(hwnd, x, y):
    bring_to_front(hwnd)
    l, t, r, b = rect_of(hwnd)
    screen_x = l + x
    screen_y = t + y
    user32.SetCursorPos(screen_x, screen_y)
    time.sleep(0.15)
    user32.mouse_event(0x0002, 0, 0, 0, 0)
    time.sleep(0.08)
    user32.mouse_event(0x0004, 0, 0, 0, 0)
    time.sleep(0.8)

def send_key(key_name):
    vk = VK.get(key_name.lower())
    if vk:
        user32.keybd_event(vk, 0, 0, 0)
        time.sleep(0.08)
        user32.keybd_event(vk, 0, 2, 0)
        time.sleep(0.4)

def send_hotkey(mod, key):
    m_vk = VK.get(mod.lower())
    k_vk = VK.get(key.lower())
    if m_vk and k_vk:
        user32.keybd_event(m_vk, 0, 0, 0)
        time.sleep(0.05)
        user32.keybd_event(k_vk, 0, 0, 0)
        time.sleep(0.08)
        user32.keybd_event(k_vk, 0, 2, 0)
        time.sleep(0.05)
        user32.keybd_event(m_vk, 0, 2, 0)
        time.sleep(0.4)

def main():
    print("=" * 60)
    print("  Mellow Music Physical PC GUI E2E Automated Verification")
    print("=" * 60)
    
    if not os.path.exists(EXE_PATH):
        print("[ERROR] Cannot find executable: %s" % EXE_PATH)
        sys.exit(1)
        
    print("[1/6] Launching physical app process: %s" % EXE_PATH)
    proc = subprocess.Popen([EXE_PATH], cwd=os.path.dirname(EXE_PATH))
    pid = proc.pid
    print("  -> PID: %s" % pid)
    
    hwnd = None
    for i in range(30):
        time.sleep(0.5)
        ws = find_flutter_windows(pid=pid)
        if ws:
            hwnd = ws[0][0]
            safe_title = ws[0][2].encode('ascii', 'backslashreplace').decode('ascii')
            print("  -> Found Win32 Window: HWND=%s, Title=%s, Class=%r" % (hwnd, safe_title, ws[0][3]))
            break
            
    if not hwnd:
        print("[ERROR] Failed to detect active Flutter desktop window!")
        proc.kill()
        sys.exit(1)
        
    try:
        # Resize window to 1440x900 @ (0,0)
        print("\n[2/6] Resizing window to 1440x900 @ (0,0) and awaiting render...")
        user32.SetWindowPos(hwnd, 0, 0, 0, 1440, 900, 0x0040)
        # 等待 3 秒让 Flutter 引擎和着色器完全初始化上屏
        time.sleep(3.0)
        bring_to_front(hwnd)
        
        # Step 1: Initial Launch
        snap1 = os.path.join(EVIDENCE_DIR, "pc_e2e_01_home_workbench.png")
        size = capture_window(hwnd, snap1)
        print("  [Step 1] Initial home workbench captured: %s (%dx%d)" % (snap1, size[0], size[1]))
        
        # Step 2: Click Toplist in sidebar (x=60, y=239)
        print("\n[3/6] Clicking sidebar 'Toplist' (x=60, y=239)...")
        click_client(hwnd, 60, 239)
        snap2 = os.path.join(EVIDENCE_DIR, "pc_e2e_02_toplist.png")
        capture_window(hwnd, snap2)
        print("  [Step 2] Toplist view captured: %s" % snap2)
        
        # Step 3: Click Favorites in sidebar (x=60, y=419)
        print("\n[4/6] Clicking sidebar 'Favorites' (x=60, y=419)...")
        click_client(hwnd, 60, 419)
        snap3 = os.path.join(EVIDENCE_DIR, "pc_e2e_03_favorites.png")
        capture_window(hwnd, snap3)
        print("  [Step 3] Favorites view captured: %s" % snap3)

        # Step 4: Click Sync Center in sidebar (x=60, y=645)
        print("\n[5/6] Clicking sidebar 'Sync Center' (x=60, y=645)...")
        click_client(hwnd, 60, 645)
        snap4 = os.path.join(EVIDENCE_DIR, "pc_e2e_04_sync_center.png")
        capture_window(hwnd, snap4)
        print("  [Step 4] Sync Center view captured: %s" % snap4)

        # Step 5: Test Shortcuts (Space for Play/Pause, Ctrl+K for Search)
        print("\n[6/6] Testing shortcuts (Space, Ctrl+K)...")
        send_key("space")
        time.sleep(0.5)
        send_hotkey("ctrl", "k")
        time.sleep(0.8)
        snap5 = os.path.join(EVIDENCE_DIR, "pc_e2e_05_shortcuts_search.png")
        capture_window(hwnd, snap5)
        print("  [Step 5] Shortcuts captured: %s" % snap5)
        
        print("\n" + "=" * 60)
        if BLANK_CAPTURES:
            print("FAILURE: %d blank screenshot(s) captured - evidence is invalid." % len(BLANK_CAPTURES))
            for p in BLANK_CAPTURES:
                print("  - %s" % p)
            print("Fix the capture path (see capture_window) and re-run. Nothing was verified.")
            print("=" * 60)
            sys.exit(1)
        print("SUCCESS: Physical PC GUI E2E Automated Verification PASSED!")
        print("Saved 5 evidence screenshots in: %s" % EVIDENCE_DIR)
        print("=" * 60)
        
    finally:
        print("\nClosing physical test process...")
        user32.PostMessageW(hwnd, 0x0010, 0, 0)
        time.sleep(1.0)
        if proc.poll() is None:
            proc.kill()
        print("[OK] Test process cleaned up successfully.")

if __name__ == "__main__":
    main()
