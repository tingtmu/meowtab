; #Included by meowtab.test.ahk where its pane drawing checks run: these top-level lines run there, in order.
; The pane's background picture (PANE_PICTURE) drawn under the tiles (pane-background design 1-2), in this run's look.

; Render's pixels for a layout with nothing of this machine in it, light | dark: the CRC-32 of the surface (RtlComputeCrc32). 9 windows
; (the fixed grid: its tiles shaped by the work area alone) in a 1600 x 1000 work area at 100 %, a 16 px title line, no titles or
; icons, tile 1 selected and tile 2 hovered, the palette's own ring.
RenderHash() {
    global wins := Repeat(9), idx := 1, hover := 2, hoverX := false, pal, accentRgb, titleLineH
    keep := titleLineH, titleLineH := 16, GridLayout(1600, 1000, 0, 0, 1), titleLineH := keep, out := ""
    for t in tiles
        t.title := ""
    for d in [false, true] {
        pal := PANE_LOOK = "velvet" ? (d ? VELVET_DARK : VELVET_LIGHT) : d ? DARK_PAL : LIGHT_PAL, accentRgb := pal.ring
        s := SurfaceMake(grid.w, grid.h), Render(s)
        out .= Format("{}{:08X}", d ? " | dark " : "light ", DllCall("ntdll\RtlComputeCrc32", "uint", 0, "ptr", s.bits, "uint", 4 * s.w * s.h, "uint")), SurfaceFree(s)
    }
    hover := 0
    return out
}

; Surface s's pixel x, y (premultiplied): "red" or "blue" where that colour alone is there at the picture's strength (PANE_PIC_ALPHA,
; ±2), else "A R G B"; loose (Velvet's tint lies over the picture): the one of red and blue that leads the other by over 40.
PicTone(s, x, y, loose := false) {
    c := NumGet(s.bits, 4 * (y * s.w + x), "uint"), a := c >> 24, r := c >> 16 & 0xFF, g := c >> 8 & 0xFF, b := c & 0xFF
    if loose
        return r - b > 40 ? "red" : b - r > 40 ? "blue" : Format("{} {} {} {}", a, r, g, b)
    at := Abs(a - PANE_PIC_ALPHA) <= 2 && g <= 2
    return at && Abs(r - a) <= 2 && b <= 2 ? "red" : at && Abs(b - a) <= 2 && r <= 2 ? "blue" : Format("{} {} {} {}", a, r, g, b)
}

plain := PANE_LOOK = "velvet" ? "light A6EACF8B | dark 90D30E2C" : "light 1F61CC6A | dark D3047086"   ; recorded before the picture
Check("with no picture the pane draws as before the background picture (a fixed layout's pixels, as recorded then)", RenderHash(), plain)

; A picture of a red left half and a blue right half, 1600 x 900 (the spec's wide picture), on a 900 x 900 pane with no tiles: its
; middle 900 x 900 part fills it. Read along the middle row: the left padding, either side of the middle, the right padding; in the
; picture's layer, and in the surface in light and dark mode (Velvet's tint over the picture: only which colour leads).
bm := NewBitmap(1600, 900), gr := Canvas(bm), DllCall("gdiplus\GdipGraphicsClear", "ptr", gr, "uint", 0xFFFF0000)
DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xFF0000FF, "ptr*", &br := 0), DllCall("gdiplus\GdipFillRectangleI", "ptr", gr, "ptr", br, "int", 800, "int", 0, "int", 800, "int", 900)
DllCall("gdiplus\GdipDeleteBrush", "ptr", br), DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr), SavePng(bm, DATA_DIR "\images\pane.png"), DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
PANE_PICTURE := "pane.png", PanePicLoad(), tiles := [], idx := 0, got := ""
for d in [false, true] {
    pal := PANE_LOOK = "velvet" ? (d ? VELVET_DARK : VELVET_LIGHT) : d ? DARK_PAL : LIGHT_PAL, sq := SurfaceMake(900, 900), Render(sq), got .= d ? "; dark:" : " | light:"
    for x in [20, 440, 460, 880]
        got .= " " PicTone(sq, x, 450, PANE_LOOK = "velvet")
    SurfaceFree(sq)
}
inLayer := "layer:"
for x in [20, 440, 460, 880]
    inLayer .= " " PicTone(picLayer, x, 450)
Check("a red | blue picture on a square pane: its middle fills it, red on the left and blue on the right, at PANE_PIC_ALPHA (within 2) in the layer, "
    . (PANE_LOOK = "velvet" ? "red then blue under Velvet's tint" : "and so in the surface"), inLayer got
    , "layer: red red blue blue | light: red red blue blue; dark: red red blue blue")

; The layer is made once per pane size: two opens on 3 windows share it, one on 6 (another pane size) makes a new one and frees the
; old. The open pane shows the picture in its left padding.
Open(3, 1), was := picLayer.hbm, Finish(false), Wait(0)
Open(3, 1), got := (picLayer.hbm = was) " " PicTone(surf, grid.pad // 2, grid.h // 2, PANE_LOOK = "velvet"), Finish(false), Wait(0)
Open(6, 1), got .= " " (picLayer.hbm != was) " " DllCall("GetObjectType", "ptr", was), Finish(false), Wait(0)
Check("two opens on 3 windows share the picture's layer (the same bitmap), red in the pane's left padding; one on 6 makes a new one and frees the old"
    , got, "1 red 1 0")

; A 2560 x 1 strip on a 900 x 900 pane: only its middle is scaled (scaled whole to cover, it would be 2304000 px wide, past WIC's limit).
bm := NewBitmap(2560, 1), SavePng(bm, DATA_DIR "\images\pane.png"), DllCall("gdiplus\GdipDisposeImage", "ptr", bm), PanePicLoad()
Check("a 2560 x 1 strip on a 900 x 900 pane still makes its layer", (strip := PaneLayer(900, 900)) ? strip.w " x " strip.h : "none", "900 x 900")

; A PANE_PICTURE file that isn't a picture (SettingsLoad only sees that it exists): none, reported naming PANE_PICTURE; then the pane
; draws as before the picture again.
FileAppend("not a picture", DATA_DIR "\images\junk.png"), PANE_PICTURE := "junk.png", SETTINGS_ISSUES := [], PanePicLoad()
Check("a PANE_PICTURE file that isn't a picture gives none and reports the line; the pane then draws as without a picture"
    , "[" PANE_PICTURE "] " (panePic || picLayer ? "a picture" : "none") ", " SETTINGS_ISSUES.Length ": " (SETTINGS_ISSUES.Length ? SETTINGS_ISSUES[1] : "")
    . (RenderHash() = plain ? ", as before" : ", drawn otherwise"), "[] none, 1: PANE_PICTURE = junk.png: can't read it as a picture, using none, as before")
FileDelete(DATA_DIR "\images\pane.png"), FileDelete(DATA_DIR "\images\junk.png")
