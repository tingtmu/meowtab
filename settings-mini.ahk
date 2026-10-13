; The switcher in miniature for the Settings… panel (#Included by settings-panel.ahk; functions only): the LOOK cards, the
; peek scenes and the title sample, each drawing the switcher's pane in small as the picked look draws it (MiniPane).

; ----- The switcher in miniature (MeowTab only): the LOOK cards, the peek scenes and the title sample -----

; A LOOK card: its look's pane in miniature (MiniPane) on a well like the mood cards', the middle tile selected, then the look's
; name and what it's like. In the well's corner, clear of the pane, the picked look has a check and the other an empty ring; the
; look the switcher has now says "in use".
PaintLook(lk, name, sub, dc, w, h, st) {
    wh := Dpx(108), r := Dpx(12), hov := st & 0x10000, gr := Canvas(0, dc), well := RoundPath(0.5, 0.5, w - 1, wh - 1, r)
    br := FadeBrush(0, 0, w, wh, 90, hov ? [[LOOK.pillHi, 255, 0], [LOOK.pill, 150, 1]] : [[LOOK.wellTop, 140, 0], [LOOK.wellBot, 80, 1]])
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", well)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br), DllCall("gdiplus\GdipDeletePath", "ptr", well)
    x := Dpx(20), y := Dpx(16), pw := w - 2 * x, ph := Dpx(72), b := Dpx(10), tw := (pw - Dpx(52)) / 3   ; tiles 16 in, 10 apart
    path := RoundPath(x - b, y - b + Dpx(3), pw + 2 * b, ph + 2 * b, Dpx(8) + b)   ; under the pane a soft shadow, as DWM gives it
    EdgeFade(gr, path, LOOK.shadow, 0, 34, (pw - 2 * b) / (pw + 2 * b), (ph - 2 * b) / (ph + 2 * b), true)
    DllCall("gdiplus\GdipDeletePath", "ptr", path), tiles := []
    for k in [0, 1, 2]
        tiles.Push([x + Dpx(16) + k * (tw + Dpx(10)), y + Dpx(14), tw, ph - Dpx(28)])
    MiniPane(gr, lk, x, y, pw, ph, Dpx(8), tiles, Dpx(13), 2)
    Stroke(gr, 0.5, 0.5, w - 1, wh - 1, r, 1, Lip(210, hov ? LOOK.pillRim : LOOK.border, hov ? 230 : 120))
    FocusRing(gr, w, wh, r, st)
    cx := w - Dpx(13), cy := Dpx(13), s := A_ScreenDPI / 96
    if lk != pnl.look                                 ; an empty ring
        Disc(gr, cx, cy, 7.5 * s, Argb("FFFFFF", 190), Argb(LOOK.border, 255))
    else {                                            ; a white check on an accent disc
        Disc(gr, cx, cy, 9 * s, Argb("FFFFFF", 235)), Disc(gr, cx, cy, 7.5 * s, Argb(LOOK.accent, 255))
        DllCall("gdiplus\GdipCreatePen1", "uint", 0xFFFFFFFF, "float", 1.6 * s, "int", 2, "ptr*", &pen := 0)
        DllCall("gdiplus\GdipSetPenStartCap", "ptr", pen, "int", 2), DllCall("gdiplus\GdipSetPenEndCap", "ptr", pen, "int", 2)   ; round
        DllCall("gdiplus\GdipSetPenLineJoin", "ptr", pen, "int", 2)
        pts := Buffer(24), NumPut("float", cx - 3.3 * s, "float", cy + 0.1 * s, "float", cx - s, "float", cy + 2.4 * s
            , "float", cx + 3.4 * s, "float", cy - 2.2 * s, pts)
        DllCall("gdiplus\GdipDrawLines", "ptr", gr, "ptr", pen, "ptr", pts, "int", 3), DllCall("gdiplus\GdipDeletePen", "ptr", pen)
    }
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    PanelText(dc, name, Dpx(4), wh + Dpx(10), w - Dpx(8), Dpx(22), pnl.f["cap"], LOOK.text)
    if lk = SettingsGet("PANE_LOOK")
        PanelText(dc, "in use", Dpx(4), wh + Dpx(10), w - Dpx(8), Dpx(22), pnl.f["small"], LOOK.muted, 0x26)
    PanelText(dc, sub, Dpx(4), wh + Dpx(32), w - Dpx(8), Dpx(18), pnl.f["small"], LOOK.muted)
}

; Peek scene j (1 = a single window at PEEK_MIN, 2 = many windows at PEEK_MAX): the picture behind the top
; edge of a small pane, raised by the same rule as ShowPeek (share of the ArtSpan rows above the edge), its card's
; frame c.f. The pane is the switcher's in the picked look (MiniPane): its first tiles in a row, the first one selected.
PaintScene(j, dc, w, h, st) {
    c := pnl.cards[j = 1 ? 1 : 3], share := pnl.peek[j] / 100, lab := Dpx(24), sh := h - lab, r := Dpx(12)
    edge := sh - Dpx(42), d := Dpx(72), f := d / IMG_SIZE, px := Dpx(22)
    gr := Canvas(0, dc), well := RoundPath(0.5, 0.5, w - 1, sh - 1, r)   ; a soft well, like the cards'
    br := FadeBrush(0, 0, w, sh, 90, [[LOOK.wellTop, 140, 0], [LOOK.wellBot, 80, 1]])
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", well), DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    DllCall("gdiplus\GdipSetClipPath", "ptr", gr, "ptr", well, "int", 0)
    if c.big {
        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gr, "int", 7)
        top := edge - Round((c.span[1] + (c.span[2] - c.span[1]) * share) * f), one := c.big
        if c.delays.Length > 1                        ; the frame alone: scaled in the strip, it would pick up the one above's last rows
            DllCall("gdiplus\GdipCloneBitmapAreaI", "int", 0, "int", c.f * IMG_SIZE, "int", IMG_SIZE, "int", IMG_SIZE, "int", 0x26200A, "ptr", c.big, "ptr*", &one)
        DllCall("gdiplus\GdipDrawImageRectRectI", "ptr", gr, "ptr", one, "int", px + Dpx(12), "int", top, "int", d, "int", d
            , "int", 0, "int", 0, "int", IMG_SIZE, "int", IMG_SIZE, "int", 2, "ptr", 0, "ptr", 0, "ptr", 0)   ; UnitPixel
        if one != c.big
            DllCall("gdiplus\GdipDisposeImage", "ptr", one)
    }
    tiles := []                                       ; the pane's top-left corner; the well clips the rest (the tiles' feet too)
    for k in [0, 1, 2]
        tiles.Push([px + Dpx(12 + 64 * k), edge + Dpx(9), Dpx(54), Dpx(44)])
    MiniPane(gr, pnl.look, px, edge, w, sh, Dpx(8), tiles, Dpx(12), 1)
    DllCall("gdiplus\GdipResetClip", "ptr", gr)
    Stroke(gr, 0.5, 0.5, w - 1, sh - 1, r, 1, Lip(210, LOOK.border, 120))
    DllCall("gdiplus\GdipDeletePath", "ptr", well), DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    PanelText(dc, j = 1 ? "1 window" : (pnl.many + 4) "+ windows", 0, sh, w / 2, lab, pnl.f["small"], LOOK.muted)
    PanelText(dc, pnl.peek[j] "%", w / 2, sh, w / 2, lab, pnl.f["num"], LOOK.text, 0x26)
}

