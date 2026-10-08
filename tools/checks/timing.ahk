; timing.ahk: the many-windows-grid timings (4.2) with QueryPerformanceCounter, on 30 demo windows (wins is set to them, so the
; user's own windows are never listed). run.ps1 includes an instrumented COPY of the root's sources: the frame functions it finds
; (ScrollTick, SelectTile, PaneWheel, and any -Wrap names) are renamed <name>__orig and wrapped, so timers and callers time
; each call into TimeLog. Calls the harness makes itself (CollectWindows, ShowPane, Step) are timed here.
;   i    open: CollectWindows + ShowPane(true), 10 times after GDI+'s warm-up (and the wait for DWM's next frame, DwmFlush)
;   ii   Tab held: Step(1) every ~33 ms for 2 s
;   iii  wheel: 6 notches down and 6 up (PostMessage), 150 ms apart, then 40 ms apart
;   iv   drag: a real mouse drag of the scroll bar, 12 steps down and 12 back up (about 1 s of ScrollTick frames); not run at HEAD
; Prints per call: n, idle (returned at once, under 0.2 ms: a notch past the end), and over the other calls the median and max (ms)
; and how many took over 8 ms; raw samples go to <Out>\timing-<tag>.txt.
; Run from the repo root:  powershell -ExecutionPolicy Bypass -File tools\checks\run.ps1 timing
;                          powershell -ExecutionPolicy Bypass -File tools\checks\run.ps1 timing -Validate
; (also [-Root <dir>] [-Out <dir>] [-Tag <name>] [-Wrap <fn>,...], see run.ps1; default out: build\checks\<tag>). Keep hands off the
; mouse and keyboard while it runs (about 40 s).
global SAMPLES := Map(), phase := ""               ; samples (ms) per "phase / call"
TimingMain(A_Args[1], A_Args[2])
ExitApp 0

TimingMain(out, tag) {
    DirCreate out
    Stage(30), SetWallpaper(false)                     ; light, whatever the Windows mode is; GDI+'s warm-up ran 200 ms after the start
    Park()
    c0 := Qpc(), t0 := A_TickCount, Sleep(100)
    clock := "QPC " Round(Qpc() - c0, 1) " ms vs A_TickCount " A_TickCount - t0 " ms over Sleep(100)"
    OpenTimes(10), TabHeld(), WheelNotches(), DragTimes()
    Report(out, tag, clock)
}

Qpc() {   ; ms
    static f := 0
    if !f
        DllCall("QueryPerformanceFrequency", "int64*", &f)
    DllCall("QueryPerformanceCounter", "int64*", &c := 0)
    return c * 1000 / f
}

TimeLog(what, ms) {   ; also called by the generated wrappers
    k := phase " / " what
    if !SAMPLES.Has(k)
        SAMPLES[k] := []
    SAMPLES[k].Push(ms)
}

Timed(what, fn) {   ; one call of fn: its time goes into the current phase and comes back (ms)
    t := Qpc(), fn()
    TimeLog(what, dt := Qpc() - t)
    return dt
}

OpenTimes(count) {
    global phase := "i open"
    Loop count {
        Park(), Sleep(50)
        cw := Timed("1 CollectWindows", CollectWindows)   ; the user's windows are counted in its time, never listed
        ListDemo(30)                                      ; wins := the 30 demo windows, as Step leaves them after its list
        sp := Timed("2 ShowPane", () => ShowPane(true))
        TimeLog("3 both", cw + sp)
        t := Qpc(), DllCall("dwmapi\DwmFlush")
        TimeLog("4 both + DwmFlush (the next DWM frame)", cw + sp + Qpc() - t)
        Critical("Off"), Sleep(600)                       ; the picture's slide and the thumbnails finish
        Finish(false), Critical("Off"), Sleep(300)
    }
}

TabHeld() {
    global phase := "ii tab held"
    OpenPane(30)
    t0 := Qpc()
    while Qpc() - t0 < 2000 {
        Timed("Step", () => Step(1))
        Critical("Off"), Sleep(33)
    }
    Sleep(300)
    ClosePane()
}

WheelNotches() {
    global phase := "iii wheel"
    OpenPane(30)
    for gap in [150, 40] {
        Loop 6
            Notch(1), Sleep(gap)
        Sleep(500)
        Loop 6
            Notch(-1), Sleep(gap)
        Sleep(500)
    }
    ClosePane()
}

DragTimes() {   ; a real drag: press on the thumb, 12 steps down and 12 back up; ScrollTick runs the drag's steps (BarDrag)
    global phase := "iv drag"
    OpenPane(30)
    if RealDrag(0, true)
        Park()
    else
        Say("iv drag: not run (no scroll bar to drag in this source)")
    ClosePane()
}

; Median and max of a, and how many are over 8 ms, not counting the calls that returned at once (under 0.2 ms: a wheel notch
; past the end, say), which are counted in `idle`.
Median(a, &mx, &over, &idle) {
    s := [], over := idle := 0
    for v in a {
        if v < 0.2
            idle += 1
        else
            s.Push(v)
    }
    Loop s.Length - 1 {                                ; insertion sort
        i := A_Index + 1, v := s[i], j := i - 1
        while j >= 1 && s[j] > v
            s[j + 1] := s[j], j--
        s[j + 1] := v
    }
    for v in s
        over += v > 8
    n := s.Length, mx := n ? s[-1] : 0
    return !n ? 0 : Mod(n, 2) ? s[(n + 1) // 2] : (s[n // 2] + s[n // 2 + 1]) / 2
}

Report(out, tag, clock) {
    text := "timing " tag ": ms; " clock "`n" Format("{:-46s}{:5s}{:5s}{:9s}{:9s}{:7s}`n", "phase / call", "n", "idle", "median", "max", ">8ms")
    raw := ""
    for k, a in SAMPLES {                              ; a Map walks its keys in order
        med := Median(a, &mx, &over, &idle)
        text .= Format("{:-46s}{:5d}{:5d}{:9.2f}{:9.2f}{:7d}`n", k, a.Length, idle, med, mx, over)
        raw .= k ":"
        for v in a
            raw .= " " Round(v, 2)
        raw .= "`n"
    }
    Say(text)
    try FileDelete(out "\timing-" tag ".txt")
    FileAppend(text "`nraw samples, in call order:`n" raw, out "\timing-" tag ".txt")
}
