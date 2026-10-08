; The native Windows 11 Alt+Tab look for the switcher's main script (#Included by it; the settings, constants
; and state globals live there): theme and acrylic, grid layout, drawing, live thumbnails and the mouse.
; Functions only, plus a guard against running it alone.

#Warn VarUnset, Off                                ; those globals don't exist when this file is opened by itself
                                                   ; (also quiets the settings-*.ahk files #Included after it)
if A_LineFile = A_ScriptFullPath {
    MsgBox "This file is #Included by the switcher's main script and can't run alone. Run that script instead.", "alttab-native", 0x10
    ExitApp
}
#Include %A_LineFile%\..\gdip-helpers.ahk   ; Argb, RoundPath, Canvas, FitBitmap, ArtSpan, ToHbm, ...

; ----- Theme and backdrop -----

ThemeDark() {   ; Windows mode (taskbar, Start), which the native switcher follows; true = dark
    try return !RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "SystemUsesLightTheme")
    return false
}

ThemeChanged(wParam, lParam, msg, hwnd) {   ; WM_SETTINGCHANGE "ImmersiveColorSet": mode or accent changed
    global dark
    if hwnd = A_ScriptHwnd && lParam && StrGet(lParam) = "ImmersiveColorSet"   ; every top-level window gets it: once
        dark := ThemeDark()                        ; the next open applies it
}

; Ring colour from the accent palette (8 x RGBA, read as hex): Dark1 in light mode, Light2 in dark mode, as
; WinUI's AccentFillColorDefault; else the palette's default blue.
AccentRing() {
    p := ""
    try p := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent", "AccentPalette")
    return StrLen(p) >= 64 ? SubStr(p, dark ? 9 : 33, 6) : pal.ring
}

; Once: the DWM state that gives a frameless popup the live acrylic without ever activating it. Each step is
; required (measured, spike\report.md): without NCRENDERING_POLICY a flat grey, without the extended frame
; opaque black. Without the system backdrop (before build 22621) Render paints an opaque pane instead.
PaneInit(h) {
    DwmSet(h, 2, 2)                                ; NCRENDERING_POLICY = ENABLED
    DwmSet(h, 33, 2)                               ; WINDOW_CORNER_PREFERENCE = ROUND (8 px at 96 dpi), with DWM's shadow
    DwmSet(h, 34, 0xFFFFFFFE)                      ; BORDER_COLOR = COLOR_NONE: no hard grey hairline; DrawEdge draws a soft one
    DllCall("dwmapi\DwmExtendFrameIntoClientArea", "ptr", h, "ptr", Buffer(16, 0xFF))   ; MARGINS -1: frame = client area
    if BACKDROP
        DwmSet(h, 38, 3)                           ; SYSTEMBACKDROP_TYPE = TRANSIENTWINDOW: the flyouts' acrylic
}
DwmSet(h, attr, v) => DllCall("dwmapi\DwmSetWindowAttribute", "ptr", h, "uint", attr, "int*", v, "uint", 4)

; Draw the laid-out grid and show it at screen x, y with its live thumbnails; fresh = a new open (light / dark,
; accent). The new surface replaces the old one whole, so an erase in between always blits a finished one.
PaneShow(x, y, fresh) {
    global surf, pal, accentRgb, hover, hoverX, mouseAt
    if fresh {                                     ; and the scroll bar shows on opening, when rows overflow
        pal := dark ? DARK_PAL : LIGHT_PAL, accentRgb := AccentRing(), DwmSet(g.Hwnd, 20, dark)   ; IMMERSIVE_DARK_MODE: dark acrylic
        BarReset(grid.end > 0)
    }
    IconsLoad()
    hover := 0, hoverX := false                    ; tiles moved: PaneHover finds the one under the mouse again
    s := SurfaceMake(grid.w, grid.h), Render(s)
    old := surf, surf := s, SurfaceFree(old)
    ThumbsClear(), ThumbsShow()                    ; afresh for this layout; before Show: no frame of empty slots
    g.Show("NA x" x " y" y " w" grid.w " h" grid.h)
    DllCall("SendMessageW", "ptr", g.Hwnd, "uint", 0x86, "ptr", 1, "ptr", 0)   ; WM_NCACTIVATE(TRUE), every show: live acrylic
    Present()
    if !fresh                                      ; e.g. a click on X: the tile that slid under the mouse
        mouseAt := CursorAt(), SetTimer(PaneHover, -1)
}

PaneFree() {   ; on hide: everything one open made; a scroll stops where it is, the scroll bar's fade and drag too
    global surf, icons, hover, hoverX, mouseAt, pressAt, clickAt, wheel, tracking
    SetTimer(ScrollTick, 0), grid.goal := grid.off, BarReset(false)
    ThumbsClear()
    for hwnd, pair in icons
        for bm in pair
            if bm
                DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    old := surf, surf := 0, icons := Map(), SurfaceFree(old)
    hover := 0, hoverX := false, mouseAt := pressAt := clickAt := 0, wheel := 0, tracking := false
}

; ----- Surface: a pane-sized 32bpp DIB that GDI+ draws into as premultiplied ARGB (real alpha over the glass) -----

