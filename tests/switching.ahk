; #Included by meowtab.test.ahk where its switching checks run: these top-level lines run there, in order.
; Switching among A-D: the recency order, Alt+Tab and Alt+Right, MONITORS, a window not listed, a click on a tile or its X.

; Bring to top of Z-order without activating: what a tiling WM's re-tile can do.
Raise(h) => DllCall("SetWindowPos", "ptr", h, "ptr", 0, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x13)

TestOrder() {
    order := ""
    for h in CollectWindows()
        if names.Has(h)
            order .= names[h] " "
    return Trim(order)
}

Listed(hwnd) {   ; is window hwnd in the list Alt+Tab would show now?
    for w in CollectWindows()
        if w = hwnd
            return true
    return false
}

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

; MONITORS: every monitor's windows (all, the default), or only those on the active window's monitor (current), where A-D are.
; A window shown on another monitor is listed under all and not under current; skipped with one monitor, or if a tiling WM
; keeps it on this one.
MONITORS := "current", cur := TestOrder(), MONITORS := "all"
Check("MONITORS=current lists A-D, on the active window's monitor, as all does", cur, TestOrder())
if MonitorGetCount() < 2
    Check("a window on another monitor is listed under all, not under current: skipped, one monitor", "", "")
else {
    here := DllCall("MonitorFromWindow", "ptr", WinExist("A"), "uint", 2, "ptr")
    Loop MonitorGetCount() {                   ; the first monitor that isn't the active window's
        MonitorGetWorkArea(A_Index, &ml, &mt)
        if DllCall("MonitorFromPoint", "int64", ((mt + 100) << 32) | ((ml + 100) & 0xFFFFFFFF), "uint", 2, "ptr") != here
            break
    }
    m := Gui(, "alttab-test M"), m.Show("NA x" ml + 100 " y" mt + 100 " w300 h200"), Sleep(300), Act(h["D"])   ; D again, should a tiling WM focus M
    away := DllCall("MonitorFromWindow", "ptr", m.Hwnd, "uint", 2, "ptr") != here
    all := Listed(m.Hwnd), MONITORS := "current", cur := Listed(m.Hwnd), MONITORS := "all", m.Destroy(), Act(h["D"])   ; recency D A B C
    if away
        Check("a window on another monitor is listed under all (1), not under current (0)", all " " cur, "1 0")
    else
        Check("a window on another monitor is listed under all, not under current: skipped, a tiling WM kept it on this one", "", "")
}

t := Gui("+ToolWindow", "alttab-test tool")   ; not Alt+Tab-eligible, so not in the list
WinGetPos(&ax, &ay, , , h["A"])                ; on A's monitor, as MONITORS=current would need: a tiling WM may put A-D on
t.Show("x" ax + 20 " y" ay + 20 " w200 h100"), guis.Push(t)   ; another one than the tool window's default
Act(t.Hwnd)                                ; recency of A-D is now: D A B C
Step(1), Finish(true), Wait(300)
Check("Alt+Tab from non-listed window goes to 1st (D)", names.Get(WinExist("A"), "?"), "D")

SendLevel 1                                ; let our own hotkeys see these keys
SendEvent "{LAlt down}"                    ; held, so WatchAlt keeps the list open
Step(1), Wait(50), SendEvent("{Blind}{Right}"), Wait(100)   ; recency D A B C: Tab -> A, Alt+Right -> B
SendEvent "{Blind}{vkE8}{LAlt up}"         ; the mask key first, as AutoHotkey sends after Alt+Tab: Right was taken, so Windows would
SendLevel 0                                ; see a lone Alt and put D in menu mode, which holds this thread until something ends it
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
