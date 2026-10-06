; Small GDI+ / GDI helpers shared by alttab-glass.ahk and settings-panel.ahk (functions only, no globals).
; Colours are "RRGGBB" strings, alphas 0-255. The caller has GDI+ started.

Argb(hex, a) => (a << 24) | Integer("0x" hex)
Bgr(hex) => (n := Integer("0x" hex), ((n & 0xFF) << 16) | (n & 0xFF00) | (n >> 16))   ; GDI COLORREF

Mix(a, b, t) {   ; "RRGGBB" a -> b by t (0-1)
    a := Integer("0x" a), b := Integer("0x" b), out := ""
    for s in [16, 8, 0]
        out .= Format("{:02X}", Round((a >> s & 0xFF) + ((b >> s & 0xFF) - (a >> s & 0xFF)) * t))
    return out
}

Lip(litA, rgb, a) => [["FFFFFF", litA, 0], ["FFFFFF", litA, 0.42], [rgb, a, 0.58], [rgb, a, 1]]   ; white bottom/left, rgb top/right

; Line brush across x, y, w, h at `angle`; stops: [[rgb, alpha, position 0-1], ...] (first 0, last 1).
FadeBrush(x, y, w, h, angle, stops) {
    rc := Buffer(16), NumPut("float", x - 1, "float", y - 1, "float", w + 2, "float", h + 2, rc)   ; 1px larger: no edge seam
    DllCall("gdiplus\GdipCreateLineBrushFromRectWithAngle", "ptr", rc, "uint", 0, "uint", 0, "float", angle
        , "int", 1, "int", 3, "ptr*", &br := 0)                    ; angle follows the rect's diagonal, WrapModeTileFlipXY
    n := BlendBufs(stops, &cols, &pos)
    DllCall("gdiplus\GdipSetLinePresetBlend", "ptr", br, "ptr", cols, "ptr", pos, "int", n)
    return br
}

; Elliptical radial gradient centred at cx, cy; stops as FadeBrush, position = distance from the centre.
RadialFill(gr, cx, cy, rx, ry, stops) {
    DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &path := 0)
    DllCall("gdiplus\GdipAddPathEllipse", "ptr", path, "float", cx - rx, "float", cy - ry, "float", 2 * rx, "float", 2 * ry)
    DllCall("gdiplus\GdipCreatePathGradientFromPath", "ptr", path, "ptr*", &br := 0)
    n := BlendBufs(stops, &cols, &pos, true)   ; path-gradient blends run from the outline (0) to the centre (1)
    DllCall("gdiplus\GdipSetPathGradientPresetBlend", "ptr", br, "ptr", cols, "ptr", pos, "int", n)
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br), DllCall("gdiplus\GdipDeletePath", "ptr", path)
}

; Path gradient from the outline (alpha aEdge) to a copy shrunk by fx, fy around the centre (aIn).
EdgeFade(gr, path, rgb, aEdge, aIn, fx, fy, bell := false) {
    DllCall("gdiplus\GdipCreatePathGradientFromPath", "ptr", path, "ptr*", &br := 0)
    DllCall("gdiplus\GdipSetPathGradientCenterColor", "ptr", br, "uint", Argb(rgb, aIn))
    DllCall("gdiplus\GdipSetPathGradientSurroundColorsWithCount", "ptr", br, "uint*", Argb(rgb, aEdge), "int*", 1)   ; last colour repeats
    DllCall("gdiplus\GdipSetPathGradientFocusScales", "ptr", br, "float", Max(fx, 0), "float", Max(fy, 0))
    if bell
        DllCall("gdiplus\GdipSetPathGradientSigmaBlend", "ptr", br, "float", 1, "float", 1)   ; soft, blur-like falloff
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

; Rounded outline drawn with a pen whose colour runs along `angle` (315 = bottom-left -> top-right).
Stroke(gr, x, y, w, h, r, width, stops, angle := 315) {
    path := RoundPath(x, y, w, h, r), br := FadeBrush(x, y, w, h, angle, stops)
    DllCall("gdiplus\GdipCreatePen2", "ptr", br, "float", width, "int", 2, "ptr*", &pen := 0)   ; UnitPixel
    DllCall("gdiplus\GdipDrawPath", "ptr", gr, "ptr", pen, "ptr", path)
    DllCall("gdiplus\GdipDeletePen", "ptr", pen), DllCall("gdiplus\GdipDeleteBrush", "ptr", br), DllCall("gdiplus\GdipDeletePath", "ptr", path)
}

; [[rgb, alpha, pos], ...] -> ARGB and float buffers for a preset blend; flip reverses positions.
BlendBufs(stops, &cols, &pos, flip := false) {
    n := stops.Length, cols := Buffer(4 * n), pos := Buffer(4 * n)
    for i, s in stops {
        o := 4 * (flip ? n - i : i - 1)
        NumPut("uint", Argb(s[1], s[2]), cols, o), NumPut("float", flip ? 1 - s[3] : s[3], pos, o)
    }
    return n
}

RoundPath(x, y, w, h, r) {   ; GDI+ rounded-rect path; caller deletes it
    DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &p := 0), d := 2 * r   ; FillModeAlternate
    for a in [180, 270, 0, 90]               ; corners clockwise from the top-left
        DllCall("gdiplus\GdipAddPathArc", "ptr", p, "float", a = 0 || a = 270 ? x + w - d : x
            , "float", a < 180 ? y + h - d : y, "float", d, "float", d, "float", a, "float", 90)
    DllCall("gdiplus\GdipClosePathFigure", "ptr", p)
    return p
}

