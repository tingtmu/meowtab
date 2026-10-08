#Requires AutoHotkey v2.0
; Integration test for meowtab.ahk. Opens 5 temporary windows on the
; current desktop (a tiling WM may tile them briefly), then checks ordering.
; Run from the repo root:  AutoHotkey64.exe /ErrorStdOut tests\meowtab.test.ahk | more
#Include %A_LineFile%\..\..\meowtab.ahk

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

; Bring to top of Z-order without activating: what a tiling WM's re-tile can do.
Raise(h) => DllCall("SetWindowPos", "ptr", h, "ptr", 0, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x13)

; Step / Finish make their thread Critical, as their hotkeys need. Called straight from this thread they leave
; it so, and then no hotkey or timer (WatchAlt, the mouse) could run: Wait sleeps with it off again.
Wait(ms) => (Critical("Off"), Sleep(ms))

TestOrder() {
    order := ""
    for h in CollectWindows()
        if names.Has(h)
            order .= names[h] " "
    return Trim(order)
}

; Send the pane a left click (WM_LBUTTONDOWN + UP) on window hwnd's tile: its centre, or with onX its close button.
ClickTile(hwnd, onX := false) {
    for i, w in wins
        if w = hwnd {
            t := tiles[i], y := TileY(t)
            x := onX ? t.x + t.w - CloseW(t) // 2 : t.x + t.w // 2, y += onX ? grid.hdr // 2 : grid.th // 2
            DllCall("SendMessageW", "ptr", g.Hwnd, "uint", 0x201, "ptr", 1, "ptr", y << 16 | x)
            return DllCall("SendMessageW", "ptr", g.Hwnd, "uint", 0x202, "ptr", 0, "ptr", y << 16 | x)
        }
    FileAppend "     (no tile for " names.Get(hwnd, hwnd) ")`n", "*"
}

guis := [], h := Map()
for n in ["A", "B", "C", "D"] {
    w := Gui(, "alttab-test " n)
    w.Show("w300 h200")
    guis.Push(w), h[n] := w.Hwnd, names[w.Hwnd] := n
}
Sleep 800                                  ; let a tiling WM settle them

for n in ["A", "B", "C", "D"]
    Act(h[n])
Act(h["B"]), Act(h["A"])                   ; recency now: A B D C
Check("baseline order", TestOrder(), "A B D C")

Raise(h["C"]), Raise(h["D"]), Sleep(100)   ; reshuffle Z-order without activation
Check("order survives Z-order reshuffle", TestOrder(), "A B D C")

Step(1), Finish(true), Wait(300)
Check("Alt+Tab from A goes to B", names.Get(WinExist("A"), "?"), "B")

Raise(h["C"]), Sleep(100)
Step(1), Finish(true), Wait(300)
Check("Alt+Tab again returns to A", names.Get(WinExist("A"), "?"), "A")

Step(1), Step(1), Finish(true), Wait(300)
Check("Alt+Tab+Tab goes to 3rd (D)", names.Get(WinExist("A"), "?"), "D")

Step(1), live := thumbs.Length, Finish(false), Wait(0)   ; same line: WatchAlt can't end it in between
Check("preview thumbnails registered while cycling", live > 0, true)
Check("preview thumbnails released after Finish", thumbs.Length, 0)

t := Gui("+ToolWindow", "alttab-test tool")   ; not Alt+Tab-eligible, so not in the list
WinGetPos(&ax, &ay, , , h["A"])                ; on A's monitor: a tiling WM may put A-D on another one than the
t.Show("x" ax + 20 " y" ay + 20 " w200 h100"), guis.Push(t)   ; tool window's default, and only this monitor is listed
Act(t.Hwnd)                                ; recency of A-D is now: D A B C
Step(1), Finish(true), Wait(300)
Check("Alt+Tab from non-listed window goes to 1st (D)", names.Get(WinExist("A"), "?"), "D")

SendLevel 1                                ; let our own hotkeys see these keys
SendEvent "{LAlt down}"                    ; held, so WatchAlt keeps the list open
Step(1), Wait(50), SendEvent("{Blind}{Right}"), Wait(100)   ; recency D A B C: Tab -> A, Alt+Right -> B
SendEvent "{LAlt up}"
SendLevel 0
Sleep 300                                  ; WatchAlt sees Alt released and switches
Check("Alt+Tab, Alt+Right goes to 3rd (B)", names.Get(WinExist("A"), "?"), "B")

; The mouse checks hold Alt without sending it: an injected Alt up right after a click's switch can stall for
; minutes on some setups (seen over Remote Desktop with GlazeWM). Stopping WatchAlt keeps the pane open as a
; held Alt would, and Finish(true) does what releasing it does.
Step(1), SetTimer(WatchAlt, 0), ClickTile(h["C"]), Wait(300)   ; recency B D A C: the pane opens on D; a click on C switches at once
Check("click on a tile switches to it (C)", names.Get(WinExist("A"), "?"), "C")
Check("the click closed the pane", cycling, false)

e := Gui(, "alttab-test E"), e.Show("w300 h200"), guis.Push(e), names[e.Hwnd] := "E"
Act(e.Hwnd)                                ; recency E C B D A
Step(1), SetTimer(WatchAlt, 0), n := wins.Length, ClickTile(e.Hwnd, true), Wait(400)   ; selection on C; E's close button
Check("click on X closes that window", DllCall("IsWindowVisible", "ptr", e.Hwnd), 0)
Check("the pane stays open, one tile less", cycling " " wins.Length, "1 " (n - 1))
Check("the selection stays on its window (C)", names.Get(wins[idx], "?"), "C")
Finish(true), Wait(300)                    ; releasing Alt
Check("then releasing Alt switches to it (C)", names.Get(WinExist("A"), "?"), "C")

Finish(false), Wait(0)                     ; Alt+Down / Up: a narrow work area wraps A-D two by two
wins := [h["A"], h["B"], h["C"], h["D"]], idx := 1, cycling := true
GridLayout(800, 1080, 0), surf := SurfaceMake(grid.w, grid.h)
StepRow(1), down := idx, StepRow(1), last := idx, StepRow(-1), up := idx, StepRow(-1), first := idx
PaneFree(), cycling := false, Wait(0)
Check("Alt+Down / Up move between two rows, none past the ends", grid.rows.Length ": " down " " last " " up " " first, "2: 3 3 1 1")

for w in guis
    w.Destroy()
FileAppend (fails ? fails " FAILED" : "ALL PASSED") "`n", "*"
ExitApp fails ? 1 : 0
