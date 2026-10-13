; The native Windows 11 Alt+Tab look for the switcher's main script (#Included by it; the settings, constants
; and state globals live there): theme and acrylic, the pane's surface, live thumbnails and the mouse. Its grid
; (layout, scrolling, selection moves, scroll bar) is in alttab-grid.ahk, its drawing in alttab-draw.ahk.
; Functions only, plus a guard against running it alone.

#Warn VarUnset, Off                                ; those globals don't exist when this file is opened by itself
                                                   ; (also quiets the settings-*.ahk files #Included after it)
if A_LineFile = A_ScriptFullPath {
    MsgBox "This file is #Included by the switcher's main script and can't run alone. Run that script instead.", "alttab-native", 0x10
    ExitApp
}
#Include %A_LineFile%\..\gdip-helpers.ahk   ; Argb, RoundPath, Canvas, FitBitmap, ArtSpan, ToHbm, ...

; ----- Theme and backdrop -----

ThemeDark() {   ; Windows mode (taskbar, Start), which the native switcher follows; true = dark
    try return !RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "SystemUsesLightTheme")
    return false
}

ThemeChanged(wParam, lParam, msg, hwnd) {   ; WM_SETTINGCHANGE "ImmersiveColorSet": mode or accent changed
    global dark
    if hwnd = A_ScriptHwnd && lParam && StrGet(lParam) = "ImmersiveColorSet"   ; every top-level window gets it: once
        dark := ThemeDark()                        ; the next open applies it
}

; Ring colour from the accent palette (8 x RGBA, read as hex): Dark1 in light mode, Light2 in dark mode, as
; WinUI's AccentFillColorDefault; else the palette's default blue.
AccentRing() {
    p := ""
    try p := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent", "AccentPalette")
    return StrLen(p) >= 64 ? SubStr(p, dark ? 9 : 33, 6) : pal.ring
}

; Once: the DWM state that gives a frameless popup the live acrylic without ever activating it. Each step is
; required (measured, spike\report.md): without NCRENDERING_POLICY a flat grey, without the extended frame
; opaque black. Without the system backdrop (before build 22621) Render paints an opaque pane instead.
PaneInit(h) {
    DwmSet(h, 2, 2)                                ; NCRENDERING_POLICY = ENABLED
    DwmSet(h, 33, 2)                               ; WINDOW_CORNER_PREFERENCE = ROUND (8 px at 96 dpi), with DWM's shadow
    DwmSet(h, 34, 0xFFFFFFFE)                      ; BORDER_COLOR = COLOR_NONE: no hard grey hairline; DrawEdge draws a soft one
    DllCall("dwmapi\DwmExtendFrameIntoClientArea", "ptr", h, "ptr", Buffer(16, 0xFF))   ; MARGINS -1: frame = client area
    if BACKDROP
        DwmSet(h, 38, 3)                           ; SYSTEMBACKDROP_TYPE = TRANSIENTWINDOW: the flyouts' acrylic
}
DwmSet(h, attr, v) => DllCall("dwmapi\DwmSetWindowAttribute", "ptr", h, "uint", attr, "int*", v, "uint", 4)

