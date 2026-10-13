; #Included by meowtab.test.ahk where its look checks run: these top-level lines run there, in order.
; The look, read from the pane's own pixels: the hovered header, the close button, the lift, Velvet's motion; then gif-peek.ahk.

; The pane's own pixel x, y (Render's surface, premultiplied) composited over the palette's plain colour, pal.pane: [r, g, b].
PanePx(x, y) {
    bm := Buffer(32, 0), DllCall("GetObject", "ptr", surf.hbm, "int", 32, "ptr", bm)   ; BITMAP: bmBits
    c := NumGet(NumGet(bm, A_PtrSize = 8 ? 24 : 20, "ptr"), 4 * (y * surf.w + x), "uint"), k := 1 - (c >> 24) / 255, p := Integer("0x" pal.pane)
    return [(c >> 16 & 0xFF) + (p >> 16) * k, (c >> 8 & 0xFF) + (p >> 8 & 0xFF) * k, (c & 0xFF) + (p & 0xFF) * k]
}
Luma(c) => 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]   ; brightness, 0-255 (Rec. 601)

; How much tile i's header changes when hovered (design 6): its mean brightness left of the icon, hovered less plain.
HoverStep(i) {
    global hover, hoverX
    t := tiles[i], y0 := TileY(t) + Round(grid.hdr * 0.3), y1 := TileY(t) + Round(grid.hdr * 0.85), x1 := t.x + Round(ICON_X * grid.S) - 3
    m := []
    for hv in [0, i] {
        hover := hv, hoverX := false, Render(surf), sum := n := 0
        Loop y1 - y0 {
            y := y0 + A_Index - 1
            Loop x1 - t.x - 3
                sum += Luma(PanePx(t.x + 2 + A_Index, y)), n += 1
        }
        m.Push(sum / n)
    }
    return m[2] - m[1]
}

