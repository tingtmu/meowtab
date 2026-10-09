; Settings… panel for meowtab.ahk and meowtab-classic.ahk (#Included by both; tray menu > Settings…, or
; the desktop icon, desktop-icon.ahk, which starts the script with /settings):
; mood images and their window ranges, how far the image peeks (peek only), the switcher's look (peek only), the font (list
; text, or tile titles in peek), the shortcuts (peek only). They scroll under a fixed bottom bar: the hint line, Reset, Cancel
; and Save. Built when opened and destroyed when closed, so nothing of it exists, runs or listens while closed, and Alt+Tab
; never waits on it. Values go to settings.ini (settings-store.ahk); Save reloads the script to apply them.

#Include %A_LineFile%\..\gdip-helpers.ahk
#Include %A_LineFile%\..\settings-store.ahk
#Include %A_LineFile%\..\settings-paint.ahk
#Include %A_LineFile%\..\cutout.ahk
#Include %A_LineFile%\..\desktop-icon.ahk

; The panel's palette (the warm ivory of the original glass switcher), one restrained accent.
global LOOK := {bgTop: "FCF9F4", bg: "FAF6EF", bgBot: "F5EEE2", card: "FDFBF7", line: "E6DAC6", border: "D9CBB4"
    , text: "181614", muted: "6B6154", soft: "8C8174", faint: "D8CEBF", pill: "D6E6F2", pillRim: "BFD5E6"
    , pillHi: "EEF5FA", accent: "6F93B6", shadow: "78350F", wellTop: "EFE6D6", wellBot: "F8F2E7", face: "Segoe UI"}
global pnl := 0                                       ; the open panel's state; 0 = closed
OnExit((*) => (PanelClose(), 0))                      ; exit or reload (Save) with it open: closed first, before the globals its
                                                      ; message handlers read are freed (else each repaint is an error dialog)
A_TrayMenu.Insert("1&", "Settings…", SettingsOpen)
A_TrayMenu.Insert("2&", "Desktop icon", DesktopIconToggle)
A_TrayMenu.Insert("3&")
A_TrayMenu.Default := "Settings…"                     ; double-click the tray icon
if A_IsCompiled                                       ; an exe's menu is just Suspend, Pause, Exit: add Reload before Exit
    A_TrayMenu.Insert(DllCall("GetMenuItemCount", "ptr", A_TrayMenu.Handle) "&", "&Reload Script", (*) => Reload())
else if FileExist(AppDir() "assets\meowtab.ico")      ; the exe carries the icon itself
    TraySetIcon AppDir() "assets\meowtab.ico"
DesktopIconStart()                                    ; check mark, "/settings", the exe's first-run question

Dpx(v) => Round(v * A_ScreenDPI / 96)                 ; 96-dpi layout units -> pixels

SettingsOpen(*) {
    global pnl
    if pnl
        return WinActivate(pnl.gui)
    DllCall("LoadLibrary", "str", "gdiplus"), si := Buffer(24, 0), NumPut("uint", 1, si)
    DllCall("gdiplus\GdiplusStartup", "ptr*", &tok := 0, "ptr", si, "ptr", 0)   ; own token: elegant shuts its own down
    PendingClear()                                    ; leftovers of a crash
    peek := SettingsHas("PEEK_MIN")
    pnl := {tok: tok, el: Map(), cards: [], frames: [], labels: [], hover: 0, side: 0, drag: 0, dirty: false
        , note: PanelIssues(), held: 0, cap: 0, why: "", dy: 0, off: 0, wide: false, grab: -1
        , some: SOME_FROM, many: MANY_FROM, face: FONT_NAME, size: FONT_SIZE
        , peek: peek ? [Round(SettingsGet("PEEK_MIN") * 100), Round(SettingsGet("PEEK_MAX") * 100)] : 0
        , keys: SettingsHas("SWITCH_KEYS") ? [SettingsGet("SWITCH_KEYS"), SettingsGet("STAY_KEYS")] : 0
        , look: SettingsHas("PANE_LOOK") ? SettingsGet("PANE_LOOK") : 0}   ; the picked look (MeowTab)
    if pnl.look                                       ; the switcher in miniature (MiniPane) takes Windows' mode and accent as they are now
        pnl.dark := SettingsGet("dark"), pnl.accent := SettingsGet("AccentRing")()
    pnl.gui := g := Gui("-MinimizeBox -MaximizeBox -DPIScale", "MeowTab settings")
    g.BackColor := LOOK.bg, g.MarginX := 0, g.MarginY := 0
    ; The sections go on a page as tall as they are, in a view that clips it above the bottom bar: both borderless child
    ; windows, CONTROLPARENT so that Tab goes through them, CLIPCHILDREN. Scrolling moves the page in the view.
    pnl.view := Gui("-Caption -DPIScale +Parent" g.Hwnd " +E0x10000 +0x2000000")
    pnl.page := p := Gui("-Caption -DPIScale +Parent" pnl.view.Hwnd " +E0x10000 +0x2000000")
    p.BackColor := LOOK.bg, p.SetFont("s10 c" LOOK.text, LOOK.face)   ; the font list's
    PanelFonts()
    pnl.at := p, pnl.h := PanelLayout(pnl.w := w := Dpx(624)), pnl.bh := Dpx(98)   ; the page's height; the bar's (PanelLayoutBar)
    ch := PanelFit(w, pnl.h + pnl.bh), pnl.viewH := ch - pnl.bh, pnl.end := pnl.h - pnl.viewH
    pnl.at := g, pnl.dy := pnl.viewH - pnl.h, PanelLayoutBar(w, pnl.h)   ; in the panel, right under the view
    for i in [1, 2, 3]
        PanelLoadCard(i)
    PanelSurface(w, pnl.h + pnl.bh)
    PanelHook(true)
    g.OnEvent("Close", PanelClose), g.OnEvent("Escape", PanelClose), g.OnEvent("DropFiles", PanelDrop), p.OnEvent("DropFiles", PanelDrop)
    for a, v in Map(33, 2, 34, Bgr(LOOK.border), 35, Bgr(LOOK.bgTop), 36, Bgr(LOOK.text))   ; round corners, border,
        DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "uint", a, "uint*", v, "uint", 4)   ; ivory caption, title
    p.Show("x0 y0 w" w " h" pnl.h " NA"), pnl.view.Show("x0 y0 w" w " h" pnl.viewH " NA")
    PanelShow(w, ch)
    PanelFontList()
}

