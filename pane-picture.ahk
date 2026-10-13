; The pane's background picture, PANE_PICTURE (#Included by the main script, after alttab-native.ahk; the settings, constants
; and state globals live there): loaded once at startup, and from it a layer as big as the pane, which the Windows 11 look's
; Render and Velvet's base layer start from in place of the clear glass. Functions only.

; Startup, once GDI+ is up: the picture decoded, reduced (never enlarged) to cover the largest work area, at its strength
; (PANE_PIC_ALPHA) already, premultiplied, and kept as a WIC bitmap. One that can't be read gives none, reported as a bad
; value in settings.ini is. Without the acrylic (an opaque pane) there's no glass to lay it on: none. A load again replaces it.
PanePicLoad() {
    global panePic, picLayer, PANE_PICTURE
    static wic := 0
    if panePic
        ObjRelease(panePic.wb), SurfaceFree(picLayer), panePic := picLayer := 0
    if PANE_PICTURE = "" || !BACKDROP
        return
    if DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", UserImagesDir() "\" PANE_PICTURE, "ptr*", &src := 0) {
        SETTINGS_ISSUES.Push(why := "PANE_PICTURE = " PANE_PICTURE ": can't read it as a picture, using none")
        return (PANE_PICTURE := "", SettingsWarn([why]))
    }
    DllCall("gdiplus\GdipGetImageWidth", "ptr", src, "uint*", &sw := 0), DllCall("gdiplus\GdipGetImageHeight", "ptr", src, "uint*", &sh := 0)
    k := 0
    Loop MonitorGetCount()                         ; the scale that covers every monitor's work area
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b), k := Max(k, (r - l) / sw, (b - t) / sh)
    w := Max(Round(sw * Min(k, 1)), 1), h := Max(Round(sh * Min(k, 1)), 1), bits := Buffer(4 * w * h, 0), cm := Buffer(100, 0)
    for i, v in [1, 1, 1, PANE_PIC_ALPHA / 255, 1] ; ColorMatrix: the identity, alpha times the strength
        NumPut("float", v, cm, 24 * (i - 1))
    DllCall("gdiplus\GdipCreateImageAttributes", "ptr*", &ia := 0)
    DllCall("gdiplus\GdipSetImageAttributesColorMatrix", "ptr", ia, "int", 0, "int", 1, "ptr", cm, "ptr", 0, "int", 0)
    DllCall("gdiplus\GdipSetImageAttributesWrapMode", "ptr", ia, "int", 3, "uint", 0, "int", 0)   ; TileFlipXY: the edges sample the picture
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h, "int", 4 * w, "int", 0xE200B, "ptr", bits, "ptr*", &bm := 0)   ; PARGB on bits
    gr := Canvas(bm), DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gr, "int", 7)   ; HighQualityBicubic
    DllCall("gdiplus\GdipDrawImageRectRectI", "ptr", gr, "ptr", src, "int", 0, "int", 0, "int", w, "int", h
        , "int", 0, "int", 0, "int", sw, "int", sh, "int", 2, "ptr", ia, "ptr", 0, "ptr", 0)   ; UnitPixel
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr), DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    DllCall("gdiplus\GdipDisposeImageAttributes", "ptr", ia), DllCall("gdiplus\GdipDisposeImage", "ptr", src)
    if !wic
        wic := ComObject("{cacaf262-9370-4615-a13b-9f5539da4c0a}", "{ec5ec8a9-c395-4314-9c77-54d7a935ff70}")   ; IWICImagingFactory
    fmt := Buffer(16), DllCall("ole32\CLSIDFromString", "wstr", "{6fddc324-4e03-4bfe-b185-3d77768dc910}", "ptr", fmt)   ; 32bppPBGRA
    ComCall(20, wic, "uint", w, "uint", h, "ptr", fmt, "uint", 4 * w, "uint", bits.Size, "ptr", bits, "ptr*", &wb := 0)   ; CreateBitmapFromMemory: a copy, bits go
    panePic := {wic: wic, wb: wb, w: w, h: h}
}

; The picture's layer for a w x h pane (0 = no picture): the picture's middle in the pane's shape, cropped evenly on the overflowing
; sides (WIC's clipper), scaled to the pane (its Fant scaler) and copied straight in. Cropped first, so a strip of any shape scales
; only what shows. Made once per pane size (about 5 ms at the largest) and kept between opens; a new size frees the old one.
PaneLayer(w, h) {
    global picLayer
    if !panePic || picLayer && picLayer.w = w && picLayer.h = h
        return picLayer
    k := Max(w / panePic.w, h / panePic.h), cw := Min(Max(Round(w / k), 1), panePic.w), ch := Min(Max(Round(h / k), 1), panePic.h)
    l := SurfaceMake(w, h), rc := Buffer(16), NumPut("int", (panePic.w - cw) // 2, "int", (panePic.h - ch) // 2, "int", cw, "int", ch, rc)
    ComCall(12, panePic.wic, "ptr*", &cl := 0), ComCall(8, cl, "ptr", panePic.wb, "ptr", rc)   ; CreateBitmapClipper, Initialize: its middle
    ComCall(11, panePic.wic, "ptr*", &sc := 0)                         ; CreateBitmapScaler
    ComCall(8, sc, "ptr", cl, "uint", w, "uint", h, "int", 3)          ; Initialize: WICBitmapInterpolationModeFant
    ComCall(7, sc, "ptr", 0, "uint", 4 * w, "uint", 4 * w * h, "ptr", l.bits), ObjRelease(sc), ObjRelease(cl)   ; CopyPixels into the layer's bits
    SurfaceFree(picLayer)
    return picLayer := l
}
