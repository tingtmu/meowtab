; #Included by meowtab.test.ahk where its grid checks run: these top-level lines run there, in order.
; The tiles' grid: rows and Alt+Down / Up, the fixed grid, smooth scrolling, minimized windows, the scroll bar, hover at open.

; Lay out n windows (A-D repeated) in a w x ht work area at scale S, the first one selected, under a picture whose art
; fills IMG_SIZE: it peeks by n as in ShowPane, and maxArt at its highest. Only the layout: nothing shows.
Lay(n, w, ht, S) {
    global wins := Repeat(n), idx := 1
    GridLayout(w, ht, Round(IMG_SIZE * PeekShare(n)), maxArt, S)
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

SameBits(a, b, sz) {   ; two sz x sz GDI+ bitmaps' pixels match exactly
    rc := Buffer(16, 0), NumPut("int", sz, "int", sz, rc, 8), da := Buffer(32, 0), db := Buffer(32, 0)   ; BitmapData
    DllCall("gdiplus\GdipBitmapLockBits", "ptr", a, "ptr", rc, "uint", 1, "int", 0xE200B, "ptr", da)   ; ReadOnly, 32bppPARGB
    DllCall("gdiplus\GdipBitmapLockBits", "ptr", b, "ptr", rc, "uint", 1, "int", 0xE200B, "ptr", db)
    n := DllCall("ntdll\RtlCompareMemory", "ptr", NumGet(da, 16, "ptr"), "ptr", NumGet(db, 16, "ptr"), "uptr", 4 * sz * sz, "uptr")
    DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", a, "ptr", da), DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", b, "ptr", db)
    return n = 4 * sz * sz
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

; Minimized windows, gone again before the next checks: MA shown first, so DWM keeps its last image; MB created minimized,
; so DWM has only a placeholder of another size (200 px wide at any scale: MB is big enough to be over twice that at 100 %);
; MC maximized first, so its last image is far bigger than its restored frame. Only MC is ever activated (maximizing does
; it), and the foreground goes back. The pane lists just the three.
was := WinExist("A")
ma := Gui(, "alttab-test MA"), ma.Show("NA w300 h200"), mb := Gui(, "alttab-test MB"), mb.Show("Hide w600 h400")
mc := Gui(, "alttab-test MC"), mc.Show("NA w300 h200"), Sleep(300), DllCall("ShowWindow", "ptr", mc.Hwnd, "int", 3), Sleep(300)   ; SW_SHOWMAXIMIZED
for w in [ma, mb, mc]
    DllCall("ShowWindow", "ptr", w.Hwnd, "int", 7) ; SW_SHOWMINNOACTIVE
Sleep 700                                  ; past the minimize animation, where Windows has it on
Act(was)                                   ; back from MC
Open(3, 1, Map(1, ma.Hwnd, 2, mb.Hwnd, 3, mc.Hwnd))
Check("a window shown, then minimized: its tile gets a thumbnail", tiles[1].iconic " " (tiles[1].thumb > 0), "1 1")
Check("a window created minimized: its tile gets none (its big icon shows), and none is kept", tiles[2].iconic " " tiles[2].thumb " " thumbs.Length, "1 -1 2")
Check("a window maximized, then minimized: its last image is over twice as wide as its restored frame, and its tile keeps it"
    , tiles[3].iconic " " (tiles[3].sw > 2 * tiles[3].src[3]) " " (tiles[3].thumb > 0), "1 1 1")
Finish(false), Wait(0)
; Minimized Chrome and Edge leave DWM only a flat fill: their tiles get no thumbnail, by program name (FLAT_MIN), here
; this test's own for one open, so MA gets none and B (not minimized) keeps its. MA gives no ICON_BIG now either: its
; big icon is its program's made at the big size, not its small one scaled up.
DllCall("SendMessageW", "ptr", ma.Hwnd, "uint", 0x80, "ptr", 1, "ptr", 0)   ; WM_SETICON: ICON_BIG none
flat := FLAT_MIN, FLAT_MIN := RegExReplace(A_AhkPath, ".*\\"), Open(2, 1, Map(1, ma.Hwnd)), FLAT_MIN := flat
Check("a minimized window of a FLAT_MIN program gets no thumbnail, one not minimized does", tiles[1].iconic " " tiles[1].thumb " " (tiles[2].thumb > 0) " " thumbs.Length, "1 -1 1 1")
bigPx := Round(BIG_ICON * grid.S), DllCall("shell32\SHDefExtractIconW", "wstr", A_AhkPath, "int", 0, "uint", 0, "ptr*", &hi := 0, "ptr", 0, "uint", 16 << 16 | bigPx)
progBm := IconBitmap(hi, bigPx), DllCall("DestroyIcon", "ptr", hi), softBm := IconBitmap(WindowIcon(ma.Hwnd, &own, &big), bigPx)
Check("a minimized FLAT_MIN window without ICON_BIG: its big icon is its program's at the big size, not its small one scaled up"
    , SameBits(icons[ma.Hwnd][2], progBm, bigPx) " " SameBits(icons[ma.Hwnd][2], softBm, bigPx) " " big, "1 0 0")
DllCall("gdiplus\GdipDisposeImage", "ptr", progBm), DllCall("gdiplus\GdipDisposeImage", "ptr", softBm)
Finish(false), Wait(0), ma.Destroy(), mb.Destroy(), mc.Destroy()

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

; Hover from the first frame, read on the open's line: ShowPane makes this thread Critical, so no mouse message's timer
; has run yet. The pane lists A-D, as Open does: the desktop's other windows can't change the layout.
Open(4, 1), t := tiles[2], g.GetClientPos(&px, &py), hx := px + t.x + t.w // 2, hy := py + TileY(t) + grid.th // 2, Finish(false), Wait(0)
MouseMove(hx, hy, 0)                       ; tile 2's centre, the pane closed: the same windows open again in the same place
wins := Repeat(4), idx := 1, cycling := true, ShowPane(true), got := hover " at " (mouseAt ? mouseAt[1] " " mouseAt[2] : "none")
    , at := CursorAt(), Finish(false), Wait(0)
Check("an open with the cursor resting on tile 2 hovers it in the first frame, at the cursor's place in the shown pane", got, "2 at " at[1] " " at[2])
MouseMove(0, 0, 0)                         ; parked again, as the scroll bar checks left it
wins := Repeat(4), idx := 1, cycling := true, ShowPane(true), got := hover, Finish(false), Wait(0)
Check("an open with the cursor away from the pane hovers nothing", got, 0)