; The page: cards (few / some / many) with their range steppers, the peek scenes and sliders, the LOOK cards, the font row, the
; shortcuts. Tab order follows creation, then goes on to the bar. Returns the page's height.
PanelLayout(w) {
    pad := Dpx(28), gap := Dpx(16), cw := (w - 2 * pad - 2 * gap) // 3, y := Dpx(20)
    pnl.labels.Push(["MOOD IMAGES", pad, y]), y += Dpx(26)
    for i, mood in Moods() {   ; few starts at 1; some and many get a "starts at" stepper
        x := pad + (i - 1) * (cw + gap), c := {mood: mood, thumb: 0, big: 0, span: [0, 1], busy: false, pending: false}
        pnl.frames.Push([x, y, cw, Dpx(232)])
        c.card := PanelAdd("card", x + Dpx(8), y + Dpx(8), cw - Dpx(16), Dpx(182), PaintCard.Bind(i)
            , "Click to choose the picture for “" MOOD_NOTES[i] "”, or drop one here.", PanelPick.Bind(i))
        if i > 1
            PanelAdd("step", x + Dpx(12), y + Dpx(194), Dpx(80), Dpx(28), PaintStepper.Bind(i)
                , "Where “" MOOD_NOTES[i] "” starts: the fewest windows that count.", PanelStepClick.Bind(i)).i := i
        c.clean := PanelAdd("chip", x + cw - Dpx(74), y + Dpx(194), Dpx(62), Dpx(28), PaintChip.Bind(i)
            , "Clean background: remove a plain light background and crop.", PanelClean.Bind(i))
        c.clean.ctl.Visible := false
        pnl.cards.Push(c)
    }
    y += Dpx(232) + Dpx(22)
    if pnl.peek
        y := PanelLayoutPeek(w, pad, gap, y)
    if pnl.look
        y := PanelLayoutLook(w, pad, gap, y)
    pnl.labels.Push([pnl.peek ? "TITLE FONT" : "LIST FONT", pad, y]), y += Dpx(26)   ; peek: its tiles' titles; elegant: its list
    pnl.ddl := pnl.page.AddDropDownList("x" pad " y" y " w" Dpx(330) " r16")
    pnl.ddl.OnEvent("Change", PanelFontPick), pnl.ddl.OnEvent("Focus", PanelReveal), pnl.ddl.GetPos(, , , &dh)
    PanelAdd("step", w - pad - Dpx(108), y + (dh - Dpx(28)) // 2, Dpx(108), Dpx(28), PaintStepper.Bind(4)
        , "Text size of the " (pnl.peek ? "window titles" : "list") ", in points (10–24).", PanelStepClick.Bind(4)).i := 4
    y += dh + Dpx(12)
    pnl.sample := PanelAdd("sample", pad, y, w - 2 * pad, Dpx(58), pnl.peek ? PaintTile : PaintSample), y += Dpx(58) + Dpx(26)
    if pnl.keys
        y := PanelLayoutKeys(w, pad, gap, y)
    return y
}

PanelLayoutBar(w, y) {   ; the bottom bar from y down, pnl.bh tall: the hint line at its top; Reset, Cancel and Save Dpx(22) above its bottom
    pad := Dpx(28)
    pnl.hint := PanelAdd("hint", pad + Dpx(2), y + Dpx(12), w - 2 * pad, Dpx(20), PaintHint), y += pnl.bh - Dpx(34 + 22)
    PanelAdd("button", pad - Dpx(12), y, Dpx(150), Dpx(34), PaintButton.Bind("Reset to defaults", 0)
        , "Put the panel's settings back to the built-in ones (asks first).", PanelReset)
    PanelAdd("button", w - pad - Dpx(212), y, Dpx(100), Dpx(34), PaintButton.Bind("Cancel", 1), "Close without saving (Esc).", PanelClose)
    PanelAdd("button", w - pad - Dpx(100), y, Dpx(100), Dpx(34), PaintButton.Bind("Save", 2), "Save and apply (Enter).", PanelSave)
}

PanelLayoutPeek(w, pad, gap, y) {   ; two scenes (1 window, many windows), a slider under each
    pnl.labels.Push(["PEEK HEIGHT", pad, y]), y += Dpx(26), sw := (w - 2 * pad - gap) // 2
    for j in [1, 2] {
        x := pad + (j - 1) * (sw + gap)
        PanelAdd("scene", x, y, sw, Dpx(132), PaintScene.Bind(j))
        PanelAdd("slider", x, y + Dpx(134), sw, Dpx(28), PaintSlider.Bind(j), j = 1
            ? "How much of the picture shows above the pane with a single window."
            : "How much shows once the window count reaches many (and beyond).").j := j
    }
    return y + Dpx(162) + Dpx(20)
}