SurfaceMake(w, h) {   ; {w, h, dc, hbm, old, bm, gr}; SurfaceFree frees it
    bi := Buffer(40, 0), NumPut("uint", 40, "int", w, "int", -h, "ushort", 1, "ushort", 32, bi)   ; top-down BITMAPINFOHEADER
    hbm := DllCall("CreateDIBSection", "ptr", 0, "ptr", bi, "uint", 0, "ptr*", &bits := 0, "ptr", 0, "uint", 0, "ptr")
    dc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr"), old := DllCall("SelectObject", "ptr", dc, "ptr", hbm, "ptr")
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h, "int", 4 * w, "int", 0xE200B, "ptr", bits, "ptr*", &bm := 0)   ; PARGB on the bits
    gr := Canvas(bm)
    DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", gr, "int", TEXT_HINT)   ; grayscale: glyph coverage goes into alpha
    return {w: w, h: h, dc: dc, hbm: hbm, old: old, bm: bm, gr: gr}
}

SurfaceFree(s) {
    if !s
        return
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", s.gr), DllCall("gdiplus\GdipDisposeImage", "ptr", s.bm)
    DllCall("SelectObject", "ptr", s.dc, "ptr", s.old), DllCall("DeleteDC", "ptr", s.dc), DllCall("DeleteObject", "ptr", s.hbm)
}

; WM_ERASEBKGND: copy the surface onto the pane. SRCCOPY keeps the alpha byte, and DWM composes the
; extended-frame client area as premultiplied ARGB over the acrylic. 1 = erased (no black flash).
PaneErase(wParam, lParam, msg, hwnd) {
    if hwnd != g.Hwnd || !(s := surf)
        return
    DllCall("BitBlt", "ptr", wParam, "int", 0, "int", 0, "int", s.w, "int", s.h, "ptr", s.dc, "int", 0, "int", 0, "uint", 0xCC0020)
    return 1
}
Present() => DllCall("RedrawWindow", "ptr", g.Hwnd, "ptr", 0, "ptr", 0, "uint", 0x105)   ; INVALIDATE|ERASE|UPDATENOW

; One off-screen header and title, so the first Alt+Tab doesn't pay GDI+'s cold start (glyph cache, ~10 ms).
WarmUp() {
    Critical
    s := SurfaceMake(240, 60)
    Paint(s.gr, CornerPath(0, 0, 240, 60, 12, 3), Argb("FFFFFF", 200))
    Title(s.gr, "Warm-up 暖身 ウォーム", 36, 0, 200, 60, "000000")
    SurfaceFree(s)
}

; ----- Layout -----

