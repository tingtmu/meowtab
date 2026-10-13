; The switcher's grid (#Included by the main script, after alttab-native.ahk; the settings, constants and state globals
; live there): the tiles' layout, scrolling, selection moves and the scroll bar. Functions only.

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

; One frame, every one comes through here: a drag's step (BarDrag), the offset (ease-out cubic), Velvet's light-up, the hover
; under the resting mouse, the scroll bar (BarStep), the thumbnails and the pixels, back to back. While the bar shows and the
; mouse isn't near it, each frame puts its fade off to BAR_SHOW_MS later. Stops itself once nothing moves any more.
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
    if glowing := glow                             ; Velvet's selection lighting up (VelvetGlow): this frame's step
        VelvetGlowStep()
    hover := HitTest(Content(mouseAt), &onX), hoverX := onX
    settled := BarStep() && grid.off = grid.goal && barGrab < 0 && !glow
    if grid.off != was || glowing                  ; thumbnails move only with the view or a light-up's lift (PaneShow places them after a re-layout)
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
    global idx
    if motion && i != idx                          ; Velvet's: it lights up in place there (VelvetGlow)
        VelvetGlow()
    was := idx, idx := i
    if PANE_LOOK = "velvet" && !motion             ; Velvet's lift moves to the new one now (a scroll's first frame doesn't move
        VelvetRelift(was)                          ; the thumbnails; the light-up's frames all do)
    if (to := Reveal(i)) != grid.goal
        return ScrollTo(to)                        ; its first frame draws the selection
    if motion                                      ; no scroll: the light-up's frames all the same, the first one now
        return (SetTimer(ScrollTick, ANIM_TICK), ScrollTick())
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
    was := idx, idx := Nearest(best, tiles[idx].x + tiles[idx].w / 2)
    if PANE_LOOK = "velvet"                        ; Velvet's lift moves to the new one now, before the scroll's first frame
        VelvetRelift(was)
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
