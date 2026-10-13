; #Included by meowtab.test.ahk where its pane picture file checks run: these top-level lines run there, in order.
; The pane's background picture: picked, it waits as pane.pending.png, still and at most 2560 px; Save makes it pane.png.
; PANE_PICTURE names a file in the user's images folder: a path or a missing file gives none, and the line is reported.

; A picture file: "<width> x <height>", " PNG" if it is one, then its colour (AARRGGBB) at each [x, y] of at; "no picture" if none.
PicSays(file, at*) {
    if !FileExist(file) || DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", file, "ptr*", &bm := 0)
        return "no picture"
    DllCall("gdiplus\GdipGetImageWidth", "ptr", bm, "uint*", &w := 0), DllCall("gdiplus\GdipGetImageHeight", "ptr", bm, "uint*", &h := 0), px := ""
    for p in at
        DllCall("gdiplus\GdipBitmapGetPixel", "ptr", bm, "int", p[1], "int", p[2], "uint*", &c := 0), px .= Format(" {:08X}", c)
    DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    return w " x " h (NumGet(FileRead(file, "RAW m4"), "uint") = 0x474E5089 ? " PNG" : "") px   ; a PNG starts 89 "PNG"
}

bigJpg := DATA_DIR "\big.jpg", bm := NewBitmap(4000, 3000), panePng := DATA_DIR "\images\pane.png"
DllCall("gdiplus\GdipSaveImageToFile", "ptr", bm, "wstr", bigJpg, "ptr", GifGuid("{557CF401-1A04-11D3-9A73-0000F81EF32E}"), "ptr", 0)   ; the JPEG encoder
DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
Check("a 4000 x 3000 JPG for the pane's background becomes a 2560 x 1920 pane.pending.png", PaneImport(bigJpg) PicSays(PanePending()), "2560 x 1920 PNG")
paneGif := MakeGif(DATA_DIR "\pane.gif", 3, 64)   ; its square covers 32, 12 only in frame 1, and 32, 50 only in frame 3
Check("a 3-frame GIF becomes its first frame, as pane.pending.png (no .gif)"
    , PaneImport(paneGif) PicSays(PanePending(), [32, 12], [32, 50]) " " FileExist(DATA_DIR "\images\pane.pending.gif"), "64 x 64 PNG FF3060C0 00000000 ")
PendingClear(), FileAppend("not a picture", junk := DATA_DIR "\junk.png")
Check("PendingClear sweeps pane.pending.png; then a file that isn't a picture is refused with a reason, and nothing waits"
    , FileExist(PanePending()) "|" PaneImport(junk) "|" FileExist(PanePending()), "|can't read that file as a picture (PNG, JPG, BMP or GIF)|")
PaneImport(paneGif)
Check("Save makes the pick pane.png, and nothing waits", PaneCommit(false) PicSays(panePng) " " FileExist(PanePending()), "64 x 64 PNG ")
loads := ""
for v in ["images\pane.png", "gone.png", "pane.png"] {   ; each a reload from the built-in none
    IniWrite v, DATA_DIR "\settings.ini", "settings", "PANE_PICTURE"
    PANE_PICTURE := "", SettingsLoad(), loads .= "[" PANE_PICTURE "] " SETTINGS_ISSUES.Length (SETTINGS_ISSUES.Length ? ": " SETTINGS_ISSUES[1] : "") "; "
}
Check("PANE_PICTURE in settings.ini: a path or a missing file gives none and reports the line; the saved pane.png is used", loads
    , "[] 1: PANE_PICTURE = images\pane.png: not a plain file name, using none; [] 1: PANE_PICTURE = gone.png: no such file in "
    . DATA_DIR "\images, using none; [pane.png] 0; ")
FileCopy DATA_DIR "\settings.ini", DATA_DIR "\settings.keep"   ; Reset's file work, then settings.ini as it was
got := SettingsReset() "[" Ini("PANE_PICTURE") "] " (FileExist(panePng) != ""), FileMove(DATA_DIR "\settings.keep", DATA_DIR "\settings.ini", 1)
Check("Reset to defaults drops the PANE_PICTURE line and keeps pane.png; Save after Remove deletes it", got "; " PaneCommit(true) FileExist(panePng), "[] 1; ")
PANE_PICTURE := "", IniDelete(DATA_DIR "\settings.ini", "settings", "PANE_PICTURE")   ; the built-in again
Check("the pane picture's checks leave the app's settings.ini and images\ unchanged", AppFiles(), before)
