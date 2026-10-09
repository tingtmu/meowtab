; keys.ahk: the custom-shortcuts cases (4.2) that tests\meowtab.test.ahk avoids (it holds Ctrl, and never taps Win or Alt alone):
; with SWITCH_KEYS=Win+Q, no Start menu or menu bar may open. run.ps1 includes it AFTER the root's meowtab.ahk, which was started
; with that setting in a new temp data folder (DATA_DIR). Keys are sent at SendLevel 1 (Press, as the test does) so that this
; script's own hooks see them. One line per step: PASS or FAIL, then the foreground window's process.
;   control   a lone Win tap with no pane open opens Start (the Start detector works); a lone Alt tap on a window with a menu bar
;             puts it in menu mode (the menu detector works). Without these the checks that follow prove nothing, and are skipped.
;   1         Win held, Q, Q, Win released: pane opens, the switch happens (to window C), Start / Search never takes the foreground
;   2         stay-open pane (Ctrl+Alt+Tab): opened without menu mode; then a lone Alt tap: no menu mode, pane still open
;   3         stay-open pane: a lone Win tap: no Start / Search, pane still open
;   4         settings panel, a click on the switch field, Win down, Q, Win up: no Start / Search, the field shows Win+Q (closed unsaved)
; Start / Search = the foreground window's process is StartMenuExperienceHost.exe / SearchHost.exe (/ SearchApp.exe). Menu mode =
; GetGUIThreadInfo's flags on the menu window's thread have GUI_INMENUMODE 0x4 or GUI_SYSTEMMENUMODE 0x8. That window lives in
; its own process (keys-menuwin.ahk): a menu loop in this script's thread would hold it up.
; Run from the repo root:  powershell -ExecutionPolicy Bypass -File tools\checks\run.ps1 keys
;                          powershell -ExecutionPolicy Bypass -File tools\checks\run.ps1 keys -Validate
; (also [-Root <dir>], see run.ps1). Keep hands off the mouse and keyboard while it runs (about 25 s).
; Exit code: 0 all PASS, 1 a FAIL, 2 the 2-minute safety exit, 3 an error, 4 no screen (SKIP: nothing was sent).
; Whatever happens, OnExit releases every modifier, closes Start / Search with Esc, closes the helper and deletes the data folder.
OnError((e, *) => (FileAppend("ERR " e.Message " (" e.What ", line " e.Line ")`n", "*"), ExitApp(3)))
SetTimer(() => ExitApp(2), -120000)
OnExit(kcExit)
global kcFails := 0, kcCode := 0, kcH := Map(), kcName := Map(), kcGuis := [], kcMenu := 0
KeysMain()
ExitApp(kcCode ? kcCode : kcFails ? 1 : 0)