; Draw the laid-out grid and show it at screen x, y with its live thumbnails; fresh = a new open (light / dark,
; accent). The new surface replaces the old one whole, so an erase in between always blits a finished one.
PaneShow(x, y, fresh) {
    global surf, pal, accentRgb, hover, hoverX, mouseAt, motion
    global glow := 0                               ; a new layout: no light-up (Velvet's motion)
    if fresh {                                     ; and the scroll bar shows on opening, when rows overflow
        pal := PANE_LOOK = "velvet" ? (dark ? VELVET_DARK : VELVET_LIGHT) : dark ? DARK_PAL : LIGHT_PAL   ; the look's, in Windows' mode
        accentRgb := AccentRing(), DwmSet(g.Hwnd, 20, dark)   ; IMMERSIVE_DARK_MODE: dark acrylic
        motion := PANE_LOOK = "velvet" && Animates(), DwmSet(g.Hwnd, 3, motion)   ; Velvet's motion; TRANSITIONS_FORCEDISABLED: DWM's own not on top
        BarReset(grid.end > 0)
    }
    IconsLoad()
    pt := Buffer(8), DllCall("GetCursorPos", "ptr", pt), mx := NumGet(pt, 0, "int") - x, my := NumGet(pt, 4, "int") - y   ; client, at this
    mouseAt := mx >= 0 && mx < grid.w && my >= 0 && my < grid.h ? [mx, my] : 0   ; show's x, y (CursorAt would measure from where it was); 0 off the pane
    hover := HitTest(Content(mouseAt), &onX), hoverX := onX   ; tiles moved: the one under the resting mouse, from the first frame
    s := SurfaceMake(grid.w, grid.h), Render(s)
    old := surf, surf := s, SurfaceFree(old)
    ThumbsClear(), ThumbsShow()                    ; afresh for this layout; before Show: no frame of empty slots
    if fresh && motion                             ; Velvet's ease-in, from the first frame
        VelvetEaseIn()
    g.Show("NA x" x " y" y " w" grid.w " h" grid.h)
    DllCall("SendMessageW", "ptr", g.Hwnd, "uint", 0x86, "ptr", 1, "ptr", 0)   ; WM_NCACTIVATE(TRUE), every show: live acrylic
    Present()
    SetTimer(PaneHover, -1)                        ; leave tracking and the scroll bar's near state start; the hover stays
}

PaneFree() {   ; on hide: everything one open made; a scroll stops where it is, the scroll bar's fade and drag too, Velvet's motion
    global surf, icons, hover, hoverX, mouseAt, pressAt, clickAt, wheel, tracking, glow
    SetTimer(ScrollTick, 0), grid.goal := grid.off, BarReset(false)
    if motion                                      ; the ease-in, if still on its way
        VelvetEaseEnd()
    ThumbsClear()
    for hwnd, pair in icons
        for bm in pair
            if bm
                DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    old := surf, surf := 0, icons := Map(), SurfaceFree(old)
    hover := 0, hoverX := false, mouseAt := pressAt := clickAt := 0, wheel := 0, tracking := false, glow := 0
}

; ----- Surface: a pane-sized 32bpp DIB that GDI+ draws into as premultiplied ARGB (real alpha over the glass) -----

SurfaceMake(w, h) {   ; {w, h, dc, hbm, bits, old, bm, gr}; SurfaceFree frees it
    bi := Buffer(40, 0), NumPut("uint", 40, "int", w, "int", -h, "ushort", 1, "ushort", 32, bi)   ; top-down BITMAPINFOHEADER
    hbm := DllCall("CreateDIBSection", "ptr", 0, "ptr", bi, "uint", 0, "ptr*", &bits := 0, "ptr", 0, "uint", 0, "ptr")
    dc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr"), old := DllCall("SelectObject", "ptr", dc, "ptr", hbm, "ptr")
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h, "int", 4 * w, "int", 0xE200B, "ptr", bits, "ptr*", &bm := 0)   ; PARGB on the bits
    gr := Canvas(bm)
    DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", gr, "int", TEXT_HINT)   ; grayscale: glyph coverage goes into alpha
    return {w: w, h: h, dc: dc, hbm: hbm, bits: bits, old: old, bm: bm, gr: gr}
}

SurfaceFree(s) {
    if !s
        return
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", s.gr), DllCall("gdiplus\GdipDisposeImage", "ptr", s.bm)
    DllCall("SelectObject", "ptr", s.dc, "ptr", s.old), DllCall("DeleteDC", "ptr", s.dc), DllCall("DeleteObject", "ptr", s.hbm)
}

; WM_ERASEBKGND: copy the surface onto the pane. SRCCOPY keeps the alpha byte, and DWM composes the
; extended-frame client area as premultiplied ARGB over the acrylic. 1 = erased (no black flash).
PaneErase(wParam, lParam, msg, hwnd) {
    if hwnd != g.Hwnd || !(s := surf)
        return
    DllCall("BitBlt", "ptr", wParam, "int", 0, "int", 0, "int", s.w, "int", s.h, "ptr", s.dc, "int", 0, "int", 0, "uint", 0xCC0020)
    return 1
}
Present() => DllCall("RedrawWindow", "ptr", g.Hwnd, "ptr", 0, "ptr", 0, "uint", 0x105)   ; INVALIDATE|ERASE|UPDATENOW

; One off-screen header and title, so the first Alt+Tab doesn't pay GDI+'s cold start (glyph cache, ~10 ms).
WarmUp() {
    Critical
    s := SurfaceMake(240, 60)
    Paint(s.gr, CornerPath(0, 0, 240, 60, 12, 3), Argb("FFFFFF", 200))
    Title(s.gr, "Warm-up 暖身 ウォーム", 36, 0, 200, 60, "000000")
    SurfaceFree(s)
}

; ----- Live thumbnails -----

