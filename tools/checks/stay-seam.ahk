; stay-seam.ahk: #Included by run.ps1's stay wrapper after lib.ahk. The wrapper includes an instrumented COPY of the root's sources
; in which CollectWindows is renamed CollectWindows__orig, so that Step() (reached through the real Stay()) lists the 30 demo
; windows and never the user's own. As in timing.ahk's "1 CollectWindows", the real scan still runs: its time counts, its result doesn't.
CollectWindows() {
    CollectWindows__orig()
    out := []
    for w in demoWins                          ; lib.ahk's: the windows Stage(30) made
        out.Push(w.Hwnd)
    return SortByRecency(out)
}