KeysMain() {
    global kcMenu
    ok := SWITCH_KEYS = "Win+Q" && STAY_KEYS = "Ctrl+Alt+Tab" && SETTINGS_ISSUES.Length = 0
    kcLine(ok, "setup: settings.ini gave SWITCH_KEYS=" SWITCH_KEYS ", STAY_KEYS=" STAY_KEYS (SETTINGS_ISSUES.Length ? ", issue: " SETTINGS_ISSUES[1] : ""))
    if !ok
        return
    Loop 5 {                                    ; a moment, in case the foreground is changing
        if WinExist("A")
            break
        Sleep 200
    }
    if !WinExist("A")
        return kcSkip("no foreground window: this session shows no screen (query session: Disc?). Nothing was opened or sent.")
    MonitorGetWorkArea(MonitorGetPrimary(), &l, &t)
    title := "keys check menu " A_TickCount
    Run(Format('"{1}" /ErrorStdOut "{2}keys-menuwin.ahk" {3} "{4}" {5} {6}', A_AhkPath, RegExReplace(A_LineFile, "[^\\]+$"), ProcessExist(), title, l + 140, t + 40))
    for i, n in ["A", "B", "C", "D"] {           ; on the primary monitor: only that monitor's windows are listed
        w := Gui(, "keys check " n), w.Show("x" l + 40 + i * 40 " y" t + 100 + i * 30 " w300 h200")
        kcGuis.Push(w), kcH[n] := w.Hwnd, kcName[w.Hwnd] := n
    }
    kcMenu := WinWait(title, , 5)
    if !kcMenu
        return kcLine(false, "setup: the menu-bar helper window (keys-menuwin.ahk) did not appear")
    Sleep 500
    if !kcAct(kcH["D"])
        return kcSkip("couldn't bring a demo window to the front (foreground: " kcFg() "). Nothing was sent.")

    ; --- control: a lone Win tap, no pane open, opens Start ---
    startMs := -1
    if kcReady(kcH["A"], "control, a lone Win tap") {
        Press("{LWin down}"), Press("{LWin up}", 0)
        startMs := kcWaitStart(3000), fg := kcFg()
        kcLine(startMs >= 0, "control, nothing of MeowTab open: a lone Win tap opens Start" (startMs >= 0 ? " (after " startMs " ms)" : "; it did not, so the Win checks prove nothing"), fg)
        kcCloseStart()
    }
    settle := Max(800, startMs * 3 + 300)       ; how long a Start that wasn't prevented would take to show, with room

    ; --- 1: Win+Q, Q, Q, Win released: the switch, no Start ---
    if startMs < 0
        kcSay("SKIP Win+Q: the Start detector isn't proven")
    else {
        for n in ["D", "C", "B", "A"]
            kcAct(kcH[n])                       ; recency A B C D
        if kcReady(kcH["A"], "Win+Q cycling") {
            Press("{LWin down}q"), opened := cycling
            Press("q"), sel := cycling && idx >= 1 && idx <= wins.Length ? kcName.Get(wins[idx], "?") : "-"
            Press("{LWin up}", 100)
            ms := kcWaitStart(settle), fg := kcFg(), at := kcName.Get(WinExist("A"), "?")
            kcLine(opened && ms < 0 && !cycling && at = "C", "Win+Q, Q, Q, Win released: pane " (opened ? "opened" : "did NOT open") ", the second Q selected " sel " (want C), "
                . (ms >= 0 ? "Start/Search OPENED" : "no Start/Search") ", pane " (cycling ? "STILL OPEN" : "closed") ", active window " at " (want C)", fg)
            kcClose()
        }
    }

    ; --- control: a lone Alt tap, no pane open, enters menu mode on the menu-bar window ---
    altOk := false
    if kcReady(kcMenu, "control, a lone Alt tap") {
        kcMenuClear()
        Press("{LAlt down}"), Press("{LAlt up}", 300)
        f := kcFlags(), fg := kcFg(), altOk := !kcNoMenu(f)
        kcLine(altOk, "control, nothing of MeowTab open: a lone Alt tap puts the menu-bar window in menu mode (flags " kcHex(f) ")" (altOk ? "" : "; it did not, so the Alt check proves nothing"), fg)
        kcMenuClear()
    }

    ; --- 2: stay-open pane, then a lone Alt tap ---
    if !altOk
        kcSay("SKIP stay-open pane and Alt: the menu detector isn't proven")
    else if kcReady(kcMenu, "stay-open pane and a lone Alt tap") {
        Press("{LCtrl down}{LAlt down}{Tab}"), Press("{LAlt up}{LCtrl up}", 300)
        opened := cycling && sticky, f := kcFlags(), fg := kcFg()
        kcLine(opened && kcNoMenu(f), "Ctrl+Alt+Tab, then released: the stay-open pane " (opened ? "stays open" : "is NOT open") ", " (kcNoMenu(f) ? "no menu mode" : "MENU MODE") " (flags " kcHex(f) ")", fg)
        if opened {
            Press("{LAlt down}"), Press("{LAlt up}", 300)
            f := kcFlags(), fg := kcFg(), still := WinExist("A") = kcMenu
            kcLine(kcNoMenu(f) && cycling && sticky && still, "stay-open pane open, a lone Alt tap: " (kcNoMenu(f) ? "no menu mode" : "MENU MODE") " (flags " kcHex(f) "), pane "
                . (cycling && sticky ? "still open" : "CLOSED") ", menu window " (still ? "still in front" : "NOT in front"), fg)
        }
        kcClose()
    }

    ; --- 3: stay-open pane, then a lone Win tap ---
    if startMs < 0
        kcSay("SKIP stay-open pane and Win: the Start detector isn't proven")
    else if kcReady(kcH["A"], "stay-open pane and a lone Win tap") {
        Press("{LCtrl down}{LAlt down}{Tab}"), Press("{LAlt up}{LCtrl up}", 300)
        if !(cycling && sticky)
            kcLine(false, "Ctrl+Alt+Tab did not open the stay-open pane, so the lone Win tap was not tried")
        else {
            Press("{LWin down}"), Press("{LWin up}", 0)
            ms := kcWaitStart(settle), fg := kcFg()
            kcLine(ms < 0 && cycling && sticky, "stay-open pane open, a lone Win tap: " (ms >= 0 ? "Start/Search OPENED" : "no Start/Search") ", pane " (cycling && sticky ? "still open" : "CLOSED"), fg)
        }
        kcClose()
    }

    ; --- 4: the settings panel captures Win+Q: no Start / Search, the field shows Win+Q ---
    if startMs < 0
        kcSay("SKIP the panel's Win+Q capture: the Start detector isn't proven")
    else {
        SettingsOpen(), Wait(500), PanelKeysDefaults()     ; the fields at Alt+Tab / Ctrl+Alt+Tab, so a captured Win+Q shows
        if kcReady(pnl.gui.Hwnd, "the panel's Win+Q capture") {
            ControlClick(kcField(1)), Wait(100)
            if !pnl.cap
                kcLine(false, "settings panel: a click on the switch field started no capture, so no key was sent")
            else {
                Press("{LWin down}"), Press("q"), Press("{LWin up}", 0)
                ms := kcWaitStart(settle), fg := kcFg()
                kcLine(ms < 0 && pnl.keys[1] = "Win+Q", "settings panel, the switch field clicked, Win down, Q, Win up: " (ms >= 0 ? "Start/Search OPENED" : "no Start/Search")
                    . ", the field shows " pnl.keys[1] " (want Win+Q)", fg)
            }
        }
        PanelClose(), kcCloseStart()                      ; closed without saving
    }

    held := kcHeld()
    kcLine(held = "", "end: no modifier key left down" (held ? " (still down: " held "; the exit handler releases them)" : ""))
    kcSay(kcFails ? kcFails " FAILED" : "ALL PASSED")
}

