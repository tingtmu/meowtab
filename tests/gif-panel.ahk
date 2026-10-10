; #Included by meowtab.test.ahk where its settings panel checks run: these top-level lines run there, in order.
; GIFs in the settings panel (design.md 6-7): a card and its peek scene play the card's GIF, through the app's seam for
; Animation effects (ANIM_EFFECTS), and stop when the panel closes; Clean background cleans a GIF frame by frame, and a still
; picture as before. Uses Customs and PixelA (gif-files.ahk), WatchDraw (drawnEls).

; A 3-frame GIF on opaque white, side px: a light disc with a dark outline, side / 20 px further right in each frame; delays
; of 100, 300 and 200 ms. noisy: frame 2's background is a pattern of greys instead. png: frame 1 saved there too, a still.
DiscGif(file, side, noisy := false, png := "") {
    fr := [], u := side / 32
    DllCall("gdiplus\GdipCreateSolidFill", "uint", 0, "ptr*", &br := 0)
    Loop 3 {
        gr := Canvas(bm := NewBitmap(side, side)), fr.Push(bm), DllCall("gdiplus\GdipGraphicsClear", "ptr", gr, "uint", 0xFFFFFFFF)
        if noisy && A_Index = 2
            Loop (side // 4) ** 2
                x := Mod(A_Index - 1, side // 4) * 4, y := (A_Index - 1) // (side // 4) * 4
                , DllCall("gdiplus\GdipSetSolidFillColor", "ptr", br, "uint", 0xFF000000 | (0x80 + Mod(x * 37 + y * 91, 0x80)) * 0x10101)
                , DllCall("gdiplus\GdipFillRectangleI", "ptr", gr, "ptr", br, "int", x, "int", y, "int", 4, "int", 4)
        cx := 16 * u + (A_Index - 1) * side / 20
        Disc(gr, cx, 16 * u, 10 * u, 0xFF202020), Disc(gr, cx, 16 * u, 10 * u - side / 40, 0xFFF4C27A)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    }
    GifWrite(fr, [100, 300, 200], file), png != "" && SavePng(fr[1], png), DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    for bm in fr
        DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    return file
}
; A cleaned DiscGif: "<n> frames, square (or w x h), cropped (from 128 px), <delays> ms, corners clear (or their alphas), discs
; kept (or the alpha at the centre)".
Cleaned(file) {
    fr := GifFrames(file, 0, &dl), DllCall("gdiplus\GdipGetImageWidth", "ptr", fr[1], "uint*", &w := 0), DllCall("gdiplus\GdipGetImageHeight", "ptr", fr[1], "uint*", &h := 0)
    ms := "", corners := "", centre := ""
    for bm in fr {
        ms .= dl[A_Index] " ", a := PixelA(bm, 0, 0) PixelA(bm, w - 1, 0) PixelA(bm, 0, h - 1) PixelA(bm, w - 1, h - 1)
        corners .= a = "0000" ? "" : " " a, centre .= PixelA(bm, w // 2, h // 2) = 255 ? "" : " " PixelA(bm, w // 2, h // 2)
        DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    }
    return fr.Length " frames, " (w = h ? "square" : w " x " h) ", " (w < 128 ? "cropped" : "not cropped") ", " ms "ms, corners"
        . (corners = "" ? " clear" : corners) ", discs " (centre = "" ? "kept" : centre)
}
; For ms: "frame <f>, playing" (or "still") at once, then each frame card c moves to.
CardPlays(c, ms) {
    s := "frame " c.f (pnlPlay ? ", playing" : ", still"), seen := "", f := c.f, t0 := A_TickCount
    while A_TickCount - t0 < ms {
        Wait(5)
        if c.f != f
            seen .= " " (f := c.f)
    }
    return s (seen = "" ? "" : ", then" seen)
}
Painted(e) {   ; element e's painter run into a bitmap, as WM_DRAWITEM runs it (st 0): its pixels
    sdc := DllCall("GetDC", "ptr", 0, "ptr"), dc := DllCall("CreateCompatibleDC", "ptr", sdc, "ptr")
    bm := DllCall("CreateCompatibleBitmap", "ptr", sdc, "int", e.w, "int", e.h, "ptr"), ob := DllCall("SelectObject", "ptr", dc, "ptr", bm, "ptr")
    paint := e.paint, paint(dc, e.w, e.h, 0), px := Buffer(e.w * e.h * 4), DllCall("GetBitmapBits", "ptr", bm, "int", px.Size, "ptr", px)
    DllCall("SelectObject", "ptr", dc, "ptr", ob), DllCall("DeleteObject", "ptr", bm), DllCall("DeleteDC", "ptr", dc), DllCall("ReleaseDC", "ptr", 0, "ptr", sdc)
    return px
}
SameBytes(a, b) => a.Size = b.Size && DllCall("ntdll\RtlCompareMemory", "ptr", a, "ptr", b, "uptr", a.Size, "uptr") = a.Size
Cleaning(c) {   ; until card c's Clean has ended (10 s at most)
    t0 := A_TickCount
    while c.busy && A_TickCount - t0 < 10000
        Wait(20)
}

panelWas := {effects: ANIM_EFFECTS, prefix: IMG_PREFIX}, PANEL_ROOM := Dpx(3000), ANIM_EFFECTS := true   ; the whole page paints
SettingsOpen(), Wait(300), discs := DiscGif(DATA_DIR "\discs.gif", 128, false, DATA_DIR "\disc.png")
PanelImport(1, discs), few := pnl.cards[1], Wait(30), drawnEls := Map()   ; the import's own repaints done
OnMessage(0x2B, WatchDraw, -1), plays := CardPlays(few, 900), OnMessage(0x2B, WatchDraw, 0), drawn := ""
for k, c in pnl.cards
    drawn .= " card " k ": " drawnEls.Has(c.card.ctl.Hwnd) (c.scene ? ", its scene: " drawnEls.Has(c.scene.ctl.Hwnd) : "") ";"
Check("a GIF made pending on a card plays there from its first frame, each frame for its own delay, looping", plays, "frame 0, playing, then 1 2 0 1")
Check("its frame changes draw that card and the peek scene showing it again, and nothing else", drawn
    , " card 1: 1, its scene: 1; card 2: 0; card 3: 0, its scene: 0;")
ANIM_EFFECTS := false, PanelLoadCard(1), stillCard := CardPlays(few, 700)
card0 := Painted(few.card), scene0 := Painted(few.scene), few.f := 1, differ := (!SameBytes(card0, Painted(few.card))) " " (!SameBytes(scene0, Painted(few.scene))), few.f := 0
Check("with Animation effects off it shows its first frame, still", stillCard, "frame 0, still")
Check("the card and its scene draw the frame shown: frame 1 unlike frame 0", differ, "1 1")

; Clean background (with Animation effects still off, so no frame changes meanwhile).
PanelClean(1), busy := few.busy, Cleaning(few)
Check("Clean on a GIF on white: background removed, still a GIF, every frame clear in the corners with its disc kept, one cropped square, the same frames and delays"
    , busy " " pnl.note " | " Customs("few.pending.*") " | " Cleaned(PendingImage("few"))
    , "1 “cozy ♡”: background removed. | few.pending.gif | 3 frames, square, cropped, 100 300 200 ms, corners clear, discs kept")
PanelImport(1, DiscGif(DATA_DIR "\noisy.gif", 128, true)), before := FileRead(PendingImage("few"), "RAW"), PanelClean(1), Cleaning(few)
Check("one frame's background not plain: the GIF is left as is, with the reason", RegExReplace(pnl.note, "left as is: .+", "left as is: <reason>")
    . " | " SameBytes(before, FileRead(PendingImage("few"), "RAW")) " " Customs("few.pending.*"), "“cozy ♡”: left as is: <reason> | 1 few.pending.gif")
PanelImport(3, DATA_DIR "\disc.png"), PanelClean(3), Cleaning(pnl.cards[3])
Check("Clean on a still picture as before: a .pending.png", pnl.note " | " Customs("many.pending.*"), "“too many…”: background removed. | many.pending.png")
FileCopy(discs, DATA_DIR "\images\custom_some.gif", 1), IMG_PREFIX := "custom", PanelLoadCard(2), PanelClean(2), Cleaning(pnl.cards[2])
Check("Clean on a saved GIF cleans a .pending.gif copy, the saved one untouched", pnl.note " | " Customs("some*.gif") " | "
    . SameBytes(FileRead(discs, "RAW"), FileRead(DATA_DIR "\images\custom_some.gif", "RAW")), "“nice ✌”: background removed. | some.gif some.pending.gif | 1")
FileDelete(DATA_DIR "\images\custom_some.gif"), IMG_PREFIX := panelWas.prefix

ANIM_EFFECTS := true, PanelLoadCard(1), was := pnlPlay, PanelClose(), at := few.f, Wait(700)
Check("after Cancel no panel timer runs: the card's frame stays put", was " " pnlPlay " " (few.f = at), "1 0 1")
ANIM_EFFECTS := panelWas.effects, PANEL_ROOM := 0
