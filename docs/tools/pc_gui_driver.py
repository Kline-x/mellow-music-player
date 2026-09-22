# -*- coding: utf-8 -*-
"""Mellow Music PC artifact E2E driver (real user-perspective GUI automation)."""
import ctypes, sys, os, time, json
from ctypes import wintypes

HERE = os.path.dirname(os.path.abspath(__file__))
STATE = os.path.join(HERE, "state.json")

user32 = ctypes.WinDLL("user32", use_last_error=True)
gdi32 = ctypes.WinDLL("gdi32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

PW_RENDERFULLCONTENT = 0x00000002
SW_RESTORE = 9
SW_SHOW = 5
VK = {
    "space": 0x20, "enter": 0x0D, "return": 0x0D, "esc": 0x1B, "escape": 0x1B,
    "tab": 0x09, "backspace": 0x08, "delete": 0x2E, "left": 0x25, "up": 0x26,
    "right": 0x27, "down": 0x28, "home": 0x24, "end": 0x23, "ctrl": 0x11,
    "alt": 0x12, "shift": 0x10, "m": 0x4D, "l": 0x4C, "q": 0x51, "k": 0x4B,
    "e": 0x45, "s": 0x53, "f": 0x46, "d": 0x44, "a": 0x41,
}

def load_state():
    if os.path.exists(STATE):
        with open(STATE) as f:
            return json.load(f)
    return {}

def save_state(s):
    with open(STATE, "w") as f:
        json.dump(s, f, ensure_ascii=False, indent=1)

def find_window(pid=None, title=None):
    res = []
    EnumProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def cb(hwnd, lparam):
        if not user32.IsWindowVisible(hwnd):
            return True
        wpid = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(wpid))
        buf = ctypes.create_unicode_buffer(512)
        user32.GetWindowTextW(hwnd, buf, 512)
        cls = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(hwnd, cls, 256)
        if pid is None and title is None:
            res.append((hwnd, wpid.value, buf.value, cls.value))
        elif pid is not None and wpid.value == pid:
            res.append((hwnd, wpid.value, buf.value, cls.value))
        elif title is not None and buf.value == title:
            res.append((hwnd, wpid.value, buf.value, cls.value))
        return True
    user32.EnumWindows(EnumProc(cb), 0)
    return res

def get_hwnd():
    st = load_state()
    pid = st.get("pid")
    if pid:
        ws = [w for w in find_window(pid=pid) if w[2]]
        if ws:
            return ws[0][0]
    # fallback 1: the Flutter Win32 runner window class
    for w in find_window():
        if w[3] == "FLUTTER_RUNNER_WIN32_WINDOW":
            return w[0]
    # fallback 2: any visible window titled 'app' or containing Mellow
    for w in find_window():
        if w[2] in ("app", "Mellow Music", "Mellow Music \u00b7 \u6da6\u97f3") or "Mellow" in w[2]:
            return w[0]
    return None

def rect_of(hwnd):
    r = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(r))
    return (r.left, r.top, r.right, r.bottom)

def client_size(hwnd):
    r = wintypes.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(r))
    return (r.right - r.left, r.bottom - r.top)

def foreground(hwnd):
    user32.ShowWindow(hwnd, SW_RESTORE)
    if user32.GetForegroundWindow() == hwnd:
        return True
    # unlock the Win32 foreground lock by simulating an ALT press
    user32.keybd_event(0x12, 0, 0, 0)
    user32.keybd_event(0x12, 0, 2, 0)
    fg = user32.GetForegroundWindow()
    tid_fg = user32.GetWindowThreadProcessId(fg, None)
    tid_me = kernel32.GetCurrentThreadId()
    user32.AttachThreadInput(tid_me, tid_fg, True)
    user32.SetForegroundWindow(hwnd)
    user32.BringWindowToTop(hwnd)
    user32.AttachThreadInput(tid_me, tid_fg, False)
    time.sleep(0.25)
    return user32.GetForegroundWindow() == hwnd

