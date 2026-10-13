; Drawing for the Settings… panel (#Included by settings-panel.ahk; functions only). Light comes from the
; bottom-left as on the original glass switcher: lit edges are white, shadows fall up and to the right. Shapes are
; GDI+ (antialiased); text is GDI DrawText, which falls back to CJK / symbol fonts by itself.

; ----- Fonts and text -----

PanelMakeFont(pt, weight := 400, face := "") => DllCall("CreateFontW", "int", -Round(pt * A_ScreenDPI / 72), "int", 0
    , "int", 0, "int", 0, "int", weight, "uint", 0, "uint", 0, "uint", 0, "uint", 1, "uint", 0, "uint", 0
    , "uint", 5, "uint", 0, "str", face = "" ? LOOK.face : face, "ptr")   ; DEFAULT_CHARSET, CLEARTYPE_QUALITY

PanelFonts() {   ; label: section titles; cap: card captions; num: stepper values
    pnl.f := Map("label", PanelMakeFont(7.5, 600), "body", PanelMakeFont(10), "cap", PanelMakeFont(10.5, 600)
        , "small", PanelMakeFont(9), "num", PanelMakeFont(10, 600))
    PanelSampleFont()
}

PanelSampleFont() {   ; the list font as chosen, for the sample row (swapped in before the old one is freed); Velvet's titles take
    face := pnl.look = "velvet" && FontInstalled(pnl.face " Medium") ? pnl.face " Medium" : pnl.face   ; its medium weight (TitleInit)
    old := pnl.f.Get("sample", 0), pnl.f["sample"] := PanelMakeFont(pnl.size, 400, face)
    if old
        DllCall("DeleteObject", "ptr", old)
}

; s in rect x, y, w, h; fmt: DrawText flags (default single line, vertically centred; | 1 centre, | 2 right).
PanelText(dc, s, x, y, w, h, font, rgb, fmt := 0x24) {
    of := DllCall("SelectObject", "ptr", dc, "ptr", font, "ptr")
    DllCall("SetBkMode", "ptr", dc, "int", 1), DllCall("SetTextColor", "ptr", dc, "uint", Bgr(rgb))
    rc := Buffer(16), NumPut("int", Round(x), "int", Round(y), "int", Round(x + w), "int", Round(y + h), rc)
    DllCall("DrawTextW", "ptr", dc, "wstr", s, "int", -1, "ptr", rc, "uint", fmt | 0x8800)   ; NOPREFIX|END_ELLIPSIS
    DllCall("SelectObject", "ptr", dc, "ptr", of)
}

; ----- Shapes -----

FillRound(gr, x, y, w, h, r, argb) {
    path := RoundPath(x, y, w, h, Min(r, h / 2, w / 2))
    DllCall("gdiplus\GdipCreateSolidFill", "uint", argb, "ptr*", &br := 0)
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br), DllCall("gdiplus\GdipDeletePath", "ptr", path)
}

Ring(gr, x, y, w, h, r, rgb, a, width := 1) => Stroke(gr, x, y, w, h, Min(r, h / 2), width, [[rgb, a, 0], [rgb, a, 1]])

Disc(gr, cx, cy, r, fill, line := 0) {   ; circle; fill / line are ARGB (0 = none)
    if fill {
        DllCall("gdiplus\GdipCreateSolidFill", "uint", fill, "ptr*", &br := 0)
        DllCall("gdiplus\GdipFillEllipse", "ptr", gr, "ptr", br, "float", cx - r, "float", cy - r, "float", 2 * r, "float", 2 * r)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    }
    if line {
        DllCall("gdiplus\GdipCreatePen1", "uint", line, "float", 1, "int", 2, "ptr*", &pen := 0)   ; UnitPixel
        DllCall("gdiplus\GdipDrawEllipse", "ptr", gr, "ptr", pen, "float", cx - r + 0.5, "float", cy - r + 0.5, "float", 2 * r - 1, "float", 2 * r - 1)
        DllCall("gdiplus\GdipDeletePen", "ptr", pen)
    }
}