; Grid for `wins` in a w x h work area at scale S, with `art` px of image above the pane now and `maxArt` at its
; highest peek. Tiles (header + thumbnail slot) as wide as their window's shape (at least TILE_MIN_W), wrapped
; greedily into centred rows. Too tall for the room under the image: the thumbnails shrink step by step to TILE_MIN
; of their height, then as many rows show as fit and the rest scrolls. From GRID_FROM windows the fixed grid instead
; (GridRows), never shrunk: as many rows show as fit under the image at its highest peek, so the pane keeps its
; height while the image rises. The view starts at offset `keep` (a close keeps it), clamped to the new end.
GridLayout(w, h, art, maxArt, S := A_ScreenDPI / 96, keep := 0) {
    global grid, tiles
    fixed := wins.Length >= GRID_FROM, pad := Round(PANE_PAD * S), gap := Round(TILE_GAP * S), margin := Round(PANE_MARGIN * S)
    hdr := Max(Round(HEADER_H * S), Ceil(titleLineH) + Round(24 * S))   ; the title's line + 12 px above and below
    maxW := Floor(PANE_MAX_W * w) - 2 * pad, minW := Min(Round(TILE_MIN_W * S), maxW), room := h - (fixed ? maxArt : art) - 2 * margin
    tiles := []
    for hwnd in wins {
        f := WindowFrame(hwnd, &iconic, &whole)
        tiles.Push({src: f, iconic: iconic, whole: whole, title: TitleOf(hwnd), aspect: Min(Max(f[3] / Max(f[4], 1), ASPECT_MIN), ASPECT_MAX)
            , thumb: 0, on: false})                ; its DWM thumbnail once in view (ThumbsShow), and whether it shows
    }
    slot := Max(Round(TILE_H * h) - hdr, 1), least := Round(slot * TILE_MIN)
    Loop {
        rows := fixed ? GridRows(slot, w / h, maxW, gap) : WrapRows(slot, minW, maxW, gap), tall := rows.Length * (hdr + slot + gap) - gap + 2 * pad
        if fixed || tall <= room || (next := Max(least, Round(slot * 0.9))) = slot   ; the grid never shrinks; else fits, or can't shrink any further
            break
        slot := next
    }
    vis := tall <= room ? rows.Length : Max(1, (room - 2 * pad + gap) // (hdr + slot + gap))
    wide := 0
    for row in rows
        wide := Max(wide, row[3])
    pane := vis * (hdr + slot + gap) - gap + 2 * pad, off := Min(keep, tall - pane)   ; the full rows that fit and the padding
    grid := {S: S, pad: pad, gap: gap, margin: margin, hdr: hdr, slot: slot, th: hdr + slot, r: Round(TILE_R * S)
        , closeW: Round(CLOSE_W * S), rows: rows, w: wide + 2 * pad, h: pane, end: tall - pane, off: off, goal: off, from: off, t0: 0}
    for r, row in rows {                           ; each row centred (the grid's from the left: its columns stay put); content y (TileY scrolls)
        x := pad + (fixed ? 0 : (wide - row[3]) // 2), y := pad + (r - 1) * (grid.th + gap)
        Loop row[2] - row[1] + 1
            t := tiles[row[1] + A_Index - 1], t.x := x, t.y := y, t.row := r, x += t.w + gap
    }
}

WrapRows(slot, minW, maxW, gap) {   ; tile widths for this thumbnail height, wrapped left to right: [[first, last, width], ...]
    rows := []
    for i, t in tiles {
        t.w := Min(Max(Round(slot * t.aspect), minW), maxW)
        if rows.Length && rows[-1][3] + gap + t.w <= maxW
            rows[-1][2] := i, rows[-1][3] += gap + t.w
        else
            rows.Push([i, i, t.w])
    }
    return rows
}

; The fixed grid, rows as WrapRows gives them: GRID_COLS tiles to a row, each as wide as a slot shaped like the
; work area (clamped as a window's shape), so a maximized window fills it; narrower only if GRID_COLS don't fit.
GridRows(slot, shape, maxW, gap) {
    tw := Min(Round(slot * Min(Max(shape, ASPECT_MIN), ASPECT_MAX)), (maxW - (GRID_COLS - 1) * gap) // GRID_COLS)
    rows := []
    for i, t in tiles {
        t.w := tw
        if Mod(i - 1, GRID_COLS)
            rows[-1][2] := i, rows[-1][3] += gap + tw
        else
            rows.Push([i, i, tw])
    }
    return rows
}

; The visible frame (DWM's extended frame bounds, without the invisible resize borders) as [x, y, w, h] within
; the window rect: what its thumbnail shows. Minimized (iconic := true): its restored size. whole := true: show
; all of the window instead (minimized, or no usable frame bounds).
WindowFrame(hwnd, &iconic, &whole) {
    whole := true
    if iconic := DllCall("IsIconic", "ptr", hwnd) {
        wp := Buffer(44, 0), NumPut("uint", 44, wp), DllCall("GetWindowPlacement", "ptr", hwnd, "ptr", wp)
        return [0, 0, NumGet(wp, 36, "int") - NumGet(wp, 28, "int"), NumGet(wp, 40, "int") - NumGet(wp, 32, "int")]   ; rcNormalPosition
    }
    wr := Buffer(16, 0), fr := Buffer(16, 0)
    DllCall("GetWindowRect", "ptr", hwnd, "ptr", wr)
    if DllCall("GetDpiForWindow", "ptr", hwnd, "uint") != A_ScreenDPI   ; frame bounds are physical px; this script's rect of
        || DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 9, "ptr", fr, "uint", 16)   ; a window at another DPI is scaled
        fr := wr                                   ; (or EXTENDED_FRAME_BOUNDS failed): no crop
    else
        whole := false
    return [NumGet(fr, 0, "int") - NumGet(wr, 0, "int"), NumGet(fr, 4, "int") - NumGet(wr, 4, "int")
        , NumGet(fr, 8, "int") - NumGet(fr, 0, "int"), NumGet(fr, 12, "int") - NumGet(fr, 4, "int")]
}

TitleOf(hwnd) {
    try return WinGetTitle(hwnd)
    return ""
}

; Scrolling, the same for both layouts: a tile sits at content y t.y and shows at client y t.y - grid.off. The view
; is the pane cut just inside its drawn edge (Inset). grid.goal: the offset a scroll heads for, from grid.from at
; tick grid.t0; grid.end: the last offset (0 = all rows fit).
TileY(t) => t.y - grid.off                                                    ; client y, scrolled
Content(pt) => pt ? [pt[1], pt[2] + grid.off] : 0                             ; client point -> content point (0 = none)
InView(t) => (y := TileY(t)) < grid.h - Inset() && y + grid.th > Inset()      ; at least partly
WholeAt(t, off) => (y := t.y - off) >= Inset() && y + grid.th <= grid.h - Inset()   ; all of it, at offset off

; The goal that shows tile i whole: the goal as it is if it does there, else just far enough that the tile sits pad
; inside the pane, as the first row does unscrolled (part of the next row then stays in view).
Reveal(i) {
    t := tiles[i]
    if WholeAt(t, grid.goal)
        return grid.goal
    return Min(Max(t.y - grid.goal < Inset() ? t.y - grid.pad : t.y + grid.th + grid.pad - grid.h, 0), grid.end)
}

; Scroll to offset goal (clamped to 0 .. end), easing out over SCROLL_MS from where the view is now: a new goal
; restarts the ease. The scroll bar shows. The first frame runs at once, as PeekTo's.
ScrollTo(goal) {
    global barOn := true
    grid.goal := Min(Max(goal, 0), grid.end), grid.from := grid.off, grid.t0 := A_TickCount
    SetTimer(ScrollTick, ANIM_TICK)
    ScrollTick()
}

; One frame, every one comes through here: a drag's step (BarDrag), the offset (ease-out cubic), the hover under the
; resting mouse, the scroll bar (BarStep), the thumbnails and the pixels, back to back. While the bar shows and the mouse
; isn't near it, each frame puts its fade off to BAR_SHOW_MS later. Stops itself once nothing moves any more.
ScrollTick() {
    global hover, hoverX, barGrab
    Critical
    if !cycling || !surf
        return SetTimer(ScrollTick, 0)
    was := grid.off
    if barGrab >= 0 {                              ; dragging until the physical button is up (the right one if swapped)
        if DllCall("GetAsyncKeyState", "int", DllCall("GetSystemMetrics", "int", 23) ? 2 : 1, "short") < 0
            BarDrag(CursorAt()[2])
        else
            barGrab := -1
    }
    p := SCROLL_MS > 0 ? Min((A_TickCount - grid.t0) / SCROLL_MS, 1) : 1
    grid.off := Round(grid.from + (grid.goal - grid.from) * (1 - (1 - p) ** 3))   ; (a drag's step: from = goal = off)
    hover := HitTest(Content(mouseAt), &onX), hoverX := onX
    settled := BarStep() && grid.off = grid.goal && barGrab < 0
    if grid.off != was                             ; thumbnails move only with the view (PaneShow places them after a re-layout)
        ThumbsShow()
    Render(surf), Present()
    if barOn && !BarNear()
        SetTimer(BarFade, -BAR_SHOW_MS)
    if settled && barGrab < 0                      ; a press on the thumb may have come in during this frame
        SetTimer(ScrollTick, 0)
}

Nearest(r, cx) {   ; the tile in row r whose centre is closest to cx
    best := 0
    Loop grid.rows[r][2] - grid.rows[r][1] + 1 {
        i := grid.rows[r][1] + A_Index - 1, d := Abs(tiles[i].x + tiles[i].w / 2 - cx)
        if !best || d < bestD
            best := i, bestD := d
    }
    return best
}

SelectTile(i) {   ; the selection to tile i, scrolled into view if it isn't whole there (judged at the goal)
    global idx := i
    if (to := Reveal(i)) != grid.goal
        return ScrollTo(to)                        ; its first frame draws the selection
    Render(surf), Present()
}

; The wheel's and the drag's rule: the selection stays whole in view at offset goal, else it goes to the nearest tile in
; the closest row that is (none, where one row at most fits: the row whose middle is nearest the view's).
KeepInView(goal) {
    global idx
    if WholeAt(tiles[idx], goal)
        return
    r := tiles[idx].row, best := 0
    for k, row in grid.rows
        if WholeAt(tiles[row[1]], goal) && (!best || Abs(k - r) < Abs(best - r))
            best := k
    if !best
        best := Min(Max(Round((goal + (grid.h - grid.th) / 2 - grid.pad) / (grid.th + grid.gap)) + 1, 1), grid.rows.Length)
    idx := Nearest(best, tiles[idx].x + tiles[idx].w / 2)
}

; ----- Scroll bar, only while rows overflow: a thumb in the right padding, drawn in our surface (DrawBar). Its width
; and opacity ease on ScrollTick's frames; a press on it starts a drag that ScrollTick follows. -----

BarReset(on) {   ; a new open: shown at once (on) with its fade set; PaneFree: none, nothing pending
    global barA := on ? 1 : 0, barW := Round(BAR_W * grid.S), barOn := on, barT := A_TickCount, barNearSeen := false, barGrab := -1
    SetTimer(BarFade, on ? -BAR_SHOW_MS : 0)
}

BarNear() => grid.end > 0 && (barGrab >= 0 || mouseAt && mouseAt[1] >= grid.w - grid.pad && mouseAt[1] < grid.w
    && mouseAt[2] >= 0 && mouseAt[2] < grid.h)     ; the mouse in the right padding (inside the pane), or a drag

; The track in client px: its top and length, clear of the pane's rounded corners; k: the thumb's length, the pane's
; share of the content.
BarTrack(&top, &len, &k) {
    top := Round(BAR_END * grid.S), len := grid.h - 2 * top, k := len * grid.h / (grid.h + grid.end)
}

; The thumb now, [x, y, w, h] in client px: its right edge BAR_EDGE from the pane's, the bar's width now, its place along
; the track the offset's share of the end.
BarKnob() => (BarTrack(&top, &len, &k), [grid.w - Round(BAR_EDGE * grid.S) - barW, top + (len - k) * grid.off / Max(grid.end, 1), barW, k])

; One frame of the bar: its width toward wide while the mouse is near (it shows then), else thin; its opacity toward
; shown or faded; linearly over BAR_GROW_MS and BAR_FADE_MS. true = both there.
BarStep() {
    global barA, barW, barOn, barT, barNearSeen
    dt := Min(A_TickCount - barT, 2 * ANIM_TICK), barT := A_TickCount   ; at most two ticks' worth: the first frame after a pause
    if barNearSeen := near := BarNear()
        barOn := true
    w := Round((near ? BAR_WIDE : BAR_W) * grid.S), a := barOn ? 1 : 0
    barW := Toward(barW, w, (BAR_WIDE - BAR_W) * grid.S * dt / BAR_GROW_MS), barA := Toward(barA, a, dt / BAR_FADE_MS)
    return barW = w && barA = a
}
Toward(v, goal, step) => v < goal ? Min(v + step, goal) : Max(v - step, goal)

BarFade() {   ; BAR_SHOW_MS after the last scroll: the bar fades out, unless the mouse is near it
    global barOn
    if !cycling || BarNear()
        return
    barOn := false, SetTimer(ScrollTick, ANIM_TICK)
}

; A drag's step: the thumb's top follows pointer y (client px) less where it was grabbed, the view jumps along (no ease),
; and the selection stays whole in view, as with the wheel.
BarDrag(y) {
    global barOn := true
    BarTrack(&top, &len, &k)
    off := Round(Min(Max((y - barGrab - top) / Max(len - k, 1), 0), 1) * grid.end)
    KeepInView(off), grid.off := grid.goal := grid.from := off
}

DrawBar(gr) {   ; the thumb: a pill in the palette's `bar`, at the bar's opacity now
    b := BarKnob()
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Argb(pal.bar[1], Round(pal.bar[2] * barA)), "ptr*", &br := 0)
    path := RoundPath(b[1], b[2], b[3], b[4], b[3] / 2)
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", path)
    DllCall("gdiplus\GdipDeletePath", "ptr", path), DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

; ----- Drawing: one full redraw per change (~2 ms for 20 tiles, spike Q5); DWM puts the thumbnails over it -----

Render(s) {   ; the pane's pixels for the current state: its edge, the tiles in view (cut just inside it), hover, selection, scroll bar
    DllCall("gdiplus\GdipGraphicsClear", "ptr", s.gr, "uint", BACKDROP ? 0 : Argb(pal.pane, 255))   ; clear glass / opaque pane
    DrawEdge(s.gr, s.w, s.h)
    DllCall("gdiplus\GdipSetClipRectI", "ptr", s.gr, "int", 0, "int", Inset(), "int", s.w, "int", s.h - 2 * Inset(), "int", 0)   ; CombineModeReplace
    for i, t in tiles
        if InView(t)
            DrawTile(s.gr, i, t)
    if idx && InView(tiles[idx])
        DrawSelection(s.gr, tiles[idx])
    DllCall("gdiplus\GdipResetClip", "ptr", s.gr)
    if grid.end > 0 && barA > 0
        DrawBar(s.gr)
    DllCall("gdiplus\GdipFlush", "ptr", s.gr, "int", 1)   ; FlushIntentionSync: done before GDI reads the bits
}

; The pane's edge, in place of DWM's hard grey border: a faint hairline (definition on light backdrops) and just
; inside it a 1 px highlight fading from the top down, as light catches a glass lip; both on DWM's corner radius.
DrawEdge(gr, w, h) {
    r := Round(PANE_R * grid.S), o := pal.hair[2] ? 1 : 0   ; the highlight goes inside the hairline, if there is one
    if o
        Stroke(gr, 0.5, 0.5, w - 1, h - 1, r - 0.5, 1, [[pal.hair[1], pal.hair[2], 0], [pal.hair[1], pal.hair[2], 1]], 90)
    Stroke(gr, o + 0.5, o + 0.5, w - 2 * o - 1, h - 2 * o - 1, r - o - 0.5, 1
        , [[pal.edge[1], pal.edge[2], 0], [pal.edge[1], pal.edge[3], 1]], 90)   ; FadeBrush at 90: top -> bottom
}
Inset() => pal.hair[2] ? 2 : 1                     ; the drawn edge's rows at the top and bottom: tiles are cut just inside

; Header (icon, title; hovered: lighter, with the close button) over the thumbnail slot, which gets a faint fill
; where the thumbnail doesn't cover it (an extreme shape is letterboxed; a minimized window shows its icon).
DrawTile(gr, i, t) {
    S := grid.S, x := t.x, y := TileY(t), w := t.w, hdr := grid.hdr, hot := i = hover
    Paint(gr, RoundPath(x, y, w, grid.th, grid.r), Argb(pal.slot*))
    Paint(gr, CornerPath(x, y, w, hdr, grid.r, 3), Argb((hot ? pal.hot : pal.head)*))   ; top corners round
    pair := icons.Get(wins[i], [0, 0]), ic := Round(ICON_PX * S), tx := x + Round(TITLE_X * S)
    if pair[1]
        DllCall("gdiplus\GdipDrawImageRectI", "ptr", gr, "ptr", pair[1], "int", x + Round(ICON_X * S), "int", y + (hdr - ic) // 2, "int", ic, "int", ic)
    if pair[2] && t.iconic {
        big := Round(BIG_ICON * S)
        DllCall("gdiplus\GdipDrawImageRectI", "ptr", gr, "ptr", pair[2], "int", x + (w - big) // 2, "int", y + hdr + (grid.slot - big) // 2, "int", big, "int", big)
    }
    if (tw := x + w - (hot ? CloseW(t) : Round(12 * S)) - tx) > 0   ; GDI+ takes a zero width as "no limit"
        Title(gr, t.title, tx, y, tw, hdr, pal.text)
    if hot
        DrawClose(gr, x + w - CloseW(t), y, CloseW(t), hdr)
}
CloseW(t) => Min(grid.closeW, t.w // 2)            ; a narrow tile's header still switches on its left half

DrawClose(gr, x, y, w, h) {   ; red, flush in the header's top-right corner (only that corner round), white X
    Paint(gr, CornerPath(x, y, w, h, grid.r, 2), Argb(hoverX ? CLOSE_HOT : CLOSE_RGB, 255))
    d := CLOSE_X * grid.S / 2, cx := x + w / 2, cy := y + h / 2
    DllCall("gdiplus\GdipCreatePen1", "uint", 0xFFFFFFFF, "float", CLOSE_LINE * grid.S, "int", 2, "ptr*", &pen := 0)   ; UnitPixel
    DllCall("gdiplus\GdipDrawLine", "ptr", gr, "ptr", pen, "float", cx - d, "float", cy - d, "float", cx + d, "float", cy + d)
    DllCall("gdiplus\GdipDrawLine", "ptr", gr, "ptr", pen, "float", cx - d, "float", cy + d, "float", cx + d, "float", cy - d)
    DllCall("gdiplus\GdipDeletePen", "ptr", pen)
}

; Selected tile, from its edge outwards: a SEL_GAP gap, a SEL_INNER stroke (white / black 70 %), a SEL_RING
; accent ring; each follows the tile's corners (outer radius 12 + 11 at 96 dpi).
DrawSelection(gr, t) {
    gp := Round(SEL_GAP * grid.S), wi := Round(SEL_INNER * grid.S), wr := Round(SEL_RING * grid.S), y := TileY(t)
    Outline(gr, t.x, y, t.w, grid.th, grid.r, gp + wi / 2, wi, Argb(pal.inner*))
    Outline(gr, t.x, y, t.w, grid.th, grid.r, gp + wi + wr / 2, wr, Argb(accentRgb, 255))
}

Outline(gr, x, y, w, h, r, o, width, argb) {   ; a `width` px line o px outside the rounded rect x, y, w, h
    DllCall("gdiplus\GdipCreatePen1", "uint", argb, "float", width, "int", 2, "ptr*", &pen := 0)
    path := RoundPath(x - o, y - o, w + 2 * o, h + 2 * o, r + o)
    DllCall("gdiplus\GdipDrawPath", "ptr", gr, "ptr", pen, "ptr", path)
    DllCall("gdiplus\GdipDeletePath", "ptr", path), DllCall("gdiplus\GdipDeletePen", "ptr", pen)
}

Paint(gr, path, argb) {   ; fill the path, then delete it
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", Brush(argb), "ptr", path)
    DllCall("gdiplus\GdipDeletePath", "ptr", path)
}

Brush(argb) {   ; a solid brush per colour, made once and kept (a handful per theme)
    static made := Map()
    if !made.Has(argb)
        DllCall("gdiplus\GdipCreateSolidFill", "uint", argb, "ptr*", &br := 0), made[argb] := br
    return made[argb]
}

; Rectangle path with only the `corners` rounded (1 top-left, 2 top-right, 4 bottom-right, 8 bottom-left); caller deletes it.
CornerPath(x, y, w, h, r, corners) {
    DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &p := 0), d := 2 * r
    for i, a in [180, 270, 0, 90] {                ; clockwise from the top-left, as RoundPath
        cx := a = 0 || a = 270 ? x + w : x, cy := a < 180 ? y + h : y
        if corners & (1 << (i - 1))
            DllCall("gdiplus\GdipAddPathArc", "ptr", p, "float", a = 0 || a = 270 ? cx - d : cx, "float", a < 180 ? cy - d : cy
                , "float", d, "float", d, "float", a, "float", 90)
        else                                       ; a square corner: just its point
            DllCall("gdiplus\GdipAddPathLine", "ptr", p, "float", cx, "float", cy, "float", cx, "float", cy)
    }
    DllCall("gdiplus\GdipClosePathFigure", "ptr", p)
    return p
}

; The title font: FONT_NAME at FONT_SIZE pt, made in pixels (the surface's DPI can't skew it); Segoe UI when GDI+
; can't use it (a CFF-outline OpenType family, or one with no Regular style). CJK falls back by itself.
; titleLineH: its line height in px.
TitleInit() {
    global titleFont, titleFmt, titleLineH
    px := FONT_SIZE * A_ScreenDPI / 72
    for face in [FONT_NAME, "Segoe UI"] {
        if DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", face, "ptr", 0, "ptr*", &ff := 0)
            continue
        DllCall("gdiplus\GdipGetEmHeight", "ptr", ff, "int", 0, "ushort*", &em := 0)
        DllCall("gdiplus\GdipGetLineSpacing", "ptr", ff, "int", 0, "ushort*", &ls := 0)
        failed := DllCall("gdiplus\GdipCreateFont", "ptr", ff, "float", px, "int", 0, "int", 2, "ptr*", &titleFont := 0)   ; Regular, UnitPixel
        DllCall("gdiplus\GdipDeleteFontFamily", "ptr", ff)
        if !failed
            break
    }
    titleLineH := px * ls / Max(em, 1)
    DllCall("gdiplus\GdipStringFormatGetGenericTypographic", "ptr*", &typo := 0)   ; no 1/6 em padding at each end
    DllCall("gdiplus\GdipCloneStringFormat", "ptr", typo, "ptr*", &titleFmt := 0)
    DllCall("gdiplus\GdipSetStringFormatFlags", "ptr", titleFmt, "int", 0x3000)                  ; NoWrap|LineLimit (clipped)
    DllCall("gdiplus\GdipSetStringFormatTrimming", "ptr", titleFmt, "int", 3)                    ; EllipsisCharacter
    DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", titleFmt, "int", 1)                   ; centred vertically
}

Title(gr, s, x, y, w, h, rgb) {   ; one line in x, y, w, h, cut with an ellipsis
    rc := Buffer(16), NumPut("float", x, "float", y, "float", w, "float", h, rc)
    DllCall("gdiplus\GdipDrawString", "ptr", gr, "wstr", s, "int", -1, "ptr", titleFont, "ptr", rc, "ptr", titleFmt, "ptr", Brush(Argb(rgb, 255)))
}

; ----- Live thumbnails -----

; One DWM thumbnail per tile in view, fitted into its slot (upscaled if need be, as native), the source cropped to
; the visible frame. Registered the first time its slot shows, then placed on each call (each frame): cut where the
; view cuts the tile, its source by the same share; hidden, not released, while out of view, and only one that just
; left is touched. DWM draws them over the acrylic and our pixels, unrounded. Handles in `thumbs` and t.thumb.
ThumbsShow() {
    global thumbs
    e := Inset()
    for i, t in tiles {
        y := TileY(t) + grid.hdr                   ; the slot's top, client
        if y >= grid.h - e || y + grid.slot <= e {
            if t.on
                ThumbHide(t), t.on := false
            continue
        }
        if !t.thumb {                              ; first sight
            if DllCall("dwmapi\DwmRegisterThumbnail", "ptr", g.Hwnd, "ptr", wins[i], "ptr*", &id := 0)
                continue                           ; failed (HRESULT != 0): the slot stays empty
            thumbs.Push(t.thumb := id), t.sw := t.src[3], t.sh := t.src[4]
            if t.whole                             ; minimized, or no usable frame: all of it, as DWM keeps it
                DllCall("dwmapi\DwmQueryThumbnailSourceSize", "ptr", id, "int64*", &sz := 0), t.sw := sz & 0xFFFFFFFF, t.sh := sz >> 32
        }
        t.on := ThumbPlace(t, y, e)
    }
}

; Tile t's thumbnail fitted and centred in its slot (its top at client y), cut e px inside the pane's top and bottom
; as Render cuts our pixels, its source rows by the same share: floating point, rounded once. true = it shows.
ThumbPlace(t, y, e) {
    sx := t.whole ? 0 : t.src[1], sy := t.whole ? 0 : t.src[2]
    k := Min(t.w / Max(t.sw, 1), grid.slot / Max(t.sh, 1)), w := t.sw * k, h := t.sh * k
    x := t.x + (t.w - w) / 2, y += (grid.slot - h) / 2, y1 := Max(y, e), y2 := Min(y + h, grid.h - e)
    if y2 <= y1 {                                  ; only its letterbox is in view
        if t.on
            ThumbHide(t)
        return false
    }
    p := Buffer(48, 0)                             ; DWM_THUMBNAIL_PROPERTIES
    NumPut("uint", 0xF, p, 0)                      ; RECTDESTINATION | RECTSOURCE | OPACITY | VISIBLE
    NumPut("int", Round(x), "int", Round(y1), "int", Round(x + w), "int", Round(y2)
        , "int", sx, "int", Round(sy + (y1 - y) / k), "int", sx + t.sw, "int", Round(sy + (y2 - y) / k), p, 4)
    NumPut("uchar", 255, p, 36), NumPut("int", 1, p, 40)   ; opaque, visible; not client-only
    DllCall("dwmapi\DwmUpdateThumbnailProperties", "ptr", t.thumb, "ptr", p)
    return true
}

ThumbHide(t) {   ; fVisible FALSE: kept, ready to show again at once
    p := Buffer(48, 0), NumPut("uint", 0x8, p, 0)  ; VISIBLE only
    DllCall("dwmapi\DwmUpdateThumbnailProperties", "ptr", t.thumb, "ptr", p)
}

ThumbsClear() {
    global thumbs
    for id in thumbs
        DllCall("dwmapi\DwmUnregisterThumbnail", "ptr", id)
    thumbs := []
}

; ----- Mouse, only while open. A handler just notes the event and a timer acts on it: posted messages run
; their handlers even inside a Critical hotkey, timers wait. Other windows are left alone (return nothing):
; the Settings panel handles the same messages while it is open. -----

PaneMouse(wParam, lParam, msg, hwnd) {   ; WM_MOUSEMOVE, WM_LBUTTONDOWN / UP / DBLCLK, WM_MOUSELEAVE, WM_MOUSEWHEEL
    global mouseAt, pressAt, clickAt, wheel, tracking, barGrab
    if hwnd != g.Hwnd || !cycling
        return
    if msg = 0x20A                                 ; wheel: wParam's high word, 120 a notch
        return (wheel += wParam << 32 >> 48, SetTimer(PaneWheel, -1), 0)
    x := lParam << 48 >> 48, y := lParam << 32 >> 48   ; client x, y (signed)
    if (msg = 0x201 || msg = 0x203) && grid.end > 0 && x >= grid.w - grid.pad && (b := BarKnob(), y >= b[2] && y < b[2] + b[4])
        return (barGrab := y - b[2], pressAt := 0, SetTimer(ScrollTick, ANIM_TICK), 0)   ; on the bar's thumb (across the padding): a drag, no click
    if msg = 0x201 || msg = 0x203                  ; button down (a quick second press comes as a double-click)
        return (pressAt := [x, y + grid.off, grid], 0)   ; a press or release: in content coordinates, and the layout it was on
    if msg = 0x202
        return (clickAt := [x, y + grid.off, grid], SetTimer(PaneClick, -1), 0)
    if msg = 0x2A3                                 ; left: tracking ended
        tracking := false
    mouseAt := msg = 0x2A3 ? 0 : [x, y], SetTimer(PaneHover, -1)   ; client: the hover follows a scroll under it
    return 0
}

; WM_MOUSEACTIVATE: MA_NOACTIVATE. NOACTIVATE keeps a press from bringing the pane to the foreground, but the press still
; made it its thread's active window, drawn inactive since that thread isn't the foreground one: flat grey glass.
PaneNoActivate(wParam, lParam, msg, hwnd) => hwnd = g.Hwnd ? 3 : ""

PaneHover() {   ; the tile under the mouse gets the lighter header and its close button
    global hover, hoverX, tracking
    Critical
    if !cycling || !surf
        return
    if mouseAt && !tracking {                      ; WM_MOUSELEAVE once it leaves (at once if it already has)
        tme := Buffer(24, 0), NumPut("uint", 24, "uint", 2, "ptr", g.Hwnd, tme)   ; TRACKMOUSEEVENT, TME_LEAVE
        tracking := DllCall("TrackMouseEvent", "ptr", tme)
    }
    i := HitTest(Content(mouseAt), &onX)
    if i != hover || onX != hoverX
        hover := i, hoverX := onX, Render(surf), Present()
    if BarNear() != barNearSeen                        ; the mouse came near the scroll bar or left it: it eases (only on the
        SetTimer(ScrollTick, ANIM_TICK)            ; change: setting the timer again restarts its countdown)
}

; On a tile: switch to it; on its close button: close that window, the pane stays. Only a press and release
; on the same tile and part, made on the layout still showing, count: a click noted during a close's wait
; would land on whatever tile slid under it.
PaneClick() {
    global idx, pressAt, clickAt
    down := pressAt, up := clickAt, pressAt := clickAt := 0
    if !cycling || !surf || !OnLayout(down) || !OnLayout(up) || !(i := HitTest(up, &onX)) || HitTest(down, &downX) != i || downX != onX
        return
    if onX
        return CloseSelected(i)
    idx := i
    Finish(true)
}
OnLayout(pt) => pt && pt[3] = grid                ; noted on the layout on screen now (in content coordinates: any scroll)

; A notch scrolls a row, notches adding up on the goal (0 .. end). The selection stays whole in view, judged at the
; goal (KeepInView).
PaneWheel() {
    global wheel
    Critical
    n := Integer(wheel / 120), wheel -= n * 120
    if !n || !cycling || !surf
        return
    goal := Min(Max(grid.goal - n * (grid.th + grid.gap), 0), grid.end)
    if goal = grid.goal
        return
    KeepInView(goal), ScrollTo(goal)               ; its frames move the hover with the tiles
}

HitTest(pt, &onX) {   ; the tile under content point pt ([x, y]; 0 = none) or 0; onX: on its close button
    onX := false
    if pt
        for i, t in tiles
            if pt[1] >= t.x && pt[1] < t.x + t.w && pt[2] >= t.y && pt[2] < t.y + grid.th
                return (onX := pt[1] >= t.x + t.w - CloseW(t) && pt[2] < t.y + grid.hdr, i)
    return 0
}

CursorAt() {   ; the mouse in the pane's client coordinates, [x, y]
    pt := Buffer(8), DllCall("GetCursorPos", "ptr", pt), DllCall("ScreenToClient", "ptr", g.Hwnd, "ptr", pt)
    return [NumGet(pt, 0, "int"), NumGet(pt, 4, "int")]
}
