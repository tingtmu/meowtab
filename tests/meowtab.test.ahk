#Requires AutoHotkey v2.0
; Integration test for meowtab.ahk. Opens 5 temporary windows on the
; current desktop (a tiling WM may tile them briefly), then checks ordering.
; Run from the repo root:  AutoHotkey64.exe /ErrorStdOut tests\meowtab.test.ahk [velvet | windows11] | more
; (the pane's look to test in, set in the test's settings.ini as a user's would be; none: the app's default look)
if A_Args.Length && !(A_Args[1] = "velvet" || A_Args[1] = "windows11")
    FileAppend("usage: meowtab.test.ahk [velvet | windows11]`n", "*"), ExitApp(1)
DATA_DIR := A_Temp "\meowtab-test-" A_TickCount   ; a new, empty data folder: the test never reads or changes the user's own
OnExit((*) => (DirExist(DATA_DIR) && DirDelete(DATA_DIR, true), 0))   ; gone again however the run ends
if A_Args.Length                           ; before the include: the app's startup reads it (and picks the title font by it)
    DirCreate(DATA_DIR), IniWrite(A_Args[1], DATA_DIR "\settings.ini", "settings", "PANE_LOOK")
ANIM_EFFECTS := false                      ; Windows' "Animation effects" as the app reads it (Animates): Velvet's motion only in its checks
#Include %A_LineFile%\..\..\meowtab.ahk
A_IconHidden := true   ; no tray icon, no TrayTip: the settings warnings the bad-value checks provoke stay out of the notification centre
lookDefault := SETTINGS_DEFAULTS["PANE_LOOK"]   ; the built-in look, as the startup load found it (this run's: PANE_LOOK)

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

; The pane's own pixel x, y (Render's surface, premultiplied) composited over the palette's plain colour, pal.pane: [r, g, b].
PanePx(x, y) {
    bm := Buffer(32, 0), DllCall("GetObject", "ptr", surf.hbm, "int", 32, "ptr", bm)   ; BITMAP: bmBits
    c := NumGet(NumGet(bm, A_PtrSize = 8 ? 24 : 20, "ptr"), 4 * (y * surf.w + x), "uint"), k := 1 - (c >> 24) / 255, p := Integer("0x" pal.pane)
    return [(c >> 16 & 0xFF) + (p >> 16) * k, (c >> 8 & 0xFF) + (p >> 8 & 0xFF) * k, (c & 0xFF) + (p & 0xFF) * k]
}
Luma(c) => 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]   ; brightness, 0-255 (Rec. 601)

; How much tile i's header changes when hovered (design 6): its mean brightness left of the icon, hovered less plain.
HoverStep(i) {
    global hover, hoverX
    t := tiles[i], y0 := TileY(t) + Round(grid.hdr * 0.3), y1 := TileY(t) + Round(grid.hdr * 0.85), x1 := t.x + Round(ICON_X * grid.S) - 3
    m := []
    for hv in [0, i] {
        hover := hv, hoverX := false, Render(surf), sum := n := 0
        Loop y1 - y0 {
            y := y0 + A_Index - 1
            Loop x1 - t.x - 3
                sum += Luma(PanePx(t.x + 2 + A_Index, y)), n += 1
        }
        m.Push(sum / n)
    }
    return m[2] - m[1]
}

