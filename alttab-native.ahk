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
    if fresh
        pal := dark ? DARK_PAL : LIGHT_PAL, accentRgb := AccentRing(), DwmSet(g.Hwnd, 20, dark)   ; IMMERSIVE_DARK_MODE: dark acrylic
    IconsLoad()
    hover := 0, hoverX := false                    ; tiles moved: PaneHover finds the one under the mouse again
    s := SurfaceMake(grid.w, grid.h), Render(s)
    old := surf, surf := s, SurfaceFree(old)
    ThumbsShow()                                   ; before Show: no frame of empty slots
    g.Show("NA x" x " y" y " w" grid.w " h" grid.h)
    DllCall("SendMessageW", "ptr", g.Hwnd, "uint", 0x86, "ptr", 1, "ptr", 0)   ; WM_NCACTIVATE(TRUE), every show: live acrylic
    Present()
    if !fresh                                      ; e.g. a click on X: the tile that slid under the mouse
        mouseAt := CursorAt(), SetTimer(PaneHover, -1)
}

PaneFree() {   ; on hide: everything one open made
    global surf, icons, hover, hoverX, mouseAt, pressAt, clickAt, wheel, tracking
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

; Grid for `wins` in a w x h work area with `art` px of image above the pane: tiles (header + thumbnail slot)
; as wide as their window's shape (at least TILE_MIN_W), wrapped greedily into centred rows. Too tall for the room
; under the image: the thumbnails shrink step by step to TILE_MIN of their height, then only the rows that fit
; show (scrolling).
GridLayout(w, h, art) {
    global grid, tiles
    S := A_ScreenDPI / 96, pad := Round(PANE_PAD * S), gap := Round(TILE_GAP * S), margin := Round(PANE_MARGIN * S)
    hdr := Max(Round(HEADER_H * S), Ceil(titleLineH) + Round(24 * S))   ; the title's line + 12 px above and below
    maxW := Floor(PANE_MAX_W * w) - 2 * pad, minW := Min(Round(TILE_MIN_W * S), maxW), room := h - art - 2 * margin
    tiles := []
    for hwnd in wins {
        f := WindowFrame(hwnd, &iconic, &whole)
        tiles.Push({src: f, iconic: iconic, whole: whole, title: TitleOf(hwnd), aspect: Min(Max(f[3] / Max(f[4], 1), ASPECT_MIN), ASPECT_MAX)})
    }
    slot := Max(Round(TILE_H * h) - hdr, 1), least := Round(slot * TILE_MIN)
    Loop {
        rows := WrapRows(slot, minW, maxW, gap), tall := rows.Length * (hdr + slot + gap) - gap + 2 * pad
        if tall <= room || (next := Max(least, Round(slot * 0.9))) = slot   ; fits, or can't shrink any further
            break
        slot := next
    }
    vis := tall <= room ? rows.Length : Max(1, (room - 2 * pad + gap) // (hdr + slot + gap))
    wide := 0
    for row in rows
        wide := Max(wide, row[3])
    grid := {S: S, pad: pad, gap: gap, margin: margin, hdr: hdr, slot: slot, th: hdr + slot, r: Round(TILE_R * S)
        , closeW: Round(CLOSE_W * S), rows: rows, top: 1, vis: vis, w: wide + 2 * pad, h: vis * (hdr + slot + gap) - gap + 2 * pad}
    for r, row in rows {                           ; each row centred; y as if every row showed (TileY scrolls)
        x := pad + (wide - row[3]) // 2, y := pad + (r - 1) * (grid.th + gap)
        Loop row[2] - row[1] + 1
            t := tiles[row[1] + A_Index - 1], t.x := x, t.y := y, t.row := r, x += t.w + gap
    }
    if idx
        Reveal(idx)
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

TileY(t) => t.y - (grid.top - 1) * (grid.th + grid.gap)       ; client y, scrolled
Shown(t) => t.row >= grid.top && t.row < grid.top + grid.vis   ; in the rows the pane shows

Reveal(i) {   ; scroll so tile i's row shows; true = the grid moved
    r := tiles[i].row, top := Min(Max(grid.top, r - grid.vis + 1), r)
    if top = grid.top
        return false
    grid.top := top
    return true
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

SelectTile(i) {   ; the selection to tile i, its row scrolled into view
    global idx := i
    if Reveal(i)
        ThumbsShow()
    Render(surf), Present()
}

; ----- Drawing: one full redraw per change (~2 ms for 20 tiles, spike Q5); DWM puts the thumbnails over it -----

Render(s) {   ; the pane's pixels for the current state: its edge, tiles, hover, selection
    DllCall("gdiplus\GdipGraphicsClear", "ptr", s.gr, "uint", BACKDROP ? 0 : Argb(pal.pane, 255))   ; clear glass / opaque pane
    DrawEdge(s.gr, s.w, s.h)
    for i, t in tiles
        if Shown(t)
            DrawTile(s.gr, i, t)
    if idx && Shown(tiles[idx])
        DrawSelection(s.gr, tiles[idx])
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

; One DWM thumbnail per shown tile, fitted into its slot (upscaled if need be, as native), the source cropped to
; the visible frame. DWM draws them over the acrylic and our pixels, unrounded. Handles in `thumbs`.
ThumbsShow() {
    global thumbs
    ThumbsClear()
    for i, t in tiles {
        if !Shown(t) || DllCall("dwmapi\DwmRegisterThumbnail", "ptr", g.Hwnd, "ptr", wins[i], "ptr*", &id := 0)
            continue                               ; failed (HRESULT != 0): the slot stays empty
        thumbs.Push(id), f := t.src, sw := f[3], sh := f[4]
        if t.whole                                 ; minimized, or no usable frame: all of it, as DWM keeps it
            DllCall("dwmapi\DwmQueryThumbnailSourceSize", "ptr", id, "int64*", &sz := 0), sw := sz & 0xFFFFFFFF, sh := sz >> 32
        k := Min(t.w / Max(sw, 1), grid.slot / Max(sh, 1)), tw := Round(sw * k), th := Round(sh * k)
        x := t.x + (t.w - tw) // 2, y := TileY(t) + grid.hdr + (grid.slot - th) // 2   ; centred in the slot
        p := Buffer(48, 0)                         ; DWM_THUMBNAIL_PROPERTIES
        NumPut("uint", t.whole ? 0xD : 0xF, p, 0)  ; RECTDESTINATION | OPACITY | VISIBLE (| RECTSOURCE)
        NumPut("int", x, "int", y, "int", x + tw, "int", y + th, "int", f[1], "int", f[2], "int", f[1] + sw, "int", f[2] + sh, p, 4)
        NumPut("uchar", 255, p, 36), NumPut("int", 1, p, 40)   ; opaque, visible; not client-only
        DllCall("dwmapi\DwmUpdateThumbnailProperties", "ptr", id, "ptr", p)
    }
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
    global mouseAt, pressAt, clickAt, wheel, tracking
    if hwnd != g.Hwnd || !cycling
        return
    if msg = 0x20A                                 ; wheel: wParam's high word, 120 a notch
        return (wheel += wParam << 32 >> 48, SetTimer(PaneWheel, -1), 0)
    pt := [lParam << 48 >> 48, lParam << 32 >> 48, grid, grid.top]   ; client x, y (signed); the layout and scroll it was on
    if msg = 0x201 || msg = 0x203                  ; button down (a quick second press comes as a double-click)
        return (pressAt := pt, 0)
    if msg = 0x202
        return (clickAt := pt, SetTimer(PaneClick, -1), 0)
    if msg = 0x2A3                                 ; left: tracking ended
        pt := 0, tracking := false
    mouseAt := pt, SetTimer(PaneHover, -1)
    return 0
}

PaneHover() {   ; the tile under the mouse gets the lighter header and its close button
    global hover, hoverX, tracking
    Critical
    if !cycling || !surf
        return
    if mouseAt && !tracking {                      ; WM_MOUSELEAVE once it leaves (at once if it already has)
        tme := Buffer(24, 0), NumPut("uint", 24, "uint", 2, "ptr", g.Hwnd, tme)   ; TRACKMOUSEEVENT, TME_LEAVE
        tracking := DllCall("TrackMouseEvent", "ptr", tme)
    }
    i := HitTest(mouseAt, &onX)
    if i != hover || onX != hoverX
        hover := i, hoverX := onX, Render(surf), Present()
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
OnLayout(pt) => pt && pt[3] = grid && pt[4] = grid.top   ; noted on the layout and scroll on screen now

PaneWheel() {   ; a notch scrolls a row when the grid has more than it shows; the selection stays in view
    global wheel, idx, hover, hoverX
    Critical
    n := Integer(wheel / 120), wheel -= n * 120
    if !n || !cycling || !surf || grid.vis >= grid.rows.Length
        return
    top := Min(Max(grid.top - n, 1), grid.rows.Length - grid.vis + 1), r := tiles[idx].row
    if top = grid.top
        return
    grid.top := top
    if r < top || r >= top + grid.vis              ; scrolled away: the nearest tile in the closest row shown
        idx := Nearest(Min(Max(r, top), top + grid.vis - 1), tiles[idx].x + tiles[idx].w / 2)
    hover := HitTest(mouseAt, &onX), hoverX := onX
    ThumbsShow(), Render(surf), Present()
}

HitTest(pt, &onX) {   ; the shown tile under client point pt ([x, y]; 0 = none) or 0; onX: on its close button
    onX := false
    if pt
        for i, t in tiles
            if Shown(t) && pt[1] >= t.x && pt[1] < t.x + t.w && pt[2] >= (y := TileY(t)) && pt[2] < y + grid.th
                return (onX := pt[1] >= t.x + t.w - CloseW(t) && pt[2] < y + grid.hdr, i)
    return 0
}

CursorAt() {   ; the mouse in the pane's client coordinates, [x, y]
    pt := Buffer(8), DllCall("GetCursorPos", "ptr", pt), DllCall("ScreenToClient", "ptr", g.Hwnd, "ptr", pt)
    return [NumGet(pt, 0, "int"), NumGet(pt, 4, "int")]
}
