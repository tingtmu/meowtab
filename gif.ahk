; Animated GIF pictures through GDI+ (writing needs GDI+ 1.1): a picture's frames read as one strip for the peek, or
; as bitmaps to work on, and frames written back as a GIF. Functions only; needs gdip-helpers.ahk and GDI+ started.
; Delays are in ms, one per frame: a GIF keeps hundredths of a second, and one under 2 counts as 10, as browsers do.

; Picture file -> premultiplied 32bpp HBITMAP of sz x (sz * frames): frame i (from 0) in rows i * sz to i * sz + sz - 1,
; each fitted as FitBitmap does (bicubic, aspect kept, centred on transparent padding). A still picture is a strip of
; one. 0 = missing or unreadable. span gets ArtSpan's [top, bottom] rows within a frame, over all frames together.
; gdip: the strip as a 32bpp ARGB GDI+ bitmap instead (the settings panel's; the caller disposes it).
GifStrip(file, sz, &span := 0, &delays := 0, gdip := false) {
    span := [0, sz]
    if !img := GifOpen(file, &n, &delays, &w, &h)
        return 0
    s := sz / Max(w, h, 1), dw := Max(1, Round(w * s)), dh := Max(1, Round(h * s))
    gr := Canvas(strip := NewBitmap(sz, sz * n))
    DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gr, "int", 7)   ; HighQualityBicubic
    Loop n {
        DllCall("gdiplus\GdipImageSelectActiveFrame", "ptr", img, "ptr", GifTime(), "uint", A_Index - 1)
        DllCall("gdiplus\GdipDrawImageRectI", "ptr", gr, "ptr", img, "int", (sz - dw) // 2, "int", (A_Index - 1) * sz + (sz - dh) // 2, "int", dw, "int", dh)
    }
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr), DllCall("gdiplus\GdipDisposeImage", "ptr", img)
    gr := Canvas(all := NewBitmap(sz, sz))             ; every frame over the others: one ArtSpan measures them all
    Loop n
        DllCall("gdiplus\GdipDrawImageRectRectI", "ptr", gr, "ptr", strip, "int", 0, "int", 0, "int", sz, "int", sz
            , "int", 0, "int", (A_Index - 1) * sz, "int", sz, "int", sz, "int", 2, "ptr", 0, "ptr", 0, "ptr", 0)   ; UnitPixel
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr), span := ArtSpan(all, sz), DllCall("gdiplus\GdipDisposeImage", "ptr", all)
    return gdip ? strip : ToHbm(strip)
}

; Picture file -> its frames as 32bpp ARGB GDI+ bitmaps (the caller disposes them): at its own size, or scaled with
; HighQualityBicubic so the longer side is at most side (0 = as is). [] = missing or unreadable.
GifFrames(file, side := 0, &delays := 0) {
    out := []
    if !img := GifOpen(file, &n, &delays, &w, &h)
        return out
    s := side ? Min(1, side / Max(w, h, 1)) : 1, dw := Max(1, Round(w * s)), dh := Max(1, Round(h * s))
    Loop n {
        DllCall("gdiplus\GdipImageSelectActiveFrame", "ptr", img, "ptr", GifTime(), "uint", A_Index - 1)
        gr := Canvas(f := NewBitmap(dw, dh))
        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gr, "int", s < 1 ? 7 : 5)   ; HighQualityBicubic; as is: NearestNeighbor, an exact copy
        DllCall("gdiplus\GdipDrawImageRectI", "ptr", gr, "ptr", img, "int", 0, "int", 0, "int", dw, "int", dh)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr), out.Push(f)
    }
    DllCall("gdiplus\GdipDisposeImage", "ptr", img)
    return out
}

; Frames (32bpp GDI+ bitmaps, left unchanged) and their delays in ms -> an animated GIF at file, looping forever. Each
; frame gets its own optimal 256-colour palette with a transparent entry; alpha under 50 % becomes transparent, with
; no dither grain. true = written; on a failure no file is left.
GifWrite(frames, delays, file) {
    static enc := GifGuid("{557CF402-1A04-11D3-9A73-0000F81EF32E}")   ; the GIF encoder
    if !first := GifIndexed(frames[1])
        return false
    hs := Buffer(4 * frames.Length, 0)                 ; 0x5100 frame delays (LONG hundredths), 0x5101 loop count (SHORT, 0 = forever)
    for d in delays
        NumPut("uint", Max(1, Round(d / 10)), hs, 4 * (A_Index - 1))
    ok := !GifProp(first, 0x5100, 4, hs) && !GifProp(first, 0x5101, 3, Buffer(2, 0))
        && !DllCall("gdiplus\GdipSaveImageToFile", "ptr", first, "wstr", file, "ptr", enc, "ptr", GifFlag(18))   ; MultiFrame
    Loop frames.Length - 1 {
        if !ok
            break
        ok := bm := GifIndexed(frames[A_Index + 1])
        ok := ok && !DllCall("gdiplus\GdipSaveAddImage", "ptr", first, "ptr", bm, "ptr", GifFlag(21))   ; FrameDimensionTime
        if bm
            DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    }
    ok := ok && !DllCall("gdiplus\GdipSaveAdd", "ptr", first, "ptr", GifFlag(20))   ; Flush
    DllCall("gdiplus\GdipDisposeImage", "ptr", first)
    try ok := ok && GifClearBetween(file)
    catch
        ok := false
    if !ok
        try FileDelete file
    return ok
}

