; The peeking image for the switcher (#Included by its main script; the globals live there): the mood image in its own
; per-pixel-alpha window just below the pane, showing only the rows above the pane's top edge, so no part of
; it is ever behind the acrylic (which would blur it into view). Functions only.

; Image file -> sz x sz 32bpp HBITMAP (FitBitmap: bicubic, aspect kept). Transparent background = alpha kept.
; 0 = failed. span gets the [top, bottom] rows of the visible art, so a peek can ignore transparent padding.
ScaledBitmap(file, sz, &span := 0) {
    span := [0, sz]
    if !bm := FitBitmap(file, sz)
        return 0                    ; missing or unreadable
    span := ArtSpan(bm, sz)
    return ToHbm(bm)
}

; Image k with n rows above the pane's top edge, its left edge at screen x: a fresh open slides it up from
; nothing, else it glides from its current height (the image swaps at once if the mood changed). No image: hidden.
PeekTo(k, n, x, edge, fresh) {
    global peekK, peekFrom, peekGoal, peekT, peekX, peekEdge, peekRim
    if !imgs[k]
        return PeekHide()
    if k != peekK
        DllCall("SelectObject", "ptr", peekDC, "ptr", imgs[k], "ptr")
    DllCall("dwmapi\DwmGetWindowAttribute", "ptr", g.Hwnd, "uint", 37, "uint*", &rim := 0, "uint", 4)   ; VISIBLE_FRAME_BORDER_THICKNESS
    peekK := k, peekFrom := fresh ? 0 : peekN, peekGoal := n, peekT := A_TickCount, peekX := x, peekEdge := edge, peekRim := rim
    SetTimer PeekTick, ANIM_TICK
    PeekTick()                                     ; the first frame now
}

; One frame (ease-out cubic). The window is n + rim rows of the image, its bottom at edge + rim: the pane's DWM
; rim is translucent, so the paws go on under it (else a hairline of desktop shows between them and the pane).
PeekTick() {
    global peekN
    Critical
    p := PEEK_MS > 0 ? Min((A_TickCount - peekT) / PEEK_MS, 1) : 1
    peekN := peekFrom + (peekGoal - peekFrom) * (1 - (1 - p) ** 3)
    if p >= 1
        SetTimer PeekTick, 0
    hw := peek.Hwnd, h := Min(Round(peekN) + peekRim, IMG_SIZE)
    if Round(peekN) < 1
        return DllCall("ShowWindow", "ptr", hw, "int", 0)   ; SW_HIDE
    DllCall("UpdateLayeredWindow", "ptr", hw, "ptr", 0, "int64*", (peekEdge + peekRim - h) << 32 | (peekX & 0xFFFFFFFF)
        , "int64*", h << 32 | IMG_SIZE, "ptr", peekDC, "int64*", 0, "uint", 0
        , "uint*", 0x01FF0000, "uint", 2)          ; source rows 0 .. h-1; AC_SRC_OVER, alpha 255, AC_SRC_ALPHA; ULW_ALPHA
    if !DllCall("IsWindowVisible", "ptr", hw)      ; just below the pane: NOSIZE|NOMOVE|NOACTIVATE|SHOWWINDOW
        DllCall("SetWindowPos", "ptr", hw, "ptr", g.Hwnd, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x53)
}

PeekHide() {
    global peekN := 0
    SetTimer PeekTick, 0
    peek.Hide()
}
