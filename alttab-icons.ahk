; App icons for the switcher's tiles (#Included by the main script, after alttab-native.ahk; the globals live
; there): found as the taskbar finds them, drawn with their alpha. Functions only.

; Icons for the listed windows this open hasn't loaded yet: icons[hwnd] := [header bitmap, big bitmap (minimized
; windows only) or 0]. PaneFree disposes them.
IconsLoad() {
    for i, hwnd in wins {
        if icons.Has(hwnd)
            continue
        hi := WindowIcon(hwnd, &own), S := grid.S
        icons[hwnd] := [hi ? IconBitmap(hi, Round(ICON_PX * S)) : 0, hi && tiles[i].iconic ? IconBitmap(hi, Round(BIG_ICON * S)) : 0]
        if own
            DllCall("DestroyIcon", "ptr", hi)
    }
}

; hwnd's icon: WM_GETICON (big, small2, small; a hung app can't stall us: 20 ms), its window class's, else its
; program's (own := true: the caller destroys that one). 0 = none.
WindowIcon(hwnd, &own) {
    own := false
    for t in [1, 2, 0]                             ; ICON_BIG, ICON_SMALL2, ICON_SMALL
        if !DllCall("SendMessageTimeoutW", "ptr", hwnd, "uint", 0x7F, "ptr", t, "ptr", 0, "uint", 2, "uint", 20, "ptr*", &hi := 0)
            break                                  ; timed out (SMTO_ABORTIFHUNG): don't wait again
        else if hi
            return hi
    if hi := DllCall("GetClassLongPtrW", "ptr", hwnd, "int", -14, "ptr") || DllCall("GetClassLongPtrW", "ptr", hwnd, "int", -34, "ptr")
        return hi                                  ; GCLP_HICON, GCLP_HICONSM
    sfi := Buffer(696, 0)                          ; SHFILEINFOW
    if (exe := ProgramOf(hwnd)) != "" && DllCall("shell32\SHGetFileInfoW", "wstr", exe, "uint", 0, "ptr", sfi, "uint", sfi.Size, "uint", 0x100)
        return (own := true, NumGet(sfi, 0, "ptr")) ; SHGFI_ICON: the program's (large) icon
    return 0
}

; The window's program; for a UWP app's frame (ApplicationFrameHost.exe) that of its CoreWindow child. "" = unknown.
ProgramOf(hwnd) {
    c := DllCall("FindWindowExW", "ptr", hwnd, "ptr", 0, "str", "Windows.UI.Core.CoreWindow", "ptr", 0, "ptr")
    DllCall("GetWindowThreadProcessId", "ptr", c || hwnd, "uint*", &pid := 0)
    try return ProcessGetPath(pid)
    return ""
}

; Any HICON -> new sz x sz PARGB GDI+ bitmap with its alpha. DrawIconEx into a zeroed 32bpp DIB gives alpha icons
; premultiplied; legacy AND/XOR icons come out alpha 0 everywhere (on the glass: see-through), so their opacity
; comes from the AND mask (DI_MASK draws it, black = opaque). The caller disposes the bitmap.
IconBitmap(hi, sz) {
    bi := Buffer(40, 0), NumPut("uint", 40, "int", sz, "int", -sz, "ushort", 1, "ushort", 32, bi)
    hbm := DllCall("CreateDIBSection", "ptr", 0, "ptr", bi, "uint", 0, "ptr*", &bits := 0, "ptr", 0, "uint", 0, "ptr")
    dc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr"), ob := DllCall("SelectObject", "ptr", dc, "ptr", hbm, "ptr")
    DllCall("DrawIconEx", "ptr", dc, "int", 0, "int", 0, "ptr", hi, "int", sz, "int", sz, "uint", 0, "ptr", 0, "uint", 3)   ; DI_NORMAL
    DllCall("GdiFlush")
    legacy := true
    Loop sz * sz
        if NumGet(bits, 4 * A_Index - 1, "uchar") {   ; any alpha: a 32bpp icon, done
            legacy := false
            break
        }
    if legacy {
        mhbm := DllCall("CreateDIBSection", "ptr", 0, "ptr", bi, "uint", 0, "ptr*", &mbits := 0, "ptr", 0, "uint", 0, "ptr")
        DllCall("SelectObject", "ptr", dc, "ptr", mhbm, "ptr")
        DllCall("DrawIconEx", "ptr", dc, "int", 0, "int", 0, "ptr", hi, "int", sz, "int", sz, "uint", 0, "ptr", 0, "uint", 1)   ; DI_MASK
        DllCall("GdiFlush")
        Loop sz * sz {
            o := 4 * A_Index - 4
            if NumGet(mbits, o, "uint") & 0xFFFFFF     ; mask white: transparent (or XOR-inverted): clear it
                NumPut("uint", 0, bits, o)
            else                                       ; mask black: opaque; DI_NORMAL already put the colour
                NumPut("uchar", 255, bits, o + 3)
        }
        DllCall("SelectObject", "ptr", dc, "ptr", hbm, "ptr"), DllCall("DeleteObject", "ptr", mhbm)
    }
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", sz, "int", sz, "int", 0, "int", 0xE200B, "ptr", 0, "ptr*", &bm := 0)
    rc := Buffer(16, 0), NumPut("int", sz, "int", sz, rc, 8)
    bd := Buffer(32, 0), NumPut("uint", sz, "uint", sz, "int", 4 * sz, "int", 0xE200B, "ptr", bits, bd)   ; BitmapData on our bits
    DllCall("gdiplus\GdipBitmapLockBits", "ptr", bm, "ptr", rc, "uint", 6, "int", 0xE200B, "ptr", bd)   ; Write|UserInputBuf:
    DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", bm, "ptr", bd)                                      ; GDI+ copies them in
    DllCall("SelectObject", "ptr", dc, "ptr", ob), DllCall("DeleteDC", "ptr", dc), DllCall("DeleteObject", "ptr", hbm)
    return bm
}