def capture(hwnd, out):
    """PrintWindow first; fall back to screen grab if the result is blank."""
    from PIL import Image
    import numpy as np
    l, t, r, b = rect_of(hwnd)
    w, h = r - l, b - t
    hdc = user32.GetWindowDC(hwnd)
    mdc = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
    gdi32.SelectObject(mdc, bmp)
    ok = user32.PrintWindow(hwnd, mdc, PW_RENDERFULLCONTENT)
    class BITMAPINFOHEADER(ctypes.Structure):
        _fields_ = [("biSize", wintypes.DWORD), ("biWidth", ctypes.c_long),
                    ("biHeight", ctypes.c_long), ("biPlanes", wintypes.WORD),
                    ("biBitCount", wintypes.WORD), ("biCompression", wintypes.DWORD),
                    ("biSizeImage", wintypes.DWORD), ("biXPelsPerMeter", ctypes.c_long),
                    ("biYPelsPerMeter", ctypes.c_long), ("biClrUsed", wintypes.DWORD),
                    ("biClrImportant", wintypes.DWORD)]
    bi = BITMAPINFOHEADER()
    bi.biSize = ctypes.sizeof(BITMAPINFOHEADER)
    bi.biWidth = w
    bi.biHeight = -h
    bi.biPlanes = 1
    bi.biBitCount = 32
    bi.biCompression = 0
    buf = ctypes.create_string_buffer(w * h * 4)
    gdi32.GetDIBits(mdc, bmp, 0, h, buf, ctypes.byref(bi), 0)
    img = Image.frombuffer("RGBA", (w, h), buf, "raw", "BGRA", 0, 1).convert("RGB")
    arr = np.asarray(img)
    blank = ok == 0 or arr.std() < 1.0
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mdc)
    user32.ReleaseDC(hwnd, hdc)
    if blank:
        foreground(hwnd)
        time.sleep(0.5)
        from PIL import ImageGrab
        img = ImageGrab.grab(bbox=(l, t, r, b), all_screens=False)
    img.save(out)
    return img.size

def click_at(px, py, double=False, button="left"):
    user32.SetCursorPos(int(px), int(py))
    time.sleep(0.12)
    down = 0x0002 if button == "left" else 0x0008
    up = 0x0004 if button == "left" else 0x0010
    user32.mouse_event(down, 0, 0, 0, 0)
    time.sleep(0.06)
    user32.mouse_event(up, 0, 0, 0, 0)
    if double:
        time.sleep(0.08)
        user32.mouse_event(down, 0, 0, 0, 0)
        time.sleep(0.06)
        user32.mouse_event(up, 0, 0, 0, 0)

def drag(x1, y1, x2, y2, steps=14):
    user32.SetCursorPos(int(x1), int(y1))
    time.sleep(0.15)
    user32.mouse_event(0x0002, 0, 0, 0, 0)
    time.sleep(0.1)
    for i in range(1, steps + 1):
        x = x1 + (x2 - x1) * i / steps
        y = y1 + (y2 - y1) * i / steps
        user32.SetCursorPos(int(x), int(y))
        time.sleep(0.03)
    time.sleep(0.1)
    user32.mouse_event(0x0004, 0, 0, 0, 0)

def press(vk, hold=0.05):
    user32.keybd_event(vk, 0, 0, 0)
    time.sleep(hold)
    user32.keybd_event(vk, 0, 2, 0)

def set_clipboard(text):
    CF_UNICODETEXT = 13
    GMEM_MOVEABLE = 0x0002
    kernel32.GlobalAlloc.argtypes = [wintypes.UINT, ctypes.c_size_t]
    kernel32.GlobalAlloc.restype = ctypes.c_void_p
    kernel32.GlobalLock.argtypes = [ctypes.c_void_p]
    kernel32.GlobalLock.restype = ctypes.c_void_p
    kernel32.GlobalUnlock.argtypes = [ctypes.c_void_p]
    user32.SetClipboardData.argtypes = [wintypes.UINT, ctypes.c_void_p]
    user32.SetClipboardData.restype = ctypes.c_void_p
    user32.OpenClipboard.argtypes = [ctypes.c_void_p]
    data = text.encode("utf-16-le") + b"\x00\x00"
    user32.OpenClipboard(None)
    user32.EmptyClipboard()
    h = kernel32.GlobalAlloc(GMEM_MOVEABLE, len(data))
    p = kernel32.GlobalLock(h)
    ctypes.memmove(p, data, len(data))
    kernel32.GlobalUnlock(h)
    user32.SetClipboardData(CF_UNICODETEXT, h)
    user32.CloseClipboard()

