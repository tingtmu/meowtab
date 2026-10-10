; Background removal for an animated GIF, frame by frame (cutout.ahk's jobs, one frame each). Functions only; needs
; cutout.ahk, gif.ahk and GDI+ started.

; Asynchronous, in place: done({changed, msg}) once every frame is done, or one couldn't be. The frames, at the GIF's own
; size (at most 512 px, as imported), go through cutout_run one after another on the worker thread: the poll starts the
; next job when one ends. A status other than 0 or 1 leaves the file as it was, with that frame's reason. Else the frames'
; squares are joined into one box, made square around its centre; every frame is cut to it and the GIF written again with
; its delays (GifWrite: alpha under 50 % goes, no soft edges). Every frame already transparent and that square the whole
; picture: "already clean", nothing written.
CutoutGifRun(file, done) {
    Critical                                          ; the panel's close waits: it shuts GDI+ down
    pics := []
    for bm in GifFrames(file, 512, &delays) {         ; each frame's pixels, its bitmap freed at once
        DllCall("gdiplus\GdipGetImageWidth", "ptr", bm, "uint*", &w := 0), DllCall("gdiplus\GdipGetImageHeight", "ptr", bm, "uint*", &h := 0)
        pics.Push(CutoutPixels(bm, w, h)), DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    }
    if !pics.Length
        return done({changed: false, msg: CutoutSay(21).msg})
    CutoutGifNext({file: file, pics: pics, delays: delays, k: 0, done: done})
}

CutoutGifNext(g) {   ; the next frame's job (g.k counts them), or the end once every frame is done
    if ++g.k > g.pics.Length
        return CutoutGifEnd(g)
    j := CutoutStart(g.file, g.pics[g.k])
    if !j.HasOwnProp("thread")
        return (done := g.done, done({changed: false, msg: j.msg}))
    CutoutWatch(j, CutoutGifFrame.Bind(g))
}

CutoutGifFrame(g, j) {   ; frame g.k's worker has ended: its outcome kept (its pixels were cleaned in place), on to the next
    r := CutoutEnd(j, ""), j.scratch := j.orig := "", j.st := r.status   ; only the pixels and the square are needed now
    if r.status != 0 && r.status != 1
        return (done := g.done, done({changed: false, msg: r.msg}))
    CutoutGifNext(g)
}

; Every frame cleaned: their squares joined, made square around the centre, and each frame copied into that box (CutoutBox,
; as CutoutSave does); written over the file with the delays it had. A frame cleaned (0) says "background removed".
CutoutGifEnd(g) {
    Critical                                          ; the panel's close waits: it shuts GDI+ down
    l := t := 0x7FFFFFFF, r := b := -0x7FFFFFFF, st := 1, done := g.done, w := g.pics[1].w, h := g.pics[1].h
    for j in g.pics
        l := Min(l, j.left), t := Min(t, j.top), r := Max(r, j.left + j.side), b := Max(b, j.top + j.side), st := Min(st, j.st)
    s := Max(r - l, b - t), l -= (s - r + l) // 2, t -= (s - b + t) // 2, bms := [], outs := [], ok := true
    if st = 1 && l = 0 && t = 0 && s = w && s = h     ; every frame already transparent (unchanged), the square the whole picture
        return done({changed: false, msg: CutoutSay(1, g.pics[1], "", true).msg})
    for j in g.pics {
        j.left := l, j.top := t, j.side := s, out := CutoutBox(j), j.px := ""
        if !(ok := out && !DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", s, "int", s, "int", s * 4, "int", 0x26200A, "ptr", out, "ptr*", &bm := 0))
            break
        outs.Push(out), bms.Push(bm)                  ; out holds bm's pixels: kept until it's disposed
    }
    ok := ok && GifWrite(bms, g.delays, g.file)
    for bm in bms
        DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    j := {w: w, h: h, left: l, top: t, side: s}
    done({changed: ok, msg: ok ? CutoutSay(st, j).msg : CutoutSay(23, j, "couldn't write " g.file).msg})
}
