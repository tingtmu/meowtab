; control.ahk: a fixed amount of plain CPU work (calibrated to about 5 ms), 400 times with Sleep(33) between, timed with QPC.
; No windows, no input. If this also shows rare 15-30 ms outliers, the frame spikes are the machine (preemption), not MeowTab.
; Run from the repo root:  AutoHotkey64.exe /ErrorStdOut tools\checks\control.ahk
#Requires AutoHotkey v2.0
OnError((e, *) => (FileAppend("control error: " e.Message "`n", "*"), ExitApp(3)))
SetTimer(() => ExitApp(2), -120000)

Qpc() {
    static f := 0
    if !f
        DllCall("QueryPerformanceFrequency", "int64*", &f)
    DllCall("QueryPerformanceCounter", "int64*", &c := 0)
    return c * 1000 / f
}
Work(n) {
    x := 0
    Loop n
        x += Mod(A_Index, 7) * 3
    return x
}

n := 20000, t := Qpc(), Work(n), dt := Qpc() - t
Loop 3 {                                   ; calibrate to about 5 ms, best of a few
    n := Round(n * 5 / Max(dt, 0.1)), best := 1e9
    Loop 5
        t := Qpc(), Work(n), best := Min(best, Qpc() - t)
    dt := best
}
s := [], over8 := over12 := 0, mx := 0
Loop 400 {
    t := Qpc(), Work(n), v := Qpc() - t
    s.Push(v), mx := Max(mx, v), over8 += v > 8, over12 += v > 12
    Sleep(33)
}
sorted := s.Clone()
Loop sorted.Length - 1 {                   ; insertion sort
    i := A_Index + 1, v := sorted[i], j := i - 1
    while j >= 1 && sorted[j] > v
        sorted[j + 1] := sorted[j], j -= 1
    sorted[j + 1] := v
}
big := ""
for i, v in s
    if v > 8
        big .= " #" i "=" Round(v, 2)
FileAppend("control: n=" n " (best " Round(dt, 2) " ms); 400 runs: median " Round(sorted[200], 2) " max " Round(mx, 2)
    . " >8ms " over8 " >12ms " over12 "`nover 8 ms:" big "`n", "*")
ExitApp 0
