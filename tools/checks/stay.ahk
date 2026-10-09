; stay.ahk: the custom-shortcuts stay-open timings (4.1), beside timing.ahk (which times the plain opens and steps), with the same
; QueryPerformanceCounter timing, on 30 demo windows from lib.ahk. The real Step() / Stay() / Finish() are called from the closed
; state, as the hotkeys call them; run.ps1 includes an instrumented COPY of the root's sources in which stay-seam.ahk makes them
; list the demo windows only.
;   i    plain open, the switch shortcut:  Step(1) from closed, then Finish(false); 10 times     (the reference)
;   ii   stay-open:  Stay() from closed, i.e. Step(1) + stayIH.Start() + StayHotkeys("On") (the mouse hook goes in); then Finish(false)
;        (stayIH.Stop() + StayHotkeys("Off")); 10 times
;   iii  Step(1) every ~33 ms for 2 s inside a stay-open pane (key block and mouse hook on)
; Per call: n, median, max (ms), and against the budget (opens <= 30, steps <= 4): how many samples are over it. "+ DwmFlush" rows add the
; wait for DWM's next frame, as timing.ahk's "4". Each open also checks the state it left (cycling / sticky / stayIH), listed as "state".
; Raw samples go to <Out>\timing-stay-<tag>.txt.
; Run from the repo root:  powershell -ExecutionPolicy Bypass -File tools\checks\run.ps1 stay
;                          powershell -ExecutionPolicy Bypass -File tools\checks\run.ps1 stay -Validate
; (also [-Root <dir>] [-Out <dir>] [-Tag <name>], see run.ps1; default out: build\checks\<tag>). Keep hands off the mouse and keyboard
; while it runs (about 40 s). Exit code: 0 ok, 2 the 2-minute exit, 3 an error, 4 no screen (SKIP), 5 a stray AutoHotkey window.
global SAMPLES := Map(), LIMITS := Map(), phase := "", stateBad := 0
StayMain(A_Args[1], A_Args[2])
ExitApp 0

StayMain(out, tag) {
    DirCreate out
    if !DllCall("GetForegroundWindow") {
        Say("SKIP no screen: no foreground window (query session: Disc?), so nothing was shown")
        ExitApp(4)
    }
    Stage(30), SetWallpaper(false)
    Park()
    c0 := Qpc(), t0 := A_TickCount, Sleep(100)
    clock := "QPC " Round(Qpc() - c0, 1) " ms vs A_TickCount " A_TickCount - t0 " ms over Sleep(100)"
    OpenTimes("i plain open (Step)", () => Step(1), false, 10)
    OpenTimes("ii stay-open (Stay)", Stay, true, 10)
    StaySteps()
    Report(out, tag, clock)
}

Qpc() {   ; ms
    static f := 0
    if !f
        DllCall("QueryPerformanceFrequency", "int64*", &f)
    DllCall("QueryPerformanceCounter", "int64*", &c := 0)
    return c * 1000 / f
}

TimeLog(what, ms, budget := 0) {
    k := phase " / " what
    if !SAMPLES.Has(k)
        SAMPLES[k] := [], LIMITS[k] := budget
    SAMPLES[k].Push(ms)
}

Timed(what, fn, budget := 0) {   ; one call of fn: its time goes into the current phase and comes back (ms)
    t := Qpc(), fn()
    TimeLog(what, dt := Qpc() - t, budget)
    return dt
}

; count opens from the closed state with fn (Step(1) or Stay()), each followed by Finish(false). stay: whether the stay-open mode is expected.
OpenTimes(name, fn, stay, count) {
    global phase := name, stateBad
    Loop count {
        Park(), Sleep(50)
        ms := Timed("1 open call", fn, 30)                 ; leaves this thread Critical, as the hotkeys' threads are
        t := Qpc(), DllCall("dwmapi\DwmFlush")
        TimeLog("2 open call + DwmFlush (the next DWM frame)", ms + Qpc() - t, 30)
        got := (cycling ? 1 : 0) " " (sticky ? 1 : 0) " " (stayIH.InProgress ? 1 : 0)   ; what the open left: pane open, the mode as asked, key block running
        if got != (stay ? "1 1 1" : "1 0 0") {
            stateBad += 1
            Say("WARN " name " #" A_Index ": state after the open is cycling/sticky/stayIH = " got)
        }
        Critical("Off"), Sleep(600)                        ; the picture's slide and the thumbnails finish
        Timed("3 Finish(false)", () => Finish(false))
        Critical("Off")
        if cycling || sticky || stayIH.InProgress {
            stateBad += 1
            Say("WARN " name " #" A_Index ": state after Finish is cycling/sticky/stayIH = " cycling " " sticky " " stayIH.InProgress)
        }
        Sleep(300)
    }
}

StaySteps() {
    global phase := "iii steps in a stay-open pane"
    Park(), Sleep(50)
    Stay(), Critical("Off"), Sleep(600)                    ; the open isn't timed here
    t0 := Qpc()
    while Qpc() - t0 < 2000 {
        Timed("Step", () => Step(1), 4)
        Critical("Off"), Sleep(33)
    }
    Sleep(300)
    Finish(false), Critical("Off"), Sleep(150)
}

Median(a) {
    s := [], n := a.Length
    for v in a
        s.Push(v)
    Loop n - 1 {                                           ; insertion sort
        i := A_Index + 1, v := s[i], j := i - 1
        while j >= 1 && s[j] > v
            s[j + 1] := s[j], j--
        s[j + 1] := v
    }
    return !n ? 0 : Mod(n, 2) ? s[(n + 1) // 2] : (s[n // 2] + s[n // 2 + 1]) / 2
}

Report(out, tag, clock) {
    text := "timing-stay " tag ": ms; " clock "`n" Format("{:-62s}{:5s}{:9s}{:9s}{:8s}{:6s}`n", "phase / call", "n", "median", "max", "budget", "over")
    raw := ""
    for k, a in SAMPLES {                                  ; a Map walks its keys in order
        b := LIMITS[k], over := 0
        for v in a
            over += b && v > b
        text .= Format("{:-62s}{:5d}{:9.2f}{:9.2f}{:8s}{:6s}`n", k, a.Length, Median(a), Max(a*), b ? "<= " b : "", b ? over : "")
        raw .= k ":"
        for v in a
            raw .= " " Round(v, 2)
        raw .= "`n"
    }
    text .= "state after each open / Finish as expected: " (stateBad ? stateBad " WARN (see above)" : "yes") "`n"
    Say(text)
    try FileDelete(out "\timing-stay-" tag ".txt")
    FileAppend(text "`nraw samples, in call order:`n" raw, out "\timing-stay-" tag ".txt")
}
