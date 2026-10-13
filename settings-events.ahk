; The Settings… panel's message and input handlers (#Included by settings-panel.ahk; functions only): painting, keys and
; the mouse, scrolling the page and its scroll bar, and what the steppers, sliders, font list, LOOK cards and tick box do.

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

PanelKey(wParam, lParam, msg, hwnd) {   ; Enter = Save; arrows / + / - / PgUp / PgDn on steppers and sliders; Tab noted (PanelReveal)
    static steps := Map(37, -1, 40, -1, 39, 1, 38, 1, 0xBB, 1, 0x6B, 1, 0xBD, -1, 0x6D, -1, 33, 10, 34, -10, 36, -100, 35, 100)
    if !pnl || DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr") != pnl.gui.Hwnd   ; GA_ROOT
        return
    if wParam = 9                                     ; Tab (or Shift+Tab), on its way to move the focus
        pnl.tabbed := true
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

; A control of the page that Tab moves the focus to scrolls into view: Dpx(16) to spare below it, and above it room for a
; section's label too (Dpx(26) over its first control). No other focus does: not a click's (the page moving under the press
; would undo the click), nor the one restored when the panel is activated again (the page would jump back to the control).
PanelReveal(ctl, *) {
    tabbed := pnl.tabbed, pnl.tabbed := false
    if !tabbed || ctl.Gui != pnl.page
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
    pnl.look := lk, pnl.dirty := true, PanelSampleFont(), PanelRedraw("look", "scene", "sample", "pane")
    PanelNote(lk = SettingsGet("PANE_LOOK") ? "" : name " picked. Save to use it."), pnl.held := ctl.Hwnd
}

PanelTick(ctl, *) {   ; the WINDOWS tick box clicked (or Space): ticked lists only the monitor the switcher opens on
    pnl.monitors := pnl.monitors = "current" ? "all" : "current", pnl.dirty := true, PanelInvalidate(ctl.Hwnd)
}
