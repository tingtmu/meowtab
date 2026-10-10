; #Included by meowtab.test.ahk where its GIF file checks run: these top-level lines run there, in order.
; GIF pictures (gif.ahk), made here with GifWrite: each frame an opaque square on a clear canvas, 6/32 of the side lower than
; in the frame before (three places, over and over); delays of 5, 50 and 1 hundredths of a second, then 10s.
MakeGif(file, n, side) {
    fr := [], dl := [], u := side / 32, DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xFF3060C0, "ptr*", &br := 0)
    Loop n {
        gr := Canvas(bm := NewBitmap(side, side)), fr.Push(bm), dl.Push(A_Index <= 3 ? [50, 500, 10][A_Index] : 100), y := 4 + 6 * Mod(A_Index - 1, 3)
        DllCall("gdiplus\GdipFillRectangleI", "ptr", gr, "ptr", br, "int", Round(8 * u), "int", Round(y * u), "int", Round(16 * u), "int", Round(12 * u))
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    }
    GifWrite(fr, dl, file), DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    for bm in fr
        DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    return file
}
GifSays(file) {   ; "<frames> x <width> px: <delays in ms>", the alpha at the corner / in frame 1's square of a 32 px GIF's frames
    fr := GifFrames(file, 0, &dl), DllCall("gdiplus\GdipGetImageWidth", "ptr", fr[1], "uint*", &w := 0), s := fr.Length " x " w " px:", a := ""
    for bm in fr
        s .= " " dl[A_Index], a .= Format(" {}/{}", PixelA(bm, 0, 0), PixelA(bm, 12, 5)), DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    return s (w = 32 ? "," a : "")
}
PixelA(bm, x, y) => (DllCall("gdiplus\GdipBitmapGetPixel", "ptr", bm, "int", x, "int", y, "uint*", &c := 0), c >> 24)
Customs(pat := "*") {   ; the user folder's custom_<pat> pictures
    s := ""
    Loop Files DATA_DIR "\images\custom_" pat
        s .= SubStr(A_LoopFileName, 8) " "
    return Trim(s)
}
three := MakeGif(DATA_DIR "\three.gif", 3, 32), strip := GifStrip(three, 32, &span), bmo := Buffer(32), DllCall("GetObject", "ptr", strip, "int", 32, "ptr", bmo)
Check("a 3-frame GIF written and read back: its frames, delays, a clear corner, each frame alone; its strip, and the art rows over all frames"
    , GifSays(three) "; " NumGet(bmo, 4, "int") " x " NumGet(bmo, 8, "int") ", rows " span[1] "-" span[2], "3 x 32 px: 50 500 100, 0/255 0/0 0/0; 32 x 96, rows 4-28")
DllCall("DeleteObject", "ptr", strip), g64 := MakeGif(DATA_DIR "\g64.gif", 3, 64), g600 := MakeGif(DATA_DIR "\g600.gif", 3, 600)
imp := ImportImage(g64, PendingImage("few")) "|" ImportImage(g600, PendingImage("some")) "|" ImportImage(MakeGif(DATA_DIR "\g101.gif", 101, 16), PendingImage("many"))
copied := FileRead(g64, "RAW"), pend := FileRead(DATA_DIR "\images\custom_few.pending.gif", "RAW")
Check("importing GIFs: 64 px copied byte for byte, 600 px back as 512 px with its frames and delays, 101 frames refused (no pending file)"
    , imp ", " (copied.Size = pend.Size && DllCall("ntdll\RtlCompareMemory", "ptr", copied, "ptr", pend, "uptr", pend.Size, "uptr") = pend.Size)
    . ", " GifSays(PendingImage("some")) ", " FileExist(DATA_DIR "\images\custom_many.pending.*"), "||too many frames (over 100), 1, 3 x 512 px: 50 500 100, ")
Check("a one-frame GIF becomes custom_many.pending.png", ImportImage(MakeGif(DATA_DIR "\g1.gif", 1, 16), PendingImage("many")) Customs("many.pending.*"), "many.pending.png")
PendingClear()
Check("PendingClear sweeps .pending.gif too", FileExist(DATA_DIR "\images\*.pending.*"), "")
FileCopy(src, DATA_DIR "\images\chill_many.png"), ImportImage(g64, PendingImage("few")), ImagesCommit("chill"), mixed := Customs()   ; the chill set: the user's (no app pictures here)
FileDelete(DATA_DIR "\images\chill_many.png"), ImportImage(src, PendingImage("few")), ImagesCommit("custom")
Check("a GIF among still pictures, saved; then a still picture replacing it, saved", mixed "; " Customs(), "few.gif many.png some.png; few.png many.png some.png")
FileCopy g64, DATA_DIR "\images\custom_few.gif"
Check("a .gif wins over a .png in the same folder", MoodImage("custom", "few"), DATA_DIR "\images\custom_few.gif")
for mood in Moods()
    FileCopy g64, DATA_DIR "\images\gifs_" mood ".gif"
Check("IMG_PREFIX=gifs with a set of GIFs only is accepted", SettingsCheck(["IMG_PREFIX", "prefix"], "gifs", "chill", &why) " [" why "]", "gifs []")