; An open GDI+ image's frame count: an animated GIF's frames, else 1.
GifCount(img) => DllCall("gdiplus\GdipImageGetFrameCount", "ptr", img, "ptr", GifTime(), "uint*", &n := 0) || n < 1 ? 1 : n

; ----- Helpers -----

GifOpen(file, &n, &delays, &w, &h) {   ; file -> GDI+ image (0 = unreadable), its frames (the first 100 at most), delays and size
    n := 0, delays := [], w := h := 0
    if DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", file, "ptr*", &img := 0)
        return 0
    n := Min(GifCount(img), 100), size := 0, v := 0   ; a GIF put in by hand isn't imported: still bounded, as the import's limit
    DllCall("gdiplus\GdipGetImageWidth", "ptr", img, "uint*", &w), DllCall("gdiplus\GdipGetImageHeight", "ptr", img, "uint*", &h)
    if !DllCall("gdiplus\GdipGetPropertyItemSize", "ptr", img, "uint", 0x5100, "uint*", &size) && size >= 24 + 4 * n
        && !DllCall("gdiplus\GdipGetPropertyItem", "ptr", img, "uint", 0x5100, "uint", size, "ptr", item := Buffer(size))
        v := NumGet(item, 16, "ptr")                   ; PropertyItem.value, inside item: one LONG per frame (a still has none)
    Loop n
        delays.Push((d := v ? NumGet(v, 4 * (A_Index - 1), "uint") : 0) < 2 ? 100 : d * 10)
    return img
}

GifIndexed(bm) {   ; 32bpp bitmap -> a new 8bpp indexed copy with an optimal palette and a transparent entry; 0 = failed
    DllCall("gdiplus\GdipGetImageWidth", "ptr", bm, "uint*", &w := 0), DllCall("gdiplus\GdipGetImageHeight", "ptr", bm, "uint*", &h := 0)
    if DllCall("gdiplus\GdipCloneBitmapAreaI", "int", 0, "int", 0, "int", w, "int", h, "int", 0x26200A, "ptr", bm, "ptr*", &out := 0)
        return 0
    pal := Buffer(8 + 256 * 4, 0), NumPut("uint", 256, pal, 4)   ; ColorPalette.Count must be 256 before it's filled
    if DllCall("gdiplus\GdipInitializePalette", "ptr", pal, "int", 1, "int", 256, "int", 1, "ptr", out)   ; PaletteTypeOptimal, with transparency
        || DllCall("gdiplus\GdipBitmapConvertFormat", "ptr", out, "int", 0x30803, "int", 1, "int", 1, "ptr", pal, "float", 50.0)   ; 8bppIndexed,
        return (DllCall("gdiplus\GdipDisposeImage", "ptr", out), 0)   ; DitherTypeSolid (None is refused), PaletteTypeOptimal, alpha threshold 50 %
    return out
}

; GDI+ writes each frame with disposal 0, so a viewer leaves it under the next frame's transparent pixels and the art
; smears. Every Graphic Control Extension gets disposal 2 (restore to background): each frame shows alone. true = done.
GifClearBetween(file) {
    b := FileRead(file, "RAW"), f := NumGet(b, 10, "uchar")
    i := 13 + (f & 0x80 ? 3 << (f & 7) + 1 : 0)        ; past the header, the screen descriptor and the global colours
    while i < b.Size {
        switch NumGet(b, i, "uchar") {
        case 0x21:                                     ; an extension: its label, then sub-blocks
            if NumGet(b, i + 1, "uchar") = 0xF9
                NumPut("uchar", NumGet(b, i + 3, "uchar") & ~0x1C | 8, b, i + 3)   ; disposal, bits 2-4
            i += 2
        case 0x2C:                                     ; an image: its descriptor, local colours, LZW code size, then sub-blocks
            f := NumGet(b, i + 9, "uchar"), i += 11 + (f & 0x80 ? 3 << (f & 7) + 1 : 0)
        default:                                       ; the trailer
            break
        }
        while s := NumGet(b, i, "uchar")               ; sub-blocks, up to the empty one
            i += s + 1
        i++
    }
    FileOpen(file, "w").RawWrite(b)
    return true
}

GifProp(bm, id, type, val) {   ; set PropertyItem {id, length, type, value} on bm; 0 = ok
    item := Buffer(24, 0), NumPut("uint", id, "uint", val.Size, "ushort", type, item), NumPut("ptr", val.Ptr, item, 16)
    return DllCall("gdiplus\GdipSetPropertyItem", "ptr", bm, "ptr", item)
}

GifFlag(v) {   ; EncoderParameters holding one EncoderSaveFlag value
    static flag := GifGuid("{292266FC-AC40-47BF-8CFC-A85B89A655DE}")
    p := Buffer(40, 0), p.val := Buffer(4), NumPut("uint", v, p.val)
    NumPut("uint", 1, p), DllCall("RtlMoveMemory", "ptr", p.Ptr + 8, "ptr", flag, "uptr", 16)
    NumPut("uint", 1, "uint", 4, "ptr", p.val.Ptr, p, 24)   ; NumberOfValues, EncoderParameterValueTypeLong, Value
    return p
}

GifTime() {   ; FrameDimensionTime: an animated GIF's frames
    static dim := GifGuid("{6AEDBD6D-3FB5-418A-83A6-7F45229DC872}")
    return dim
}

GifGuid(s) => (g := Buffer(16), DllCall("ole32\CLSIDFromString", "wstr", s, "ptr", g), g)
