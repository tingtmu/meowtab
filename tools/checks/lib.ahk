; Usage: none, it is #Included by shots.ahk and timing.ahk (run them with tools\checks\run.ps1, from the repo root).
; tools\checks\lib.ahk: shared by shots.ahk and timing.ahk (the many-windows-grid checks 4.1 captures, 4.2 timing).
; Adapted from tools\readme-shots.ahk: demo windows, the stand-in wallpaper, the privacy guard (ForeignAbove), Capture;
; plus opening the pane on the demo windows and real mouse input. #Included by the wrapper that run.ps1 generates, after the
; root's meowtab.ahk, so the switcher's globals and functions are in scope. Nothing here writes into the source root.
; (Names are chosen not to collide with the switcher's: AutoHotkey names are case-insensitive and shared by variables and functions.)

global demoWins := [], wall := 0, MON_RECT := [0, 0, 0, 0], skipped := 0, heldDown := false
OnExit((*) => (heldDown && Click("Up"), 0))                    ; never leave the left mouse button down
OnError((e, *) => (Say("ERROR: " e.Message " (" e.What ") at " e.File ":" e.Line), ExitApp(3)))
SetTimer(() => ExitApp(2), -120000)                            ; a stuck run must not leave a stand-in wallpaper over the screen
Say(s) => FileAppend(s "`n", "*")

; --- the only windows that may ever show: neutral titles, fake contents (as readme-shots) ---
DEMO := [["Trip plan — 旅行計畫.md", 1500, 950, "1E1E1E", "3C3C3C", "shell32.dll", 71, "code"]
    , ["小算盤 Calculator", 640, 980, "F3F3F3", "0067C0", "shell32.dll", 24, "keys"]
    , ["Photos — sleepy cat.png", 1400, 900, "202020", "2B2B2B", "imageres.dll", 68, "cat"]
    , ["收件匣 Inbox", 1400, 900, "FFFFFF", "0F6CBD", "shell32.dll", 157, "lines"]
    , ["Terminal", 1200, 700, "0C0C0C", "1F1F1F", "imageres.dll", 312, "term"]]

DemoSet(n) {   ; n demo windows: the specs cycled, titles numbered after the first lap
    made := []
    Loop n {
        spec := DEMO[Mod(A_Index - 1, DEMO.Length) + 1], lap := (A_Index - 1) // DEMO.Length
        made.Push(DemoWindow(spec, spec[1] (lap ? " (" lap + 1 ")" : "")))
    }
    return made
}

DemoWindow(spec, title) {   ; an app-like window, shown without activation, with a system icon (WM_SETICON)
    w := spec[2], h := spec[3], night := InStr("1E1E1E 202020 0C0C0C", spec[4])
    win := Gui("-DPIScale", title), win.BackColor := spec[4], win.MarginX := 0, win.MarginY := 0
    win.AddText("x0 y0 w" w " h64 Background" spec[5])
    switch spec[8] {
    case "cat":                                    ; the shipped picture, as a photo viewer would show it
        win.AddPicture("x" (w - 560) // 2 " y" 120 " w560 h560 BackgroundTrans", SRC_ROOT "\images\chill_few.png")
    case "keys":                                   ; a calculator's display and keypad
        win.SetFont("s40 c202020", "Segoe UI"), win.AddText("x40 y110 w" w - 80 " Right BackgroundTrans", "42")
        Loop 20
            win.AddText(Format("x{} y{} w{} h{} BackgroundE9E9E9", 24 + Mod(A_Index - 1, 4) * 150, 260 + (A_Index - 1) // 4 * 140, 138, 128))
    default:
        win.SetFont("s14 c" (night ? (spec[8] = "term" ? "4CC2FF" : "9CDCFE") : "404040"), spec[8] = "lines" ? "Segoe UI" : "Consolas")
        text := Map("code", ["## Day 1 — 台北 Taipei", "- [x] 101 observatory", "- [ ] 夜市 night market", "", "## Day 2 — 九份 Jiufen", "- [ ] tea house", "- [ ] lanterns"]
            , "term", ["PS> git status", "On branch main", "nothing to commit, working tree clean", "PS> meow", "=^.^=", "PS> _"]
            , "lines", ["Re: Friday lunch?", "Weekly update — draft", "Your package is on its way", "相片已分享 Photos shared", "Meeting notes"])[spec[8]]
        for i, line in text
            win.AddText("x48 y" 70 + i * 52 " w" w - 96 " BackgroundTrans", line)
    }
    win.Show("NA w" w " h" h)
    hi := LoadPicture(spec[6], "Icon" spec[7] " w32 h32", &kind)
    if hi && kind = 1                              ; IMAGE_ICON
        DllCall("SendMessageW", "ptr", win.Hwnd, "uint", 0x80, "ptr", 1, "ptr", hi)   ; WM_SETICON, ICON_BIG
    return win
}

; The backdrop window over one monitor (not activated, not Alt+Tab-eligible). TOPMOST here, unlike readme-shots': the user's own
; always-on-top overlays (the taskbar, a timer such as Catime) would otherwise sit above it, inside the crop, and the guard
; would refuse every capture. Above them it covers them; the guard still refuses anything above the wallpaper.
Wallpaper(night, X, Y, W, H) {
    bm := NewBitmap(W, H), gr := Canvas(bm)
    Fill(gr, FadeBrush(0, 0, W, H, 60, night ? [["0B1530", 255, 0], ["1C3A8A", 255, 0.55], ["0A0F24", 255, 1]]
        : [["DCE6F2", 255, 0], ["A9C1E0", 255, 0.55], ["EEF2F7", 255, 1]]), W, H)
    RadialFill(gr, W * 0.66, H * 0.62, 560, 420, [["2F6FEB", night ? 220 : 150, 0], ["2F6FEB", 0, 1]])
    RadialFill(gr, W * 0.22, H * 0.30, 420, 300, [["F59E0B", night ? 90 : 120, 0], ["F59E0B", 0, 1]])
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    win := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000"), win.MarginX := 0, win.MarginY := 0   ; NOACTIVATE: a click can't raise it over the pane
    win.AddPicture("x0 y0 w" W " h" H, "HBITMAP:" ToHbm(bm))
    win.Show("NA x" X " y" Y " w" W " h" H)
    return win
}

; Visible windows of other AutoHotkey processes ("" = none): a stray dialog would sit on the screen and trip the guard.
StrayAhk() {
    me := ProcessExist(), found := ""
    for hwnd in WinGetList()
        try if WinGetPID(hwnd) != me && WinGetProcessName(hwnd) ~= "i)^AutoHotkey"
            found .= (found ? ", " : "") "[" WinGetTitle(hwnd) "] " WinGetClass(hwnd) " pid " WinGetPID(hwnd)
    return found
}

Stage(count) {   ; the monitor the pane opens on, the root's pictures, and `count` demo windows (painted)
    global demoWins, MON_RECT, imgs, spans
    if stray := StrayAhk() {
        Say("not starting, an AutoHotkey window is already on screen: " stray)
        ExitApp(5)
    }
    mi := Buffer(40, 0), NumPut("uint", 40, mi), DllCall("GetMonitorInfoW", "ptr", CurrentMonitor(), "ptr", mi)
    MON_RECT := [NumGet(mi, 4, "int"), NumGet(mi, 8, "int"), NumGet(mi, 12, "int"), NumGet(mi, 16, "int")]
    imgs := [], spans := []                        ; the include looked for the pictures next to the wrapper: load the root's own
    for mood in ["few", "some", "many"]
        imgs.Push(ScaledBitmap(SRC_ROOT "\" IMG_DIR "\" IMG_PREFIX "_" mood ".png", IMG_SIZE, &span)), spans.Push(span)
    demoWins := DemoSet(count), Sleep(2500)
}

SetWallpaper(night) {   ; the stand-in wallpaper over that monitor, light or dark (a new one replaces the old); the pane's look follows
    global wall, dark
    dark := night
    if wall
        wall.Destroy()
    wall := Wallpaper(night, MON_RECT[1], MON_RECT[2], MON_RECT[3] - MON_RECT[1], MON_RECT[4] - MON_RECT[2])
    for hwnd in [peek.Hwnd, g.Hwnd]                ; the new topmost wallpaper is above the (hidden) picture and pane: raise them,
        DllCall("SetWindowPos", "ptr", hwnd, "ptr", -1, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x13)   ; the pane last, so it is above the picture
    Sleep(500)
}

; --- the pane, as Alt+Tab leaves it: the first n demo windows listed (never the user's own), `sel` selected ---
ListDemo(n, sel := 2) {
    global wins, idx, cycling
    wins := [], idx := Min(sel, n), cycling := true
    Loop n
        wins.Push(demoWins[A_Index].Hwnd)
}

OpenPane(n, sel := 2) {   ; listed, shown (the picture slides up), thumbnails and acrylic settled
    Park(), Sleep(50)
    ListDemo(n, sel)
    ShowPane(true), Critical("Off")                ; ShowPane leaves the thread Critical: timers and messages wait
    Sleep(500)                                     ; (not longer: the scroll bar fades out BAR_SHOW_MS = 1 s after the open)
}

ClosePane() {
    Finish(false), Critical("Off")
    Sleep(150)
}

Park() => MouseMove(MON_RECT[1] + 40, MON_RECT[2] + 40, 0)   ; the cursor away from the pane: no hover look, nothing lit under it

; --- input ---
Notch(dir) {   ; one wheel notch (1 = down, -1 = up) posted to the pane, as the mouse driver does: delta in wParam's high word
    MouseGetPos(&mx, &my)
    DllCall("PostMessageW", "ptr", g.Hwnd, "uint", 0x20A, "ptr", ((-120 * dir) & 0xFFFF) << 16, "ptr", (my & 0xFFFF) << 16 | (mx & 0xFFFF))
}

; The scroll bar's thumb centre in SCREEN px, from the code's BarKnob() ([x, y, w, h] in client px; a press counts on the thumb
; anywhere across the right padding at its height). false = no bar here: a source without BarKnob, or all rows fit.
BarThumb(&x, &y) {
    x := y := 0
    if !IsSet(BarKnob) || !IsObject(grid) || !grid.HasProp("end") || grid.end <= 0
        return false
    knob := BarKnob, b := knob()
    g.GetPos(&px, &py)
    x := Round(px + b[1] + b[3] / 2), y := Round(py + b[2] + b[4] / 2)
    return true
}

; A real drag with the mouse: to the thumb, press on its centre, down half the pane's height in steps (and, with back, up again);
; held() runs while the button is still down; release. true = it was done.
RealDrag(held := 0, back := false) {
    global heldDown
    if !BarThumb(&x, &y)
        return Say("no scroll bar to drag in this source (no BarKnob, or all rows fit)")
    g.GetPos(, , , &ph)
    MouseMove(x, y, 0), Sleep(500)                 ; near the bar: it goes wide
    MouseGetPos(, , &under)
    if under != g.Hwnd
        return Say("drag skipped: the pane is not under the cursor at " x "," y)   ; never press on anything else
    Click("Down"), heldDown := true
    try {
        Loop 12
            MouseMove(x, y + A_Index * ph // 24, 0), Sleep(40)
        Sleep(200)                                 ; the last position gets its frame
        if held
            held()
        if back
            Loop 12
                MouseMove(x, y + (12 - A_Index) * ph // 24, 0), Sleep(40)
    } finally {
        Click("Up"), heldDown := false
    }
    Sleep(200)
    return true
}

; --- capture, with the privacy guard ---
; The pane and picture to `file`, unless a window that isn't ours is above the wallpaper in the crop. Logs the rects, and the
; glass (report, or whenever it is flat): the pane's left padding at mid-height, from the capture's own pixels.
Shot(file, settle := true, report := false) {
    global skipped
    if settle
        Sleep(100)
    DllCall("dwmapi\DwmFlush")
    g.GetPos(&px, &py, &pw, &ph)
    kx := ky := kw := kh := 0
    try WinGetPos(&kx, &ky, &kw, &kh, peek.Hwnd)   ; the picture's window (hidden: all 0)
    x0 := Max(px - 48, MON_RECT[1]), y0 := Max((kh ? Min(ky, py) : py) - 32, MON_RECT[2])   ; the pane, the picture and a margin, inside that monitor
    x1 := Min(px + pw + 48, MON_RECT[3]), y1 := Min(py + ph + 48, MON_RECT[4])
    if (foreign := ForeignAbove(wall.Hwnd, x0, y0, x1, y1)) != "" {
        Say("not captured, a window that isn't ours is above the stand-in wallpaper in the crop: " foreign)
        skipped += 1
        return false
    }
    pad := 0
    try pad := grid.pad
    stat := Capture(x0, y0, x1 - x0, y1 - y0, file     ; the left padding: no tile, selection ring or scroll bar reaches it
        , [px + Round(pad * 0.15) - x0, py + ph // 3 - y0, Max(Round(pad * 0.45), 4), ph // 3])
    SplitPath(file, &name)
    Say("rects " name ": pane=" px "," py "," pw "," ph " picture=" kx "," ky "," kw "," kh)   ; screen px: x,y,w,h, one line per image
    if report || InStr(stat, "FLAT")
        Say("glass " name ": " stat)
    return true
}

; The windows above `wallHwnd` in the Z-order that are visible, not cloaked and inside the crop, other than the pane and the
; picture: "class (process)", comma-separated ("" = none).
ForeignAbove(wallHwnd, x0, y0, x1, y1) {
    found := "", rc := Buffer(16), h := DllCall("GetTopWindow", "ptr", 0, "ptr")
    while h && h != wallHwnd {
        cloaked := 0, DllCall("dwmapi\DwmGetWindowAttribute", "ptr", h, "uint", 14, "uint*", &cloaked, "uint", 4)
        if h != g.Hwnd && h != peek.Hwnd && !cloaked && DllCall("IsWindowVisible", "ptr", h) && DllCall("GetWindowRect", "ptr", h, "ptr", rc)
            && NumGet(rc, 0, "int") < x1 && NumGet(rc, 8, "int") > x0 && NumGet(rc, 4, "int") < y1 && NumGet(rc, 12, "int") > y0
            try found .= (found ? ", " : "") WinGetClass(h) " (" WinGetProcessName(h) ")"
        h := DllCall("GetWindow", "ptr", h, "uint", 2, "ptr")   ; GW_HWNDNEXT
    }
    return found
}

; Screen rect -> PNG, DWM's composition included (CAPTUREBLT). glass: [x, y, w, h] inside the capture to measure (GlassOf);
; returns that measure ("" without glass).
Capture(x, y, w, h, file, glass := 0) {
    sdc := DllCall("GetDC", "ptr", 0, "ptr"), mdc := DllCall("CreateCompatibleDC", "ptr", sdc, "ptr")
    hbm := DllCall("CreateCompatibleBitmap", "ptr", sdc, "int", w, "int", h, "ptr"), ob := DllCall("SelectObject", "ptr", mdc, "ptr", hbm, "ptr")
    ok := DllCall("BitBlt", "ptr", mdc, "int", 0, "int", 0, "int", w, "int", h, "ptr", sdc, "int", x, "int", y, "uint", 0x40CC0020)
    stat := glass ? GlassOf(mdc, glass*) : ""
    DllCall("SelectObject", "ptr", mdc, "ptr", ob), DllCall("DeleteDC", "ptr", mdc), DllCall("ReleaseDC", "ptr", 0, "ptr", sdc)
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &bm := 0)
    saved := SavePng(bm, file)
    DllCall("gdiplus\GdipDisposeImage", "ptr", bm), DllCall("DeleteObject", "ptr", hbm)
    Say("capture " w "x" h " at " x "," y ": blt " ok ", saved " saved " -> " file)
    return stat
}

; The glass in a rect of a DC (the capture's, in its own coordinates): the average RGB and how far the sampled pixels spread
; (max - min over the channels). A pane drawn inactive is a flat neutral grey with no spread (211 light / 84 dark at HEAD);
; live acrylic shows the wallpaper through it. Returns "avg=r,g,b spread=n live" or "... FLAT GREY".
GlassOf(dc, x, y, w, h) {
    sum := [0, 0, 0], lo := [255, 255, 255], hi := [0, 0, 0], n := 0
    Loop 10 {
        yy := y + (A_Index - 1) * (h - 1) // 9
        Loop 4 {
            c := DllCall("GetPixel", "ptr", dc, "int", x + (A_Index - 1) * (w - 1) // 3, "int", yy, "uint")
            if c = 0xFFFFFFFF                      ; CLR_INVALID: outside the bitmap
                continue
            n += 1
            for k, v in [c & 0xFF, c >> 8 & 0xFF, c >> 16 & 0xFF]
                sum[k] += v, lo[k] := Min(lo[k], v), hi[k] := Max(hi[k], v)
        }
    }
    if !n
        return "no pixels measured"
    avg := [Round(sum[1] / n), Round(sum[2] / n), Round(sum[3] / n)]
    spread := Max(hi[1] - lo[1], hi[2] - lo[2], hi[3] - lo[3])
    return "avg=" avg[1] "," avg[2] "," avg[3] " spread=" spread (spread <= 2 && Max(avg*) - Min(avg*) <= 3 ? " FLAT GREY" : " live")
}