FocusRing(gr, w, h, r, st) {   ; keyboard focus (cues shown): a soft accent ring just inside the element
    if (st & 0x10) && !(st & 0x200)                   ; ODS_FOCUS without ODS_NOFOCUSRECT
        Ring(gr, 1, 1, w - 2, h - 2, r, LOOK.accent, 200, 2)
}

; ----- The surface: background, card frames, section labels (rendered once per open) -----

PanelSurface(w, h) {   ; the page's (pnl.h) and under it the bar's, whose top edge is a hairline
    bm := NewBitmap(w, h), gr := Canvas(bm)
    Fill(gr, FadeBrush(0, 0, w, h, 90, [[LOOK.bgTop, 255, 0], [LOOK.bg, 255, 0.45], [LOOK.bgBot, 255, 1]]), w, h)
    RadialFill(gr, 0, h, 0.65 * w, 0.5 * h, [["FFFFFF", 110, 0], ["FFF7EA", 45, 0.5], ["FFF7EA", 0, 1]])   ; light, bottom-left
    for f in pnl.frames
        PaintFrame(gr, f*)
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Argb(LOOK.line, 255), "ptr*", &br := 0)
    DllCall("gdiplus\GdipFillRectangleI", "ptr", gr, "ptr", br, "int", 0, "int", pnl.h, "int", w, "int", Dpx(1))
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br), DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    pnl.surfDC := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
    pnl.surfOld := DllCall("SelectObject", "ptr", pnl.surfDC, "ptr", pnl.surfBmp := ToHbm(bm), "ptr")
    DllCall("SetTextCharacterExtra", "ptr", pnl.surfDC, "int", Dpx(1))   ; airy small caps
    for l in pnl.labels
        PanelText(pnl.surfDC, l[1], l[2], l[3], Dpx(300), Dpx(16), pnl.f["label"], LOOK.soft)
    DllCall("SetTextCharacterExtra", "ptr", pnl.surfDC, "int", 0)
}

PaintFrame(gr, x, y, w, h) {   ; a card: soft warm shadow up-right, lit-corner fill, hairline with a white lower-left lip
    r := Dpx(14), b := Dpx(14), sw := w + 2 * b, sh := h + 2 * b
    path := RoundPath(x - b + Dpx(3), y - b - Dpx(2), sw, sh, r + b)
    EdgeFade(gr, path, LOOK.shadow, 0, 20, (w - 2 * b) / sw, (h - 2 * b) / sh, true)
    DllCall("gdiplus\GdipDeletePath", "ptr", path)
    path := RoundPath(x, y, w, h, r), br := FadeBrush(x, y, w, h, 315, [["FFFFFF", 255, 0], [LOOK.card, 255, 0.55], [LOOK.card, 255, 1]])
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br), DllCall("gdiplus\GdipDeletePath", "ptr", path)
    Stroke(gr, x + 0.5, y + 0.5, w - 1, h - 1, r, 1, Lip(230, LOOK.line, 170))
}

PaintThumb(dc) {   ; the scroll bar's thumb on the page, where the view shows it (PanelKnob): a pill in the soft text colour
    b := PanelKnob(), gr := Canvas(0, dc)
    FillRound(gr, b[1], pnl.off + b[2], b[3], b[4], b[3] / 2, Argb(LOOK.soft, 200))
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
}

; ----- Element painters: (dc, w, h, st); dc already holds the surface beneath. st: ODS_* | 0x10000 hovered -----

