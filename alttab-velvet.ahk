; The Velvet look for the switcher's pane (#Included by the main script, after alttab-native.ahk; the settings, constants
; and state globals live there): native at a glance, softer and warmer up close. alttab-native.ahk calls in here only where
; Velvet's shapes differ (PANE_LOOK = "velvet"); the layout, thumbnails and mouse stay its own. Functions only.

; ----- The surface: a base layer made once per pane size, copied at the start of each frame -----

; Render's, for Velvet: the base layer (VelvetBaseMake) in place of the clear glass and the edge, then the tiles in view,
; the selected one last (lifted over the rest), and the scroll bar.
VelvetRender(s) {
    global velvetBase
    if !velvetBase || velvetBase.w != s.w || velvetBase.h != s.h   ; a new pane size: its base, once
        VelvetBaseFree(), velvetBase := VelvetBaseMake(s.w, s.h)
    DllCall("BitBlt", "ptr", s.dc, "int", 0, "int", 0, "int", s.w, "int", s.h, "ptr", velvetBase.dc, "int", 0, "int", 0, "uint", 0xCC0020)   ; SRCCOPY
    DllCall("GdiFlush")                            ; in the bits before GDI+ draws on them
    VelvetClip(s.gr), frost := VelvetFrost()
    for i, t in tiles
        if i != idx && InView(t)
            VelvetTile(s.gr, i, t, frost)
    if idx && InView(tiles[idx])
        VelvetSelection(s.gr, tiles[idx], frost)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", frost), DllCall("gdiplus\GdipResetClip", "ptr", s.gr)
    if grid.end > 0 && barA > 0
        DrawBar(s.gr)
    DllCall("gdiplus\GdipFlush", "ptr", s.gr, "int", 1)   ; FlushIntentionSync: done before GDI reads the bits
}
VelvetClip(gr) => DllCall("gdiplus\GdipSetClipRectI", "ptr", gr, "int", 0, "int", Inset(), "int", grid.w, "int", grid.h - 2 * Inset(), "int", 0)   ; the view, as Render's

; The base layer for a w x h pane: the warm tint with the grain in it (VelvetGrain), then a soft highlight down the top half
; of the padding; with the caches that go with the pane's size (VelvetFaded, VelvetShade, VelvetImage's attributes).
VelvetBaseMake(w, h) {
    b := SurfaceMake(w, h), b.fades := Map(), b.shades := Map(), b.ia := 0, lip := grid.pad // 2
    DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", b.gr, "int", 3)   ; None: the texture fill is 15x faster
    DllCall("gdiplus\GdipSetCompositingMode", "ptr", b.gr, "int", 1)   ; SourceCopy: the first layer, copied (20x faster than
    Fill(b.gr, VelvetGrain(pal), w, h, false)                           ; drawn over the clear surface, the same pixels)
    DllCall("gdiplus\GdipSetCompositingMode", "ptr", b.gr, "int", 0)
    Fill(b.gr, FadeBrush(0, 0, w, lip, 90, [[pal.lip[1], pal.lip[2], 0], [pal.lip[1], 0, 1]]), w, lip)
    DllCall("gdiplus\GdipFlush", "ptr", b.gr, "int", 1)
    return b
}

VelvetBaseFree() {   ; with the surface (PaneFree), and at exit: the base layer and its caches
    global velvetBase
    if !velvetBase
        return
    for k, br in velvetBase.fades
        DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    for k, sh in velvetBase.shades
        DllCall("gdiplus\GdipDisposeImage", "ptr", sh.bm)
    if velvetBase.ia
        DllCall("gdiplus\GdipDisposeImageAttributes", "ptr", velvetBase.ia)
    SurfaceFree(velvetBase), velvetBase := 0
}

