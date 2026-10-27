; readme-shots.ahk's story mode (#Included by it, after the app): the README's demo GIF of the real MeowTab, one language per
; run. Over the stand-in wallpaper on the monitor the pane opens on, demo windows open and close on the desktop between three
; opens of the pane, on 3, 12 and 2 windows (the some, many and few cats), with captions drawn on the screen in windows of their
; own. ffmpeg's gdigrab records that whole monitor; the GIF is then cut to the clock, cropped to every scene's pane, picture and
; captions, and scaled down. These constants, then functions only.

; ----- To tune by eye: the texts, the timeline, the captions' look, the export -----
STORY_TEXT := Map("en", ["Your Alt+Tab cat monitors your work stress.", "too many...", "cozy ♡", "Too many windows. One tired cat, meow~"]
    , "zh-TW", ["你的 Alt+Tab 貓咪，正在監控你的工作壓力。", "太多了…", "愜意 ♡", "視窗堆成山，貓咪已累癱，喵～"])   ; the slogan, scene 2's, scene 3's, the closing line
STORY_COUNTS := [3, 12, 2]                     ; demo windows listed in scenes 1, 2 and 3 (some, many, few)
STORY_MS := [2500, 1000, 3500, 1000, 4000]     ; scene 1, the desktop, scene 2, the desktop, scene 3: ms each; their sum is the GIF's length
STORY_OPEN_MS := 90, STORY_SHUT_MS := 80       ; the desktop: from one demo window opening (closing) to the next
STORY_WIN_SCALE := 0.5                         ; the demo windows' size (readme-shots' DEMO at 1): small enough that the pile shows
STORY_TAB_AT := 600, STORY_TAB_MS := 250       ; scene 2: the first Tab after the open, then one every STORY_TAB_MS, up to the last tile
STORY_LINE_AT := 1000                          ; scene 3: the closing line, after the open
STORY_TITLE_PX := 30, STORY_NOTE_PX := 26      ; text px (the GIF shows them about 0.74x): the slogan and the closing line; the mood captions
STORY_GAP := 24                                ; the title spot's bottom over the tallest picture above scene 1's pane; a mood caption's top under its pane
STORY_LABEL := {fill: ["FFFDFA", 245], edge: ["000000", 16], text: "1A1714", shadow: ["3B2A1A", 64], blur: 14, r: 14, padX: 22, padY: 10}
STORY_FPS := 30, STORY_WIDTH := 960            ; the recording's and the GIF's frames a second; the GIF's width
STORY_MARGIN := 40                             ; the crop: this much around the union of the scenes' rects
STORY_DITHER := "bayer:bayer_scale=3"          ; paletteuse's: no visible grain, under 5 MB (5 banded the wallpaper's glows)
STORY_LEAD := 2000                             ; ms the recording runs past the timeline: the clock may start that late in it (ffmpeg starting up)
STORY_GRAB := "-f gdigrab -framerate {1} -draw_mouse 0 -offset_x {2} -offset_y {3} -video_size {4}x{5} -i desktop"   ; ffmpeg's input: fps, the monitor