; Tile i's close button with the mouse on the tile, then on the button, at a point above its middle (inside Velvet's disc, clear
; of the X) and one left of that (outside the disc, inside the Windows 11 look's square): "RRGGBB" where red, else "grey"
; (in Velvet the first as RedOver the second); ", disc" when the first stands out from the second.
CloseTones(i) {
    global hover, hoverX
    t := tiles[i], x := t.x + t.w - CloseW(t) // 2, y := TileY(t) + grid.hdr // 2 - Round(VELVET_CLOSE * grid.S * 0.3)
    s := ""
    for onX in [false, true] {
        hover := i, hoverX := onX, Render(surf), c := PanePx(x, y), out := PanePx(x - Round(VELVET_CLOSE * grid.S * 0.75), y)
        s .= (onX ? "; on it " : "on the tile ") (PANE_LOOK = "velvet" ? RedOver(c, out) : Tone(c)) " " Tone(out) (Abs(Luma(c) - Luma(out)) >= 6 ? ", disc" : "")
    }
    return s
}
Tone(c) => c[1] - (c[2] + c[3]) / 2 > 100 ? Format("{:02X}{:02X}{:02X}", Round(c[1]), Round(c[2]), Round(c[3])) : "grey"

; How much CLOSE_RGB covers pixel c over the plain header beside it, out (least squares over r, g, b): "soft red" at 70-85 %
; (Velvet's disc on the hovered tile: alpha 200, 78 %), "full red" from 97 %, else the share.
RedOver(c, out) {
    red := Integer("0x" CLOSE_RGB), num := den := 0
    for k, v in [red >> 16, red >> 8 & 0xFF, red & 0xFF]
        num += (c[k] - out[k]) * (v - out[k]), den += (v - out[k]) ** 2
    a := num / den
    return a >= 0.97 ? "full red" : a >= 0.7 && a <= 0.85 ? "soft red" : Format("red at {:.0f} %", 100 * a)
}

; DWM's rectangle for tile t's thumbnail, as ThumbPlace last set it (t.props): [left, top, right, bottom].
ThumbRect(t) => [NumGet(t.props, 4, "int"), NumGet(t.props, 8, "int"), NumGet(t.props, 12, "int"), NumGet(t.props, 16, "int")]

; One open on A-D, as Step makes it, with Velvet's motion on or off through the app's seam (ANIM_EFFECTS), never Windows' own
; setting: whether the pane is layered (easing in) at its first frame, read on the open's line (ShowPane leaves this thread
; Critical: no tick has run yet), and once eased in; then Tab, read on its line too: whether a light-up is under way, the
; selection's strength under tile 2 (ShadeUnder: 0 as before the Tab, 1 as once still), and tile 1's and tile 2's thumbnails;
; then the ms until the light-up is over, and once all is still tile 2's thumbnail, and where tile 1's belongs (ThumbsShow).
MotionOpen(on) {
    global ANIM_EFFECTS := on, wins := Repeat(4), idx := 1, cycling := true
    ShowPane(true), first := Layered(), Wait(VELVET_IN_MS + 100), eased := Layered(), none := ShadeUnder(tiles[2])
    Step(1), t0 := A_TickCount, moving := glow ? 1 : 0, lit := ShadeUnder(tiles[2]), was := ThumbRect(tiles[1]), start := ThumbRect(tiles[2])
    while glow && A_TickCount - t0 < 500
        Wait(5)
    took := A_TickCount - t0, Wait(100), full := ShadeUnder(tiles[2]), end := ThumbRect(tiles[2]), ThumbsShow(), rest := ThumbRect(tiles[1])
    Finish(false), Wait(0)
    return {first: first, eased: eased, moving: moving, lit: full = none ? -1 : (lit - none) / (full - none), took: took
        , settles: Format("{} {} {} {}", was*) = Format("{} {} {} {}", rest*), grew: end[3] - end[1] - start[3] + start[1]
        , start: Format("{} {} {} {}", start*), end: Format("{} {} {} {}", end*)}
}
Layered() => DllCall("GetWindowLongPtrW", "ptr", g.Hwnd, "int", -20, "ptr") >> 19 & 1   ; the pane has WS_EX_LAYERED (Velvet's ease-in)

; The selection around tile t as the pane shows it now: the surface's alpha summed down a short line below the middle of its
; frame as lifted, clear of the tile at any lift, where Velvet's shadow is deep (and the Windows 11 look's ring).
ShadeUnder(t) {
    bm := Buffer(32, 0), DllCall("GetObject", "ptr", surf.hbm, "int", 32, "ptr", bm), bits := NumGet(bm, A_PtrSize = 8 ? 24 : 20, "ptr")
    x := t.x + t.w // 2, y0 := Ceil(TileY(t) + grid.th * (1 + VELVET_LIFT / 2)) + 2, sum := 0
    Loop Round(8 * grid.S)
        sum += NumGet(bits, 4 * ((y0 + A_Index) * surf.w + x), "uint") >> 24
    return sum
}

; Tab's selection as MotionOpen read it: at once at full strength, or lit up from partial strength (0.35 to 0.7: 0.4, or
; about 0.64 if A_TickCount's 15.6 ms step falls between the start and the first frame) to full within VELVET_GLOW_MS and 4
; animation ticks (room for a late tick or two); then tile 1's and tile 2's thumbnails.
LightUp(o) => (!o.moving ? (o.lit = 1 ? "at once at full strength" : Format("at once at {:.2f}", o.lit))
    : o.lit < 0.35 || o.lit > 0.7 ? Format("lights up from {:.2f}", o.lit)
    : o.took > VELVET_GLOW_MS + 4 * ANIM_TICK ? "lights up from partial strength, full in " o.took " ms"
    : "lights up from partial strength, full within its " VELVET_GLOW_MS " ms and 4 ticks")
    . ", tile 1 " (o.settles ? "settles at once" : "settles late") ", tile 2's thumbnail " (o.start = o.end ? "stays put" : o.grew > 0 ? "grows" : "shrinks")

; A shortcut through KeysParse: "readable hotkey-name", or why it's refused.
Parsed(text, stay := false, other := "") => (why := KeysParse(text, stay, other, &keys, &hk)) = "" ? keys " " hk : why

; Real keys, sent so that our own hotkeys see them; then their threads run. A held key stays held across calls.
Press(s, ms := 100) => (SendLevel(1), SendEvent("{Blind}" s), SendLevel(0), Wait(ms))

Field(j) {   ; the open settings panel's shortcut field j (1 = switching, 2 = staying open)
    for hwnd, e in pnl.el
        if e.kind = "keys" && e.j = j
            return e.ctl
}

SaveAt() {   ; where the open settings panel's Save is on the screen: "x,y" of the bar's rightmost button
    for hwnd, e in pnl.el
        if e.kind = "button" && e.ctl.Gui = pnl.gui && (!IsSet(save) || e.x > save.x)
            save := e
    WinGetPos(&x, &y, , , save.ctl)
    return x "," y
}

Whole(ctl) => (ctl.GetPos(, &y, , &h), y >= pnl.off && y + h <= pnl.off + pnl.viewH)   ; a control of the panel's page shows whole

; settings.ini's shortcut lines ("" = none).
KeysLines() => Trim(IniRead(DATA_DIR "\settings.ini", "settings", "SWITCH_KEYS", "") " " IniRead(DATA_DIR "\settings.ini", "settings", "STAY_KEYS", ""))

; The open panel's LOOK cards whose painter, run as WM_DRAWITEM runs it, draws the pick's check: its accent disc in the well's
; corner (PaintLook), read above the check itself.
Marked() {
    s := "", sdc := DllCall("GetDC", "ptr", 0, "ptr"), dc := DllCall("CreateCompatibleDC", "ptr", sdc, "ptr")
    for hwnd, e in pnl.el
        if e.kind = "look" {
            bm := DllCall("CreateCompatibleBitmap", "ptr", sdc, "int", e.w, "int", e.h, "ptr"), ob := DllCall("SelectObject", "ptr", dc, "ptr", bm, "ptr")
            paint := e.paint, paint(dc, e.w, e.h, 0)
            s .= DllCall("GetPixel", "ptr", dc, "int", e.w - Dpx(13), "int", Dpx(9), "uint") = Bgr(LOOK.accent) ? " " e.lk : ""
            DllCall("SelectObject", "ptr", dc, "ptr", ob), DllCall("DeleteObject", "ptr", bm)
        }
    DllCall("DeleteDC", "ptr", dc), DllCall("ReleaseDC", "ptr", 0, "ptr", sdc)
    return Trim(s)
}

WatchDraw(wParam, lParam, *) {   ; WM_DRAWITEM, ahead of the panel's own handler: the elements drawn (drawnEls)
    drawnEls[NumGet(lParam, 24, "ptr")] := true
}

; What fn's keys do to the panel: "menu mode" if they put its thread there (GetGUIThreadInfo: GUI_INMENUMODE 0x4, GUI_SYSTEMMENUMODE 0x8),
; else "no menu mode". That mode holds this thread up, timers too, so a helper process watches and ends it with an Alt tap.
MenuModeDuring(fn) {
    helper := DATA_DIR "\menu-watch.ahk", out := DATA_DIR "\menu-watch.txt"
    FileOpen(helper, "w").Write("
    (
    #NoTrayIcon
    seen := 'no menu mode', t := A_TickCount, info := Buffer(A_PtrSize = 8 ? 72 : 48)
    while seen = 'no menu mode' && A_TickCount - t < 2000 {
        NumPut('uint', info.Size, info)
        if DllCall('GetGUIThreadInfo', 'uint', A_Args[1], 'ptr', info) && NumGet(info, 4, 'uint') & 0xC
            seen := 'menu mode', SendEvent('{LAlt down}{LAlt up}')
        Sleep 20
    }
    FileAppend seen, A_Args[2]
    )")
    Run('"' A_AhkPath '" "' helper '" ' DllCall("GetWindowThreadProcessId", "ptr", pnl.gui.Hwnd, "ptr", 0, "uint") ' "' out '"', , , &pid)
    Wait(500), fn(), ProcessWaitClose(pid, 5)
    return FileExist(out) ? FileRead(out) : "no answer"
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

; The look, read from the pane's own pixels: this run's (PANE_LOOK; the gate runs the test in each), in light and in dark mode,
; switched as readme-shots does. ShowPane leaves this thread Critical: no timer redraws until the Wait.
was := dark, steps := [], tones := ""
for d in [false, true] {
    dark := d, wins := Repeat(4), idx := 1, cycling := true, ShowPane(true)
    steps.Push(HoverStep(2)), tones .= (d ? " | dark: " : "light: ") CloseTones(2), Finish(false), Wait(0)
}
dark := was
Check("the hovered header is at least 12 levels brighter or darker than a plain one, in light and in dark mode"
    , Abs(steps[1]) >= 12 && Abs(steps[2]) >= 12 ? "at least 12" : Format("light {:.1f}, dark {:.1f}", steps*), "at least 12")
Check(PANE_LOOK = "velvet" ? "Velvet's close button: a soft red disc on the hovered tile, full red with the mouse on it"
    : "the close button: red on the hovered tile, darker red with the mouse on it, as before", tones
    , Format("light: {1} | dark: {1}", PANE_LOOK = "velvet" ? "on the tile soft red grey, disc; on it full red grey, disc" : "on the tile E81123 E81123; on it C42B1C C42B1C"))
; Velvet's close button is its disc: a point in the Windows 11 look's square button but off the disc (2 px in from the square's
; left, at the header's middle) is plain header, so it isn't lit and a click there switches to the window. In the Windows 11 look
; the point is on the button: lit, and a click closes the window. The cursor rests there as the pane opens: the first frame's hover.
xw := Gui(, "alttab-test X"), xw.Show("NA w300 h200"), Sleep(300)
Open(4, 1, Map(2, xw.Hwnd)), t := tiles[2], x := t.x + t.w - CloseW(t) + 2, y := TileY(t) + grid.hdr // 2, g.GetClientPos(&px, &py), Finish(false), Wait(0)
MouseMove(px + x, py + y, 0), wins := Repeat(4, Map(2, xw.Hwnd)), idx := 1, cycling := true, ShowPane(true), lit := hoverX, Wait(0)
DllCall("SendMessageW", "ptr", g.Hwnd, "uint", 0x201, "ptr", 1, "ptr", y << 16 | x), DllCall("SendMessageW", "ptr", g.Hwnd, "uint", 0x202, "ptr", 0, "ptr", y << 16 | x)
Wait(400), got := lit " " DllCall("IsWindowVisible", "ptr", xw.Hwnd) " " cycling, MouseMove(0, 0, 0), Finish(false), Wait(0), xw.Destroy()
Check(PANE_LOOK = "velvet" ? "in Velvet a point in the square close button's place but off the disc isn't lit, and a click there switches to the window"
    : "in the Windows 11 look that point is on the square close button: lit, and a click there closes the window", got, PANE_LOOK = "velvet" ? "0 1 0" : "1 0 1")
Open(4, 1), rest := ThumbRect(tiles[2]), Step(1), lifted := ThumbRect(tiles[2]), Step(1), after := ThumbRect(tiles[2]), Finish(false), Wait(0)
grow := (lifted[3] - lifted[1]) / (rest[3] - rest[1])   ; Tab to tile 2, then on to tile 3: its thumbnail's width, selected / not
Check("Tab lifts the selected thumbnail about 2 % in Velvet (not in Windows 11), and the next Tab puts it back"
    , (Abs(grow - 1.02) <= 0.015 ? "about 2 % larger" : grow = 1 ? "the same size" : Round(grow, 3) " times as wide")
    . (Format("{} {} {} {}", after*) = Format("{} {} {} {}", rest*) ? ", then back" : ", then not back")
    , (PANE_LOOK = "velvet" ? "about 2 % larger" : "the same size") ", then back")

; Velvet's motion, switched through the app's seam (MotionOpen). Off, the first frame is final and nothing moves after it; on, only
; Velvet moves: the pane eases in, and Tab's selection lights up in place on the next tile (LightUp), its thumbnail growing into
; its lift and landing as it does without, while tile 1's settles at once.
off := MotionOpen(false), on := MotionOpen(true), atOnce := "at once at full strength, tile 1 settles at once, tile 2's thumbnail stays put"
Check("with Animation effects off the first frame is final: the pane isn't layered, Tab's selection is on tile 2 at once at full strength (no light-up), tile 1 settles at once and tile 2's thumbnail stays put after"
    , off.first " " off.eased ", " LightUp(off), "0 0, " atOnce)
Check(PANE_LOOK = "velvet" ? "with it on Velvet eases in (layered, then not), and Tab's selection lights up on tile 2 from partial strength to full within VELVET_GLOW_MS and 4 ticks, tile 1 settling at once, tile 2's thumbnail growing and landing as without motion"
    : "with it on the Windows 11 look still has no motion", on.first " " on.eased ", " LightUp(on) ", " (on.end = off.end ? "lands as without motion" : "lands elsewhere")
    , (PANE_LOOK = "velvet" ? "1 0, lights up from partial strength, full within its " VELVET_GLOW_MS " ms and 4 ticks, tile 1 settles at once, tile 2's thumbnail grows"
    : "0 0, " atOnce) ", lands as without motion")
; A close mid-motion (Tab, then Esc at once) leaves no motion timer running. The hidden pane is then made layered at alpha 1, a
; probe that a tick of the ease-in would change; the light-up's frames are ScrollTick's, which the close stops, the picture's PeekTick's.
ANIM_EFFECTS := true, Open(4, 1), Step(1), Finish(false), shut := Layered(), ex :=DllCall("GetWindowLongPtrW", "ptr", g.Hwnd, "int", -20, "ptr")
DllCall("SetWindowLongPtrW", "ptr", g.Hwnd, "int", -20, "ptr", ex | 0x80000, "ptr"), DllCall("SetLayeredWindowAttributes", "ptr", g.Hwnd, "uint", 0, "uchar", 1, "uint", 2)
Wait(VELVET_IN_MS + 100), DllCall("GetLayeredWindowAttributes", "ptr", g.Hwnd, "ptr", 0, "uchar*", &alpha := 0, "ptr", 0)
probe := Layered() " " alpha, DllCall("SetWindowLongPtrW", "ptr", g.Hwnd, "int", -20, "ptr", ex, "ptr"), ANIM_EFFECTS := false
Check("a close mid-motion leaves no motion timer running: the pane not layered, no light-up, the picture hidden, the probe's alpha untouched"
    , shut " " (glow ? 1 : 0) " " DllCall("IsWindowVisible", "ptr", peek.Hwnd) " " probe, "0 0 0 1 1")
#Include %A_LineFile%\..\gif-peek.ahk

; User data goes to DATA_DIR (the user's AppData\MeowTab in real use), never next to the script.
got := ""
Loop Files DATA_DIR "\*", "FD"
    got .= A_LoopFileName " "
Check("data folder is new and empty, but for the settings.ini of the look to test in", Trim(got), A_Args.Length ? "settings.ini" : "")
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
#Include %A_LineFile%\..\gif-files.ahk
Check("the app's settings.ini and images\ are unchanged", AppFiles(), before)
IniWrite "glass", DATA_DIR "\settings.ini", "settings", "PANE_LOOK"
runLook := PANE_LOOK, PANE_LOOK := lookDefault, SettingsLoad()   ; a reload from the built-in look, as a restart has it
Check("PANE_LOOK=glass in settings.ini: a reload gives the default look and reports the line"
    , PANE_LOOK ", " SETTINGS_ISSUES.Length ": " (SETTINGS_ISSUES.Length ? SETTINGS_ISSUES[1] : "")
    , lookDefault ", 1: PANE_LOOK = glass: expected velvet or windows11, using " lookDefault)
PANE_LOOK := runLook, A_Args.Length ? IniWrite(runLook, DATA_DIR "\settings.ini", "settings", "PANE_LOOK") : IniDelete(DATA_DIR "\settings.ini", "settings", "PANE_LOOK")   ; this run's look again

; Shortcuts: SWITCH_KEYS / STAY_KEYS as settings.ini has them (KeysParse), registered by KeysRegister. Custom ones are
; checked holding Ctrl: if a check goes wrong, a held Win or Alt could open Start or a menu bar.
Check("shortcuts in any order and case come back readable, with their hotkey names"
    , Parsed("alt+tab") ", " Parsed("shift+alt+ctrl+tab", true) ", " Parsed("win+q"), "Alt+Tab !Tab, Ctrl+Alt+Shift+Tab ^!+Tab, Win+Q #q")
Check("Alt+Esc is refused", Parsed("Alt+Esc"), "Escape is used inside the switcher")
Check("Shift+Tab is refused", Parsed("Shift+Tab"), "it needs Alt, Ctrl or Win")
Check("Ctrl+Alt+Q is refused for switching", Parsed("Ctrl+Alt+Q"), "switching takes only one of Alt, Ctrl and Win")
Check("Alt+Shift+Q is refused for switching", Parsed("Alt+Shift+Q"), "Shift is kept for going back")
Check("Win+L is refused", Parsed("Win+L"), "Windows keeps Win+L for locking the screen")
Check("staying open on Alt+Shift+Tab is refused while switching is Alt+Tab", Parsed("Alt+Shift+Tab", true, "Alt+Tab"), "going back already uses it")
IniWrite "Alt+Esc", DATA_DIR "\settings.ini", "settings", "SWITCH_KEYS"
SettingsLoad()                             ; a reload: the built-in shortcuts are still set
Check("SWITCH_KEYS=Alt+Esc in settings.ini: a reload gives Alt+Tab and reports the line"
    , SWITCH_KEYS ", " SETTINGS_ISSUES.Length ": " (SETTINGS_ISSUES.Length ? SETTINGS_ISSUES[1] : "")
    , "Alt+Tab, 1: SWITCH_KEYS = Alt+Esc: Escape is used inside the switcher, using Alt+Tab")
IniWrite "Ctrl+Tab", DATA_DIR "\settings.ini", "settings", "SWITCH_KEYS"
IniWrite "Ctrl+Shift+Tab", DATA_DIR "\settings.ini", "settings", "STAY_KEYS"
SettingsLoad()
Check("switching on Ctrl+Tab and staying open on Ctrl+Shift+Tab clash: both get their defaults", SWITCH_KEYS ", " STAY_KEYS ", " SETTINGS_ISSUES.Length
    , "Alt+Tab, Ctrl+Alt+Tab, 1")
IniDelete DATA_DIR "\settings.ini", "settings", "STAY_KEYS"

iw := Gui(, "alttab-test I"), ed := iw.AddEdit("w280 h180"), iw.Show("w300 h200"), guis.Push(iw), names[iw.Hwnd] := "I"
DllCall("imm32\ImmAssociateContext", "ptr", ed.Hwnd, "ptr", 0, "ptr")   ; no IME: a sent q types a q, a Chinese one would take it
for n in ["D", "C", "B"]
    Act(h[n])
Act(iw.Hwnd)                               ; recency: I B C D
Press("{LAlt down}{Tab}"), Press("{Tab}"), Press("{LAlt up}", 300)
Check("real keys: Alt held, Tab twice, Alt released goes to 3rd (C)", names.Get(WinExist("A"), "?"), "C")
SWITCH_KEYS := "Ctrl+Q", KeysRegister()    ; recency C I B D: Q -> I, B, D, Shift+Q -> B
Press("{LCtrl down}q"), Press("q"), Press("q"), Press("+q"), Press("{LCtrl up}", 300)
Check("Ctrl+Q bound: Ctrl held, Q three times, Shift+Q, Ctrl released goes to 3rd (B)", names.Get(WinExist("A"), "?"), "B")
Press("{LCtrl down}q"), wasOpen := cycling, Press(wasOpen ? "{Esc}" : ""), Press("{LCtrl up}", 300)   ; not opened: Ctrl+Esc would open Start
Check("Ctrl held, Q, Esc, Ctrl released: the pane closes and the same window stays (B)", wasOpen " " cycling " " names.Get(WinExist("A"), "?"), "1 0 B")
Press("{LCtrl down}q"), at := idx, Press("{Right}"), at .= " " idx, Press("{LCtrl up}", 300)   ; recency B C I D: Right -> I
Check("Ctrl held, Q, Right: the selection moves a tile", at, "2 3")
Act(iw.Hwnd), ed.Value := "", Press("q")
Check("with the pane closed, a plain q reaches the Edit", ed.Value, "q")
Check("saving Ctrl+Q: no error", SettingsWrite(Map("SWITCH_KEYS", "Ctrl+Q")), "")
SWITCH_KEYS := "Alt+Tab", SettingsLoad(), KeysRegister()   ; as a restart does; recency I B C D
Press("{LCtrl down}q"), wasOpen := cycling, Press("{LCtrl up}", 300)
Check("then a load and registering again: Ctrl+Q still opens the pane and switches (B)", SWITCH_KEYS " " wasOpen " " names.Get(WinExist("A"), "?"), "Ctrl+Q 1 B")
Check("SettingsReset: no error", SettingsReset(), "")
SWITCH_KEYS := "Alt+Tab", SettingsLoad(), KeysRegister()   ; recency B I C D
Press("{LCtrl down}q"), ctrlQ := cycling, Press("{LCtrl up}"), Press("{LAlt down}{Tab}"), altTab := cycling, Press("{LAlt up}", 300)
Check("then a load: Alt+Tab is back and opens the pane, Ctrl+Q doesn't (I)", SWITCH_KEYS " " ctrlQ " " altTab " " names.Get(WinExist("A"), "?")
    , "Alt+Tab 0 1 I")

; The stay-open mode (STAY_KEYS, Ctrl+Alt+Tab): the pane stays once every key is up. Enter switches, Esc or a click off it
; closes it, and other keys are blocked meanwhile.
Press("{LCtrl down}{LAlt down}{Tab}"), Press("{LAlt up}{LCtrl up}", 300)   ; recency I B C D: on B
Check("Ctrl+Alt+Tab, then every key released: the pane stays open on the previous window (B)", cycling " " names.Get(wins[idx], "?"), "1 B")
Press("{Right}"), Press("{Right}"), Press("{Enter}", 300)
Check("then Right, Right, Enter goes to the 4th window (D)", cycling " " names.Get(WinExist("A"), "?"), "0 D")
Press("{LCtrl down}{LAlt down}{Tab}"), Press("{LAlt up}{LCtrl up}"), at := idx   ; recency D I B C: on I
Press("{LAlt down}{Tab}"), Press("{LAlt up}", 300)
Check("open again, Alt held, Tab, Alt released: the selection moves a tile, and the pane stays open", at " " idx " " cycling, "2 3 1")
Press("{Esc}", 300)
Check("then Esc closes it, and the same window stays (D)", cycling " " names.Get(WinExist("A"), "?"), "0 D")
mi := Buffer(40, 0), NumPut("uint", 40, mi), DllCall("GetMonitorInfoW", "ptr", CurrentMonitor(), "ptr", mi)
WinMove(NumGet(mi, 20, "int"), NumGet(mi, 24, "int"), , , h["C"]), Sleep(100)   ; to the work area's top-left: the pane is centred
WinGetPos(&cx, &cy, , &ch, h["C"])                                               ; and at most PANE_MAX_W wide
Press("{LCtrl down}{LAlt down}{Tab}"), Press("{LAlt up}{LCtrl up}"), wasOpen := cycling   ; on I
Press("{Click " cx + 40 " " cy + ch // 2 "}", 300)
Check("a click on a window outside the pane closes the pane, and that window becomes active (C)", wasOpen " " cycling " " names.Get(WinExist("A"), "?")
    , "1 0 C")
Act(iw.Hwnd), ed.Value := ""               ; recency I C D B
Press("{LCtrl down}{LAlt down}{Tab}"), Press("{LAlt up}{LCtrl up}"), Press("q")
Check("a letter typed while the pane stays open doesn't reach the Edit, and the pane stays open", cycling " " StrLen(ed.Value), "1 0")
Press("{Esc}"), Press("q")
Check("after Esc, a letter reaches the Edit", ed.Value, "q")
Check("Ctrl and Alt aren't left down after a Ctrl+Alt+Tab open and Esc", GetKeyState("Ctrl") " " GetKeyState("Alt"), "0 0")

; The settings panel's room under GlazeWM: its top + bottom outer gaps from config.yaml's text (GlazeGaps), at 150 % (dpi 144).
glazeCfg := "
(
gaps:
  # Whether to scale the gaps with the DPI of the monitor.
  scale_with_dpi: true

  # Gap between adjacent windows.
  inner_gap: '3px'

  # Gap between windows and the screen edge.
  outer_gap:
    top: '46px'
    right: '10px'
    bottom: '6px'
    left: '10px'

window_effects:
  focused_window:
    border:
      enabled: true
      color: '#2da44e'
)"
Check("GlazeWM's gaps from the author's config: top 46 + bottom 6, scaled", GlazeGaps(glazeCfg, 144), 78)
Check("quoted keys, as YAML allows (`"gaps`":, 'outer_gap':, `"top`":), read the same"
    , GlazeGaps(StrReplace(StrReplace(StrReplace(glazeCfg, "gaps:", "`"gaps`":"), "outer_gap:", "'outer_gap':"), "top:", "`"top`":"), 144), 78)
Check("the { top, bottom } flow form reads the same",GlazeGaps("gaps:`n  outer_gap: { top: '46px', right: '10px', bottom: '6px', left: '10px' }  # bar`n", 144), 78)
Check("scale_with_dpi: false leaves them unscaled", GlazeGaps(StrReplace(glazeCfg, "scale_with_dpi: true", "scale_with_dpi: false"), 144), 52)
Check("a gaps: block with only single_window_outer_gap, or no gaps: block, is 0"
    , GlazeGaps("gaps:`n  inner_gap: 3`n  single_window_outer_gap:`n    top: 46`n    bottom: 6`n", 144) " " GlazeGaps("general:`n  focus_follows_cursor: false`n", 144), "0 0")
Check("a % value or empty text can't tell", "[" GlazeGaps(StrReplace(glazeCfg, "top: '46px'", "top: '5%'"), 144) "] [" GlazeGaps("", 144) "]", "[] []")

; The settings panel is never scaled: its window is its content plus the bottom bar, or the room, whichever is less, and the
; page scrolls under the bar. PANEL_ROOM sets the room for these checks: in 600 px (at 96 dpi) it overflows on any screen,
; in 3000 px it fits. The wheel notches are sent to the page, as a wheel over it sends them.
PANEL_ROOM := Dpx(600)
SettingsOpen(), Wait(500), WinGetPos(, , , &wh, pnl.gui), save := SaveAt()
Check("in a 600 px room the panel's window is as tall as the room, and its page overflows", wh " " (pnl.end > 0), PANEL_ROOM " 1")
pnl.hint.ctl.GetPos(, &hy, , &hh), pnl.gui.GetClientPos(, , , &ch)
Check("the hint line sits in the bottom bar, under the page's view", (pnl.hint.ctl.Gui = pnl.gui) " " (hy >= pnl.viewH && hy + hh <= ch), "1 1")
DllCall("SendMessageW", "ptr", pnl.page.Hwnd, "uint", 0x20A, "ptr", 0xFF880000, "ptr", 0), Wait(100)   ; a notch down
WinGetPos(, &py, , , pnl.page), WinGetPos(, &vy, , , pnl.view)
Check("a wheel notch scrolls the page up in its view, and Save stays put", pnl.off " " (vy - py) " " SaveAt()
    , Min(Dpx(60), pnl.end) " " Min(Dpx(60), pnl.end) " " save)
for hwnd, e in pnl.el
    if e.kind = "step" && e.i = 4                 ; the text size, just before the shortcut fields
        size := e.ctl
Act(pnl.gui.Hwnd), size.Focus(), Wait(100), was := Whole(Field(1))
Press("{Tab}")
Check("Tab from the text size to the hidden switch field scrolls it into view, whole", was " " (DllCall("GetFocus", "ptr") = Field(1).Hwnd) " " Whole(Field(1)), "0 1 1")
PanelClose(), PANEL_ROOM := Dpx(3000)
SettingsOpen(), Wait(500), save := SaveAt()
DllCall("SendMessageW", "ptr", pnl.page.Hwnd, "uint", 0x20A, "ptr", 0xFF880000, "ptr", 0), Wait(100)
Check("in a 3000 px room the page fits: no scroll bar, and a wheel notch scrolls nothing", pnl.end " " pnl.off " " (SaveAt() = save), "0 0 1")
PanelClose(), PANEL_ROOM := 0                     ; the desktop's room again

; The settings panel's SHORTCUTS row: a click on a field captures the next combination, with every key blocked and the
; hotkeys suspended meanwhile. Keys go only while a capture runs: otherwise Alt+Tab would switch and Esc close the panel.
SettingsWrite(Map("SWITCH_KEYS", "Ctrl+Q", "STAY_KEYS", "Ctrl+Alt+Q")), was := KeysLines()
err := SettingsWrite(Map("SWITCH_KEYS", "Alt+Tab", "STAY_KEYS", "Ctrl+Alt+Tab"))
Check("SettingsWrite with the default shortcuts leaves no shortcut lines in settings.ini", was " -> " err KeysLines(), "Ctrl+Q Ctrl+Alt+Q -> ")
FileDelete DATA_DIR "\settings.ini"
SettingsOpen(), Wait(500)                  ; shown and active
WinGetPos(, &wy, , &wh, pnl.gui), DllCall("GetMonitorInfoW", "ptr", CurrentMonitor(), "ptr", mi)
wt := NumGet(mi, 24, "int"), wb := NumGet(mi, 32, "int"), lf := Buffer(92), DllCall("GetObjectW", "ptr", pnl.f["body"], "int", 92, "ptr", lf)
Check("in the desktop's room the panel's window is inside the work area less Dpx(16), and its text is full size (10 pt)"
    , (wy >= wt && wy + wh <= wb && wh <= wb - wt - Dpx(16)) " " NumGet(lf, 0, "int"), "1 -" Round(10 * A_ScreenDPI / 72))
Field(2).Focus(), Press("+{Tab}")                 ; in view first (Shift+Tab to it), as a user sees a field before clicking it
ControlClick(Field(1)), Wait(100), was := (pnl.cap ? pnl.cap.j : 0) " " A_IsSuspended
Press(pnl.cap ? "{LCtrl down}q" : ""), Press("{LCtrl up}")
Check("a click on the switch field captures with the hotkeys suspended; Ctrl+Q then shows, the hotkeys back"
    , was ", " pnl.keys[1] " " A_IsSuspended, "1 1, Ctrl+Q 0")
ControlClick(Field(1)), Wait(100)
Press(pnl.cap ? "{LAlt down}{Tab}" : ""), Press("{LAlt up}", 300)
Check("a captured Alt+Tab shows as Alt+Tab, and no switcher opens (the panel stays active)"
    , pnl.keys[1] " " cycling " " (WinExist("A") = pnl.gui.Hwnd), "Alt+Tab 0 1")
ControlClick(Field(1)), Wait(100)
Press(pnl.cap ? "{LAlt down}{Esc}" : ""), Press("{LAlt up}", 300)
Check("Alt+Esc is refused with a reason, and the old value stays", pnl.keys[1] " | " pnl.note
    , "Alt+Tab | Alt+Escape can't be used: Escape is used inside the switcher.")
ControlClick(Field(2)), Wait(100)
Press(pnl.cap ? "{LAlt down}{LShift down}{Tab}" : ""), Press("{LShift up}{LAlt up}", 300)
Check("Alt+Shift+Tab for staying open is refused as a clash", pnl.keys[2] " | " pnl.note
    , "Ctrl+Alt+Tab | Alt+Shift+Tab can't be used: going back already uses it.")
ControlClick(Field(1)), Wait(100), was := IsObject(pnl.cap)
Press(was ? "{Esc}" : "", 300)
Check("Esc cancels the capture, and the panel stays open", was " " IsObject(pnl) " " (IsObject(pnl) && IsObject(pnl.cap)) " "
    . A_IsSuspended " " (IsObject(pnl) ? pnl.keys[1] : ""), "1 1 0 0 Alt+Tab")
Act(pnl.gui.Hwnd), ControlClick(Field(1)), Wait(100)   ; Alt let go before the blocked Q: unmasked, Windows sees Alt alone, and Down
                                                        ; then puts the panel in its system menu mode
got := MenuModeDuring(() => (Press(pnl.cap ? "{LAlt down}{q down}" : ""), Press("{LAlt up}"), Press("{q up}"), Press("{Down}", 300)))
Check("a captured Alt+Q with Alt let go before Q, then Down: the panel shows Alt+Q and isn't in menu mode", pnl.keys[1] ", " got, "Alt+Q, no menu mode")
got := ""
for how in ["a click elsewhere", "the panel losing focus", "the panel closing"] {   ; active first, as a real click makes it
    Act(pnl.gui.Hwnd), ControlClick(Field(1)), Wait(100), got .= how ": " A_IsSuspended
    switch A_Index {
    case 1: ControlClick(pnl.hint.ctl)
    case 2: Act(iw.Hwnd)
    case 3: PanelClose()
    }
    Wait(100), got .= " -> " A_IsSuspended (IsObject(pnl) && IsObject(pnl.cap) ? " still capturing" : "") "; "
}
Check("a capture ended by a click elsewhere, the panel losing focus or closing leaves no hotkey suspended", got
    , "a click elsewhere: 1 -> 0; the panel losing focus: 1 -> 0; the panel closing: 1 -> 0; ")
Act(iw.Hwnd), Press("{LAlt down}{Tab}"), wasOpen := cycling, Press("{LAlt up}", 300)
Check("closed without saving: no shortcut lines, and Alt+Tab opens the switcher again", "[" KeysLines() "] " wasOpen, "[] 1")

; The settings panel's LOOK cards, opened in this run's look with the built-in one as a restart has it (the reloads above took
; this run's for it). The whole page fits its room, so every element paints; the WM_DRAWITEMs after a pick are watched.
PANE_LOOK := lookDefault, SettingsLoad(), PANE_LOOK := runLook, PANEL_ROOM := Dpx(3000)
SettingsOpen(), Wait(500), other := runLook = "velvet" ? "windows11" : "velvet", cards := Map(), drawnEls := Map()
for hwnd, e in pnl.el
    if e.kind = "look"
        cards[e.lk] := e
was := pnl.look " " Marked(), OnMessage(0x2B, WatchDraw, -1)
ControlClick(cards[other].ctl), Wait(300), OnMessage(0x2B, WatchDraw, 0)
redrawn := 0
for hwnd, e in pnl.el
    redrawn += e.kind ~= "^(look|scene|sample)$" && drawnEls.Has(hwnd)
Check("a click on the " other " card picks it: it's marked instead of the " runLook " card, and both cards, the peek scenes and the title sample are drawn again"
    , was " -> " pnl.look " " Marked() ", " redrawn " drawn again", runLook " " runLook " -> " other " " other ", 5 drawn again")
got := "", want := ""
for lk in [other, runLook] {                      ; the click picked the other look; Space on this run's card picks it back
    if lk = runLook
        Act(pnl.gui.Hwnd), cards[lk].ctl.Focus(), Press("{Space}")
    SettingsWrite(PanelVals()), got .= lk ": " PanelVals().Get("PANE_LOOK", "none") " [" IniRead(DATA_DIR "\settings.ini", "settings", "PANE_LOOK", "") "] "
    want .= lk ": " lk " [" (lk = lookDefault ? "" : lk) "] "
}
Check("then Space on the " runLook " card picks it back. Save's values carry each pick, and settings.ini holds it as PANE_LOOK"
    . ", but no line for the built-in look (" lookDefault ")", got, want)
PanelClose(), PANEL_ROOM := 0
#Include %A_LineFile%\..\gif-panel.ahk
; Classic's own panel, opened by Classic in a process of its own on a data folder of its own: no LOOK section, as Classic has
; no PANE_LOOK (the panel shows the section where the script defines it).
classic := DATA_DIR "\classic-panel.ahk", answer := DATA_DIR "\classic-panel.txt"
FileOpen(classic, "w").Write("#NoTrayIcon`nOnError((e, *) => (FileAppend('error: ' e.Message, A_Args[1]), ExitApp(3)))`n"
    . "DATA_DIR := A_ScriptDir '\classic'`n#Include " AppDir() "meowtab-classic.ahk`n" "
(
SettingsOpen(), n := 0
for hwnd, e in pnl.el
    n += e.kind = 'look'
for l in pnl.labels
    n += l[1] = 'LOOK'
FileAppend(n ' LOOK elements, ' pnl.cards.Length ' picture cards', A_Args[1]), ExitApp()
)")
Run('"' A_AhkPath '" /ErrorStdOut "' classic '" "' answer '"', , , &pid)
if stuck := ProcessWaitClose(pid, 10)             ; still running after 10 s: an error dialog on its way out holds it
    ProcessClose(pid)
Check("Classic's own panel has no LOOK section, and Classic exits with it open without an error"
    , (FileExist(answer) ? FileRead(answer) : "no answer") (stuck ? ", then stuck" : ""), "0 LOOK elements, 3 picture cards")

for w in guis
    w.Destroy()
FileAppend (fails ? fails " FAILED" : "ALL PASSED") "`n", "*"
ExitApp fails ? 1 : 0