; One DWM thumbnail per tile in view, fitted into its slot (upscaled if need be, as native), the source cropped to
; the visible frame. Registered the first time its slot shows, then placed on each call (each frame): cut where the
; view cuts the tile, its source by the same share; hidden, not released, while out of view, and only one that just
; left is touched. DWM draws them over the acrylic and our pixels, unrounded. Handles in `thumbs` and t.thumb; a
; minimized window DWM kept no image of gets none (t.thumb -1: its source is under half its restored frame both ways;
; a kept one can be far bigger, e.g. last shown maximized or snapped), nor does a minimized one of a FLAT_MIN program
; (Chrome, Edge: DWM keeps only a flat fill of it), so their big icon shows.
ThumbsShow() {
    global thumbs
    e := Inset()
    for i, t in tiles {
        y := TileY(t) + grid.hdr                   ; the slot's top, client
        if y >= grid.h - e || y + grid.slot <= e {
            if t.on
                ThumbHide(t), t.on := false
            continue
        }
        if !t.thumb {                              ; first sight
            if t.iconic && FlatMin(ProgramOf(wins[i])) {
                t.thumb := -1                      ; its program's name on the list
                continue
            }
            if DllCall("dwmapi\DwmRegisterThumbnail", "ptr", g.Hwnd, "ptr", wins[i], "ptr*", &id := 0)
                continue                           ; failed (HRESULT != 0): the slot stays empty
            thumbs.Push(t.thumb := id), t.sw := t.src[3], t.sh := t.src[4]
            if t.whole                             ; minimized, or no usable frame: all of it, as DWM keeps it
                DllCall("dwmapi\DwmQueryThumbnailSourceSize", "ptr", id, "int64*", &sz := 0), t.sw := sz & 0xFFFFFFFF, t.sh := sz >> 32
            if t.iconic && t.sw * 2 < t.src[3] && t.sh * 2 < t.src[4]   ; DWM kept no image (created minimized: a small
                DllCall("dwmapi\DwmUnregisterThumbnail", "ptr", id), thumbs.Pop(), t.thumb := -1   ; fixed placeholder): the big icon instead
        }
        t.on := t.thumb != -1 && ThumbPlace(t, y, e)
    }
}

