; #Included by meowtab.test.ahk where its settings panel checks run: these top-level lines run there, in order.
; The BACKGROUND section (pane-background spec, "The panel sets the picture"): a file dropped on its card waits there, shown
; cut to the pane's shape; Save's file work (PanelSave's: the test can't reload) makes it pane.png and PANE_PICTURE; Cancel
; changes nothing; Remove and Save delete both; Classic's panel has no such section. Each card's frame takes a file dropped on
; it (PanelDrop's frame order). Uses Painted, SameBytes (gif-panel.ahk), PicSays, Ini.

; A 500 x 100 PNG: green, with red then blue in its middle 300 px. Cut from the middle to a 2.5 : 1 pane (250 px across) only
; red and blue show; stretched or fitted whole, the green would.
BandsPng(file) {
    gr := Canvas(bm := NewBitmap(500, 100)), DllCall("gdiplus\GdipGraphicsClear", "ptr", gr, "uint", 0xFF00C000)
    for c in [0xFFFF0000, 0xFF0000FF]
        DllCall("gdiplus\GdipCreateSolidFill", "uint", c, "ptr*", &br := 0)
        , DllCall("gdiplus\GdipFillRectangleI", "ptr", gr, "ptr", br, "int", 100 + 150 * (A_Index - 1), "int", 0, "int", 150, "int", 100)
        , DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr), SavePng(bm, file), DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    return file
}
; A file dropped on the open panel's page in the middle of frame f, as the page's DropFiles event passes it on. (AHK gives the
; event the cursor's place, not the drop's: a posted WM_DROPFILES can't aim without moving the user's mouse.)
DropAt(file, f) => PanelDrop(pnl.page, 0, [file], f[1] + f[3] // 2, f[2] + f[4] // 2)
Bytes(file) => FileExist(file) ? FileRead(file, "RAW") : Buffer(0)   ; a file's bytes; none if it's missing (no error dialog to hold the run)
; The open panel's BACKGROUND card as its painter draws it (Painted): "glass" if as with no picture (paneGlass), else its pane's
; colours (RRGGBB) near its left and right edges, halfway down; then " + Remove" while that chip shows.
CardShows() {
    e := pnl.pane.card, px := Painted(e), x := Dpx(23), y := Dpx(16) + (e.h - Dpx(36)) // 2
    s := SameBytes(px, paneGlass) ? "glass" : Format("{:06X} {:06X}", NumGet(px, (y * e.w + x) * 4, "uint") & 0xFFFFFF
        , NumGet(px, (y * e.w + e.w - 1 - x) * 4, "uint") & 0xFFFFFF)
    return s (pnl.pane.remove.ctl.Visible ? " + Remove" : "")
}

PANEL_ROOM := Dpx(3000), bands := BandsPng(DATA_DIR "\bands.png"), paneFile := UserImagesDir() "\pane.png"   ; the whole page paints
FileAppend("not a picture", notPic := DATA_DIR "\not-a-picture.png")
SettingsOpen(), Wait(300), paneGlass := Painted(pnl.pane.card), bg := pnl.frames[pnl.frames.Length], got := CardShows()
DropAt(notPic, bg), got .= " | " pnl.note " " CardShows()
Check("the BACKGROUND card opens as plain glass; a file that isn't a picture dropped on it is refused with the reason, and nothing waits"
    , got " " FileExist(PanePending()), "glass | That file didn't work: can't read that file as a picture (PNG, JPG, BMP or GIF). glass ")
DropAt(bands, bg), got := CardShows() " " pnl.pane.pending
vals := PanelVals(), err := PaneCommit(pnl.pane.gone) SettingsWrite(vals)   ; Save's file work
Check("a PNG dropped on it waits there, shown cut to the pane's shape from its middle, with Remove; Save's file work makes it pane.png"
    . " and PANE_PICTURE=pane.png, and nothing waits", got " | " err "[" Ini("PANE_PICTURE") "] " PicSays(paneFile) " " FileExist(PanePending())
    , "FF0000 0000FF + Remove 1 | [pane.png] 500 x 100 PNG ")
PanelClose(), PANE_PICTURE := Ini("PANE_PICTURE")   ; as the reload loads it

; Cancel: a drop with pane.png saved, then the panel closed without saving.
saved := Bytes(paneFile), iniWas := Bytes(DATA_DIR "\settings.ini"), gold := DATA_DIR "\gold.png"
gr := Canvas(bm := NewBitmap(64, 64)), DllCall("gdiplus\GdipGraphicsClear", "ptr", gr, "uint", 0xFFFFC000), DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
SavePng(bm, gold), DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
SettingsOpen(), Wait(300), got := CardShows() " " pnl.pane.pending
DropAt(gold, pnl.frames[pnl.frames.Length]), got .= " -> " CardShows() " " pnl.pane.pending, PanelClose()
Check("with pane.png saved the card shows it, with Remove; a drop then waits there, and Cancel leaves settings.ini and pane.png as they were"
    . ", and no pending file", got " | " SameBytes(iniWas, Bytes(DATA_DIR "\settings.ini")) " " SameBytes(saved, Bytes(paneFile)) " [" FileExist(UserImagesDir() "\*.pending.*") "]"
    , "FF0000 0000FF + Remove 0 -> FFC000 FFC000 + Remove 1 | 1 1 []")

; Remove, then Save's file work.
SettingsOpen(), Wait(300), ControlClick(pnl.pane.remove.ctl), Wait(100)
got := CardShows() " " pnl.pane.gone " " (DllCall("GetFocus", "ptr") = pnl.pane.card.ctl.Hwnd)
vals := PanelVals(), err := PaneCommit(pnl.pane.gone) SettingsWrite(vals)
Check("Remove puts the card back to plain glass, the chip gone and the focus on the card; Save's file work then leaves no PANE_PICTURE"
    . " line and deletes pane.png", got " | " err "[" Ini("PANE_PICTURE") "] " (FileExist(paneFile) != ""), "glass 1 1 | [] 0")
PanelClose(), PANE_PICTURE := ""

; Frame order: a drop on each frame, nothing else waiting, lands on that frame's card (none for a LOOK card).
SettingsOpen(), Wait(300), got := ""
for i, f in pnl.frames {
    PendingClear()
    for k in [1, 2, 3]
        PanelLoadCard(k)
    PanelLoadPane(), DropAt(bands, f), took := ""
    for c in pnl.cards
        took .= c.pending ? " " c.mood : ""
    got .= i ":" took (pnl.pane.pending ? " background" : "") "; "
}
PanelClose(), PANEL_ROOM := 0
Check("a drop on each card lands on that card: the three mood cards, not the two LOOK cards, then the BACKGROUND card"
    , got, "1: few; 2: some; 3: many; 4:; 5:; 6: background; ")

; Classic's own panel, opened by Classic in a process of its own on a data folder of its own.
classicPane := DATA_DIR "\classic-pane.ahk", paneAnswer := DATA_DIR "\classic-pane.txt"
FileOpen(classicPane, "w").Write("#NoTrayIcon`nOnError((e, *) => (FileAppend('error: ' e.Message, A_Args[1]), ExitApp(3)))`n"
    . "DATA_DIR := A_ScriptDir '\classic-pane'`n#Include " AppDir() "meowtab-classic.ahk`n" "
(
SettingsOpen(), n := 0
for hwnd, e in pnl.el
    n += e.kind = 'pane'
for l in pnl.labels
    n += l[1] = 'BACKGROUND'
FileAppend(n ' BACKGROUND elements, ' pnl.frames.Length ' card frames, PANE_PICTURE saved: ' PanelVals().Has('PANE_PICTURE'), A_Args[1]), ExitApp()
)")
Run('"' A_AhkPath '" /ErrorStdOut "' classicPane '" "' paneAnswer '"', , , &pid)
if stuck := ProcessWaitClose(pid, 10)             ; still running after 10 s: an error dialog on its way out holds it
    ProcessClose(pid)
Check("Classic's own panel has no BACKGROUND section, and its Save writes no PANE_PICTURE"
    , (FileExist(paneAnswer) ? FileRead(paneAnswer) : "no answer") (stuck ? ", then stuck" : ""), "0 BACKGROUND elements, 3 card frames, PANE_PICTURE saved: 0")