; Peek's sample: one tile header (app icon + title) in the chosen font, on the pane and selected as the switcher draws them in
; the picked look (MiniPane). The header keeps room around it for the selection, however large the font.
PaintTile(dc, w, h, st) {
    of := DllCall("SelectObject", "ptr", dc, "ptr", pnl.f["sample"], "ptr")
    title := "小算盤 — Calculator", sz := Buffer(8), DllCall("GetTextExtentPoint32W", "ptr", dc, "str", title, "int", StrLen(title), "ptr", sz)
    DllCall("SelectObject", "ptr", dc, "ptr", of)
    tw := NumGet(sz, 0, "int") + 2, th := NumGet(sz, 4, "int"), rh := Min(th + Dpx(10), h - Dpx(12)), y := (h - rh) / 2, x := Dpx(14), ic := Round(th * 0.7)
    tx := x + Dpx(18) + ic, rw := Min(tx + tw + Dpx(10) - x, w - 2 * x)   ; the tile is as wide as its header, at most the strip
    gr := Canvas(0, dc), p := MiniPane(gr, pnl.look, 0, 0, w, h, Dpx(8), [[x, y, rw, rh]], rh, 1)
    FillRound(gr, x + Dpx(10), y + (rh - ic) / 2, ic, ic, ic / 4, Argb(p.text, 110))   ; app icon placeholder
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    PanelText(dc, title, tx, y, x + rw - Dpx(10) - tx, rh, pnl.f["sample"], p.text)
}

