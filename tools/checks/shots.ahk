; shots.ahk: the many-windows-grid captures (4.1), light and dark. Privacy: only this script's own demo windows can end up in an
; image, over a stand-in wallpaper covering the monitor; a capture is refused if a window that isn't ours is above it (exit code 4).
; Every image logs a line "rects <file>: pane=x,y,w,h picture=x,y,w,h" (screen px: the pane's and the picture window's rects).
;   a  8 windows                                -> a-08-<theme>.png
;   b  9, 12 and 30 windows right after opening -> b-09-, b-12-, b-30-<theme>.png; then a close from 12 (spec "Closing a window
;      from 12"), logged as "close12 before=... after=... picture before=... after=... -> pane same|MOVED" (no image)
;   c  frames mid-scroll, SCROLL_MS raised to 4 s: one wheel notch, then Tab into a hidden row, caught at 400 / 900 / 1460 ms
;                                               -> c-wheel-400ms-<theme>.png ... c-keys-1460ms-<theme>.png
;   d  the wide scroll bar during a real mouse drag: press on the thumb's centre (BarThumb(), from the code's BarKnob()), 12 steps
;      down, captured with the button still down -> d-30-<theme>.png, and after the release -> d-30-released-<theme>.png
;      (nothing is done where there is no scroll bar, e.g. at HEAD)
;   m  a real mouse move / press / release on the pane, off the thumb (does the glass stay live?) -> m-0-open- ... m-3-released-<theme>.png
; The glass (the pane's left padding, from the capture's own pixels) is logged for m and d as "glass <file>: avg=r,g,b spread=n
; live|FLAT GREY", and for any image where it is flat. FLAT GREY = the pane drawn inactive: 211 light / 84 dark, as the first real press
; did at HEAD; the live code answers WM_MOUSEACTIVATE with MA_NOACTIVATE, so m and d should read "live". One process per theme.
; Run from the repo root:  powershell -ExecutionPolicy Bypass -File tools\checks\run.ps1 shots [-Theme light,dark] [-Scenes abcdm]
;                          powershell -ExecutionPolicy Bypass -File tools\checks\run.ps1 shots -Theme light -Scenes a
; (also [-Root <dir>] [-Out <dir>] [-Tag <name>] [-Validate], see run.ps1; default out: build\checks\<tag>). Keep hands off the mouse
; and keyboard while it runs (about 40 s per theme).
ShotsMain(A_Args[1], StrSplit(A_Args[2], ","), A_Args[3])
ExitApp skipped ? 4 : 0

ShotsMain(out, themes, scenes) {
    global OUT_DIR := out, theme
    DirCreate out
    Stage(30)
    for theme in themes {
        SetWallpaper(theme = "dark")
        if InStr(scenes, "a")
            Opened("a", 8)
        if InStr(scenes, "b") {
            for n in [9, 12, 30]
                Opened("b", n)
            Close12()
        }
        if InStr(scenes, "c")
            MidScroll(20)
        if InStr(scenes, "d")
            DragShot(30)
        if InStr(scenes, "m")
            MouseProbe(30)
    }
}

Png(name) => OUT_DIR "\" name "-" theme ".png"     ; theme: the loop's, a global

Opened(scene, n) {   ; a, b: n windows right after opening
    OpenPane(n)
    Shot(Png(scene "-" Format("{:02}", n)))
    ClosePane()
}

; b, then: closing a window from 12 through the switcher (CloseSelected on the 12th, not the selection): the pane must neither
; move nor change size, only the picture glides to its new height. The demo window is shown again for the later scenes.
Close12() {
    OpenPane(12)
    g.GetPos(&x, &y, &w, &h), WinGetPos(&px, &py, &pw, &ph, peek.Hwnd), before := [x, y, w, h], pic := [px, py, pw, ph]
    CloseSelected(12), Critical("Off"), Sleep(400)  ; it lays out 11 (still overflowing); the picture glides (PEEK_MS)
    g.GetPos(&x, &y, &w, &h), WinGetPos(&px, &py, &pw, &ph, peek.Hwnd), after := [x, y, w, h]
    Say("close12 before=" RectStr(before) " after=" RectStr(after) " picture before=" RectStr(pic) " after=" RectStr([px, py, pw, ph])
        . " -> pane " (RectStr(before) = RectStr(after) ? "same" : "MOVED"))
    ClosePane()
    demoWins[12].Show("NA"), Sleep(300)            ; back for scenes c, d and m
}
RectStr(a) => a[1] "," a[2] "," a[3] "," a[4]

; c: through the real code path, the scroll in slow motion. The wheel starts a one-row scroll; the keys do it with Tab into the
; first row that isn't fully visible. Three frames each. With ease-out cubic over 4 s and 2 full rows at 1080p / 150 %, the row
; peeking in at the bottom is about half cut at 380 ms, the top row at 1450 ms; 900 ms is in between.
MidScroll(n) {
    global SCROLL_MS
    has := IsSet(SCROLL_MS), old := has ? SCROLL_MS : 0
    if has
        SCROLL_MS := 4000
    else
        Say("c: no SCROLL_MS in this source (HEAD): it scrolls whole rows at once, so these frames show the end state, not mid-scroll")
    for how in ["wheel", "keys"] {
        OpenPane(n)
        if how = "wheel"
            Notch(1)
        else
            Loop RowsFit() * Cols() + 1 - idx      ; from the 2nd tile to the first of the row after the full ones
                Step(1)
        t0 := A_TickCount
        for ms in [400, 900, 1460] {
            Critical("Off"), Sleep(Max(t0 + ms - A_TickCount, 1))
            Shot(Png("c-" how "-" ms "ms"), false)
        }
        ClosePane()
    }
    if has
        SCROLL_MS := old
}
RowsFit() {   ; the full rows the pane shows (the grid's own measure; 2 on a 1080p screen if the names changed)
    try return (grid.h - 2 * grid.pad + grid.gap) // (grid.th + grid.gap)
    return 2
}
Cols() => IsSet(GRID_COLS) ? GRID_COLS : 3

DragShot(n) {   ; d: a real drag of the thumb: one capture while the button is still down, one after the release
    OpenPane(n)
    if RealDrag(() => Shot(Png("d-" Format("{:02}", n)), false, true))
        Shot(Png("d-" Format("{:02}", n) "-released"), false, true)
    else
        Say("d: no drag, so no capture")
    Park(), ClosePane()
}

MouseProbe(n) {   ; m: does the glass stay live under real mouse input? captures: just open, cursor moved in, button down, released
    global heldDown
    OpenPane(n)
    Shot(Png("m-0-open"), true, true)
    g.GetPos(&px, &py, &pw, &ph)
    MouseMove(px + pw - 30, py + ph // 2, 0), Sleep(500)     ; into the right padding, off the thumb (which sits at the top)
    MouseGetPos(, , &under)
    Shot(Png("m-1-moved"), false, true)
    if under = g.Hwnd {
        try {
            Click("Down"), heldDown := true, Sleep(300)
            Shot(Png("m-2-pressed"), false, true)
        } finally {
            Click("Up"), heldDown := false
        }
        Sleep(300)
        Shot(Png("m-3-released"), false, true)
    }
    fg := "none"
    try fg := WinGetClass("A") " (" WinGetProcessName("A") ")"
    Say("m: foreground window now: " fg)
    Park(), ClosePane()
}
