#Requires AutoHotkey v2.0
; Integration test for meowtab.ahk. Opens 5 temporary windows on the
; current desktop (a tiling WM may tile them briefly), then checks ordering.
; Its checks run in parts it includes in place, in order: switching.ahk, grid.ahk, look.ahk, settings-data.ahk, panel.ahk and login.ahk.
; Run from the repo root:  AutoHotkey64.exe /ErrorStdOut tests\meowtab.test.ahk [velvet | windows11] | more
; (the pane's look to test in, set in the test's settings.ini as a user's would be; none: the app's default look)
if A_Args.Length && !(A_Args[1] = "velvet" || A_Args[1] = "windows11")
    FileAppend("usage: meowtab.test.ahk [velvet | windows11]`n", "*"), ExitApp(1)
DATA_DIR := A_Temp "\meowtab-test-" A_TickCount   ; a new, empty data folder: the test never reads or changes the user's own
OnExit((*) => (DirExist(DATA_DIR) && DirDelete(DATA_DIR, true), 0))   ; gone again however the run ends
STARTUP_DIR := DATA_DIR "\startup"         ; Start at login's shortcut goes there, never in the user's Startup folder
if A_Args.Length                           ; before the include: the app's startup reads it (and picks the title font by it)
    DirCreate(DATA_DIR), IniWrite(A_Args[1], DATA_DIR "\settings.ini", "settings", "PANE_LOOK")
ANIM_EFFECTS := false                      ; Windows' "Animation effects" as the app reads it (Animates): Velvet's motion only in its checks
#Include %A_LineFile%\..\..\meowtab.ahk
A_IconHidden := true   ; no tray icon, no TrayTip: the settings warnings the bad-value checks provoke stay out of the notification centre
lookDefault := SETTINGS_DEFAULTS["PANE_LOOK"]   ; the built-in look, as the startup load found it (this run's: PANE_LOOK)

global fails := 0, names := Map()

Check(label, got, want) {
    global fails
    ok := got = want
    fails += !ok
    FileAppend (ok ? "PASS " : "FAIL ") label (ok ? "" : "`n     got:  " got "`n     want: " want) "`n", "*"
}

Act(h) {
    WinActivate(h)
    WinWaitActive(h, , 2)
    Sleep 200
}

; Step / Finish make their thread Critical, as their hotkeys need. Called straight from this thread they leave
; it so, and then no hotkey or timer (WatchAlt, the mouse) could run: Wait sleeps with it off again.
Wait(ms) => (Critical("Off"), Sleep(ms))

; Send the pane a left click (WM_LBUTTONDOWN + UP) on window hwnd's tile: its centre, or with onX its close button,
; where it shows at the offset now (TileY). between: run between the press and the release, e.g. a scroll.
ClickTile(hwnd, onX := false, between := 0) {
    for i, w in wins
        if w = hwnd {
            t := tiles[i], y := TileY(t)
            x := onX ? t.x + t.w - CloseW(t) // 2 : t.x + t.w // 2, y += onX ? grid.hdr // 2 : grid.th // 2
            DllCall("SendMessageW", "ptr", g.Hwnd, "uint", 0x201, "ptr", 1, "ptr", y << 16 | x)
            if between
                between()
            return DllCall("SendMessageW", "ptr", g.Hwnd, "uint", 0x202, "ptr", 0, "ptr", y << 16 | x)
        }
    FileAppend "     (no tile for " names.Get(hwnd, hwnd) ")`n", "*"
}

Repeat(n, extra := Map()) {   ; n windows: A-D over and over, extra's (position -> window) in between
    out := []
    Loop n
        out.Push(extra.Has(A_Index) ? extra[A_Index] : h[["A", "B", "C", "D"][Mod(A_Index - 1, 4) + 1]])
    return out
}

; Open the pane on n windows (Repeat) with tile sel selected, as Step does once it has listed them. WatchAlt stays
; off: the pane stays open, as with Alt held, until Finish.
Open(n, sel, extra := Map()) {
    global wins := Repeat(n, extra), idx := sel, cycling := true
    ShowPane(true), Wait(0)
}

; Real keys, sent so that our own hotkeys see them; then their threads run. A held key stays held across calls.
Press(s, ms := 100) => (SendLevel(1), SendEvent("{Blind}" s), SendLevel(0), Wait(ms))

Ini(k) => IniRead(DATA_DIR "\settings.ini", "settings", k, "")   ; settings.ini's line for k ("" = none)

guis := [], h := Map()
for n in ["A", "B", "C", "D"] {
    w := Gui(, "alttab-test " n)
    w.Show("w300 h200")
    guis.Push(w), h[n] := w.Hwnd, names[w.Hwnd] := n
}
Sleep 800                                  ; let a tiling WM settle them

#Include %A_LineFile%\..\switching.ahk
#Include %A_LineFile%\..\grid.ahk
#Include %A_LineFile%\..\look.ahk
#Include %A_LineFile%\..\settings-data.ahk
#Include %A_LineFile%\..\panel.ahk
#Include %A_LineFile%\..\login.ahk

for w in guis
    w.Destroy()
FileAppend (fails ? fails " FAILED" : "ALL PASSED") "`n", "*"
ExitApp fails ? 1 : 0