PanelLayoutLook(w, pad, gap, y) {   ; two cards, Velvet and Windows 11, each its look in miniature (PaintLook); a click picks one
    pnl.labels.Push(["LOOK", pad, y]), y += Dpx(26), sw := (w - 2 * pad - gap) // 2
    for j, c in [["velvet", "Velvet", "Softer and warmer up close", "warm frosted glass, rounder tiles and a lifted selection"]
        , ["windows11", "Windows 11", "As Windows draws it", "the switcher as Windows draws its own"]] {
        x := pad + (j - 1) * (sw + gap)
        pnl.frames.Push([x, y, sw, Dpx(178)])         ; after the mood cards' frames, which PanelDrop goes by
        PanelAdd("look", x + Dpx(8), y + Dpx(8), sw - Dpx(16), Dpx(162), PaintLook.Bind(c[1], c[2], c[3])
            , "Pick " c[2] ": " c[4] " (Save applies it).", PanelLook.Bind(c[1], c[2])).lk := c[1]
    }
    return y + Dpx(178) + Dpx(22)
}

; Two fields (a click captures a shortcut: PanelCapture). Under them going back (under the first) and Defaults, or in their place,
; across both, why a capture was refused (PanelWhy).
PanelLayoutKeys(w, pad, gap, y) {
    pnl.labels.Push(["SHORTCUTS", pad, y]), y += Dpx(26), fw := (w - 2 * pad - gap) // 2
    for j in [1, 2]
        PanelAdd("keys", pad + (j - 1) * (fw + gap), y, fw, Dpx(30), PaintKeys.Bind(j), j = 1
            ? "Click, then press the new shortcut: Alt, Ctrl or Win with one key."
            : "Click, then press the shortcut for a switcher that stays open once you let go.", PanelCapture.Bind(j)).j := j
    pnl.back := PanelAdd("line", pad, y + Dpx(30), fw, Dpx(52) - Dpx(30), PaintKeysLine.Bind(false))
    pnl.defaults := PanelAdd("button", w - pad - Dpx(84), y + Dpx(30), Dpx(84), Dpx(22), PaintButton.Bind("Defaults", 0)
        , "Put the shortcuts back to " SETTINGS_DEFAULTS["SWITCH_KEYS"] " and " SETTINGS_DEFAULTS["STAY_KEYS"] " (Save applies it).", PanelKeysDefaults)
    pnl.refused := PanelAdd("line", pad, y + Dpx(30), w - 2 * pad, Dpx(52) - Dpx(30), PaintKeysLine.Bind(true)), pnl.refused.ctl.Visible := false
    return y + Dpx(52) + Dpx(20)
}

; An owner-drawn element on pnl.at, pnl.dy below its place in the surface (x, y): a focusable button, which scrolls into
; view when it takes the focus, or a plain owner-drawn static for the display-only kinds.
PanelAdd(kind, x, y, w, h, paint, hint := "", click := 0) {
    if kind ~= "^(hint|scene|sample|line)$"
        c := pnl.at.AddText("x" x " y" y + pnl.dy " w" w " h" h " 0xD")    ; SS_OWNERDRAW
    else {
        c := pnl.at.AddButton("x" x " y" y + pnl.dy " w" w " h" h), c.OnEvent("Focus", PanelReveal)
        DllCall("SetWindowLongPtr", "ptr", c.Hwnd, "int", -16, "ptr", ControlGetStyle(c) & ~0xF | 0xB)   ; BS_OWNERDRAW (Add masks it)
    }
    if click
        c.OnEvent("Click", click), c.OnEvent("DoubleClick", click)   ; quick repeat clicks come as double-clicks
    return pnl.el[c.Hwnd] := {ctl: c, kind: kind, x: x, y: y, w: w, h: h, paint: paint, hint: hint}
}

PanelIssues() {   ; what settings.ini had wrong at startup, for the hint line ("" = nothing)
    n := SETTINGS_ISSUES.Length
    return n ? "settings.ini: " SETTINGS_ISSUES[1] (n > 1 ? "  (+" n - 1 " more)" : "") : ""
}

