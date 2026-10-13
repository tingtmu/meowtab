; The switcher's drawing (#Included by the main script, after alttab-native.ahk; the settings, constants and state globals
; live there): Render, one full redraw of the pane (Velvet's in VelvetRender), and its helpers, which Velvet uses too: the
; edge, tiles, close button, selection, brushes and paths, the title font. Functions only.

; ----- Drawing: one full redraw per change (~2 ms for 20 tiles, spike Q5); DWM puts the thumbnails over it -----

Render(s) {   ; the pane's pixels for the current state: its edge, the tiles in view (cut just inside it), hover, selection, scroll bar
    if PANE_LOOK = "velvet"
        return VelvetRender(s)
    if pic := PaneLayer(s.w, s.h)                  ; the background picture's layer in place of the clear glass: one copy
        DllCall("BitBlt", "ptr", s.dc, "int", 0, "int", 0, "int", s.w, "int", s.h, "ptr", pic.dc, "int", 0, "int", 0, "uint", 0xCC0020)   ; SRCCOPY
        , DllCall("GdiFlush")                      ; in the bits before GDI+ draws on them
    else
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
; can't use it (a CFF-outline OpenType family, or one with no Regular style). CJK falls back by itself. Velvet first
; tries its medium weight, the family Windows lists as "<FONT_NAME> Medium" (Noto Sans TC has one, Segoe UI none).
; titleLineH: its line height in px.
TitleInit() {
    global titleFont, titleFmt, titleLineH
    px := FONT_SIZE * A_ScreenDPI / 72
    for face in (PANE_LOOK = "velvet" ? [FONT_NAME " Medium", FONT_NAME, "Segoe UI"] : [FONT_NAME, "Segoe UI"]) {
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