; The switcher's palette for look lk ("velvet" or "windows11") in Windows' mode as the panel found it (pnl.dark). The switcher's
; own names are reached through their names here (SettingsGet): Classic includes this file too and has none of them, and a plain
; reference to one would keep Classic from loading.
MiniPal(lk) => SettingsGet(lk = "velvet" ? (pnl.dark ? "VELVET_DARK" : "VELVET_LIGHT") : pnl.dark ? "DARK_PAL" : "LIGHT_PAL")

; Look lk's pane in small, as the switcher draws it in Windows' mode and accent (pnl.dark, pnl.accent): its glass in x, y, w, h
; (corners r), opaque as where there's no acrylic, then its tiles ([x, y, w, h] each, a header hdr tall over a window), tile
; sel selected the look's way (none: the BACKGROUND card's glass). A tile no taller than its header is the title sample's: its
; icon and title are the caller's. Returns the palette.
MiniPane(gr, lk, x, y, w, h, r, tiles, hdr, sel) {
    p := MiniPal(lk), vel := lk = "velvet", glass := RoundPath(x, y, w, h, r)
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Argb(p.pane, 255), "ptr*", &br := 0)
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", glass), DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    ; Velvet: the warm tint (the switcher's brush) and a soft highlight down the top. Windows 11: DrawEdge's edge, a hairline
    ; (none in dark mode) and a highlight inside it.
    if vel {
        tint := SettingsGet("VelvetTint")
        DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", tint(p), "ptr", glass)
        lip := RoundPath(x, y, w, Dpx(16), r), br := FadeBrush(x, y, w, Dpx(16), 90, [[p.lip[1], p.lip[2], 0], [p.lip[1], 0, 0.5], [p.lip[1], 0, 1]])
        DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", lip)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", br), DllCall("gdiplus\GdipDeletePath", "ptr", lip)
    } else {
        o := p.hair[2] ? 1 : 0
        if o
            Ring(gr, x + 0.5, y + 0.5, w - 1, h - 1, r - 0.5, p.hair[1], p.hair[2])
        Stroke(gr, x + o + 0.5, y + o + 0.5, w - 2 * o - 1, h - 2 * o - 1, r - o - 0.5, 1, [[p.edge[1], p.edge[2], 0], [p.edge[1], p.edge[3], 1]], 90)
    }
    DllCall("gdiplus\GdipDeletePath", "ptr", glass)
    for i, t in tiles
        if i != sel
            MiniTile(gr, p, vel, i, hdr, t*)
    if sel
        MiniSelected(gr, p, vel, sel, hdr, tiles[sel]*)
    return p
}