PaintCard(i, dc, w, h, st) {   ; picture well (its strip's frame c.f), caption, window range
    c := pnl.cards[i], wh := Dpx(134), r := Dpx(12), hov := st & 0x10000, t := Dpx(112)
    gr := Canvas(0, dc), path := RoundPath(0.5, 0.5, w - 1, wh - 1, r)
    br := FadeBrush(0, 0, w, wh, 90, hov ? [[LOOK.pillHi, 255, 0], [LOOK.pill, 150, 1]] : [[LOOK.wellTop, 140, 0], [LOOK.wellBot, 80, 1]])
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br), DllCall("gdiplus\GdipDeletePath", "ptr", path)
    Stroke(gr, 0.5, 0.5, w - 1, wh - 1, r, 1, Lip(210, hov ? LOOK.pillRim : LOOK.border, hov ? 230 : 120))
    FocusRing(gr, w, wh, r, st)
    if c.thumb {
        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gr, "int", 7)
        DllCall("gdiplus\GdipDrawImageRectRectI", "ptr", gr, "ptr", c.thumb, "int", (w - t) // 2, "int", (wh - t) // 2, "int", t, "int", t
            , "int", 0, "int", c.f * t, "int", t, "int", t, "int", 2, "ptr", 0, "ptr", 0, "ptr", 0)   ; UnitPixel
    }
    if c.busy                                         ; veil while the cleaning runs
        FillRound(gr, 1, 1, w - 2, wh - 2, r, Argb("FFFFFF", 165))
    if c.pending                                      ; a new, unsaved picture
        Disc(gr, Dpx(13), Dpx(13), Dpx(3.5), Argb(LOOK.accent, 255))
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    if c.busy || !c.thumb
        PanelText(dc, c.busy ? "cleaning…" : hov ? "Choose a picture" : "No picture", 0, 0, w, wh, pnl.f["small"], LOOK.muted, 0x25)
    PanelText(dc, MOOD_NOTES[i], Dpx(4), wh + Dpx(10), w - Dpx(8), Dpx(22), pnl.f["cap"], LOOK.text)
    PanelText(dc, RangeText(i), Dpx(4), wh + Dpx(32), w - Dpx(8), Dpx(18), pnl.f["small"], LOOK.muted)
}

RangeText(i) {   ; "1–2 windows", "3–7 windows", "8+ windows"
    a := [1, pnl.some, pnl.many][i], b := [pnl.some - 1, pnl.many - 1, 0][i]
    return i = 3 ? a "+ windows" : a = b ? a (a = 1 ? " window" : " windows") : a "–" b " windows"
}

PaintStepper(i, dc, w, h, st) {   ; − value +; i: 2 = some starts at, 3 = many starts at, 4 = font size
    v := [0, pnl.some, pnl.many, pnl.size][i], lo := [0, 2, pnl.some + 1, 10][i], hi := [0, pnl.many - 1, 30, 24][i]
    side := st & 0x10000 ? pnl.side : 0, r := h / 2
    gr := Canvas(0, dc)
    FillRound(gr, 0.5, 0.5, w - 1, h - 1, r, Argb("F4EEE4", 255))
    if side && (side < 0 ? v > lo : v < hi)           ; the half under the mouse
        Disc(gr, side < 0 ? r : w - r, r, r - Dpx(3), Argb(LOOK.pill, 255))
    Stroke(gr, 0.5, 0.5, w - 1, h - 1, r, 1, Lip(220, LOOK.line, 210))
    FocusRing(gr, w, h, r, st)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    PanelText(dc, i = 4 ? v " pt" : v, 0, 0, w, h, pnl.f["num"], LOOK.text, 0x25)
    PanelText(dc, "−", 0, 0, 2 * r, h, pnl.f["body"], v > lo ? LOOK.muted : LOOK.faint, 0x25)
    PanelText(dc, "+", w - 2 * r, 0, 2 * r, h, pnl.f["body"], v < hi ? LOOK.muted : LOOK.faint, 0x25)
}

PaintChip(label, dc, w, h, st) {   ; "Clean" (background) or "Remove", a quiet pill
    hov := st & 0x10000, off := st & 4, gr := Canvas(0, dc), r := h / 2
    FillRound(gr, 0.5, 0.5, w - 1, h - 1, r, Argb(hov ? LOOK.pillHi : "FFFFFF", hov ? 255 : 150))
    Stroke(gr, 0.5, 0.5, w - 1, h - 1, r, 1, Lip(220, hov ? LOOK.pillRim : LOOK.line, 220))
    FocusRing(gr, w, h, r, st)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    PanelText(dc, label, 0, 0, w, h, pnl.f["small"], off ? LOOK.soft : LOOK.text, 0x25)
}