; ---- helpers (kc prefix: AutoHotkey names are shared with meowtab.ahk's; Act / Wait / Press are the test's, free of those) ----
kcSay(s) => FileAppend(s "`n", "*")

kcSkip(why) {
    global kcCode := 4
    kcSay("SKIP " why)
}

kcLine(ok, text, fg := "") {
    global kcFails
    kcFails += !ok
    kcSay((ok ? "PASS " : "FAIL ") text " | foreground: " (fg != "" ? fg : kcFg()))
}

kcFg() {
    try return WinGetProcessName("A")
    return "(none)"
}

kcIsStart(proc) => proc ~= "i)^(StartMenuExperienceHost|SearchHost|SearchApp)\.exe$"

; ms until the foreground is Start or Search, polling; -1 if it isn't within ms
kcWaitStart(ms) {
    t := A_TickCount
    while (d := A_TickCount - t) < ms {
        if kcIsStart(kcFg())
            return d
        Sleep 25
    }
    return -1
}

; GUITHREADINFO.flags of the menu window's thread; -1 if unreadable. 0x4 GUI_INMENUMODE, 0x8 GUI_SYSTEMMENUMODE.
kcFlags() {
    info := Buffer(A_PtrSize = 8 ? 72 : 48, 0), NumPut("uint", info.Size, info)
    tid := DllCall("GetWindowThreadProcessId", "ptr", kcMenu, "ptr", 0, "uint")
    return tid && DllCall("GetGUIThreadInfo", "uint", tid, "ptr", info) ? NumGet(info, 4, "uint") : -1
}
kcNoMenu(f) => f >= 0 && !(f & 0xC)
kcHex(f) => f < 0 ? "unreadable" : "0x" Format("{:X}", f)

