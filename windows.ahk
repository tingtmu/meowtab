; Window listing for meowtab.ahk and meowtab-classic.ahk (#Included by both, and by settings-panel.ahk; MONITORS lives in the
; main script): the Alt+Tab-eligible windows, most recently activated first; the recency behind that order (MruStart, called
; once at startup, seeds it and installs the foreground hook; it declares mru, mruTick, fgHook and fgHookH global); the current
; monitor and its work area; whether a window is still open. Functions only.

; Recency is tracked from foreground changes, not Z-order: tiling WMs re-tile with
; SetWindowPos, which reshuffles Z-order without anything being activated.
MruStart() {
    global mru := Map(), mruTick := 0   ; hwnd -> stamp of last activation (higher = newer)
    for hwnd in WinGetList()            ; seed from Z-order so the first Alt+Tab is sensible
        mru[hwnd] := -A_Index
    if a := WinExist("A")               ; the active window is the newest
        mru[DllCall("GetAncestor", "ptr", a, "uint", 3, "ptr")] := 0
    global fgHook := CallbackCreate(OnForeground, "F", 7)
    global fgHookH := DllCall("SetWinEventHook", "uint", 3, "uint", 3, "ptr", 0, "ptr", fgHook   ; EVENT_SYSTEM_FOREGROUND
        , "uint", 0, "uint", 0, "uint", 0, "ptr")                                               ; WINEVENT_OUTOFCONTEXT
    OnExit((*) => (DllCall("UnhookWinEvent", "ptr", fgHookH), 0))   ; exit frees mru before it stops pumping events
}

; Monitor of the active window; falls back to the cursor's monitor (e.g. empty workspace).
CurrentMonitor() {
    hwnd := WinExist("A")
    if hwnd && !IsShell(hwnd)
        return DllCall("MonitorFromWindow", "ptr", hwnd, "uint", 2, "ptr")
    MouseGetPos &x, &y
    return DllCall("MonitorFromPoint", "int64", (y << 32) | (x & 0xFFFFFFFF), "uint", 2, "ptr")
}

; The work area (rcWork) of monitor mon, [l, t, r, b] in screen px.
WorkArea(mon) => (mi := Buffer(40, 0), NumPut("uint", 40, mi), DllCall("GetMonitorInfoW", "ptr", mon, "ptr", mi), [NumGet(mi, 20, "int"), NumGet(mi, 24, "int"), NumGet(mi, 28, "int"), NumGet(mi, 32, "int")])

OnForeground(hook, event, hwnd, idObject, *) {
    global mruTick
    if idObject != 0 || !hwnd           ; OBJID_WINDOW only
        return
    mru[hwnd] := ++mruTick
    owner := DllCall("GetAncestor", "ptr", hwnd, "uint", 3, "ptr")   ; GA_ROOTOWNER: a dialog counts for its app
    if owner && owner != hwnd
        mru[owner] := mruTick
}

; Alt+Tab-eligible windows on every monitor (MONITORS = "current": on the current one), most recently activated first.
CollectWindows() {
    mon := MONITORS = "current" ? CurrentMonitor() : 0   ; 0: no filter (a monitor's handle is never 0)
    out := []
    for hwnd in WinGetList() {          ; Z-order breaks ties between never-activated windows
        try {   ; a window may close mid-scan
            if IsSwitchable(hwnd) && (!mon || DllCall("MonitorFromWindow", "ptr", hwnd, "uint", 2, "ptr") = mon)
                out.Push(hwnd)
        }
    }
    for hwnd in [mru*]                  ; forget closed windows (handles get reused)
        if !WinExist(hwnd)
            mru.Delete(hwnd)
    return SortByRecency(out)
}

; Stable insertion sort, newest first; lists are short.
SortByRecency(hwnds) {
    out := []
    for hwnd in hwnds {
        s := mru.Get(hwnd, -1e9), i := out.Length + 1
        while i > 1 && mru.Get(out[i - 1], -1e9) < s
            i--
        out.InsertAt(i, hwnd)
    }
    return out
}

IsShell(hwnd) {
    cls := WinGetClass(hwnd)
    return cls = "Progman" || cls = "WorkerW" || cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd"
}

IsSwitchable(hwnd) {
    if WinGetTitle(hwnd) = "" || IsShell(hwnd)
        return false
    ex := WinGetExStyle(hwnd)
    if ex & 0x08000000                                   ; WS_EX_NOACTIVATE
        return false
    if !(ex & 0x40000) {                                 ; not WS_EX_APPWINDOW
        if ex & 0x80                                     ; WS_EX_TOOLWINDOW
            return false
        if DllCall("GetWindow", "ptr", hwnd, "uint", 4, "ptr")  ; owned window
            return false
    }
    cloaked := 0                                         ; DWMWA_CLOAKED: other desktops, hidden workspaces, background UWP
    DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 14, "uint*", &cloaked, "uint", 4)
    return !cloaked
}

; Exists and visible (apps that "close to tray" only hide their window).
IsOpen(hwnd) => WinExist(hwnd) && DllCall("IsWindowVisible", "ptr", hwnd)
