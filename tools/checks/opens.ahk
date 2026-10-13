; opens.ahk: velvet-look's "Many opens" (tasks 3.4 and 7.2): the pane opened and closed n times (default 200) on lib.ahk's demo
; windows over the light stand-in wallpaper, as timing.ahk stages them, in the look run.ps1 gives the app (-Look). Each open is
; lib.ahk's OpenPane / ClosePane: the picture's slide-up finishes, the scroll bar's fade is still pending at the close. The opens
; take 8 and 30 windows by turns, the shaped layout and the grid, so the pane's size changes at each (two grid counts, such as 29
; and 30, make the same pane) and Velvet's base layer and its caches are made again, the old ones freed. Each sample follows an
; open on 30. The last one is closed 60 ms in instead, mid-motion: the picture still sliding up, a wheel scroll under way.
; One line per check, PASS or FAIL, then ALL PASSED or "n FAILED":
;   handles  GDI and USER objects (GetGuiResources) after the last close: at most 2 more than after a warm-up of 10 opens. A leak of
;            one object per open adds n; 2 leaves room for an object Windows or GDI+ makes once, late.
;   memory   private bytes (GetProcessMemoryInfo), the same way: at most 1 MB more. A leaked surface is megabytes and an icon's bitmap
;            a few KB, so leaking either per open adds far more over 200 opens, while 1 MB leaves room for the heap to settle. A
;            leaked brush or path (under 1 KB, and neither a GDI nor a USER object) slips under both.
;   timers   run.ps1 includes an instrumented COPY of the root's sources in which every function the app hands SetTimer (its
;            "wrap:" lines: ScrollTick, BarFade, PeekTick, PaneHover, ...) is wrapped, as timing's frame functions are, so each call
;            reaches TimeLog here. A timer still on fires within its period (the longest, BarFade's, is BAR_SHOW_MS = 1 s), so no
;            call in the 2 s after the last close means none runs. Its control: calls were seen during the opens.
; The samples (after the warm-up, every 50 opens, after the last) and the verdicts also go to <Out>\opens-<tag>.txt.
; Run from the repo root:  powershell -ExecutionPolicy Bypass -File tools\checks\run.ps1 opens -Look velvet [-Count <n>]
;                          powershell -ExecutionPolicy Bypass -File tools\checks\run.ps1 opens -Look velvet -Validate
; (also [-Root <dir>] [-Out <dir>] [-Tag <name>] [-Picture <file>], see run.ps1; default out: build\checks\<tag>; with a picture, its
; layer is made again at each open too). Keep hands off the mouse and keyboard while it runs (about 2.5 min for 200). Exit code:
; 0 ALL PASSED, 1 a FAIL, 2 the safety exit, 3 an error, 4 no screen (SKIP), 5 a stray AutoHotkey window.
global lateCalls := 0, seenCalls := Map(), opFails := 0, opText := ""   ; timer calls after the last close (a Map then) and before it
SetTimer(Overrun, -(Integer(A_Args[3]) + 70) * 1000)   ; lib.ahk's safety exit, later: about 0.7 s an open, and room
OpensMain(A_Args[1], A_Args[2], Integer(A_Args[3]))
ExitApp opFails ? 1 : 0

OpensMain(out, tag, n) {
    global lateCalls
    DirCreate out
    if !DllCall("GetForegroundWindow") {
        Say("SKIP no screen: no foreground window (query session: Disc?), so nothing was shown")
        ExitApp(4)
    }
    Note("opens " tag ": " n " opens in the " (IsSet(PANE_LOOK) ? PANE_LOOK : "windows11") " look, 8 and 30 demo windows by turns")
    Stage(30), SetWallpaper(false)                     ; as timing.ahk: light, whatever the Windows mode is
    Loop 10                                            ; the warm-up: GDI+'s, DWM's and the app's own caches fill
        OpenPane(A_Index & 1 ? 8 : 30), ClosePane()
    Sleep(2000)                                        ; as long as the watch after the last close
    first := Taken("after the warm-up of 10")
    Loop n - 1 {
        OpenPane(A_Index & 1 ? 8 : 30), ClosePane()
        if !Mod(A_Index, 50)
            Taken("after " A_Index " of " n)
    }
    Park(), Sleep(50), ListDemo(30), ShowPane(true), Critical("Off")   ; the last open, closed 60 ms in
    Notch(1), Sleep(60)
    Finish(false), lateCalls := Map(), Critical("Off")   ; Finish leaves the thread Critical: no timer runs before the watch starts
    Sleep(2000)
    last := Taken("after " n ", 2 s after the last close")
    Verdict(last[2] - first[2] <= 2 && last[3] - first[3] <= 2
        , "handles: GDI " first[2] " -> " last[2] ", USER " first[3] " -> " last[3] " (at most 2 more)")
    Verdict(last[4] - first[4] <= 1024, "memory: private " first[4] " -> " last[4] " KB (at most 1024 KB more)")
    Verdict(seenCalls.Count, "control, the app's timer functions called during the opens: " (seenCalls.Count ? Counts(seenCalls)
        : "none, so the wrappers aren't in this run and the timer check proves nothing"))
    if seenCalls.Count
        Verdict(!lateCalls.Count, "timers: " (lateCalls.Count ? "called after the last close: " Counts(lateCalls)
            : "none called in the 2 s after the last close"))
    Note(opFails ? opFails " FAILED" : "ALL PASSED")
    try FileDelete(out "\opens-" tag ".txt")
    FileAppend(opText, out "\opens-" tag ".txt")
}

; [when, GDI objects, USER objects, private KB] of this process now, noted as a line
Taken(when) {
    pmc := Buffer(8 + 9 * A_PtrSize, 0), NumPut("uint", pmc.Size, pmc)   ; PROCESS_MEMORY_COUNTERS_EX: PrivateUsage is its last field
    if !DllCall("psapi\GetProcessMemoryInfo", "ptr", -1, "ptr", pmc, "uint", pmc.Size)   ; -1: this process
        throw OSError()
    row := [when, DllCall("GetGuiResources", "ptr", -1, "uint", 0), DllCall("GetGuiResources", "ptr", -1, "uint", 1)   ; GDI, USER
        , NumGet(pmc, 8 + 8 * A_PtrSize, "uptr") // 1024]
    Note(Format("{:-42s}GDI {:5d}   USER {:5d}   private {:8d} KB", row*))
    return row
}

; The generated wrappers' (run.ps1's template, shared with timing.ahk): each call of a function the app hands SetTimer comes here,
; counted under the opens or, once the last close is done, under after it. Their time isn't used.
Qpc() => 0
TimeLog(what, ms) {
    global seenCalls, lateCalls
    if !IsSet(seenCalls)                               ; WarmUp's timer can come before this file's first line has run
        return
    m := lateCalls ? lateCalls : seenCalls
    m[what] := m.Get(what, 0) + 1
}

Counts(m) {   ; "PeekTick 120, PaneHover 10, ..." from a Map of call counts
    s := ""
    for fn, k in m
        s .= (s ? ", " : "") fn " " k
    return s
}

Note(s) {   ; a line out, and into the report file's text
    global opText
    opText .= s "`n"
    Say(s)
}

Verdict(ok, text) {   ; PASS or FAIL, as keys.ahk's lines
    global opFails
    opFails += !ok
    Note((ok ? "PASS " : "FAIL ") text)
}