def main():
    a = sys.argv[1:]
    cmd = a[0]
    st = load_state()
    if cmd == "launch":
        exe = a[1]
        os.chdir(os.path.dirname(exe))
        import subprocess
        p = subprocess.Popen([exe], cwd=os.path.dirname(exe))
        st["pid"] = p.pid
        st["exe"] = exe
        save_state(st)
        hwnd = None
        for _ in range(60):
            time.sleep(0.5)
            ws = [w for w in find_window(pid=p.pid) if w[2]]
            if ws:
                hwnd = ws[0][0]
                break
        if not hwnd:
            print("NO_WINDOW pid=%s" % p.pid)
            return
        print("hwnd=%s pid=%s title=%r class=%r" % (hwnd, p.pid, ws[0][2], ws[0][3]))
        print("rect=%s client=%s" % (rect_of(hwnd), client_size(hwnd)))
    elif cmd == "resize":
        hwnd = get_hwnd()
        w, h = int(a[1]), int(a[2])
        x, y = (int(a[3]), int(a[4])) if len(a) > 4 else (0, 0)
        user32.SetWindowPos(hwnd, 0, x, y, w, h, 0x0040)
        time.sleep(0.6)
        print("rect=%s client=%s" % (rect_of(hwnd), client_size(hwnd)))
    elif cmd == "info":
        hwnd = get_hwnd()
        if not hwnd:
            print("NO_WINDOW")
            return
        buf = ctypes.create_unicode_buffer(512)
        user32.GetWindowTextW(hwnd, buf, 512)
        print(json.dumps({"hwnd": hwnd, "title": buf.value, "rect": rect_of(hwnd),
                          "client": client_size(hwnd),
                          "alive": bool(user32.IsWindow(hwnd))}, ensure_ascii=False))
    elif cmd == "shot":
        hwnd = get_hwnd()
        foreground(hwnd)
        time.sleep(float(a[2]) if len(a) > 2 else 0.45)
        size = capture(hwnd, a[1])
        print("saved %s %s" % (a[1], size))
    elif cmd == "click":
        hwnd = get_hwnd()
        x, y = int(a[1]), int(a[2])
        double = len(a) > 3 and a[3] == "double"
        ok = foreground(hwnd)
        l, t, r, b = rect_of(hwnd)
        if not ok:
            # a click on an inactive window is consumed by activation: click, then click again
            click_at(l + x, t + y)
            time.sleep(0.4)
            foreground(hwnd)
            l, t, r, b = rect_of(hwnd)
        click_at(l + x, t + y, double=double)
        print("clicked win(%s,%s) -> screen(%s,%s) fg=%s" % (x, y, l + x, t + y, hwnd == user32.GetForegroundWindow()))
    elif cmd == "drag":
        hwnd = get_hwnd()
        foreground(hwnd)
        l, t, r, b = rect_of(hwnd)
        drag(l + int(a[1]), t + int(a[2]), l + int(a[3]), t + int(a[4]))
        print("dragged")
    elif cmd == "key":
        hwnd = get_hwnd()
        foreground(hwnd)
        for k in a[1:]:
            press(VK[k.lower()])
            time.sleep(0.18)
        print("keys %s" % a[1:])
    elif cmd == "hotkey":
        hwnd = get_hwnd()
        foreground(hwnd)
        mods = [VK[m.lower()] for m in a[1:-1]]
        for m in mods:
            user32.keybd_event(m, 0, 0, 0)
        press(VK[a[-1].lower()])
        for m in reversed(mods):
            user32.keybd_event(m, 0, 2, 0)
        print("hotkey %s" % a[1:])
    elif cmd == "pastefile":
        hwnd = get_hwnd()
        foreground(hwnd)
        with open(a[1], encoding="utf-8") as f:
            txt = f.read().strip()
        set_clipboard(txt)
        time.sleep(0.2)
        user32.keybd_event(VK["ctrl"], 0, 0, 0)
        press(0x56)  # V
        user32.keybd_event(VK["ctrl"], 0, 2, 0)
        print("pasted-file %r" % txt)
    elif cmd == "paste":
        hwnd = get_hwnd()
        foreground(hwnd)
        set_clipboard(a[1])
        time.sleep(0.2)
        user32.keybd_event(VK["ctrl"], 0, 0, 0)
        press(0x56)  # V
        user32.keybd_event(VK["ctrl"], 0, 2, 0)
        print("pasted %r" % a[1])
    elif cmd == "close":
        hwnd = get_hwnd()
        if hwnd:
            user32.PostMessageW(hwnd, 0x0010, 0, 0)
        print("close requested")
    else:
        print("unknown cmd")

if __name__ == "__main__":
    main()