; story <lang> <out.gif>: the GIF in that language; exits (0 written; 1 no recording or no export; 4 a window that isn't ours was
; in the crop: no GIF). All on the monitor the pane opens on (the active window's).
StoryRun(lang, out) {
    global ANIM_EFFECTS := true, dark := false     ; Velvet's ease-in and the cat's bounce, through the app's seam; light mode
    SplitPath(out, , &outDir)
    if !DirExist(outDir)                           ; found now, not after the recording
        FileAppend("no folder " outDir "`n", "*"), ExitApp(1)
    mon := CurrentMonitor(), mi := Buffer(40, 0), NumPut("uint", 40, mi), DllCall("GetMonitorInfoW", "ptr", mon, "ptr", mi)
    m := [NumGet(mi, 4, "int"), NumGet(mi, 8, "int"), NumGet(mi, 12, "int"), NumGet(mi, 16, "int")]   ; rcMonitor
    st := {text: STORY_TEXT[lang], dir: DATA_DIR "\story", seen: Map(), box: 0, title: StoryLayer(), note: StoryLayer(), wa: WorkArea(mon)}
    st.made := StoryWindows(st.wa)
    Loop STORY_COUNTS[1]                           ; scene 1's windows: under the wallpaper, as readme-shots' are (the glass over it alone)
        StoryShow(st.made[A_Index])
    DirCreate(st.dir), st.wall := Wallpaper(false, m[1], m[2], m[3] - m[1], m[4] - m[2])   ; made after them: over them; the rest open above it
    MouseMove(m[1], m[2], 0)                       ; the monitor's corner, off every pane: no tile gets the hover look
    Sleep(300), StoryOpen(st, 1), Sleep(700)       ; scene 1, settled: the poster frame
    g.GetPos(&px, &py, &pw), st.cx := px + pw // 2, st.top := py - IMG_SIZE - STORY_GAP   ; the title spot: over the tallest picture
    StoryLabel(st.title, st.text[1], STORY_TITLE_PX, st.cx, st.top, false)
    total := 0
    for ms in STORY_MS
        total += ms
    pid := StoryStart(st.dir, m, (total + STORY_LEAD) / 1000)
    if (ss := StoryClock(st.dir "\rec.txt", pid)) != "" {   ; the clock starts with the first frames: a lag only lengthens scene 1
        sample := ForeignAbove.Bind(st.wall.Hwnd, m[1], m[2], m[3], m[4], st.seen)   ; windows that aren't ours: judged by the crop at the end
        sample(), SetTimer(sample, 250), StoryScenes(st, A_TickCount), SetTimer(sample, 0), sample()
    }
    if ProcessWaitClose(pid, (total + STORY_LEAD) / 1000 + 10)   ; ffmpeg stops itself; till then the wallpaper stays
        RunWait("taskkill /T /F /PID " pid, , "Hide")             ; hung: cmd, the shim and ffmpeg end here, and its hold on the recording
    Finish(false), Critical("Off")
    for win in st.made
        win.Destroy()
    st.title.Destroy(), st.note.Destroy(), st.wall.Destroy()
    if ss = "" || StoryProgress(st.dir "\rec.txt").Get("progress", "") != "end"
        FileAppend("no recording (" (ss = "" ? "it didn't start in time" : "it didn't finish") "): " FileRead(st.dir "\rec.log") "`n", "*"), ExitApp(1)
    ExitApp StoryExport(st, m, ss, total / 1000, out)
}

; The timeline on the clock started at t0, scene 1 open already. Each scene's rects are logged before it closes.
StoryScenes(st, t0) {
    n := STORY_COUNTS, s := STORY_MS, tabs := 0
    At(t := s[1]), StoryLog(st, 1), Finish(false), Critical("Off"), st.title.Hide()
    Loop n[2] - n[1]                               ; the desktop: windows open one by one, each on top
        At(t + A_Index * STORY_OPEN_MS), StoryShow(st.made[n[1] + A_Index])
    At(t += s[2]), StoryOpen(st, 2), StoryNote(st, st.text[2])
    while idx < wins.Length && (due := STORY_TAB_AT + tabs * STORY_TAB_MS) <= s[3] - STORY_TAB_MS
        At(t + due), Step(1), Critical("Off"), tabs++
    At(t += s[3]), StoryLog(st, 2, Format(", {} Tabs, scrolled {:.1f} rows", tabs, grid.off / (grid.th + grid.gap)))
    Finish(false), Critical("Off"), st.note.Hide()
    Loop n[2] - n[3]                               ; the desktop: the newest windows close one by one
        At(t + A_Index * STORY_SHUT_MS), st.made[n[2] + 1 - A_Index].Hide()
    At(t += s[4]), StoryOpen(st, 3), StoryNote(st, st.text[3])
    At(t + STORY_LINE_AT), StoryLabel(st.title, st.text[4], STORY_TITLE_PX, st.cx, st.top, false)
    At(t += s[5]), StoryLog(st, 3)
    At(ms) => Sleep(Max(t0 + ms - A_TickCount, 0))   ; until ms on the clock
}

StoryOpen(st, k) {   ; scene k: the pane on its demo windows, the newest first, the selection as after one Tab (as readme-shots')
    global wins := [], idx := 2, cycling := true
    Loop STORY_COUNTS[k]
        wins.InsertAt(1, st.made[A_Index].Hwnd)
    ShowPane(true), Critical("Off")                ; ShowPane's Critical off: Velvet's motion and the picture's timers run in the waits
}

; Scene k's rects, of the pane, the picture and the captions showing, into the crop's union st.box; one log line (more: its end).
StoryLog(st, k, more := "") {
    line := "scene " k " (" wins.Length " windows):", rc := Buffer(16)
    for name, h in Map("pane", g.Hwnd, "picture", peek.Hwnd, "title", st.title.Hwnd, "caption", st.note.Hwnd)
        if DllCall("IsWindowVisible", "ptr", h) && DllCall("GetWindowRect", "ptr", h, "ptr", rc) {
            r := [NumGet(rc, 0, "int"), NumGet(rc, 4, "int"), NumGet(rc, 8, "int"), NumGet(rc, 12, "int")]
            st.box := st.box ? [Min(st.box[1], r[1]), Min(st.box[2], r[2]), Max(st.box[3], r[3]), Max(st.box[4], r[4])] : r
            line .= " " name " " r[1] "," r[2] " " r[3] - r[1] "x" r[4] - r[2] ";"
        }
    FileAppend RTrim(line, ";") more "`n", "*"
}

; Every scene's demo windows (readme-shots' DEMO at STORY_WIN_SCALE, cycled, titles numbered), made hidden at their spots: those
; that open on the desktop cascade down and to the right through the middle of work area wa, each kept in it where it fits.
StoryWindows(wa) {
    made := [], n := Max(STORY_COUNTS*), s := STORY_WIN_SCALE
    Loop n {
        spec := DEMO[Mod(A_Index - 1, DEMO.Length) + 1], lap := (A_Index - 1) // DEMO.Length, k := A_Index - (n + STORY_COUNTS[1] + 1) / 2
        w := Round(spec[2] * s), h := Round(spec[3] * s)   ; scene 1's sit under the wallpaper: the rest centred
        x := Max(Min(Round((wa[1] + wa[3] - w) / 2 + 64 * k), wa[3] - w), wa[1])
        y := Max(Min(Round((wa[2] + wa[4] - h) / 2 + 48 * k), wa[4] - h), wa[2])
        made.Push(DemoWindow(spec, spec[1] (lap ? " (" lap + 1 ")" : ""), "Hide x" x " y" y, s))
    }
    return made
}
StoryShow(win) => DllCall("SetWindowPos", "ptr", win.Hwnd, "ptr", 0, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x53)   ; on top (HWND_TOP), shown, not activated

; ----- Captions: each in its own per-pixel-alpha window, as the picture is -----

StoryLayer() => Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08080020")   ; LAYERED|TRANSPARENT|NOACTIVATE: click-through, never activated

; Caption s at px in layered window win, shown at once (no slide): centred on cx, hanging from y (down) or standing on it.
StoryLabel(win, s, px, cx, y, down) {
    c := StoryCard(s, px), hbm := ToHbm(c.bm), dc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr"), old := DllCall("SelectObject", "ptr", dc, "ptr", hbm, "ptr")
    y -= c.top + (down ? 0 : c.lh), x := cx - c.w // 2
    DllCall("UpdateLayeredWindow", "ptr", win.Hwnd, "ptr", 0, "int64*", y << 32 | (x & 0xFFFFFFFF), "int64*", c.h << 32 | c.w
        , "ptr", dc, "int64*", 0, "uint", 0, "uint*", 0x01FF0000, "uint", 2)   ; AC_SRC_OVER, alpha 255, AC_SRC_ALPHA; ULW_ALPHA
    DllCall("SelectObject", "ptr", dc, "ptr", old), DllCall("DeleteDC", "ptr", dc), DllCall("DeleteObject", "ptr", hbm)
    DllCall("SetWindowPos", "ptr", win.Hwnd, "ptr", -1, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x53)   ; shown, topmost, not activated
}
StoryNote(st, s) => (g.GetPos(, &py, , &ph), StoryLabel(st.note, s, STORY_NOTE_PX, st.cx, py + ph + STORY_GAP, true))   ; a mood caption, under this pane

; Caption s drawn: the tile titles' font (StoryFont) at px, dark, centred on a bright rounded label with a hairline edge and a
; soft shadow, deeper below (VelvetShade's); a new GDI+ bitmap {bm, w, h}, the label lh tall from row top.
StoryCard(s, px) {
    L := STORY_LABEL, b := L.blur, font := StoryFont(px), rc := Buffer(16, 0), fit := Buffer(16)
    DllCall("gdiplus\GdipStringFormatGetGenericTypographic", "ptr*", &typo := 0), DllCall("gdiplus\GdipCloneStringFormat", "ptr", typo, "ptr*", &fmt := 0)
    DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", fmt, "int", 1), DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", fmt, "int", 1)   ; centred
    gr := Canvas(bm := NewBitmap(1, 1)), DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", gr, "int", TEXT_HINT)   ; measured first
    DllCall("gdiplus\GdipMeasureString", "ptr", gr, "wstr", s, "int", -1, "ptr", font, "ptr", rc, "ptr", fmt, "ptr", fit, "ptr", 0, "ptr", 0)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr), DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    w := Ceil(NumGet(fit, 8, "float")) + 2 * L.padX, h := Ceil(NumGet(fit, 12, "float")) + 2 * L.padY, x := b, y := b // 2
    gr := Canvas(bm := NewBitmap(w + 2 * b, h + 2 * b)), DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", gr, "int", TEXT_HINT)
    label := RoundPath(x, y, w, h, L.r), shade := RoundPath(0, 0, w + 2 * b, h + 2 * b, L.r + b)   ; the shadow: b out, b / 2 lower
    DllCall("gdiplus\GdipSetClipPath", "ptr", gr, "ptr", label, "int", 4)   ; CombineModeExclude: only around the label
    EdgeFade(gr, shade, L.shadow[1], 0, L.shadow[2], (w - 2 * b) / (w + 2 * b), (h - 2 * b) / (h + 2 * b), true)
    DllCall("gdiplus\GdipDeletePath", "ptr", shade), DllCall("gdiplus\GdipResetClip", "ptr", gr)
    Paint(gr, label, Argb(L.fill*)), Outline(gr, x, y, w, h, L.r, -0.5, 1, Argb(L.edge*))   ; the hairline on the label's outer pixels
    NumPut("float", x, "float", y, "float", w, "float", h, rc)
    DllCall("gdiplus\GdipDrawString", "ptr", gr, "wstr", s, "int", -1, "ptr", font, "ptr", rc, "ptr", fmt, "ptr", Brush(Argb(L.text, 255)))
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr), DllCall("gdiplus\GdipDeleteFont", "ptr", font), DllCall("gdiplus\GdipDeleteStringFormat", "ptr", fmt)
    return {bm: bm, w: w + 2 * b, h: h + 2 * b, top: y, lh: h}
}