; The client height for content h (client w x h): all of it, or what the room leaves, whichever is less. The room: the work
; area of the monitor it opens on, less keep. keep: Dpx(16) of air; while GlazeWM runs, at least its top + bottom outer gaps,
; as it floats and centres new windows in the work area less those and clips them to it (Dpx(60) if its config can't tell).
; A test may set PANEL_ROOM, the room in px.
PanelFit(w, h) {
    g := pnl.gui, keep := Dpx(16), text := ""
    if ProcessExist("glazewm.exe") {
        try text := FileRead(EnvGet("USERPROFILE") "\.glzr\glazewm\config.yaml", "UTF-8")   ; GlazeWM's default path
        keep := (gaps := GlazeGaps(text, A_ScreenDPI)) = "" ? Dpx(60) : Max(keep, gaps)
    }
    g.Show("Hide w" w " h" h), g.GetPos(, , , &wh), g.GetClientPos(, , , &ch)
    mi := Buffer(40, 0), NumPut("uint", 40, mi), DllCall("GetMonitorInfoW", "ptr", CurrentMonitor(), "ptr", mi)
    room := IsSet(PANEL_ROOM) && PANEL_ROOM ? PANEL_ROOM : NumGet(mi, 32, "int") - NumGet(mi, 24, "int") - keep
    return Min(h, room - (wh - ch))                   ; wh - ch: caption and frame
}

; GlazeWM's top + bottom outer gap in px from config.yaml's text: gaps > outer_gap, in block or { } flow form (not
; single_window_outer_gap), times dpi / 96 under scale_with_dpi (on by default). No outer_gap, or no gaps block, is 0 as
; in GlazeWM. "" = can't tell: empty text, a % or anything else unreadable. Only these shapes, no YAML parser.
GlazeGaps(text, dpi) {
    if text = ""
        return ""
    inGaps := false, sub := 0, kid := "", scale := true, og := 0
    for line in StrSplit(text, "`n", "`r") {
        line := RegExReplace(line, "\s+#.*")          ; comments (a quoted '#2da44e' keeps its #: no space before it)
        if !RegExMatch(line, "^(\s*)['`"]?([\w-]+)['`"]?\s*:\s*(.*?)\s*$", &m)   ; a key, quoted or not
            continue
        if !m.Len[1] {                                ; a top-level key starts or ends the gaps block
            if (inGaps := m[2] = "gaps") && m[3] != ""   ; gaps: { … } on one line
                return ""
            continue
        }
        if !inGaps
            continue
        if !sub || m.Len[1] <= sub {                  ; a key of gaps itself
            sub := m.Len[1], kid := m[2]
            if kid = "scale_with_dpi"
                scale := m[3] != "false"
            else if kid = "outer_gap" {
                og := Map()
                for side in ["top", "bottom"]         ; the flow form; the block form's lines follow
                    if RegExMatch(m[3], "\b" side "\s*:\s*([^,}\s]+)", &v)
                        og[side] := v[1]
            }
        } else if kid = "outer_gap" && (m[2] = "top" || m[2] = "bottom")
            og[m[2]] := m[3]
    }
    if !og
        return 0
    px := 0
    for side in ["top", "bottom"] {                   ; '46px', 46px or 46
        if !og.Has(side) || !RegExMatch(Trim(og[side], "'`""), "^(\d+(?:\.\d+)?)(px)?$", &n)
            return ""
        px += n[1]
    }
    return Round(px * (scale ? dpi / 96 : 1))
}

PanelShow(w, h) {   ; centred on the active window's monitor (or the cursor's), never above or left of its work area
    g := pnl.gui
    g.Show("Hide w" w " h" h), g.GetPos(, , &ww, &wh)
    mi := Buffer(40, 0), NumPut("uint", 40, mi), DllCall("GetMonitorInfoW", "ptr", CurrentMonitor(), "ptr", mi)
    l := NumGet(mi, 20, "int"), t := NumGet(mi, 24, "int"), r := NumGet(mi, 28, "int"), b := NumGet(mi, 32, "int")
    g.Show("x" Max(l, l + (r - l - ww) // 2) " y" Max(t, t + (b - t - wh) // 2))
}

PanelFontList() {
    names := FontFamilies(), at := 0
    for i, n in names
        if n = pnl.face
            at := i
    if !at                                            ; e.g. a font known by another name: keep it on top
        names.InsertAt(1, pnl.face), at := 1
    pnl.ddl.Add(names), pnl.ddl.Choose(at)
}

PanelHook(on) {   ; message handlers exist only while the panel is open
    static msgs := Map(0x2B, PanelDrawItem, 0x14, PanelErase, 0x100, PanelKey, 0x200, PanelMouse, 0x201, PanelMouse
        , 0x202, PanelMouse, 0x2A3, PanelLeave, 0x20, PanelCursor, 0x06, PanelActivate   ; DRAWITEM ERASEBKGND KEYDOWN mouse MOUSELEAVE SETCURSOR ACTIVATE
        , 0x20A, PanelWheel)                          ; MOUSEWHEEL
    for m, f in msgs
        OnMessage(m, f, on ? 1 : 0)
}

PanelClose(*) {
    global pnl
    if !pnl
        return
    PanelCaptureEnd(), CutoutCancel(), PanelHook(false), pnl.page.Destroy(), pnl.view.Destroy(), pnl.gui.Destroy(), PendingClear()
    for c in pnl.cards
        for b in [c.thumb, c.big]
            if b
                DllCall("gdiplus\GdipDisposeImage", "ptr", b)
    for k, f in pnl.f
        DllCall("DeleteObject", "ptr", f)
    DllCall("SelectObject", "ptr", pnl.surfDC, "ptr", pnl.surfOld), DllCall("DeleteObject", "ptr", pnl.surfBmp)
    DllCall("DeleteDC", "ptr", pnl.surfDC), DllCall("gdiplus\GdiplusShutdown", "ptr", pnl.tok)
    pnl := 0
}

; ----- Messages: painting, keys, mouse -----

PanelDrawItem(wParam, lParam, msg, hwnd) {   ; WM_DRAWITEM (page or bar): surface underneath, then the element's painter
    if !pnl || hwnd != pnl.page.Hwnd && hwnd != pnl.gui.Hwnd || !(e := pnl.el.Get(NumGet(lParam, 24, "ptr"), 0))
        return
    dc := NumGet(lParam, 32, "ptr"), st := NumGet(lParam, 16, "uint") | (pnl.hover = e.ctl.Hwnd ? 0x10000 : 0)
    mdc := DllCall("CreateCompatibleDC", "ptr", dc, "ptr"), bmp := DllCall("CreateCompatibleBitmap", "ptr", dc, "int", e.w, "int", e.h, "ptr")
    ob := DllCall("SelectObject", "ptr", mdc, "ptr", bmp, "ptr")
    DllCall("BitBlt", "ptr", mdc, "int", 0, "int", 0, "int", e.w, "int", e.h, "ptr", pnl.surfDC, "int", e.x, "int", e.y, "uint", 0xCC0020)
    paint := e.paint, paint(mdc, e.w, e.h, st)       ; st: ODS_* bits, 0x10000 = hovered
    DllCall("BitBlt", "ptr", dc, "int", 0, "int", 0, "int", e.w, "int", e.h, "ptr", mdc, "int", 0, "int", 0, "uint", 0xCC0020)
    DllCall("SelectObject", "ptr", mdc, "ptr", ob), DllCall("DeleteObject", "ptr", bmp), DllCall("DeleteDC", "ptr", mdc)
    return true
}

; WM_ERASEBKGND: the cached surface. The page shows its part of it and the scroll bar; the panel, under the view, the bar's
; part; the view nothing, as the page covers it.
PanelErase(wParam, lParam, msg, hwnd) {
    if !pnl || hwnd != pnl.page.Hwnd && hwnd != pnl.gui.Hwnd && hwnd != pnl.view.Hwnd
        return
    if hwnd = pnl.page.Hwnd {
        DllCall("BitBlt", "ptr", wParam, "int", 0, "int", 0, "int", pnl.w, "int", pnl.h, "ptr", pnl.surfDC, "int", 0, "int", 0, "uint", 0xCC0020)
        if pnl.end > 0
            PaintThumb(wParam)
    } else if hwnd = pnl.gui.Hwnd
        DllCall("BitBlt", "ptr", wParam, "int", 0, "int", pnl.viewH, "int", pnl.w, "int", pnl.bh, "ptr", pnl.surfDC, "int", 0, "int", pnl.h, "uint", 0xCC0020)
    return 1
}

PanelKey(wParam, lParam, msg, hwnd) {   ; Enter = Save; arrows / + / - / PgUp / PgDn on steppers and sliders
    static steps := Map(37, -1, 40, -1, 39, 1, 38, 1, 0xBB, 1, 0x6B, 1, 0xBD, -1, 0x6D, -1, 33, 10, 34, -10, 36, -100, 35, 100)
    if !pnl || DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr") != pnl.gui.Hwnd   ; GA_ROOT
        return
    if wParam = 13 {
        if SendMessage(0x157, 0, 0, pnl.ddl)          ; CB_GETDROPPEDSTATE: Enter picks from the open list
            return
        return (PanelSave(), 0)
    }
    if !(e := pnl.el.Get(hwnd, 0)) || !steps.Has(wParam) || !(e.kind = "step" || e.kind = "slider")
        return
    if e.kind = "step"
        PanelStep(e.i, steps[wParam] > 0 ? 1 : -1)
    else
        PanelPeek(e.j, pnl.peek[e.j] + steps[wParam])
    return 0
}

PanelMouse(wParam, lParam, msg, hwnd) {   ; slider drags, the scroll bar, hover (WM_MOUSEMOVE / LBUTTONDOWN / LBUTTONUP)
    if !pnl
        return
    if msg = 0x201 && pnl.cap                         ; a click ends a capture (on its own field: that starts it again)
        PanelCaptureEnd()
    if msg = 0x202                                    ; and a refusal's line, once released: hiding elements under a pressed button
        PanelWhy("")                                  ; moves the mouse for it, to where the cursor is, which can undo the click
    x := lParam << 48 >> 48, e := pnl.el.Get(hwnd, 0)  ; signed client x
    if hwnd = pnl.page.Hwnd && PanelThumb(msg, wParam, x, lParam << 32 >> 48)
        return 0
    if msg = 0x201 && e && e.kind = "slider" {
        pnl.drag := hwnd, DllCall("SetCapture", "ptr", hwnd), e.ctl.Focus()
        return (PanelSlideTo(e, x), 0)
    }
    if pnl.drag && pnl.drag = hwnd {
        if msg = 0x200 && wParam & 1                  ; MK_LBUTTON
            PanelSlideTo(e, x)
        else
            pnl.drag := 0, DllCall("ReleaseCapture")
        return 0
    }
    if msg = 0x200
        PanelHover(hwnd, e, x)
}

PanelHover(hwnd, e, x) {   ; track the element under the mouse (and a stepper's - / + side) for hover looks and hints
    side := e && e.kind = "step" ? (x < e.w / 3 ? -1 : x > e.w * 2 / 3 ? 1 : 0) : 0
    h := e && e.hint != "" ? hwnd : 0
    if h = pnl.hover && side = pnl.side
        return
    old := pnl.hover, pnl.hover := h, pnl.side := side, pnl.held := 0, PanelWhy("")
    PanelInvalidate(old), PanelInvalidate(h), PanelInvalidate(pnl.hint.ctl.Hwnd)
    if h
        tme := Buffer(24, 0), NumPut("uint", 24, "uint", 2, "ptr", h, tme), DllCall("TrackMouseEvent", "ptr", tme)   ; TME_LEAVE
}

PanelLeave(wParam, lParam, msg, hwnd) {   ; WM_MOUSELEAVE: off an element, or off the page (the scroll bar narrows)
    if pnl && hwnd = pnl.hover
        pnl.hover := 0, PanelInvalidate(hwnd), PanelInvalidate(pnl.hint.ctl.Hwnd)
    else if pnl && hwnd = pnl.page.Hwnd && pnl.wide && pnl.grab < 0
        pnl.wide := false, PanelThumbPaint()
}

; WM_ACTIVATE: the panel losing focus ends a capture. Destroying the panel sends it too, also while the script exits
; (Save's Reload, the tray's Exit), when the globals are already unset: hence IsSet.
PanelActivate(wParam, lParam, msg, hwnd) {
    if IsSet(pnl) && pnl && hwnd = pnl.gui.Hwnd && !(wParam & 0xFFFF)
        PanelCaptureEnd()
}

PanelCursor(wParam, lParam, msg, hwnd) {   ; WM_SETCURSOR: a hand over anything clickable
    if pnl && (e := pnl.el.Get(wParam, 0)) && e.hint != "" && e.kind != "slider"
        return (DllCall("SetCursor", "ptr", DllCall("LoadCursor", "ptr", 0, "ptr", 32649, "ptr")), 1)   ; IDC_HAND
}

PanelInvalidate(hwnd) => hwnd && DllCall("InvalidateRect", "ptr", hwnd, "ptr", 0, "int", 0)

PanelRedraw(kinds*) {   ; repaint every element of these kinds
    for hwnd, e in pnl.el
        for k in kinds
            if e.kind = k
                PanelInvalidate(hwnd)
}

PanelNote(text) {   ; a message in the hint line (hover hints still take its place for a moment, except pnl.held's)
    pnl.note := text, PanelInvalidate(pnl.hint.ctl.Hwnd)
}

; ----- Scrolling: the page moves in its view while it overflows (pnl.end > 0); a scroll bar, drawn on the page -----

PanelScroll(off) {   ; the page to offset off (0 .. end), at once
    if (off := Min(Max(Round(off), 0), pnl.end)) = pnl.off
        return
    pnl.off := off
    DllCall("SetWindowPos", "ptr", pnl.page.Hwnd, "ptr", 0, "int", 0, "int", -off, "int", 0, "int", 0, "uint", 0x15)   ; NOSIZE NOZORDER NOACTIVATE
    PanelThumbPaint()
}

PanelWheel(wParam, lParam, msg, hwnd) {   ; WM_MOUSEWHEEL anywhere over the panel scrolls the page, not while the font list is open
    if !pnl || DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr") != pnl.gui.Hwnd || SendMessage(0x157, 0, 0, pnl.ddl)   ; GA_ROOT, CB_GETDROPPEDSTATE
        return
    PanelScroll(pnl.off - (wParam << 32 >> 48) * Dpx(60) / 120)   ; a notch (120) scrolls Dpx(60)
    return 0
}

; A control of the page that takes the keyboard focus scrolls into view: Dpx(16) to spare below it, and above it room for a
; section's label too (Dpx(26) over its first control). Not a click's focus: the page moving under the press would undo the click.
PanelReveal(ctl, *) {
    if ctl.Gui != pnl.page || GetKeyState("LButton", "P")
        return
    ctl.GetPos(, &y, , &h)
    PanelScroll(Min(Max(pnl.off, y + h + Dpx(16) - pnl.viewH), y - Dpx(42)))
}

PanelTrack(&top, &len, &k) {   ; the scroll bar's track in the view: its top and length; k: the thumb's length, the view's share of the page
    top := Dpx(6), len := pnl.viewH - 2 * top, k := len * pnl.viewH / pnl.h
}

; The thumb, [x, y, w, h] in the view: its right edge Dpx(4) from the panel's, 3 px wide (6 while wide), its place along the
; track the offset's share of the end.
PanelKnob() {
    PanelTrack(&top, &len, &k), bw := Dpx(pnl.wide ? 6 : 3)
    return [pnl.w - Dpx(4) - bw, top + (len - k) * pnl.off / Max(pnl.end, 1), bw, k]
}

; The scroll bar under the mouse (msg at x, y on the page): wide while the mouse is in the page's right padding or drags the
; thumb; a press on the thumb (across the padding) starts a drag. true = the message was the bar's.
PanelThumb(msg, wParam, x, y) {
    y -= pnl.off, PanelTrack(&top, &len, &k), b := PanelKnob()   ; y in the view
    if pnl.grab >= 0 && msg = 0x200 && wParam & 1     ; MK_LBUTTON: the thumb's top follows y less where it was grabbed
        return (PanelScroll((y - pnl.grab - top) / Max(len - k, 1) * pnl.end), true)
    if pnl.grab >= 0                                  ; let go
        pnl.grab := -1, DllCall("ReleaseCapture")
    near := pnl.end > 0 && x >= pnl.w - Dpx(28) && x < pnl.w && y >= 0 && y < pnl.viewH
    if msg = 0x201 && near && y >= b[2] && y < b[2] + b[4]
        pnl.grab := y - b[2], DllCall("SetCapture", "ptr", pnl.page.Hwnd)
    if (near || pnl.grab >= 0) != pnl.wide {
        pnl.wide := !pnl.wide, PanelThumbPaint()
        tme := Buffer(24, 0), NumPut("uint", 24, "uint", 2, "ptr", pnl.page.Hwnd, tme), DllCall("TrackMouseEvent", "ptr", tme)   ; TME_LEAVE
    }
    return pnl.grab >= 0
}

PanelThumbPaint() {   ; repaint the scroll bar's column, the page's whole height: the thumb moves on it with the offset
    rc := Buffer(16), NumPut("int", pnl.w - Dpx(12), "int", 0, "int", pnl.w, "int", pnl.h, rc)
    DllCall("InvalidateRect", "ptr", pnl.page.Hwnd, "ptr", rc, "int", 1)
}

; ----- Actions -----

PanelStepClick(i, ctl, *) {   ; the - or + third of a stepper; Space (cursor elsewhere) is left to the arrows
    pt := Buffer(8), DllCall("GetCursorPos", "ptr", pt), DllCall("ScreenToClient", "ptr", ctl.Hwnd, "ptr", pt)
    e := pnl.el[ctl.Hwnd], x := NumGet(pt, 0, "int"), y := NumGet(pt, 4, "int")
    if x >= 0 && y >= 0 && x < e.w && y < e.h && (x < e.w / 3 || x > e.w * 2 / 3)
        PanelStep(i, x < e.w / 3 ? -1 : 1)
}

PanelStep(i, d) {   ; 2 = some starts at, 3 = many starts at, 4 = font size; each kept within its neighbours
    switch i {
    case 2: v := pnl.some, pnl.some := Min(Max(v + d, 2), pnl.many - 1), changed := pnl.some != v
    case 3: v := pnl.many, pnl.many := Min(Max(v + d, pnl.some + 1), 30), changed := pnl.many != v
    case 4: v := pnl.size, pnl.size := Min(Max(v + d, 10), 24), changed := pnl.size != v
    default: return
    }
    if !changed
        return
    pnl.dirty := true
    if i = 4
        PanelSampleFont(), PanelRedraw("step", "sample")
    else
        PanelRedraw("step", "card", "scene")
}

PanelPeek(j, v) {   ; slider j (1 = min, 2 = max) to v %; the other one makes room so min < max
    p := [pnl.peek[1], pnl.peek[2]], p[j] := v := Min(Max(v, 30), 100)
    if p[1] >= p[2] && j = 1
        p[2] := Min(v + 1, 100), p[1] := p[2] - 1
    else if p[1] >= p[2]
        p[1] := Max(v - 1, 30), p[2] := p[1] + 1
    if p[1] = pnl.peek[1] && p[2] = pnl.peek[2]
        return
    pnl.peek := p, pnl.dirty := true, PanelRedraw("slider", "scene")
}

PanelSlideTo(e, x) {
    r := Dpx(9)
    PanelPeek(e.j, 30 + Round((x - r) / Max(e.w - 2 * r, 1) * 70))
}

PanelFontPick(ctl, *) {
    pnl.face := ctl.Text, pnl.dirty := true, PanelSampleFont(), PanelRedraw("sample")
}

PanelLook(lk, name, ctl, *) {   ; a LOOK card clicked (or Space): its look is picked, and the cards, scenes and sample draw it at once
    if lk = pnl.look
        return
    pnl.look := lk, pnl.dirty := true, PanelSampleFont(), PanelRedraw("look", "scene", "sample")
    PanelNote(lk = SettingsGet("PANE_LOOK") ? "" : name " picked. Save to use it."), pnl.held := ctl.Hwnd
}

PanelPick(i, *) {   ; card click: file picker
    pnl.gui.Opt("+OwnDialogs")
    if pnl.cards[i].busy
        return
    f := FileSelect(1, , "Choose the picture for “" MOOD_NOTES[i] "”", "Pictures (*.png; *.jpg; *.jpeg; *.bmp; *.gif)")
    if f != "" && pnl
        PanelImport(i, f)
}

PanelDrop(gui, ctl, files, x, y) {   ; a file dropped on the page (x, y on it, however scrolled): the mood card under it takes it
    if gui = pnl.page
        for i, f in pnl.frames                        ; the mood cards' come first (the LOOK cards' take no pictures)
            if i <= pnl.cards.Length && x >= f[1] && x < f[1] + f[3] && y >= f[2] && y < f[2] + f[4]
                return pnl.cards[i].busy ? 0 : PanelImport(i, files[1])
    PanelNote("Drop the picture onto one of the three cards.")
}

PanelImport(i, file) {   ; the picture becomes this card's pending one (images\custom_<mood>.pending.png)
    if why := ImportImage(file, PendingImage(Moods()[i]))
        return PanelNote("That file didn't work: " why ".")
    pnl.dirty := true, PanelLoadCard(i)
    PanelNote("New picture for “" MOOD_NOTES[i] "”. Save to use it, or clean its background first.")
}

; (Re)load card i's picture: the pending one, else the current set's. Peek also keeps it at IMG_SIZE with
; its art span (ArtSpan, as the switcher measures it) for the peek scenes.
PanelLoadCard(i) {
    c := pnl.cards[i], old := [c.thumb, c.big]
    pending := FileExist(PendingImage(c.mood)) != ""
    file := pending ? PendingImage(c.mood) : MoodImage(IMG_PREFIX, c.mood)
    thumb := FitBitmap(file, Dpx(112)), big := pnl.peek ? FitBitmap(file, IMG_SIZE) : 0
    span := big ? ArtSpan(big, IMG_SIZE) : [0, 1]
    Critical                                          ; a paint may interrupt between lines: swap, then free
    c.pending := pending, c.file := file, c.thumb := thumb, c.big := big, c.span := span
    Critical "Off"
    for b in old
        if b
            DllCall("gdiplus\GdipDisposeImage", "ptr", b)
    PanelChips(), PanelRedraw("card", "scene", "hint")
}

PanelChips() {   ; "Clean" shows on cards with the user's own picture
    for c in pnl.cards
        c.clean.ctl.Visible := c.thumb && (c.pending || IMG_PREFIX = "custom")
}

PanelClean(i, *) {   ; cutout.ahk on the card's working copy (made from the live picture if needed), async
    c := pnl.cards[i], pend := PendingImage(c.mood)
    if c.busy
        return
    made := !c.pending
    if made
        try {
            DirCreate UserImagesDir()
            FileCopy c.file, pend, 1
        } catch as e
            return PanelNote("Couldn't prepare the picture (" e.Message ").")
    c.busy := true, c.clean.ctl.Enabled := false, PanelRedraw("card", "chip")
    PanelNote("Cleaning “" MOOD_NOTES[i] "”…")
    CutoutRun(pend, PanelCleaned.Bind(i, made))
}

PanelCleaned(i, made, r) {
    if !pnl
        return
    c := pnl.cards[i], c.busy := false, c.clean.ctl.Enabled := true
    if made && !r.changed                             ; nothing to keep: drop the copy again
        try FileDelete PendingImage(c.mood)
    pnl.dirty := pnl.dirty || r.changed
    PanelLoadCard(i), PanelNote("“" MOOD_NOTES[i] "”: " r.msg ".")
}

; Shortcut field j (1 = switching, 2 = staying open) clicked: capture the next combination, as AHK's KeyWaitCombo does. An
; InputHook blocks every key and ends on the first one that isn't a modifier; the script's hotkeys are suspended meanwhile,
; so Alt+Tab reaches it and neither switcher opens. PanelCaptured checks the result; PanelCaptureEnd undoes both.
PanelCapture(j, ctl, *) {
    PanelCaptureEnd(), PanelWhy("")                   ; one running: this click starts it again
    if cycling                                        ; a pane open: Suspend would leave its key block on
        Finish(false)
    ih := InputHook("L0 I"), ih.VisibleNonText := false   ; I: as stayIH's; level-1 keys (the test's) are still caught
    ih.KeyOpt("{All}", "E"), ih.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}", "-E")
    ih.OnEnd := PanelCaptured
    pnl.cap := {ih: ih, j: j, suspended: A_IsSuspended}, ih.Start(), Suspend(true)
    PanelNote("Press the new shortcut, or Esc to keep the old one."), pnl.held := ctl.Hwnd, PanelRedraw("keys")
}

PanelCaptured(ih) {   ; the capture ended on a key: Esc alone cancels, any other combination is checked (KeysParse)
    if !pnl || !pnl.cap || pnl.cap.ih != ih           ; already ended: a click, the panel's focus or its close
        return
    j := pnl.cap.j, held := pnl.held, PanelCaptureEnd(), text := ""
    if ih.EndMods = "" && ih.EndKey = "Escape"
        return
    for i, m in ["Win", "Ctrl", "Alt", "Shift"]
        text .= InStr(ih.EndMods, SubStr("#^!+", i, 1)) ? m "+" : ""
    text .= ih.EndKey
    if ih.EndMods ~= "[#!]"                           ; the Win / Alt release, its key blocked, opens no Start / system menu
        Send "{Blind}{vkE8}"
    if why := KeysParse(text, j = 2, pnl.keys[3 - j], &keys, &hk)
        return (PanelNote(text " can't be used: " why "."), PanelWhy(pnl.note), pnl.held := held)
    if keys != pnl.keys[j]
        pnl.keys := j = 1 ? [keys, pnl.keys[2]] : [pnl.keys[1], keys], pnl.dirty := true, PanelRedraw("keys", "line")
    PanelNote("New shortcut " keys ". Save to use it."), pnl.held := held
}

PanelWhy(text) {   ; why a capture was refused, in place of the line under the fields (going back, Defaults); "" = that line again
    if text = pnl.why
        return
    pnl.why := text, pnl.refused.ctl.Visible := text != ""
    pnl.back.ctl.Visible := pnl.defaults.ctl.Visible := text = ""
}

PanelCaptureEnd() {   ; a running capture stops, however it ends: the hotkeys go back to the user's own suspend state
    if !pnl || !(c := pnl.cap)
        return
    pnl.cap := 0, pnl.held := 0, c.ih.Stop(), Suspend(c.suspended)
    PanelNote(""), PanelRedraw("keys")
}

PanelKeysDefaults(*) {   ; the Defaults link: both shortcuts back to the built-in ones, saved like any edit
    keys := [SETTINGS_DEFAULTS["SWITCH_KEYS"], SETTINGS_DEFAULTS["STAY_KEYS"]]
    if keys[1] = pnl.keys[1] && keys[2] = pnl.keys[2]
        return
    pnl.keys := keys, pnl.dirty := true, PanelRedraw("keys", "line")
}

PanelSave(*) {   ; write settings.ini (+ pictures) and reload; nothing changed = just close
    if !pnl
        return
    for c in pnl.cards
        if c.busy
            return PanelNote("Still cleaning a picture, one moment…")
    if !pnl.dirty
        return PanelClose()
    vals := PanelVals()
    for c in pnl.cards
        if c.pending {
            if err := ImagesCommit(IMG_PREFIX)
                return PanelFail(err)
            vals["IMG_PREFIX"] := "custom"
            break
        }
    if err := SettingsWrite(vals)
        return PanelFail(err)
    Reload()
}

PanelVals() {   ; the panel's values for settings.ini, as Save writes them (the test writes them too: Save itself reloads)
    vals := Map("FONT_NAME", pnl.face, "FONT_SIZE", pnl.size, "SOME_FROM", pnl.some, "MANY_FROM", pnl.many, "IMG_PREFIX", IMG_PREFIX)
    if pnl.peek
        vals["PEEK_MIN"] := pnl.peek[1] / 100, vals["PEEK_MAX"] := pnl.peek[2] / 100
    if pnl.keys
        vals["SWITCH_KEYS"] := pnl.keys[1], vals["STAY_KEYS"] := pnl.keys[2]
    if pnl.look
        vals["PANE_LOOK"] := pnl.look
    return vals
}

PanelReset(*) {
    pnl.gui.Opt("+OwnDialogs")
    if MsgBox("Put the panel's settings back to the built-in defaults?`n`nYour pictures stay in the images folder, "
        . "and lines you added to settings.ini yourself (such as WM_PROCESS) are kept.", "MeowTab settings", "OKCancel Iconi Default2") != "OK"
        return
    if err := SettingsReset()
        return PanelFail(err)
    PendingClear(), Reload()
}

PanelFail(err) {
    pnl.gui.Opt("+OwnDialogs")
    MsgBox "The settings couldn't be saved:`n" err, "MeowTab settings", "Icon!"
}
