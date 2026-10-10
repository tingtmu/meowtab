; The peeking image for the switcher (#Included by its main script; the globals live there): the mood image in its own
; per-pixel-alpha window just below the pane, showing only the rows above the pane's top edge, so no part of
; it is ever behind the acrylic (which would blur it into view). Functions only.

; Image k with n rows above the pane's top edge, its left edge at screen x: a fresh open slides it up from
; nothing, else it glides from its current height (the image swaps at once if the mood changed). No image: hidden.
; A fresh open or a mood change shows its first frame; a GIF then plays (PeekFrame) while Windows' "Animation effects"
; is on (Animates, read then), in both looks. A still picture arms no timer.
PeekTo(k, n, x, edge, fresh) {
    global peekK, peekFrom, peekGoal, peekT, peekX, peekEdge, peekF, peekPlay
    if !imgs[k]                                    ; forgotten too: back on a GIF mood, it starts again from its first frame
        return (peekK := 0, PeekHide())
    if fresh || k != peekK {
        peekF := 0, play := delays[k].Length > 1 && Animates()
        if play || peekPlay                        ; armed for the first frame's delay, or the last mood's GIF stopped
            SetTimer PeekFrame, play ? -delays[k][1] : 0
        peekPlay := play
    }
    if k != peekK
        DllCall("SelectObject", "ptr", peekDC, "ptr", imgs[k], "ptr")
    peekK := k, peekFrom := fresh ? 0 : peekN, peekGoal := n, peekT := A_TickCount, peekX := x, peekEdge := edge
    SetTimer PeekTick, ANIM_TICK
    PeekTick()                                     ; the first frame now
}

; One frame (ease-out cubic; with Velvet's motion, ease-out back: it settles with a small bounce).
PeekTick() {
    global peekN
    Critical
    p := PEEK_MS > 0 ? Min((A_TickCount - peekT) / PEEK_MS, 1) : 1
    q := 1 - p, b := motion ? 1 : 0                ; back 1: past the goal by 1/27 of the way (at p = 2/3), then on it
    peekN := peekFrom + (peekGoal - peekFrom) * (1 - (1 + b) * q ** 3 + b * q ** 2)
    if p >= 1
        SetTimer PeekTick, 0
    PeekDraw()
}

; A playing GIF's next frame (after the last, the first again), at the height the image has now; then armed again
; for that frame's delay. PeekTo starts it, PeekHide stops it.
PeekFrame() {
    global peekF
    Critical
    peekF := Mod(peekF + 1, delays[peekK].Length)
    PeekDraw()
    SetTimer PeekFrame, -delays[peekK][peekF + 1]
}

; Frame peekF's top peekN rows (the strip's rows from peekF * IMG_SIZE), the window's bottom exactly on the pane's top
; edge. DWM's border is off (PaneInit), so the acrylic reaches the edge: nothing goes under it (it would blur into the glass).
PeekDraw() {
    hw := peek.Hwnd, h := Min(Round(peekN), IMG_SIZE)
    if h < 1
        return DllCall("ShowWindow", "ptr", hw, "int", 0)   ; SW_HIDE
    DllCall("UpdateLayeredWindow", "ptr", hw, "ptr", 0, "int64*", (peekEdge - h) << 32 | (peekX & 0xFFFFFFFF)
        , "int64*", h << 32 | IMG_SIZE, "ptr", peekDC, "int64*", (peekF * IMG_SIZE) << 32, "uint", 0
        , "uint*", 0x01FF0000, "uint", 2)          ; source x 0, y at the frame; AC_SRC_OVER, alpha 255, AC_SRC_ALPHA; ULW_ALPHA
    if !DllCall("IsWindowVisible", "ptr", hw)      ; just below the pane: NOSIZE|NOMOVE|NOACTIVATE|SHOWWINDOW
        DllCall("SetWindowPos", "ptr", hw, "ptr", g.Hwnd, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x53)
}

PeekHide() {
    global peekN := 0, peekPlay
    SetTimer PeekTick, 0
    if peekPlay                                    ; a GIF's playback
        SetTimer(PeekFrame, 0), peekPlay := false
    peek.Hide()
}