StoryFont(px) {   ; FONT_NAME's medium weight at px, as Velvet's titles (Noto Sans TC: the Chinese too), else its regular, else Segoe UI
    for face in [FONT_NAME " Medium", FONT_NAME, "Segoe UI"]
        if !DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", face, "ptr", 0, "ptr*", &ff := 0) {
            bad := DllCall("gdiplus\GdipCreateFont", "ptr", ff, "float", px, "int", 0, "int", 2, "ptr*", &font := 0)   ; Regular, UnitPixel
            DllCall("gdiplus\GdipDeleteFontFamily", "ptr", ff)
            if !bad
                return font
        }
}

; ----- The recording and the GIF: ffmpeg, from the PATH -----

StoryStart(dir, m, secs) => StoryFfmpeg(Format(STORY_GRAB, STORY_FPS, m[1], m[2], m[3] - m[1], m[4] - m[2])   ; monitor m for secs, losslessly
    . Format(' -t {1:.3f} -c:v libx264rgb -preset ultrafast -tune zerolatency -qp 0 -progress "{2}\rec.txt" -stats_period 0.1 "{2}\rec.mkv"', secs, dir), dir "\rec.log")

; The clock's start: once the recording's first frames are in (progress file prog), their time in it, in s. "" if ffmpeg (cmd's
; pid) ended or none came within about 10 s, or if that's STORY_LEAD in already (the recording would end before the timeline).
StoryClock(prog, pid) {
    Loop 1000 {
        if (p := StoryProgress(prog)).Get("frame", 0) > 0 && IsInteger(us := p.Get("out_time_us", ""))
            return us / 1000 < STORY_LEAD ? us / 1000000 : ""
        if !ProcessExist(pid)
            return ""
        Sleep 10
    }
    return ""
}