Fill(gr, br, w, h, del := true) {   ; fill 0, 0, w, h (within the clip); deletes the brush unless del = false
    DllCall("gdiplus\GdipFillRectangleI", "ptr", gr, "ptr", br, "int", 0, "int", 0, "int", w, "int", h)
    if del
        DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

NewBitmap(w, h) => (DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h, "int", 0, "int", 0x26200A   ; 32bppARGB
    , "ptr", 0, "ptr*", &bm := 0), bm)

Canvas(bm, dc := 0) {   ; antialiased GDI+ graphics on bm (or on dc); caller deletes it
    if dc
        DllCall("gdiplus\GdipCreateFromHDC", "ptr", dc, "ptr*", &gr := 0)
    else
        DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", bm, "ptr*", &gr := 0)
    DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gr, "int", 4)     ; AntiAlias
    DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gr, "int", 4)   ; HighQuality: pixel i spans i..i+1
    return gr
}

ToHbm(bm) {   ; GDI+ bitmap -> premultiplied 32bpp HBITMAP; disposes bm
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "ptr", bm, "ptr*", &hbm := 0, "uint", 0)
    DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    return hbm
}

; Image file -> new sz x sz GDI+ bitmap via HighQualityBicubic (built-in "w24 h24" is nearest-neighbor and
; drops thin lines). Aspect kept: a non-square image is centred on transparent padding. 0 = missing / unreadable.
FitBitmap(file, sz) {
    if DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", file, "ptr*", &src := 0)
        return 0
    DllCall("gdiplus\GdipGetImageWidth", "ptr", src, "uint*", &w := 0), DllCall("gdiplus\GdipGetImageHeight", "ptr", src, "uint*", &h := 0)
    s := sz / Max(w, h, 1), dw := Max(1, Round(w * s)), dh := Max(1, Round(h * s))
    gr := Canvas(dst := NewBitmap(sz, sz))
    DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gr, "int", 7)   ; HighQualityBicubic
    DllCall("gdiplus\GdipDrawImageRectI", "ptr", gr, "ptr", src, "int", (sz - dw) // 2, "int", (sz - dh) // 2, "int", dw, "int", dh)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr), DllCall("gdiplus\GdipDisposeImage", "ptr", src)
    return dst
}

ArtSpan(bm, sz) {   ; [first, last + 1] row holding pixels with alpha > 24; startup only, stops at the art
    rc := Buffer(16), NumPut("int", 0, "int", 0, "int", sz, "int", sz, rc), bd := Buffer(32, 0)
    DllCall("gdiplus\GdipBitmapLockBits", "ptr", bm, "ptr", rc, "uint", 1, "int", 0x26200A, "ptr", bd)   ; ReadOnly, 32bppARGB
    stride := NumGet(bd, 8, "int"), bits := NumGet(bd, 16, "ptr"), top := 0, bot := sz
    Row(y) {
        Loop sz
            if NumGet(bits, y * stride + 4 * A_Index - 1, "uchar") > 24
                return true
        return false
    }
    while top < sz && !Row(top)
        top++
    while bot > top && !Row(bot - 1)
        bot--
    DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", bm, "ptr", bd)
    return top < bot ? [top, bot] : [0, sz]
}

SavePng(bm, file) {   ; GDI+ bitmap -> PNG file; true = written
    static clsid := 0
    if !clsid
        clsid := Buffer(16), DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", clsid)
    return !DllCall("gdiplus\GdipSaveImageToFile", "ptr", bm, "wstr", file, "ptr", clsid, "ptr", 0)
}

ExifTurn(bm) {   ; EXIF orientation -> GDI+ RotateFlipType that makes it upright (0 = none)
    if DllCall("gdiplus\GdipGetPropertyItemSize", "ptr", bm, "uint", 0x0112, "uint*", &n := 0) || n < 26   ; 24-byte item + SHORT
        return 0
    item := Buffer(n)
    if DllCall("gdiplus\GdipGetPropertyItem", "ptr", bm, "uint", 0x0112, "uint", n, "ptr", item)
        return 0
    o := NumGet(NumGet(item, 16, "ptr"), "ushort")       ; PropertyItem.value -> SHORT
    return o >= 1 && o <= 8 ? [0, 4, 2, 6, 5, 1, 7, 3][o] : 0
}
