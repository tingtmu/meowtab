; The Settings… panel's pictures (#Included by settings-panel.ahk; functions only): a mood card's pick, drop and import,
; the cards' loading and GIF playback, the Clean chips and Clean background, and the BACKGROUND card's pick, remove and load.

PanelPick(i, *) {   ; card click: file picker, opened where the cats are (the app's images folder)
    pnl.gui.Opt("+OwnDialogs")
    if pnl.cards[i].busy
        return
    f := FileSelect(1, A_ScriptDir "\" IMG_DIR, "Choose the picture for “" MOOD_NOTES[i] "”", "Pictures (*.png; *.jpg; *.jpeg; *.bmp; *.gif)")
    if f != "" && pnl
        PanelImport(i, f)
}

PanelDrop(gui, ctl, files, x, y) {   ; a file dropped on the page (x, y on it, however scrolled): the picture card under it takes it
    if gui = pnl.page
        for i, f in pnl.frames                        ; the mood cards' come first, the BACKGROUND card's last (the LOOK cards' take no pictures)
            if x >= f[1] && x < f[1] + f[3] && y >= f[2] && y < f[2] + f[4] {
                if i <= pnl.cards.Length
                    return pnl.cards[i].busy ? 0 : PanelImport(i, files[1])
                if pnl.pane && i = pnl.frames.Length
                    return PanelPane(files[1])
            }
    PanelNote(pnl.pane ? "Drop the picture onto a mood card or the background card." : "Drop the picture onto one of the three cards.")
}

PanelImport(i, file) {   ; the picture becomes this card's pending one (images\custom_<mood>.pending.png or .gif)
    if why := ImportImage(file, PendingImage(Moods()[i]))
        return PanelNote("That file didn't work: " why ".")
    pnl.dirty := true, PanelLoadCard(i)
    PanelNote("New picture for “" MOOD_NOTES[i] "”. Save to use it, or clean its background first.")
}

; (Re)load card i's picture: the pending one, else the current set's. Peek keeps all its frames, as strips (GifStrip): at the
; card's size, and at IMG_SIZE with its art span over all frames (as the switcher measures it) for the peek scenes; the card's
; clock starts again from its first frame (PanelFrame). Classic shows a GIF still: its first frame (FitBitmap).
PanelLoadCard(i) {
    c := pnl.cards[i], old := [c.thumb, c.big]
    pending := FileExist(PendingImage(c.mood)) != ""
    file := pending ? PendingImage(c.mood) : MoodImage(IMG_PREFIX, c.mood)
    delays := [100], span := [0, 1], big := 0
    if pnl.peek
        thumb := GifStrip(file, Dpx(112), , &delays, true), big := GifStrip(file, IMG_SIZE, &span, , true)
    else
        thumb := FitBitmap(file, Dpx(112))
    Critical                                          ; a paint may interrupt between lines: swap, then free
    c.pending := pending, c.file := file, c.thumb := thumb, c.big := big, c.span := span, c.delays := delays, c.f := 0, c.t0 := A_TickCount
    Critical "Off"
    for b in old
        if b
            DllCall("gdiplus\GdipDisposeImage", "ptr", b)
    PanelChips(), PanelPlay(), PanelRedraw("card", "scene", "hint")
}

; The cards' GIFs play while the panel is open: in MeowTab only (the peek scenes'), with Windows' "Animation effects" on (read
; now, as the switcher reads it at an open: Animates), and only while a card has more than one frame. One timer for all cards.
PanelPlay() {
    global pnlPlay
    on := false
    if pnl.peek && SettingsGet("Animates")()          ; by name: Classic has no Animates, and a plain call would keep it from loading
        for c in pnl.cards
            on := on || c.delays.Length > 1
    if on || pnlPlay
        SetTimer(PanelFrame, on ? 30 : 0)
    pnlPlay := on
}

; Each playing card's frame from the time since it loaded (its delays over and over). A card whose frame changed is drawn
; again, and the peek scene that shows it; nothing else.
PanelFrame() {
    Critical                                          ; the panel's close waits: it destroys what this draws
    for c in pnl.cards {
        if c.delays.Length < 2
            continue
        n := 0
        for d in c.delays
            n += d
        t := Mod(A_TickCount - c.t0, n), f := 0
        while t >= c.delays[f + 1]
            t -= c.delays[++f]
        if f != c.f
            c.f := f, PanelInvalidate(c.card.ctl.Hwnd), c.scene && PanelInvalidate(c.scene.ctl.Hwnd)
    }
}

PanelChips() {   ; "Clean" shows on cards with the user's own picture
    for c in pnl.cards
        c.clean.ctl.Visible := c.thumb && (c.pending || IMG_PREFIX = "custom")
}

PanelClean(i, *) {   ; cutout.ahk on the card's working copy (made from the live picture if needed), async; a GIF frame by frame
    c := pnl.cards[i], gif := c.file ~= "i)\.gif$", pend := PendingImage(c.mood)
    if c.busy
        return
    if gif                                            ; a GIF stays one: its working copy is the .pending.gif
        pend := RegExReplace(pend, "png$", "gif")
    made := !c.pending
    if made
        try {
            DirCreate UserImagesDir()
            FileCopy c.file, pend, 1
        } catch as e
            return PanelNote("Couldn't prepare the picture (" e.Message ").")
    c.busy := true, c.clean.ctl.Enabled := false, PanelRedraw("card", "chip")
    PanelNote("Cleaning “" MOOD_NOTES[i] "”…")
    cut := gif ? CutoutGifRun : CutoutRun             ; the card stays veiled ("cleaning…") until done
    cut(pend, PanelCleaned.Bind(i, made))
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

PanelPanePick(*) {   ; the BACKGROUND card clicked: file picker
    pnl.gui.Opt("+OwnDialogs")
    f := FileSelect(1, , "Choose the picture behind the tiles", "Pictures (*.png; *.jpg; *.jpeg; *.bmp; *.gif)")
    if f != "" && pnl
        PanelPane(f)
}

PanelPane(file) {   ; the picture becomes the BACKGROUND card's pending one (images\pane.pending.png, still)
    if why := PaneImport(file)
        return PanelNote("That file didn't work: " why ".")
    pnl.pane.gone := false, pnl.dirty := true, PanelLoadPane()
    PanelNote("New background picture. Save to use it.")
}

; Remove: plain glass until Save, which deletes pane.png (gone; only if a picture is saved: else there's nothing to delete).
; A pick waiting goes now. The focus moves to the card first, as the chip hides.
PanelPaneRemove(*) {
    try FileExist(PanePending()) && FileDelete(PanePending())
    catch as e
        return PanelNote("Couldn't remove the picture (" e.Message ").")
    pnl.pane.gone := SettingsGet("PANE_PICTURE") != "", pnl.dirty := true
    pnl.pane.card.ctl.Focus(), PanelLoadPane(), PanelNote("Plain glass again. Save to use it.")
}

; (Re)load the BACKGROUND card's picture: the pending pick, else PANE_PICTURE unless removed, cut from its middle to the shape
; of the card's pane (PaintPane's) and scaled to it, its file let go at once (Save moves it, Cancel deletes it). Remove shows
; while there is one.
PanelLoadPane() {
    p := pnl.pane, old := p.bm, bm := 0, pic := SettingsGet("PANE_PICTURE"), p.pending := FileExist(PanePending()) != ""
    file := p.pending ? PanePending() : p.gone || pic = "" ? "" : UserImagesDir() "\" pic
    if file != "" && !DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", file, "ptr*", &src := 0) {
        DllCall("gdiplus\GdipGetImageWidth", "ptr", src, "uint*", &w := 0), DllCall("gdiplus\GdipGetImageHeight", "ptr", src, "uint*", &h := 0)
        pw := p.card.w - Dpx(40), ph := p.card.h - Dpx(36), s := Max(pw / w, ph / h)   ; covers it: the overflow cut evenly
        gr := Canvas(bm := NewBitmap(pw, ph)), DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gr, "int", 7)   ; HighQualityBicubic
        DllCall("gdiplus\GdipCreateImageAttributes", "ptr*", &ia := 0)
        DllCall("gdiplus\GdipSetImageAttributesWrapMode", "ptr", ia, "int", 3, "uint", 0, "int", 0)   ; TileFlipXY: no faded edge
        DllCall("gdiplus\GdipDrawImageRectRect", "ptr", gr, "ptr", src, "float", 0, "float", 0, "float", pw, "float", ph
            , "float", (w - pw / s) / 2, "float", (h - ph / s) / 2, "float", pw / s, "float", ph / s, "int", 2, "ptr", ia, "ptr", 0, "ptr", 0)   ; UnitPixel
        DllCall("gdiplus\GdipDisposeImageAttributes", "ptr", ia), DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
        DllCall("gdiplus\GdipDisposeImage", "ptr", src)
    }
    p.bm := bm, p.remove.ctl.Visible := bm != 0       ; swapped in before the old one is freed: a paint may come between
    if old
        DllCall("gdiplus\GdipDisposeImage", "ptr", old)
    PanelRedraw("pane"), PanelInvalidate(p.name.ctl.Hwnd), PanelInvalidate(pnl.hint.ctl.Hwnd)
}