StoryProgress(file) {   ; ffmpeg's -progress file: each key's last value
    p := Map(), text := ""
    try text := FileRead(file)
    Loop Parse text, "`n", "`r"
        if eq := InStr(A_LoopField, "=")
            p[SubStr(A_LoopField, 1, eq - 1)] := SubStr(A_LoopField, eq + 1)
    return p
}

StoryFfmpeg(args, log, wait := false) {   ; ffmpeg on args, hidden, its errors into log: cmd's PID (it waits for ffmpeg), or with wait the exit code
    cmd := A_ComSpec ' /s /c "ffmpeg -hide_banner -loglevel error -nostdin -y ' args ' 2>"' log '""'
    return wait ? RunWait(cmd, , "Hide") : (Run(cmd, , "Hide", &pid), pid)
}

; The GIF: the recording's secs from ss (of monitor m), cropped to the scenes' union plus STORY_MARGIN in the work area (never the
; taskbar), STORY_WIDTH wide, looping,
; through palettegen / paletteuse; made beside the recording, then moved to out (never half-written). None if a window that isn't
; ours was in the crop. Logs the crop, the recording's frames and the GIF; returns the exit code (0, 1, 4).
StoryExport(st, m, ss, secs, out) {
    b := st.box, wa := st.wa, x0 := Max(b[1] - STORY_MARGIN, wa[1]), y0 := Max(b[2] - STORY_MARGIN, wa[2]), x1 := Min(b[3] + STORY_MARGIN, wa[3]), y1 := Min(b[4] + STORY_MARGIN, wa[4])
    p := StoryProgress(st.dir "\rec.txt"), foreign := "", gif := st.dir "\story.gif"
    FileAppend Format("crop {}x{} at {},{}`nrecording: {} frames of {} expected ({:.2f} s at {} fps), dup {}, drop {}; the clock started {:.3f} s in`n"
        , x1 - x0, y1 - y0, x0, y0, p["frame"], Round((secs + STORY_LEAD / 1000) * STORY_FPS), p["out_time_us"] / 1000000, STORY_FPS, p["dup_frames"], p["drop_frames"], ss), "*"
    for key, r in st.seen                          ; ForeignAbove's samples: "class (process) l,t,r,b" -> [l, t, r, b]
        if r[1] < x1 && r[3] > x0 && r[2] < y1 && r[4] > y0
            foreign .= (foreign ? ", " : "") RegExReplace(key, " \S+$")
    if foreign != ""
        return (FileAppend("no GIF, a window that isn't ours was above the stand-in wallpaper in the crop: " foreign "`n", "*"), 4)
    code := StoryFfmpeg(Format('-ss {:.3f} -t {:.3f} -i "{}\rec.mkv" -filter_complex "fps={},crop={}:{}:{}:{},scale={}:-1:flags=lanczos,split[a][b];'
        . '[a]palettegen[p];[b][p]paletteuse=dither={}:diff_mode=rectangle" -loop 0 "{}"', ss, secs, st.dir, STORY_FPS
        , x1 - x0, y1 - y0, x0 - m[1], y0 - m[2], STORY_WIDTH, STORY_DITHER, gif), st.dir "\gif.log", true)
    if code || !FileExist(gif)
        return (FileAppend("no GIF, the export failed (" code "): " FileRead(st.dir "\gif.log") "`n", "*"), 1)
    FileMove(gif, out, true)
    FileAppend Format("gif {} px wide, {:.1f} s, {:.2f} MB -> {}`n", STORY_WIDTH, secs, FileGetSize(out) / 1048576, out), "*"
    return 0
}