kcField(j) {   ; the open settings panel's shortcut field j (1 = switching, 2 = staying open), as the test's Field
    for hwnd, e in pnl.el
        if e.kind = "keys" && e.j = j
            return e.ctl
}

; Esc ends a menu mode (the pane must be closed, else its *Esc hotkey takes it)
kcMenuClear() {
    Loop 3 {
        if kcNoMenu(kcFlags())
            return
        Press("{Esc}", 200)
    }
}

; Start or Search left open: close the pane first (its *Esc would take the key), then Esc, then give a demo window the focus
kcCloseStart() {
    if cycling
        Finish(false), Wait(50)
    Loop 3 {
        if !kcIsStart(kcFg())
            return
        Press("{Esc}", 300)
    }
    if kcIsStart(kcFg())
        kcAct(kcH["A"])
}

; end of a step: close the pane (stops the stay-open key block), end a menu mode, close Start / Search
kcClose() {
    if cycling
        Finish(false)
    Wait(100)
    kcMenuClear()
    kcCloseStart()
}

kcAct(hwnd) {
    try {
        WinActivate(hwnd)
        WinWaitActive(hwnd, , 2)
    }
    Sleep 200
    return WinExist("A") = hwnd
}

; our window in front before any key is sent; else the step says so and sends nothing
kcReady(hwnd, what) {
    if kcAct(hwnd)
        return true
    kcLine(false, what ": couldn't bring our window to the front, so no key was sent")
    return false
}

kcHeld() {   ; modifier keys the OS has down (injected ones too)
    out := ""
    for k, vk in Map("LWin", 0x5B, "RWin", 0x5C, "LShift", 0xA0, "RShift", 0xA1, "LCtrl", 0xA2, "RCtrl", 0xA3, "LAlt", 0xA4, "RAlt", 0xA5)
        if DllCall("GetAsyncKeyState", "int", vk, "short") < 0
            out .= (out ? " " : "") k
    return out
}

; The test's helpers: Press sends real keys that our own hotkeys see (SendLevel 1); Wait lets their threads run (Finish / Step leave this
; thread Critical). Unlike the test's Press, this one is Critical(-1) while the level is 1: otherwise stayIH.OnKeyDown's thread
; starts in the middle of the send, inherits SendLevel 1, and its mask key `Send("{Blind}{vkE8}")` goes out as a level-1 SendEvent,
; which stayIH (MinSendLevel 1) collects and blocks. A lone Alt / Win then opens the menu bar / Start. Seen on screen: a harness
; artifact, in the app the level is 0. Keep the real-key sends atomic.
Wait(ms) => (Critical("Off"), Sleep(ms))
Press(s, ms := 100) => (Critical(-1), SendLevel(1), SendEvent("{Blind}" s), SendLevel(0), Critical("Off"), Sleep(ms))

kcExit(*) {
    try {
        if cycling
            Finish(false)                       ; first: stops the stay-open key block and the click hooks
        Critical("Off")
    }
    try {
        if kcHeld() != ""
            Send "{LWin up}{RWin up}{LAlt up}{RAlt up}{LCtrl up}{RCtrl up}{LShift up}{RShift up}"   ; sent only if one is down: a lone Alt-up could itself open a menu
    }
    try {
        if kcIsStart(kcFg())
            Send "{Esc}"
    }
    if kcMenu
        try WinClose(kcMenu)
    for w in kcGuis
        try w.Destroy()
    try DirDelete(DATA_DIR, true)
    return 0
}