; The glass's first layer for palette p, as a 128 x 128 texture brush: faint black and white specks (alpha up to 2 grain,
; about that many levels either way) over the warm tint (without the backdrop, the tint over the opaque pane). The specks
; come from a fixed sequence, so they're the same every run; premultiplied, as the surface is. One per tint and grain, made
; once (WarmUp makes this mode's: about 20 ms) and deleted at exit, with the base layer.
VelvetGrain(p) {
    static made := Map()
    if made.Has(key := p.tint[1] p.tint[2] "/" p.grain (BACKDROP ? "" : "/" p.pane))
        return made[key]
    if !made.Count
        OnExit(Free)
    u := Integer("0x" (BACKDROP ? p.tint[1] : Mix(p.pane, p.tint[1], p.tint[2] / 255))), ua := BACKDROP ? p.tint[2] : 255
    ur := (u >> 16) * ua / 255, ug := (u >> 8 & 0xFF) * ua / 255, ub := (u & 0xFF) * ua / 255   ; the tint, premultiplied
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", 128, "int", 128, "int", 0, "int", 0xE200B, "ptr", 0, "ptr*", &bm := 0)   ; PARGB
    rc := Buffer(16), NumPut("int", 0, "int", 0, "int", 128, "int", 128, rc), bd := Buffer(32, 0)
    DllCall("gdiplus\GdipBitmapLockBits", "ptr", bm, "ptr", rc, "uint", 2, "int", 0xE200B, "ptr", bd)   ; ImageLockModeWrite
    stride := NumGet(bd, 8, "int"), bits := NumGet(bd, 16, "ptr"), n := 0
    Loop 128 {
        row := bits + (A_Index - 1) * stride
        Loop 128 {                                 ; hashed counter (murmur3's finalizer; no lattice, unlike a plain LCG):
            h := ++n * 0x9E3779B9 & 0xFFFFFFFF     ; a speck of alpha a, black or white (s), over the tint
            h := (h ^ h >> 16) * 0x85EBCA6B & 0xFFFFFFFF, h := (h ^ h >> 13) * 0xC2B2AE35 & 0xFFFFFFFF, v := Mod(h ^ h >> 16, 4 * p.grain + 2)
            a := v >> 1, s := v & 1 ? a : 0, k := 1 - a / 255
            NumPut("uint", Round(a + ua * k) << 24 | Round(s + ur * k) << 16 | Round(s + ug * k) << 8 | Round(s + ub * k), row, 4 * A_Index - 4)
        }
    }
    DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", bm, "ptr", bd)
    DllCall("gdiplus\GdipCreateTexture", "ptr", bm, "int", 0, "ptr*", &br := 0)   ; WrapModeTile; copies the image
    DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    return made[key] := br
    Free(*) {
        VelvetBaseFree()
        for a, b in made
            DllCall("gdiplus\GdipDeleteBrush", "ptr", b)
        return 0
    }
}

; The frost on every row's header at once: head's colour, its alpha at the top of each row to 0 at the header's bottom,
; repeating every row (th + gap apart). Made each frame (the rows scroll); the caller deletes it.
VelvetFrost() {
    rc := Buffer(16), NumPut("float", 0, "float", grid.pad - grid.off, "float", 1, "float", grid.th + grid.gap, rc)
    DllCall("gdiplus\GdipCreateLineBrushFromRect", "ptr", rc, "uint", 0, "uint", 0, "int", 1, "int", 0, "ptr*", &br := 0)   ; vertical, WrapModeTile
    n := BlendBufs([[pal.head[1], pal.head[2], 0], [pal.head[1], 0, grid.hdr / (grid.th + grid.gap)], [pal.head[1], 0, 1]], &cols, &pos)
    DllCall("gdiplus\GdipSetLinePresetBlend", "ptr", br, "ptr", cols, "ptr", pos, "int", n)
    return br
}

; ----- The cut-row fade: a row cut by the pane's top or bottom edge fades out toward it -----

; The fade at client row y: 1 in the view, falling to 0 at its top and bottom edges (Inset) across the padding, where only
; cut rows reach (whole ones sit at least pad inside the pane).
VelvetFade(y) {
    e := Inset()
    return Min(Max(Min(y - e, grid.h - e - y) / (grid.pad - e), 0), 1)
}
VelvetCut(y0, y1) => y0 < grid.pad || y1 > grid.h - grid.pad   ; rows y0 .. y1 reach into the fade

; A brush for rgb at alpha a faded as the rows are, across the whole view: 0 at its top and bottom edges, a from the padding
; in. Made once per pane size and kept with the base layer.
VelvetFaded(rgb, a) {
    if !velvetBase.fades.Has(key := rgb "/" a) {
        e := Inset(), v := grid.h - 2 * e, p := (grid.pad - e) / v
        velvetBase.fades[key] := FadeBrush(0, e, 1, v, 90, [[rgb, 0, 0], [rgb, a, p], [rgb, a, 1 - p], [rgb, 0, 1]])
    }
    return velvetBase.fades[key]
}

; A brush for rgb from alpha a at row y0 to 0 at row y1 (a header's frost or wash); in a cut row, times the fade, with stops
; where the fade bends and halfway between (the product of the two bends there). The caller deletes it.
VelvetRamp(rgb, a, y0, y1, cut) {
    ys := [y0], stops := []
    if cut
        for b in [Inset(), grid.pad, grid.h - grid.pad, grid.h - Inset()]   ; where the fade bends, in order
            if b > y0 && b < y1
                ys.Push(b)
    ys.Push(y1)
    for k, y in ys {
        if k > 1 && cut
            Stop((ys[k - 1] + y) / 2)
        Stop(y)
    }
    return FadeBrush(0, y0, 1, y1 - y0, 90, stops)
    Stop(y) => stops.Push([rgb, Round(a * (y1 - y) / (y1 - y0) * (cut ? VelvetFade(y) : 1)), (y - y0) / (y1 - y0)])
}

VelvetFill(gr, path, br, own := false) {   ; fill the path, then delete it (and the brush, if own)
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", path), DllCall("gdiplus\GdipDeletePath", "ptr", path)
    if own
        DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

VelvetDim(y1, y2) => Round(255 * VelvetFade((y1 + y2) / 2))   ; a thumbnail's opacity, rows y1 .. y2 showing: DWM dims it whole

; ----- Tiles -----

; Tile i: its frame (the mat around the thumbnail), the header's frost fading into it (VelvetFrost's; hovered: a wash over
; the header, and the close button), the icon and the title; faded where a cut row reaches into the padding.
VelvetTile(gr, i, t, frost) {
    S := grid.S, x := t.x, y := TileY(t), w := t.w, hdr := grid.hdr, r := Round(VELVET_R * S), hot := i = hover
    cut := VelvetCut(y, y + grid.th)
    VelvetFill(gr, RoundPath(x, y, w, grid.th, r), cut ? VelvetFaded(pal.slot*) : Brush(Argb(pal.slot*)))
    VelvetFill(gr, CornerPath(x, y, w, hdr, r, 3), cut ? VelvetRamp(pal.head[1], pal.head[2], y, y + hdr, true) : frost, cut)   ; top corners round
    if hot                                         ; a wash that fades out as the frost does: no edge under the header
        VelvetFill(gr, CornerPath(x, y, w, hdr, r, 3), VelvetRamp(pal.hot[1], pal.hot[2], y, y + hdr, cut), true)
    pair := icons.Get(wins[i], [0, 0]), ic := Round(ICON_PX * S), tx := x + Round(TITLE_X * S)
    if pair[1]
        VelvetImage(gr, pair[1], x + Round(ICON_X * S), y + (hdr - ic) // 2, ic, cut)
    if pair[2] && t.iconic {
        big := Round(BIG_ICON * S)
        VelvetImage(gr, pair[2], x + (w - big) // 2, y + hdr + (grid.slot - big) // 2, big, cut)
    }
    if (tw := x + w - (hot ? CloseW(t) : Round(12 * S)) - tx) > 0   ; GDI+ takes a zero width as "no limit"
        VelvetTitle(gr, t.title, tx, y, tw, hdr, cut ? VelvetFaded(pal.text, 255) : Brush(Argb(pal.text, 255)))
    if hot
        VelvetClose(gr, x + w - CloseW(t), y, CloseW(t), hdr)
}

; An icon, sz px square at x, y; in a cut row, at the fade of its middle (one alpha for all of it), through image attributes
; kept with the base layer.
VelvetImage(gr, bm, x, y, sz, cut) {
    if !cut || (m := VelvetFade(y + sz / 2)) >= 1
        return DllCall("gdiplus\GdipDrawImageRectI", "ptr", gr, "ptr", bm, "int", x, "int", y, "int", sz, "int", sz)
    if !velvetBase.ia
        DllCall("gdiplus\GdipCreateImageAttributes", "ptr*", &ia := 0), velvetBase.ia := ia
    cm := Buffer(100, 0)                           ; ColorMatrix: the identity, alpha times m
    for k, v in [1, 1, 1, m, 1]
        NumPut("float", v, cm, 24 * (k - 1))
    DllCall("gdiplus\GdipSetImageAttributesColorMatrix", "ptr", velvetBase.ia, "int", 0, "int", 1, "ptr", cm, "ptr", 0, "int", 0)
    DllCall("gdiplus\GdipDrawImageRectRectI", "ptr", gr, "ptr", bm, "int", x, "int", y, "int", sz, "int", sz
        , "int", 0, "int", 0, "int", sz, "int", sz, "int", 2, "ptr", velvetBase.ia, "ptr", 0, "ptr", 0)   ; UnitPixel
}

VelvetTitle(gr, s, x, y, w, h, br) {   ; Title's, with a brush (in a cut row, faded)
    rc := Buffer(16), NumPut("float", x, "float", y, "float", w, "float", h, rc)
    DllCall("gdiplus\GdipDrawString", "ptr", gr, "wstr", s, "int", -1, "ptr", titleFont, "ptr", rc, "ptr", titleFmt, "ptr", br)
}

; The close button in the hovered header's right end (x, y, w, h: the Windows 11 look's square one, where a click closes): a
; round disc, muted (the text colour at low alpha) with a grey X; red with a white X while the mouse is on it.
VelvetClose(gr, x, y, w, h) {
    S := grid.S, rd := VELVET_CLOSE * S / 2, d := CLOSE_X * S / 3, cx := x + w / 2, cy := y + h / 2, m := VelvetFade(cy)
    DllCall("gdiplus\GdipCreateSolidFill", "uint", hoverX ? Argb(CLOSE_RGB, Round(255 * m)) : Argb(pal.text, Round(pal.close[1] * m)), "ptr*", &br := 0)
    DllCall("gdiplus\GdipFillEllipse", "ptr", gr, "ptr", br, "float", cx - rd, "float", cy - rd, "float", 2 * rd, "float", 2 * rd)
    DllCall("gdiplus\GdipCreatePen1", "uint", hoverX ? Argb("FFFFFF", Round(255 * m)) : Argb(pal.text, Round(pal.close[2] * m))
        , "float", CLOSE_LINE * S, "int", 2, "ptr*", &pen := 0)   ; UnitPixel
    DllCall("gdiplus\GdipDrawLine", "ptr", gr, "ptr", pen, "float", cx - d, "float", cy - d, "float", cx + d, "float", cy + d)
    DllCall("gdiplus\GdipDrawLine", "ptr", gr, "ptr", pen, "float", cx - d, "float", cy + d, "float", cx + d, "float", cy - d)
    DllCall("gdiplus\GdipDeletePen", "ptr", pen), DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

; ----- The selection, lifted -----

; The selected tile: a soft shadow around it (VelvetShade), the tile VELVET_LIFT larger around its centre (VelvetBox lifts
; its thumbnail alike), and a thin outline of the accent mixed toward the header's colour.
VelvetSelection(gr, t, frost) {
    S := grid.S, k := 1 + VELVET_LIFT, cx := t.x + t.w / 2, cy := TileY(t) + grid.th / 2, r := Round(VELVET_R * S)
    w := t.w * k, h := grid.th * k, x := cx - w / 2, y := cy - h / 2, sh := VelvetShade(w, h), tile := RoundPath(x, y, w, h, r * k)
    DllCall("gdiplus\GdipSetClipPath", "ptr", gr, "ptr", tile, "int", 4)   ; CombineModeExclude: only around the tile (its fills let it through)
    DllCall("gdiplus\GdipDrawImageRectI", "ptr", gr, "ptr", sh.bm, "int", Round(x - sh.o), "int", Round(y - sh.o), "int", sh.w, "int", sh.h)   ; whole px: no resampling
    DllCall("gdiplus\GdipDeletePath", "ptr", tile)
    VelvetClip(gr)
    DllCall("gdiplus\GdipTranslateWorldTransform", "ptr", gr, "float", -cx, "float", -cy, "int", 1)   ; MatrixOrderAppend: to the
    DllCall("gdiplus\GdipScaleWorldTransform", "ptr", gr, "float", k, "float", k, "int", 1)           ; origin, larger, and back:
    DllCall("gdiplus\GdipTranslateWorldTransform", "ptr", gr, "float", cx, "float", cy, "int", 1)     ; around the tile's centre
    VelvetTile(gr, idx, t, frost)
    lw := VELVET_LINE * S
    Outline(gr, t.x, TileY(t), t.w, grid.th, r, lw / 2, lw, Argb(Mix(accentRgb, pal.head[1], pal.line), 255))
    DllCall("gdiplus\GdipResetWorldTransform", "ptr", gr)
}

; The selection's shadow for a lifted tile w x h: a soft ring, deeper below (lit from above), a path gradient with a bell
; falloff as the panel's cards have; baked once per tile size into a premultiplied bitmap (the surface's format: a quick
; copy) with the tile's top-left at o, o, kept with the base layer. {bm, o, w, h}
VelvetShade(w, h) {
    if velvetBase.shades.Has(key := Round(w) "x" Round(h))
        return velvetBase.shades[key]
    b := VELVET_SHADOW * grid.S, o := Ceil(b) + 1, bw := Ceil(w) + 2 * o, bh := Ceil(h) + 2 * o
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", bw, "int", bh, "int", 0, "int", 0xE200B, "ptr", 0, "ptr*", &bm := 0)   ; PARGB
    sg := Canvas(bm)
    path := RoundPath(o - b, o - b * 2 / 3, w + 2 * b, h + 2 * b, VELVET_R * grid.S * (1 + VELVET_LIFT) + b)   ; b / 3 lower
    EdgeFade(sg, path, pal.shadow[1], 0, pal.shadow[2], (w - 2 * b) / (w + 2 * b), (h - 2 * b) / (h + 2 * b), true)
    DllCall("gdiplus\GdipDeletePath", "ptr", path), DllCall("gdiplus\GdipDeleteGraphics", "ptr", sg)
    return velvetBase.shades[key] := {bm: bm, o: o, w: bw, h: bh}
}

; Tile t's thumbnail box (ThumbPlace fits the thumbnail in it): its slot x, y, w, h inside the mat at the sides and the
; bottom; while selected, VELVET_LIFT larger around the tile's centre, as VelvetSelection draws the tile.
VelvetBox(t, &x, &y, &w, &h) {
    m := Round(VELVET_MAT * grid.S), x += m, w -= 2 * m, h -= m
    if !idx || ObjPtr(t) != ObjPtr(tiles[idx])
        return
    k := 1 + VELVET_LIFT, cx := t.x + t.w / 2, cy := TileY(t) + grid.th / 2
    x := cx + (x - cx) * k, y := cy + (y - cy) * k, w *= k, h *= k
}

VelvetRelift(was) {   ; the selection moved with no scroll: tile was's thumbnail back to its size, the selected one's lifted
    for i in [was, idx]
        if i && tiles[i].on
            ThumbPlace(tiles[i], TileY(tiles[i]) + grid.hdr, Inset())
}