PaintButton(label, kind, dc, w, h, st) {   ; kind 0 = text link, 1 = quiet, 2 = primary (the switcher's selection pill)
    hov := st & 0x10000, down := st & 1, gr := Canvas(0, dc), r := h / 2
    if kind = 2 {
        FillRound(gr, 0.5, 0.5, w - 1, h - 1, r, Argb(down ? LOOK.pillRim : hov ? Mix(LOOK.pill, LOOK.pillRim, 0.45) : LOOK.pill, 255))
        Ring(gr, 0.5, 0.5, w - 1, h - 1, r, LOOK.pillRim, 255)
        DllCall("gdiplus\GdipCreatePen1", "uint", Argb(LOOK.pillHi, 255), "float", 1, "int", 2, "ptr*", &pen := 0)
        DllCall("gdiplus\GdipDrawLine", "ptr", gr, "ptr", pen, "float", r, "float", 2, "float", w - r, "float", 2)   ; glassy top highlight
        DllCall("gdiplus\GdipDeletePen", "ptr", pen)
    } else if kind = 1 {
        FillRound(gr, 0.5, 0.5, w - 1, h - 1, r, Argb("FFFFFF", down ? 230 : hov ? 200 : 110))
        Stroke(gr, 0.5, 0.5, w - 1, h - 1, r, 1, Lip(230, LOOK.line, 230))
    }
    FocusRing(gr, w, h, r, st)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    PanelText(dc, label, 0, 0, w, h, pnl.f[kind = 2 ? "num" : "body"], kind || hov ? LOOK.text : LOOK.muted, 0x25)
}

PaintKeys(j, dc, w, h, st) {   ; a shortcut field: what it's for, then its keys (a prompt while capturing)
    fh := Dpx(30), r := fh / 2, x := Dpx(14), hov := st & 0x10000, cap := pnl.cap && pnl.cap.j = j, gr := Canvas(0, dc)
    FillRound(gr, 0.5, 0.5, w - 1, fh - 1, r, Argb(cap ? LOOK.pill : hov ? LOOK.pillHi : "F4EEE4", 255))
    Stroke(gr, 0.5, 0.5, w - 1, fh - 1, r, 1, Lip(220, cap || hov ? LOOK.pillRim : LOOK.line, 210))
    FocusRing(gr, w, fh, r, st)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    label := j = 1 ? "Switch windows" : "Stay open", sz := Buffer(8)
    of := DllCall("SelectObject", "ptr", dc, "ptr", pnl.f["small"], "ptr")
    DllCall("GetTextExtentPoint32W", "ptr", dc, "str", label, "int", StrLen(label), "ptr", sz), DllCall("SelectObject", "ptr", dc, "ptr", of)
    lw := NumGet(sz, 0, "int") + 2                    ; +2: END_ELLIPSIS can want a pixel more
    PanelText(dc, label, x, 0, lw, fh, pnl.f["small"], LOOK.muted)
    PanelText(dc, cap ? "press a shortcut…" : pnl.keys[j], x + lw + Dpx(8), 0, w - 2 * x - lw - Dpx(8), fh
        , pnl.f[cap ? "small" : "num"], cap ? LOOK.muted : LOOK.text, 0x26)
}

PaintKeysLine(refused, dc, w, h, st) {   ; under the shortcut fields: going back (under the first), or why a capture was refused (across both)
    PanelText(dc, refused ? pnl.why : "back: " KeysBack(pnl.keys[1]), Dpx(14), 0, w - Dpx(28), h, pnl.f["small"], LOOK.muted)
}

PaintHint(dc, w, h, st) {
    PanelText(dc, PanelHintText(), 0, 0, w, h, pnl.f["small"], LOOK.muted)
}

PanelHintText() {   ; hovered element's hint (unless the message is about it: pnl.held), else the last message, else the standing hint
    if pnl.hover && pnl.hover != pnl.held && (e := pnl.el.Get(pnl.hover, 0)) && e.hint != ""
        return e.hint
    if pnl.note != ""
        return pnl.note
    return "Click a card to choose its picture, or drop one onto it."
}

; The BACKGROUND card: on a well like the LOOK cards', the pane in small (inset as theirs, so a pane's wide shape), its glass as
; the picked look draws it (MiniPane, no tiles) under the picture as it is (pnl.pane.bm, already that shape). With none, it
; says what a click does. A new, unsaved picture has the mood cards' dot.
PaintPane(dc, w, h, st) {
    p := pnl.pane, r := Dpx(12), hov := st & 0x10000, gr := Canvas(0, dc), well := RoundPath(0.5, 0.5, w - 1, h - 1, r)
    br := FadeBrush(0, 0, w, h, 90, hov ? [[LOOK.pillHi, 255, 0], [LOOK.pill, 150, 1]] : [[LOOK.wellTop, 140, 0], [LOOK.wellBot, 80, 1]])
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", well)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br), DllCall("gdiplus\GdipDeletePath", "ptr", well)
    x := Dpx(20), y := Dpx(16), pw := w - 2 * x, ph := h - Dpx(36), b := Dpx(10)
    path := RoundPath(x - b, y - b + Dpx(3), pw + 2 * b, ph + 2 * b, Dpx(8) + b)   ; under the pane a soft shadow, as PaintLook's
    EdgeFade(gr, path, LOOK.shadow, 0, 34, (pw - 2 * b) / (pw + 2 * b), (ph - 2 * b) / (ph + 2 * b), true)
    DllCall("gdiplus\GdipDeletePath", "ptr", path), pal := MiniPane(gr, pnl.look, x, y, pw, ph, Dpx(8), [], 0, 0)
    if p.bm {
        path := RoundPath(x, y, pw, ph, Dpx(8)), DllCall("gdiplus\GdipSetClipPath", "ptr", gr, "ptr", path, "int", 0)
        DllCall("gdiplus\GdipDrawImageRectI", "ptr", gr, "ptr", p.bm, "int", x, "int", y, "int", pw, "int", ph)
        DllCall("gdiplus\GdipResetClip", "ptr", gr), DllCall("gdiplus\GdipDeletePath", "ptr", path)
    }
    Stroke(gr, 0.5, 0.5, w - 1, h - 1, r, 1, Lip(210, hov ? LOOK.pillRim : LOOK.border, hov ? 230 : 120))
    FocusRing(gr, w, h, r, st)
    if p.pending
        Disc(gr, Dpx(13), Dpx(13), Dpx(3.5), Argb(LOOK.accent, 255))
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    if !p.bm
        PanelText(dc, "Choose a picture", x, y, pw, ph, pnl.f["small"], Mix(pal.text, pal.pane, 0.4), 0x25)
}

