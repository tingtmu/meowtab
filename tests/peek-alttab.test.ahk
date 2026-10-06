#Requires AutoHotkey v2.0
; Integration test for peek-alttab.ahk. Opens 4 temporary windows on the
; current desktop (a tiling WM may tile them briefly), then checks ordering.
; Run from the repo root:  AutoHotkey64.exe /ErrorStdOut tests\peek-alttab.test.ahk | more
#Include %A_LineFile%\..\..\peek-alttab.ahk

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

TestOrder() {
    order := ""
    for h in CollectWindows()
        if names.Has(h)
            order .= names[h] " "
    return Trim(order)
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

Step(1), Finish(true), Sleep(300)
Check("Alt+Tab from A goes to B", names.Get(WinExist("A"), "?"), "B")

Raise(h["C"]), Sleep(100)
Step(1), Finish(true), Sleep(300)
Check("Alt+Tab again returns to A", names.Get(WinExist("A"), "?"), "A")

Step(1), Step(1), Finish(true), Sleep(300)
Check("Alt+Tab+Tab goes to 3rd (D)", names.Get(WinExist("A"), "?"), "D")

Step(1), shown := thumb, Finish(false)    ; same line: WatchAlt can't end it in between
Check("preview thumbnail registered while cycling", shown != 0, true)
Check("preview thumbnail released after Finish", thumb, 0)

t := Gui("+ToolWindow", "alttab-test tool")   ; not Alt+Tab-eligible, so not in the list
t.Show("w200 h100"), guis.Push(t)
Act(t.Hwnd)                                ; recency of A-D is now: D A B C
Step(1), Finish(true), Sleep(300)
Check("Alt+Tab from non-listed window goes to 1st (D)", names.Get(WinExist("A"), "?"), "D")

SendLevel 1                                ; let our own hotkeys see these keys
SendEvent "{LAlt down}"                    ; held, so WatchAlt keeps the list open
Step(1), SendEvent("{Blind}{Down}"), Sleep(100)   ; recency D A B C: Tab -> A, Alt+Down -> B
SendEvent "{LAlt up}"
SendLevel 0
Sleep 300                                  ; WatchAlt sees Alt released and switches
Check("Alt+Tab, Alt+Down goes to 3rd (B)", names.Get(WinExist("A"), "?"), "B")

for w in guis
    w.Destroy()
FileAppend (fails ? fails " FAILED" : "ALL PASSED") "`n", "*"
ExitApp fails ? 1 : 0