; Tile i's close button with the mouse on the tile, then on the button, at a point above its middle (inside Velvet's disc, clear
; of the X) and one left of that (outside the disc, inside the Windows 11 look's square): "RRGGBB" where red, else "grey"
; (in Velvet the first as RedOver the second); ", disc" when the first stands out from the second.
CloseTones(i) {
    global hover, hoverX
    t := tiles[i], x := t.x + t.w - CloseW(t) // 2, y := TileY(t) + grid.hdr // 2 - Round(VELVET_CLOSE * grid.S * 0.3)
    s := ""
    for onX in [false, true] {
        hover := i, hoverX := onX, Render(surf), c := PanePx(x, y), out := PanePx(x - Round(VELVET_CLOSE * grid.S * 0.75), y)
        s .= (onX ? "; on it " : "on the tile ") (PANE_LOOK = "velvet" ? RedOver(c, out) : Tone(c)) " " Tone(out) (Abs(Luma(c) - Luma(out)) >= 6 ? ", disc" : "")
    }
    return s
}
Tone(c) => c[1] - (c[2] + c[3]) / 2 > 100 ? Format("{:02X}{:02X}{:02X}", Round(c[1]), Round(c[2]), Round(c[3])) : "grey"

; How much CLOSE_RGB covers pixel c over the plain header beside it, out (least squares over r, g, b): "soft red" at 70-85 %
; (Velvet's disc on the hovered tile: alpha 200, 78 %), "full red" from 97 %, else the share.
RedOver(c, out) {
    red := Integer("0x" CLOSE_RGB), num := den := 0
    for k, v in [red >> 16, red >> 8 & 0xFF, red & 0xFF]
        num += (c[k] - out[k]) * (v - out[k]), den += (v - out[k]) ** 2
    a := num / den
    return a >= 0.97 ? "full red" : a >= 0.7 && a <= 0.85 ? "soft red" : Format("red at {:.0f} %", 100 * a)
}

; DWM's rectangle for tile t's thumbnail, as ThumbPlace last set it (t.props): [left, top, right, bottom].
ThumbRect(t) => [NumGet(t.props, 4, "int"), NumGet(t.props, 8, "int"), NumGet(t.props, 12, "int"), NumGet(t.props, 16, "int")]

; One open on A-D, as Step makes it, with Velvet's motion on or off through the app's seam (ANIM_EFFECTS), never Windows' own
; setting: whether the pane is layered (easing in) at its first frame, read on the open's line (ShowPane leaves this thread
; Critical: no tick has run yet), and once eased in; then Tab, read on its line too: whether a light-up is under way, the
; selection's strength under tile 2 (ShadeUnder: 0 as before the Tab, 1 as once still), and tile 1's and tile 2's thumbnails;
; then the ms until the light-up is over, and once all is still tile 2's thumbnail, and where tile 1's belongs (ThumbsShow).
MotionOpen(on) {
    global ANIM_EFFECTS := on, wins := Repeat(4), idx := 1, cycling := true
    ShowPane(true), first := Layered(), Wait(VELVET_IN_MS + 100), eased := Layered(), none := ShadeUnder(tiles[2])
    Step(1), t0 := A_TickCount, moving := glow ? 1 : 0, lit := ShadeUnder(tiles[2]), was := ThumbRect(tiles[1]), start := ThumbRect(tiles[2])
    while glow && A_TickCount - t0 < 500
        Wait(5)
    took := A_TickCount - t0, Wait(100), full := ShadeUnder(tiles[2]), end := ThumbRect(tiles[2]), ThumbsShow(), rest := ThumbRect(tiles[1])
    Finish(false), Wait(0)
    return {first: first, eased: eased, moving: moving, lit: full = none ? -1 : (lit - none) / (full - none), took: took
        , settles: Format("{} {} {} {}", was*) = Format("{} {} {} {}", rest*), grew: end[3] - end[1] - start[3] + start[1]
        , start: Format("{} {} {} {}", start*), end: Format("{} {} {} {}", end*)}
}
Layered() => DllCall("GetWindowLongPtrW", "ptr", g.Hwnd, "int", -20, "ptr") >> 19 & 1   ; the pane has WS_EX_LAYERED (Velvet's ease-in)

; The selection around tile t as the pane shows it now: the surface's alpha summed down a short line below the middle of its
; frame as lifted, clear of the tile at any lift, where Velvet's shadow is deep (and the Windows 11 look's ring).
ShadeUnder(t) {
    bm := Buffer(32, 0), DllCall("GetObject", "ptr", surf.hbm, "int", 32, "ptr", bm), bits := NumGet(bm, A_PtrSize = 8 ? 24 : 20, "ptr")
    x := t.x + t.w // 2, y0 := Ceil(TileY(t) + grid.th * (1 + VELVET_LIFT / 2)) + 2, sum := 0
    Loop Round(8 * grid.S)
        sum += NumGet(bits, 4 * ((y0 + A_Index) * surf.w + x), "uint") >> 24
    return sum
}

; Tab's selection as MotionOpen read it: at once at full strength, or lit up from partial strength (0.35 to 0.7: 0.4, or
; about 0.64 if A_TickCount's 15.6 ms step falls between the start and the first frame) to full within VELVET_GLOW_MS and 4
; animation ticks (room for a late tick or two); then tile 1's and tile 2's thumbnails.
LightUp(o) => (!o.moving ? (o.lit = 1 ? "at once at full strength" : Format("at once at {:.2f}", o.lit))
    : o.lit < 0.35 || o.lit > 0.7 ? Format("lights up from {:.2f}", o.lit)
    : o.took > VELVET_GLOW_MS + 4 * ANIM_TICK ? "lights up from partial strength, full in " o.took " ms"
    : "lights up from partial strength, full within its " VELVET_GLOW_MS " ms and 4 ticks")
    . ", tile 1 " (o.settles ? "settles at once" : "settles late") ", tile 2's thumbnail " (o.start = o.end ? "stays put" : o.grew > 0 ? "grows" : "shrinks")

; The look, read from the pane's own pixels: this run's (PANE_LOOK; the gate runs the test in each), in light and in dark mode,
; switched as readme-shots does. ShowPane leaves this thread Critical: no timer redraws until the Wait.
was := dark, steps := [], tones := ""
for d in [false, true] {
    dark := d, wins := Repeat(4), idx := 1, cycling := true, ShowPane(true)
    steps.Push(HoverStep(2)), tones .= (d ? " | dark: " : "light: ") CloseTones(2), Finish(false), Wait(0)
}
dark := was
Check("the hovered header is at least 12 levels brighter or darker than a plain one, in light and in dark mode"
    , Abs(steps[1]) >= 12 && Abs(steps[2]) >= 12 ? "at least 12" : Format("light {:.1f}, dark {:.1f}", steps*), "at least 12")
Check(PANE_LOOK = "velvet" ? "Velvet's close button: a soft red disc on the hovered tile, full red with the mouse on it"
    : "the close button: red on the hovered tile, darker red with the mouse on it, as before", tones
    , Format("light: {1} | dark: {1}", PANE_LOOK = "velvet" ? "on the tile soft red grey, disc; on it full red grey, disc" : "on the tile E81123 E81123; on it C42B1C C42B1C"))
; Velvet's close button is its disc: a point in the Windows 11 look's square button but off the disc (2 px in from the square's
; left, at the header's middle) is plain header, so it isn't lit and a click there switches to the window. In the Windows 11 look
; the point is on the button: lit, and a click closes the window. The cursor rests there as the pane opens: the first frame's hover.
xw := Gui(, "alttab-test X"), xw.Show("NA w300 h200"), Sleep(300)
Open(4, 1, Map(2, xw.Hwnd)), t := tiles[2], x := t.x + t.w - CloseW(t) + 2, y := TileY(t) + grid.hdr // 2, g.GetClientPos(&px, &py), Finish(false), Wait(0)
MouseMove(px + x, py + y, 0), wins := Repeat(4, Map(2, xw.Hwnd)), idx := 1, cycling := true, ShowPane(true), lit := hoverX, Wait(0)
DllCall("SendMessageW", "ptr", g.Hwnd, "uint", 0x201, "ptr", 1, "ptr", y << 16 | x), DllCall("SendMessageW", "ptr", g.Hwnd, "uint", 0x202, "ptr", 0, "ptr", y << 16 | x)
Wait(400), got := lit " " DllCall("IsWindowVisible", "ptr", xw.Hwnd) " " cycling, MouseMove(0, 0, 0), Finish(false), Wait(0), xw.Destroy()
Check(PANE_LOOK = "velvet" ? "in Velvet a point in the square close button's place but off the disc isn't lit, and a click there switches to the window"
    : "in the Windows 11 look that point is on the square close button: lit, and a click there closes the window", got, PANE_LOOK = "velvet" ? "0 1 0" : "1 0 1")
Open(4, 1), rest := ThumbRect(tiles[2]), Step(1), lifted := ThumbRect(tiles[2]), Step(1), after := ThumbRect(tiles[2]), Finish(false), Wait(0)
grow := (lifted[3] - lifted[1]) / (rest[3] - rest[1])   ; Tab to tile 2, then on to tile 3: its thumbnail's width, selected / not
Check("Tab lifts the selected thumbnail about 2 % in Velvet (not in Windows 11), and the next Tab puts it back"
    , (Abs(grow - 1.02) <= 0.015 ? "about 2 % larger" : grow = 1 ? "the same size" : Round(grow, 3) " times as wide")
    . (Format("{} {} {} {}", after*) = Format("{} {} {} {}", rest*) ? ", then back" : ", then not back")
    , (PANE_LOOK = "velvet" ? "about 2 % larger" : "the same size") ", then back")

; Velvet's motion, switched through the app's seam (MotionOpen). Off, the first frame is final and nothing moves after it; on, only
; Velvet moves: the pane eases in, and Tab's selection lights up in place on the next tile (LightUp), its thumbnail growing into
; its lift and landing as it does without, while tile 1's settles at once.
off := MotionOpen(false), on := MotionOpen(true), atOnce := "at once at full strength, tile 1 settles at once, tile 2's thumbnail stays put"
Check("with Animation effects off the first frame is final: the pane isn't layered, Tab's selection is on tile 2 at once at full strength (no light-up), tile 1 settles at once and tile 2's thumbnail stays put after"
    , off.first " " off.eased ", " LightUp(off), "0 0, " atOnce)
Check(PANE_LOOK = "velvet" ? "with it on Velvet eases in (layered, then not), and Tab's selection lights up on tile 2 from partial strength to full within VELVET_GLOW_MS and 4 ticks, tile 1 settling at once, tile 2's thumbnail growing and landing as without motion"
    : "with it on the Windows 11 look still has no motion", on.first " " on.eased ", " LightUp(on) ", " (on.end = off.end ? "lands as without motion" : "lands elsewhere")
    , (PANE_LOOK = "velvet" ? "1 0, lights up from partial strength, full within its " VELVET_GLOW_MS " ms and 4 ticks, tile 1 settles at once, tile 2's thumbnail grows"
    : "0 0, " atOnce) ", lands as without motion")
; A close mid-motion (Tab, then Esc at once) leaves no motion timer running. The hidden pane is then made layered at alpha 1, a
; probe that a tick of the ease-in would change; the light-up's frames are ScrollTick's, which the close stops, the picture's PeekTick's.
ANIM_EFFECTS := true, Open(4, 1), Step(1), Finish(false), shut := Layered(), ex :=DllCall("GetWindowLongPtrW", "ptr", g.Hwnd, "int", -20, "ptr")
DllCall("SetWindowLongPtrW", "ptr", g.Hwnd, "int", -20, "ptr", ex | 0x80000, "ptr"), DllCall("SetLayeredWindowAttributes", "ptr", g.Hwnd, "uint", 0, "uchar", 1, "uint", 2)
Wait(VELVET_IN_MS + 100), DllCall("GetLayeredWindowAttributes", "ptr", g.Hwnd, "ptr", 0, "uchar*", &alpha := 0, "ptr", 0)
probe := Layered() " " alpha, DllCall("SetWindowLongPtrW", "ptr", g.Hwnd, "int", -20, "ptr", ex, "ptr"), ANIM_EFFECTS := false
Check("a close mid-motion leaves no motion timer running: the pane not layered, no light-up, the picture hidden, the probe's alpha untouched"
    , shut " " (glow ? 1 : 0) " " DllCall("IsWindowVisible", "ptr", peek.Hwnd) " " probe, "0 0 0 1 1")
#Include %A_LineFile%\..\gif-peek.ahk