PaintPaneName(dc, w, h, st) {   ; under the BACKGROUND card, beside Remove: what it shows
    PanelText(dc, !pnl.pane.bm ? "Plain glass" : pnl.pane.pending ? "New picture" : "Your picture", 0, 0, w, h, pnl.f["cap"], LOOK.text)
}

; The WINDOWS tick box's row (all of it takes the click): a rounded box, white in a rim of the border colour, or while ticked
; (only this monitor's windows) the accent with a white check as on the picked LOOK card; its label beside it. The mouse over
; the row lights the box (pale fill and an accent rim, or a lighter accent), as the slider's knob; the keyboard focus rings it.
PaintTick(dc, w, h, st) {
    s := A_ScreenDPI / 96, b := Dpx(18), r := Dpx(4), x := Dpx(6), y := (h - b) // 2, lw := Dpx(1.5), hov := st & 0x10000
    on := pnl.monitors = "current", gr := Canvas(0, dc)
    if on
        FillRound(gr, x, y, b, b, r, Argb(hov ? Mix(LOOK.accent, "FFFFFF", 0.15) : LOOK.accent, 255))
    else {
        FillRound(gr, x, y, b, b, r, Argb(hov ? LOOK.pillHi : "FFFFFF", 255))
        Ring(gr, x + lw / 2, y + lw / 2, b - lw, b - lw, r - lw / 2, hov ? LOOK.accent : LOOK.border, 255, lw)
    }
    if (st & 0x10) && !(st & 0x200)                   ; ODS_FOCUS without ODS_NOFOCUSRECT, as FocusRing
        Ring(gr, x - Dpx(3), y - Dpx(3), b + Dpx(6), b + Dpx(6), r + Dpx(3), LOOK.accent, 200, 2)
    if on {
        cx := x + b / 2, cy := y + b / 2
        DllCall("gdiplus\GdipCreatePen1", "uint", 0xFFFFFFFF, "float", 1.8 * s, "int", 2, "ptr*", &pen := 0)
        DllCall("gdiplus\GdipSetPenStartCap", "ptr", pen, "int", 2), DllCall("gdiplus\GdipSetPenEndCap", "ptr", pen, "int", 2)   ; round
        DllCall("gdiplus\GdipSetPenLineJoin", "ptr", pen, "int", 2)
        pts := Buffer(24), NumPut("float", cx - 4 * s, "float", cy + 0.1 * s, "float", cx - 1.2 * s, "float", cy + 2.9 * s
            , "float", cx + 4.1 * s, "float", cy - 2.6 * s, pts)
        DllCall("gdiplus\GdipDrawLines", "ptr", gr, "ptr", pen, "ptr", pts, "int", 3), DllCall("gdiplus\GdipDeletePen", "ptr", pen)
    }
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    PanelText(dc, "Only this monitor's windows", x + b + Dpx(10), 0, w - x - b - Dpx(10), h, pnl.f["body"], LOOK.text)
}

PaintSlider(j, dc, w, h, st) {   ; track 30–100 %, filled to the knob; knob lit from the bottom-left
    r := Dpx(8), x0 := r + 1, x1 := w - r - 1, cy := h / 2, hot := st & 0x10000 || pnl.drag && pnl.el[pnl.drag].j = j
    cx := x0 + (pnl.peek[j] - 30) / 70 * (x1 - x0)
    gr := Canvas(0, dc)
    FillRound(gr, x0, cy - Dpx(2), x1 - x0, Dpx(4), Dpx(2), Argb("E7DDCC", 255))
    FillRound(gr, x0, cy - Dpx(2), Max(cx - x0, Dpx(4)), Dpx(4), Dpx(2), Argb(LOOK.accent, 170))
    Disc(gr, cx + 1, cy - 1, r + 1, Argb(LOOK.shadow, 22))           ; shadow, away from the light
    Disc(gr, cx, cy, r, Argb("FFFFFF", 255), Argb(hot ? LOOK.accent : LOOK.border, 255))
    if (st & 0x10) && !(st & 0x200)
        Disc(gr, cx, cy, r + Dpx(3), 0, Argb(LOOK.accent, 150))
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
}

PaintSample(dc, w, h, st) {   ; one list row in the chosen font, selected like in the switcher
    gr := Canvas(0, dc)
    FillRound(gr, 0.5, 0.5, w - 1, h - 1, Dpx(10), Argb(LOOK.card, 255))
    Stroke(gr, 0.5, 0.5, w - 1, h - 1, Dpx(10), 1, Lip(230, LOOK.line, 170))
    of := DllCall("SelectObject", "ptr", dc, "ptr", pnl.f["sample"], "ptr")
    title := "Visual Studio Code", sz := Buffer(8), DllCall("GetTextExtentPoint32W", "ptr", dc, "str", title, "int", StrLen(title), "ptr", sz)
    tw := NumGet(sz, 0, "int") + 2                    ; read before "Ag" reuses sz; +2: END_ELLIPSIS can want a pixel more
    DllCall("GetTextExtentPoint32W", "ptr", dc, "str", "Ag", "int", 2, "ptr", sz), DllCall("SelectObject", "ptr", dc, "ptr", of)
    rh := NumGet(sz, 4, "int") + Dpx(12), y := (h - rh) / 2
    FillRound(gr, Dpx(6), y, w - Dpx(12), rh, Dpx(7), Argb(LOOK.pill, 255))
    Ring(gr, Dpx(6) + 0.5, y + 0.5, w - Dpx(12) - 1, rh - 1, Dpx(7), LOOK.pillRim, 255)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    x := Dpx(20)
    PanelText(dc, title, x, y, tw, rh, pnl.f["sample"], LOOK.text)
    PanelText(dc, "   —   視窗 · ウィンドウ", x + tw, y, w - x - tw - Dpx(14), rh, pnl.f["sample"], LOOK.muted)
}