; Tile t's thumbnail fitted and centred in its slot (its top at client y), cut e px inside the pane's top and bottom
; as Render cuts our pixels, its source rows by the same share: floating point, rounded once. true = it shows.
ThumbPlace(t, y, e) {
    sx := t.whole ? 0 : t.src[1], sy := t.whole ? 0 : t.src[2]
    bx := t.x, bw := t.w, bh := grid.slot          ; the box it's fitted in: its slot
    if PANE_LOOK = "velvet"
        VelvetBox(t, &bx, &y, &bw, &bh)            ; inside the mat; lifted when selected
    k := Min(bw / Max(t.sw, 1), bh / Max(t.sh, 1)), w := t.sw * k, h := t.sh * k
    x := bx + (bw - w) / 2, y += (bh - h) / 2, y1 := Max(y, e), y2 := Min(y + h, grid.h - e)
    if y2 <= y1 {                                  ; only its letterbox is in view
        if t.on
            ThumbHide(t)
        return false
    }
    p := t.props := Buffer(48, 0)                  ; DWM_THUMBNAIL_PROPERTIES, kept with the tile (DWM can't be asked: the test reads it)
    NumPut("uint", 0xF, p, 0)                      ; RECTDESTINATION | RECTSOURCE | OPACITY | VISIBLE
    NumPut("int", Round(x), "int", Round(y1), "int", Round(x + w), "int", Round(y2)
        , "int", sx, "int", Round(sy + (y1 - y) / k), "int", sx + t.sw, "int", Round(sy + (y2 - y) / k), p, 4)
    NumPut("uchar", PANE_LOOK = "velvet" ? VelvetDim(y1, y2) : 255, p, 36), NumPut("int", 1, p, 40)   ; opaque (Velvet: as faded), visible; not client-only
    DllCall("dwmapi\DwmUpdateThumbnailProperties", "ptr", t.thumb, "ptr", p)
    return true
}

ThumbHide(t) {   ; fVisible FALSE: kept, ready to show again at once
    p := Buffer(48, 0), NumPut("uint", 0x8, p, 0)  ; VISIBLE only
    DllCall("dwmapi\DwmUpdateThumbnailProperties", "ptr", t.thumb, "ptr", p)
}

ThumbsClear() {
    global thumbs
    for id in thumbs
        DllCall("dwmapi\DwmUnregisterThumbnail", "ptr", id)
    thumbs := []
}

; ----- Mouse, only while open. A handler just notes the event and a timer acts on it: posted messages run
; their handlers even inside a Critical hotkey, timers wait. Other windows are left alone (return nothing):
; the Settings panel handles the same messages while it is open. -----

PaneMouse(wParam, lParam, msg, hwnd) {   ; WM_MOUSEMOVE, WM_LBUTTONDOWN / UP / DBLCLK, WM_MOUSELEAVE, WM_MOUSEWHEEL
    global mouseAt, pressAt, clickAt, wheel, tracking, barGrab
    if hwnd != g.Hwnd || !cycling
        return
    if msg = 0x20A                                 ; wheel: wParam's high word, 120 a notch
        return (wheel += wParam << 32 >> 48, SetTimer(PaneWheel, -1), 0)
    x := lParam << 48 >> 48, y := lParam << 32 >> 48   ; client x, y (signed)
    if (msg = 0x201 || msg = 0x203) && grid.end > 0 && x >= grid.w - grid.pad && (b := BarKnob(), y >= b[2] && y < b[2] + b[4])
        return (barGrab := y - b[2], pressAt := 0, SetTimer(ScrollTick, ANIM_TICK), 0)   ; on the bar's thumb (across the padding): a drag, no click
    if msg = 0x201 || msg = 0x203                  ; button down (a quick second press comes as a double-click)
        return (pressAt := [x, y + grid.off, grid], 0)   ; a press or release: in content coordinates, and the layout it was on
    if msg = 0x202
        return (clickAt := [x, y + grid.off, grid], SetTimer(PaneClick, -1), 0)
    if msg = 0x2A3                                 ; left: tracking ended
        tracking := false
    mouseAt := msg = 0x2A3 ? 0 : [x, y], SetTimer(PaneHover, -1)   ; client: the hover follows a scroll under it
    return 0
}

; WM_MOUSEACTIVATE: MA_NOACTIVATE. NOACTIVATE keeps a press from bringing the pane to the foreground, but the press still
; made it its thread's active window, drawn inactive since that thread isn't the foreground one: flat grey glass.
PaneNoActivate(wParam, lParam, msg, hwnd) => hwnd = g.Hwnd ? 3 : ""

PaneHover() {   ; the tile under the mouse gets the lighter header and its close button
    global hover, hoverX, tracking
    Critical
    if !cycling || !surf
        return
    if mouseAt && !tracking {                      ; WM_MOUSELEAVE once it leaves (at once if it already has)
        tme := Buffer(24, 0), NumPut("uint", 24, "uint", 2, "ptr", g.Hwnd, tme)   ; TRACKMOUSEEVENT, TME_LEAVE
        tracking := DllCall("TrackMouseEvent", "ptr", tme)
    }
    i := HitTest(Content(mouseAt), &onX)
    if i != hover || onX != hoverX
        hover := i, hoverX := onX, Render(surf), Present()
    if BarNear() != barNearSeen                        ; the mouse came near the scroll bar or left it: it eases (only on the
        SetTimer(ScrollTick, ANIM_TICK)            ; change: setting the timer again restarts its countdown)
}

; On a tile: switch to it; on its close button: close that window, the pane stays. Only a press and release
; on the same tile and part, made on the layout still showing, count: a click noted during a close's wait
; would land on whatever tile slid under it.
PaneClick() {
    global idx, pressAt, clickAt
    down := pressAt, up := clickAt, pressAt := clickAt := 0
    if !cycling || !surf || !OnLayout(down) || !OnLayout(up) || !(i := HitTest(up, &onX)) || HitTest(down, &downX) != i || downX != onX
        return
    if onX
        return CloseSelected(i)
    idx := i
    Finish(true)
}
OnLayout(pt) => pt && pt[3] = grid                ; noted on the layout on screen now (in content coordinates: any scroll)

; A notch scrolls a row, notches adding up on the goal (0 .. end). The selection stays whole in view, judged at the
; goal (KeepInView).
PaneWheel() {
    global wheel
    Critical
    n := Integer(wheel / 120), wheel -= n * 120
    if !n || !cycling || !surf
        return
    goal := Min(Max(grid.goal - n * (grid.th + grid.gap), 0), grid.end)
    if goal = grid.goal
        return
    KeepInView(goal), ScrollTo(goal)               ; its frames move the hover with the tiles
}

HitTest(pt, &onX) {   ; the tile under content point pt ([x, y]; 0 = none) or 0; onX: on its close button (Velvet's: VelvetOnClose)
    onX := false
    if pt
        for i, t in tiles
            if pt[1] >= t.x && pt[1] < t.x + t.w && pt[2] >= t.y && pt[2] < t.y + grid.th
                return (onX := PANE_LOOK = "velvet" ? VelvetOnClose(pt, t) : pt[1] >= t.x + t.w - CloseW(t) && pt[2] < t.y + grid.hdr, i)
    return 0
}

CursorAt() {   ; the mouse in the pane's client coordinates, [x, y]
    pt := Buffer(8), DllCall("GetCursorPos", "ptr", pt), DllCall("ScreenToClient", "ptr", g.Hwnd, "ptr", pt)
    return [NumGet(pt, 0, "int"), NumGet(pt, 4, "int")]
}