; Tile i of a MiniPane at x, y, w, h: a header hdr tall (an icon, a title bar) over a window. Windows 11: the header's fill over
; the slot's, the window flush below it. Velvet: rounder, the frame with the header's frost fading into it, the window inside
; its mat.
MiniTile(gr, p, vel, i, hdr, x, y, w, h) {
    tile := RoundPath(x, y, w, h, Dpx(vel ? 6 : 4))
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Argb(p.slot*), "ptr*", &br := 0)
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", tile), DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    if vel
        br := FadeBrush(x, y, w, hdr, 90, [[p.head[1], p.head[2], 0], [p.head[1], 0, 1]])
    else
        DllCall("gdiplus\GdipCreateSolidFill", "uint", Argb(p.head*), "ptr*", &br := 0)
    DllCall("gdiplus\GdipSaveGraphics", "ptr", gr, "uint*", &state := 0)
    DllCall("gdiplus\GdipSetClipRect", "ptr", gr, "float", x, "float", y, "float", w, "float", hdr, "int", 1)   ; Intersect: the tile's top
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", tile), DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    DllCall("gdiplus\GdipRestoreGraphics", "ptr", gr, "uint", state), DllCall("gdiplus\GdipDeletePath", "ptr", tile)
    if h <= hdr
        return
    ic := Dpx(5), FillRound(gr, x + Dpx(5), y + (hdr - ic) / 2, ic, ic, Dpx(1), Argb(p.text, 100))   ; the icon and the title
    FillRound(gr, x + Dpx(13), y + hdr / 2 - Dpx(1), (w - Dpx(19)) * [0.75, 0.5, 0.62][Mod(i - 1, 3) + 1], Dpx(2), Dpx(1), Argb(p.text, 70))
    m := vel ? Dpx(3) : 0, win := [["2D2D2D", "3E3E3E"], ["FFFFFF", "E8E8E8"], ["F1F1F1", "DCDCDC"]][Mod(i - 1, 3) + 1]   ; the window and its bar
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Argb(win[1], 255), "ptr*", &br := 0)
    DllCall("gdiplus\GdipFillRectangle", "ptr", gr, "ptr", br, "float", x + m, "float", y + hdr, "float", w - 2 * m, "float", h - hdr - m)
    DllCall("gdiplus\GdipSetSolidFillColor", "ptr", br, "uint", Argb(win[2], 255))
    DllCall("gdiplus\GdipFillRectangle", "ptr", gr, "ptr", br, "float", x + m, "float", y + hdr, "float", w - 2 * m, "float", Dpx(3))
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

; The selected tile of a MiniPane. Windows 11: a gap, an inner stroke and the accent ring around it (SEL_GAP, SEL_INNER and
; SEL_RING in small). Velvet: lifted, a little larger around its centre over a soft shadow, with a thin outline of the accent
; mixed toward the header's colour.
MiniSelected(gr, p, vel, i, hdr, x, y, w, h) {
    if !vel {
        MiniTile(gr, p, false, i, hdr, x, y, w, h), r := Dpx(4), gp := Dpx(2), wi := Dpx(1), wr := Dpx(2)
        Ring(gr, x - gp - wi / 2, y - gp - wi / 2, w + 2 * gp + wi, h + 2 * gp + wi, r + gp + wi / 2, p.inner[1], p.inner[2], wi)
        o := gp + wi + wr / 2
        return Ring(gr, x - o, y - o, w + 2 * o, h + 2 * o, r + o, pnl.accent, 255, wr)
    }
    k := 1.04, r := Dpx(6), b := Dpx(6), x -= w * (k - 1) / 2, y -= h * (k - 1) / 2, w *= k, h *= k
    tile := RoundPath(x, y, w, h, r), shade := RoundPath(x - b, y - b * 2 / 3, w + 2 * b, h + 2 * b, r + b)   ; the shadow b / 3 lower
    DllCall("gdiplus\GdipSaveGraphics", "ptr", gr, "uint*", &state := 0)
    DllCall("gdiplus\GdipSetClipPath", "ptr", gr, "ptr", tile, "int", 4)   ; Exclude: only around the tile (its fills let it through)
    EdgeFade(gr, shade, p.shadow[1], 0, p.shadow[2], (w - 2 * b) / (w + 2 * b), (h - 2 * b) / (h + 2 * b), true)
    DllCall("gdiplus\GdipRestoreGraphics", "ptr", gr, "uint", state)
    DllCall("gdiplus\GdipDeletePath", "ptr", tile), DllCall("gdiplus\GdipDeletePath", "ptr", shade)
    MiniTile(gr, p, true, i, hdr * k, x, y, w, h), lw := A_ScreenDPI / 96
    Ring(gr, x - lw / 2, y - lw / 2, w + lw, h + lw, r + lw / 2, Mix(pnl.accent, p.head[1], p.line), 255, lw)
}
