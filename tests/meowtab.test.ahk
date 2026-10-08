#Requires AutoHotkey v2.0
; Integration test for meowtab.ahk. Opens 5 temporary windows on the
; current desktop (a tiling WM may tile them briefly), then checks ordering.
; Run from the repo root:  AutoHotkey64.exe /ErrorStdOut tests\meowtab.test.ahk | more
DATA_DIR := A_Temp "\meowtab-test-" A_TickCount   ; a new, empty data folder: the test never reads or changes the user's own
OnExit((*) => (DirExist(DATA_DIR) && DirDelete(DATA_DIR, true), 0))   ; gone again however the run ends
#Include %A_LineFile%\..\..\meowtab.ahk

global fails := 0, names := Map()

Check(label, got, want) {
    global fails
    ok := got = want
    fails += !ok
    FileAppend (ok ? "PASS " : "FAIL ") label (ok ? "" : "`n     got:  " got "`n     want: " want) "`n", "*"
}

AppFiles() {   ; settings.ini beside meowtab.ahk and the files in its images\ (name, size, time): the test must not change them
    s := ""
    for pat in [AppDir() "settings.ini", AppDir() IMG_DIR "\*"]
        Loop Files pat
            s .= A_LoopFileName " " A_LoopFileSize " " A_LoopFileTimeModified "`n"
    return s
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

; Lay out n windows (A-D repeated) in a w x ht work area at scale S, the first one selected, under a picture whose art
; fills IMG_SIZE: it peeks by n as in ShowPane, and maxArt at its highest. Only the layout: nothing shows.
Lay(n, w, ht, S) {
    global wins := Repeat(n), idx := 1
    GridLayout(w, ht, Round(IMG_SIZE * PeekShare(n)), maxArt, S)
}

; Open the pane on n windows (Repeat) with tile sel selected, as Step does once it has listed them. WatchAlt stays
; off: the pane stays open, as with Alt held, until Finish.
Open(n, sel, extra := Map()) {
    global wins := Repeat(n, extra), idx := sel, cycling := true
    ShowPane(true), Wait(0)
}

Notch() => DllCall("SendMessageW", "ptr", g.Hwnd, "uint", 0x20A, "ptr", 0xFF880000, "ptr", 0)   ; the wheel on the pane: a notch down (-120)

ThumbsSeen() {   ; "in view" if only tiles at least partly in the pane have a thumbnail; then whether each whole one has
    s := "in view", whole := ", whole ones too"
    for t in tiles {
        y := TileY(t)
        if t.thumb && (y >= grid.h || y + grid.th <= 0)
            s := "one out of view"
        else if !t.thumb && y >= 0 && y + grid.th <= grid.h
            whole := ", a whole one without"
    }
    return s whole
}

Thumbed() {   ; how many tiles have a thumbnail
    n := 0
    for t in tiles
        n += t.thumb != 0
    return n
}

Shaped() {   ; the layout up to 8 windows: every tile as wide as its window's shape, every row centred
    for t in tiles
        if t.w != Round(grid.slot * t.aspect)
            return false
    for row in grid.rows
        if Abs(tiles[row[1]].x - grid.pad - (grid.w - grid.pad - tiles[row[2]].x - tiles[row[2]].w)) > 1
            return false
    return true
}

Rows() {   ; the rows, as "first-last ..."
    s := ""
    for row in grid.rows
        s .= (s = "" ? "" : " ") row[1] "-" row[2]
    return s
}

Columns() {   ; every tile as wide as the first, right under the one GRID_COLS before it (a short last row starts at the left)
    for i, t in tiles
        if t.w != tiles[1].w || i > GRID_COLS && t.x != tiles[i - GRID_COLS].x
            return "not in columns"
    return "in columns"
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
GridLayout(800, 1080, 0, 0), surf := SurfaceMake(grid.w, grid.h)
StepRow(1), down := idx, StepRow(1), last := idx, StepRow(-1), up := idx, StepRow(-1), first := idx
PaneFree(), cycling := false, Wait(0)
Check("Alt+Down / Up move between two rows, none past the ends", grid.rows.Length ": " down " " last " " up " " first, "2: 3 3 1 1")

; From GRID_FROM windows, the fixed grid. 1920x1032 and 1920x1008: a 1080p work area at 100 and 150 %. No pictures
; are loaded: Lay puts the tallest there can be (its art fills IMG_SIZE) over the pane.
maxArt := Round(IMG_SIZE * PEEK_MAX)
Lay(8, 1920, 1032, 1), th8 := grid.th
Check("8 windows on 1920x1032 keep the shaped layout", Shaped(), true)
Lay(9, 1920, 1032, 1), size9 := tiles[1].w "x" grid.th
Check("9 windows make 3 rows of 3, in columns", Rows() ", " Columns(), "1-3 4-6 7-9, in columns")
Lay(20, 1920, 1032, 1), got := Columns() ", " tiles[1].w "x" grid.th
Lay(50, 1920, 1032, 1), got .= "; " Columns() ", " tiles[1].w "x" grid.th
Check("20 and 50 windows: tiles in columns, as big as with 9 and as tall as with 8", got "; " th8
    , "in columns, " size9 "; in columns, " size9 "; " grid.th)
heights := ""
for count in [9, 12, 30, 50]
    Lay(count, 1920, 1008, 1.5), heights .= (heights = "" ? "" : " ") grid.h
Check("at 150 % on 1920x1008 the pane is as tall for 9, 12, 30 and 50 windows", heights, Format("{1} {1} {1} {1}", grid.h))
Check("and the pane fits in the work area under the picture at its highest peek", (fit := maxArt + grid.h + 2 * grid.margin) <= 1008 ? "fits" : fit " px", "fits")
Lay(12, 1920, 1032, 1), h12 := grid.h, GridLayout(1920, 1032, 0, maxArt, 1)   ; again, with no picture above the pane now
Check("the grid's rows follow the picture's highest peek, not today's", grid.h, h12)
Lay(12, 1920, 1032, 1), idx := 2, cycling := true, surf := SurfaceMake(grid.w, grid.h)
StepRow(1), got := "2 " idx, StepRow(1), got .= " " idx, StepRow(-1), got .= " " idx
PaneFree(), Lay(10, 1920, 1032, 1), idx := 9, surf := SurfaceMake(grid.w, grid.h)
StepRow(1), got .= "; 9 " idx, StepRow(1), got .= " " idx
PaneFree(), cycling := false, Wait(0)
Check("Alt+Down / Up in the grid stay in the column, a shorter last row gets its last tile", got, "2 5 8 5; 9 10 10")

; Smooth scrolling, on the real pane over A-D repeated, F and G. No picture here, so more full rows fit than under
; one (3 at 1080p instead of 2): the checks go by the rows that fit. Goals are checked at once, offsets after a wait.
fw := Gui(, "alttab-test F"), fw.Show("w300 h200"), guis.Push(fw), names[fw.Hwnd] := "F"
gw := Gui(, "alttab-test G"), gw.Show("w300 h200"), guis.Push(gw), names[gw.Hwnd] := "G"
hw := Gui(, "alttab-test H"), hw.Show("w300 h200"), guis.Push(hw), names[hw.Hwnd] := "H"
Sleep 300
Open(20, 1), full := (grid.h - 2 * grid.pad + grid.gap) // (grid.th + grid.gap), rowH := grid.th + grid.gap
Check("at open, only tiles at least partly in view have a thumbnail", ThumbsSeen(), "in view, whole ones too")
first := thumbs.Length, Step(-1), Wait(SCROLL_MS + 100), Step(1), Wait(SCROLL_MS + 100)   ; to the last tile and back
Check("scrolling down and back registers no tile twice", thumbs.Length " for " Thumbed() " tiles, more than at open: " (thumbs.Length > first)
    , Thumbed() " for " Thumbed() " tiles, more than at open: 1")
SelectTile(3 * full), Step(1), top := tiles[idx].y - grid.goal, next := tiles[3 * full + 4].y - grid.goal
got := (grid.goal = rowH ? "one row" : grid.goal " px") (top >= grid.pad && top + grid.th <= grid.h - grid.pad ? ", pad inside" : ", at " top)
Check("Tab from the last full row into the next scrolls one row: the tile pad inside, the next row's top in view"
    , got (next < grid.h ? ", the next row's top in view" : ", the next row hidden"), "one row, pad inside, the next row's top in view")
Finish(false), Wait(0)
Open(20, 20)                               ; as Shift+Tab opens: on the last window
Check("an open with Shift+Tab starts at the bottom, at once", (grid.end > 0) " " grid.off " " grid.goal, "1 " grid.end " " grid.end)
Notch(), Wait(50)
Check("at the end, a wheel notch changes nothing", grid.off " " grid.goal " " idx, grid.end " " grid.end " 20")
Step(1)
Check("Tab from the last window selects the first, with goal 0", idx " " grid.goal, "1 0")
Finish(false), Wait(0)
Open(20, 1), Notch(), Wait(50)
Check("at the top, a wheel notch scrolls one row, the selection to the new top row", (grid.goal = rowH) " " tiles[idx].row, "1 2")
Finish(false), Wait(0)
; A close keeps the selection on its window (with A-D listed many times: on their last tile), so it goes to F here.
Open(20, 1, Map(4, fw.Hwnd, 8, gw.Hwnd)), Notch(), Wait(SCROLL_MS + 100), at := grid.off   ; a row down, the selection on F
ClickTile(gw.Hwnd, true), Wait(400)        ; G's close button (row 3, whole in view)
Check("closing a window while scrolled keeps the offset", (at > 0) " " wins.Length " " grid.off, "1 19 " at)
Finish(false), Wait(0)
Open(20, 3 * full), Step(1), going := grid.goal != grid.off, Finish(false), at := grid.off, Wait(SCROLL_MS + 100)
Check("Finish during a scroll leaves no scroll running", going " " grid.off " " grid.goal, "1 " at " " at)
Act(h["A"]), Open(20, 1, Map(19, fw.Hwnd)), Step(-1), Wait(SCROLL_MS + 100)   ; to the last tile: the end, F (row 7) whole in view
ClickTile(fw.Hwnd), Wait(300)
Check("a click on a tile in a scrolled grid switches to it (F)", names.Get(WinExist("A"), "?") " " cycling, "F 0")
Open(20, 1), ClickTile(h["B"], false, () => (ScrollTo(rowH), Wait(SCROLL_MS + 100))), Wait(300)   ; pressed on B's tile, released a row lower
Check("a press and release on different tiles, a scroll in between, do nothing", cycling " " idx " " grid.off, "1 1 " rowH)
Finish(false), Wait(0)
Open(9, 1, Map(9, hw.Hwnd)), ClickTile(hw.Hwnd, true), Wait(400)   ; H's close button: 8 windows left
Check("closing one of 9 windows goes back to the shaped layout", wins.Length " " Shaped() " " grid.end, "8 1 0")
Finish(false), Wait(0)

; The scroll bar. The real mouse goes to the screen's corner first: not near the bar, it can't hold off the fade.
MouseMove(0, 0, 0)
Open(12, 1), shown := barA, Wait(700), still := barA, Wait(800)          ; the fade starts BAR_SHOW_MS (1 s) after the open
Check("with 12 windows the bar shows at open, still at 0.7 s, and is gone about 1.5 s later", (grid.end > 0) " " shown " " still " " (barA = 0), "1 1 1 1")
Finish(false), Wait(0)
Open(8, 1), shown := barA, Wait(1500)
Check("with 8 windows the bar never shows", grid.end " " shown " " (barA = 0), "0 0 1")
Finish(false), Wait(0)
Open(20, 20), b := BarKnob(), BarTrack(&top, &len, &k), Critical("On")   ; at the end; no frame until the Wait below
pt := Round(b[2] + b[4] / 2) << 16 | Round(b[1] + b[3] / 2)                 ; the thumb's middle
DllCall("SendMessageW", "ptr", g.Hwnd, "uint", 0x201, "ptr", 1, "ptr", pt)  ; pressed there: a drag
BarDrag(top), atTop := grid.off, BarDrag(top + len), atEnd := grid.off      ; the drag's step, the pointer at the track's top, bottom
Check("dragging the thumb to the track's top and bottom scrolls to 0 and the end, the selection in view, the press no click"
    , atTop " " atEnd " " WholeAt(tiles[idx], grid.off) " " (IsObject(pressAt) ? "a click" : pressAt), "0 " grid.end " 1 0")
DllCall("SendMessageW", "ptr", g.Hwnd, "uint", 0x202, "ptr", 0, "ptr", pt), Wait(100)   ; no physical button is down
Check("the drag ends once the button is up, and the release clicks nothing", barGrab " " cycling, "-1 1")
Finish(false), Wait(0)

; User data goes to DATA_DIR (the user's AppData\MeowTab in real use), never next to the script.
Check("data folder is new and empty", FileExist(DATA_DIR) "", "")
before := AppFiles()
Check("saving settings: no error", SettingsWrite(Map("FONT_SIZE", 14)), "")
Check("saving settings creates <data>\settings.ini", IniRead(DATA_DIR "\settings.ini", "settings", "FONT_SIZE", ""), 14)
src := DATA_DIR "\src.png", bm := NewBitmap(8, 8), SavePng(bm, src), DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
imp := ""
for mood in Moods()
    imp .= ImportImage(src, PendingImage(mood))
Check("importing pictures: no error", imp, "")
Check("pending pictures sit in <data>\images", FileExist(DATA_DIR "\images\custom_few.pending.png") != "", true)
PendingClear()
Check("PendingClear sweeps the user folder", FileExist(DATA_DIR "\images\custom_*.pending.png") "", "")
for mood in Moods()
    ImportImage(src, PendingImage(mood))
Check("saving pictures: no error", ImagesCommit("chill"), "")
Check("saving pictures puts custom_* in <data>\images", FileExist(DATA_DIR "\images\custom_few.png") != "" && FileExist(DATA_DIR "\images\custom_many.png") != "", true)
Check("and no pending file is left", FileExist(DATA_DIR "\images\*.pending.png") "", "")
Check("the lookup finds the user folder first", MoodImage("custom", "some"), DATA_DIR "\images\custom_some.png")
Check("else falls back to the app folder", MoodImage("chill", "some"), A_ScriptDir "\" IMG_DIR "\chill_some.png")
FileCopy src, DATA_DIR "\images\chill_some.png"
Check("a user set of the same name wins", MoodImage("chill", "some"), DATA_DIR "\images\chill_some.png")
Check("the app's settings.ini and images\ are unchanged", AppFiles(), before)

for w in guis
    w.Destroy()
FileAppend (fails ? fails " FAILED" : "ALL PASSED") "`n", "*"
ExitApp fails ? 1 : 0
