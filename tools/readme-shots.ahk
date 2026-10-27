#Requires AutoHotkey v2.0
#SingleInstance Off
; README screenshots of the real MeowTab, captured from the screen (needs a connected, unlocked desktop). Privacy: only
; this script's own windows can end up in the image.
;   light | dark: the pane with its acrylic, live DWM thumbnails and the peeking picture. Only this script's demo windows are
;     listed (neutral titles, fake contents), over a stand-in wallpaper covering the monitor the pane opens on; the capture is
;     cropped to the pane and the picture, and not taken if a window that isn't ours is above the wallpaper inside the crop.
;     [windows]: how many demo windows to list (default 5; 12 and more reach PEEK_MAX).
;     [look]: the pane's look, velvet or windows11 (default: the app's default look).
;     [tint]: Velvet's tint alpha for this shot, 0-255, in place of the palette's (its colour stays): to compare strengths.
;       - keeps the palette's (to give a picture after it).
;     [picture]: a background picture for the pane, imported into the temporary data folder as the panel's Save does
;       (pane.png); [strength]: its alpha, 0-255, in place of PANE_PIC_ALPHA.
;   hold: light's pane on 2 demo windows with the shipped images\chill.gif as the "few" picture, playing (as with Windows'
;     Animation effects on), held open <seconds> for a screen recording (docs\meowtab-gif.gif) instead of captured: prints
;     the crop, about 960 px wide, and reports a window that isn't ours in it, also one that shows up while it holds.
;   settings: the settings panel alone (its own pixels), with default settings: it runs on an empty temporary data
;     folder, so the user's own settings.ini is neither read nor written. The panel gets its whole content height, every
;     section with no scroll bar, also where that's taller than the screen: it's raised until all of it has been on the
;     screen, and PrintWindow takes DWM's copy of the whole window. At this display's own scale: docs\settings.png is taken
;     on a 150 % display.
;   story: the README's demo GIF (docs\demo.gif, docs\demo.zh-TW.gif), its captions in English or 繁體中文 (readme-story.ahk).
;     Over the stand-in wallpaper, demo windows open and close between three opens of light's pane, on 3, 12 and 2 windows,
;     with the captions drawn on the screen; ffmpeg (on the PATH) records that monitor, then makes the GIF: cropped to the
;     scenes, about 960 px wide, looping. No GIF if a window that isn't ours showed in the crop. Hands off for ~20 s.
; Run from the repo root:  AutoHotkey64.exe /ErrorStdOut tools\readme-shots.ahk <light | dark> [out.png] [windows] [velvet | windows11] [tint | -]
;                              [picture] [strength]
;                          AutoHotkey64.exe /ErrorStdOut tools\readme-shots.ahk settings <out.png>
;                          AutoHotkey64.exe /ErrorStdOut tools\readme-shots.ahk hold <seconds 1-100>
;                          AutoHotkey64.exe /ErrorStdOut tools\readme-shots.ahk story <en | zh-TW> <out.gif>
; (default out: docs\meowtab.png / docs\meowtab-dark.png). Keep hands off the mouse and keyboard for ~5 s.
DATA_DIR := A_Temp "\meowtab-shots-" A_TickCount   ; a new, empty data folder: default settings, and the user's own are never read or changed
OnExit((*) => (DirExist(DATA_DIR) && DirDelete(DATA_DIR, true), 0))
if A_Args.Length > 3 && !(A_Args[4] = "velvet" || A_Args[4] = "windows11")
    || A_Args.Length > 4 && !(A_Args[5] = "-" || IsInteger(A_Args[5]) && A_Args[5] >= 0 && A_Args[5] <= 255)
    || A_Args.Length > 6 && !(IsInteger(A_Args[7]) && A_Args[7] >= 0 && A_Args[7] <= 255)
    FileAppend("usage: readme-shots.ahk <light | dark> [out.png] [windows] [velvet | windows11] [tint 0-255 | -] [picture] [strength 0-255]`n", "*"), ExitApp(1)
if A_Args.Length > 3                               ; the look, in that folder's settings.ini: the app's startup reads it (and picks the title font by it)
    DirCreate(DATA_DIR), IniWrite(A_Args[4], DATA_DIR "\settings.ini", "settings", "PANE_LOOK")
#Include %A_LineFile%\..\..\meowtab.ahk
#Include %A_LineFile%\..\readme-story.ahk          ; the story mode: its constants (the texts, the timeline), then functions
if A_Args.Length > 4 && A_Args[5] != "-"          ; the tint: Velvet's palettes as copies with that alpha (each keeps its colour)
    VELVET_LIGHT := VELVET_LIGHT.Clone(), VELVET_LIGHT.tint := [VELVET_LIGHT.tint[1], Integer(A_Args[5])]
    , VELVET_DARK := VELVET_DARK.Clone(), VELVET_DARK.tint := [VELVET_DARK.tint[1], Integer(A_Args[5])]
if A_Args.Length > 5 {                             ; the picture: pane.png in that folder, as the panel's Save makes it, loaded again at the strength
    if (why := PaneImport(A_Args[6]) PaneCommit(false)) != ""
        FileAppend("can't use " A_Args[6] ": " why "`n", "*"), ExitApp(1)
    PANE_PICTURE := "pane.png", PANE_PIC_ALPHA := A_Args.Length > 6 ? Integer(A_Args[7]) : PANE_PIC_ALPHA, PanePicLoad()
}

REPO := RegExReplace(A_LineFile, "\\[^\\]+\\[^\\]+$")   ; the folder above tools\
global imgs := [], delays := [], spans := []   ; the include looked for the pictures next to this script: load the repo's
for mood in ["few", "some", "many"]
    imgs.Push(GifStrip(REPO "\" IMG_DIR "\" IMG_PREFIX "_" mood ".png", IMG_SIZE, &span, &frameMs)), delays.Push(frameMs), spans.Push(span)
SetTimer(() => ExitApp(2), -120000)            ; a stuck run must not leave a stand-in wallpaper over the screen

which := A_Args.Length ? A_Args[1] : "light"
if which = "settings" && A_Args.Length < 2     ; no default out: the shot in docs\ is framed on a 150 % display
    FileAppend("usage: readme-shots.ahk settings <out.png>`n", "*"), ExitApp(1)
if which = "hold" && !(A_Args.Length > 1 && IsInteger(A_Args[2]) && A_Args[2] >= 1 && A_Args[2] <= 100)   ; inside the safety exit
    FileAppend("usage: readme-shots.ahk hold <seconds 1-100>`n", "*"), ExitApp(1)
if which = "story" && !(A_Args.Length > 2 && STORY_TEXT.Has(A_Args[2]))
    FileAppend("usage: readme-shots.ahk story <en | zh-TW> <out.gif>`n", "*"), ExitApp(1)
if which = "hold"                                 ; the GIF cat as the few picture, playing: Animation effects on, through the app's seam
    imgs[1] := GifStrip(REPO "\" IMG_DIR "\chill.gif", IMG_SIZE, &span, &frameMs), delays[1] := frameMs, spans[1] := span, ANIM_EFFECTS := true
out := which = "story" ? A_Args[3] : A_Args.Length > 1 ? A_Args[2] : REPO "\docs\meowtab" (which = "dark" ? "-dark" : "") ".png"
if !RegExMatch(out, "^([A-Za-z]:)?\\")         ; relative: to where it was started from
    out := A_InitialWorkingDir "\" out
if which = "settings"                             ; a room the panel can't fill (PanelFit): its whole content height
    PANEL_ROOM := 100000, SettingsShot(out)
DEMO := [["Trip plan — 旅行計畫.md", 1500, 950, "1E1E1E", "3C3C3C", "shell32.dll", 71, "code"]
    , ["小算盤 Calculator", 640, 980, "F3F3F3", "0067C0", "shell32.dll", 24, "keys"]
    , ["Photos — sleepy cat.png", 1400, 900, "202020", "2B2B2B", "imageres.dll", 68, "cat"]
    , ["收件匣 Inbox", 1400, 900, "FFFFFF", "0F6CBD", "shell32.dll", 157, "lines"]
    , ["Terminal", 1200, 700, "0C0C0C", "1F1F1F", "imageres.dll", 312, "term"]]
if which = "story"                                ; its own windows, scenes and recording (readme-story.ahk); exits when done
    StoryRun(A_Args[2], out)
made := []
Loop which = "hold" ? 2 : A_Args.Length > 2 ? Max(Integer(A_Args[3]), 1) : DEMO.Length {   ; more than the specs: cycle through them, titles numbered
    spec := DEMO[Mod(A_Index - 1, DEMO.Length) + 1], lap := (A_Index - 1) // DEMO.Length
    made.Push(DemoWindow(spec, spec[1] (lap ? " (" lap + 1 ")" : "")))
}
Sleep 800
mi := Buffer(40, 0), NumPut("uint", 40, mi), DllCall("GetMonitorInfoW", "ptr", CurrentMonitor(), "ptr", mi)   ; where the pane opens
ml := NumGet(mi, 4, "int"), mt := NumGet(mi, 8, "int"), mr := NumGet(mi, 12, "int"), mb := NumGet(mi, 16, "int")   ; rcMonitor
wall := Wallpaper(which = "dark", ml, mt, mr - ml, mb - mt)   ; covers that whole monitor: nothing of yours shows
Sleep 300
wins := [], idx := Min(2, made.Length), cycling := true, dark := which = "dark"
for win in made
    wins.Push(win.Hwnd)
ShowPane(true), Critical("Off")
Sleep 700                                          ; first the open's own hover pass, which would undo the look set here
hover := dark ? 3 : 0, hoverX := false, mouseAt := 0, Render(surf), Present()   ; dark: the hover look on tile 3 (the selection is tile 2); light: none
Sleep(100), DllCall("dwmapi\DwmFlush")
g.GetPos(&px, &py, &pw, &ph), WinGetPos(&kx, &ky, &kw, &kh, peek.Hwnd)
side := which = "hold" ? Max(48, (960 - pw) // 2) : 48   ; hold: wider, about 960 px
x0 := Max(px - side, ml), y0 := Max(Min(ky, py) - 32, mt)   ; crop to the pane, the picture and a margin, inside that monitor
x1 := Min(px + pw + side, mr), y1 := Min(py + ph + 48, mb)
if (foreign := ForeignAbove(wall.Hwnd, x0, y0, x1, y1)) = "" && which = "hold" {   ; recorded from outside: the crop, then held
    FileAppend "hold " x1 - x0 "x" y1 - y0 " at " x0 "," y0 " for " A_Args[2] " s`n", "*"
    Loop A_Args[2] * 4                             ; watched meanwhile: the first window that isn't ours is reported
        Sleep(250), foreign := foreign || ForeignAbove(wall.Hwnd, x0, y0, x1, y1)
} else if foreign = ""
    Capture(x0, y0, x1 - x0, y1 - y0, out)
if foreign != ""
    FileAppend "not captured, a window that isn't ours is above the stand-in wallpaper in the crop: " foreign "`n", "*"
Finish(false)
for win in made
    win.Destroy()
wall.Destroy()
ExitApp foreign = "" ? 0 : 4

; The windows above `wallHwnd` in the Z-order that are visible, not cloaked and inside the crop, other than this script's own
; (the pane, the picture; the story's demo windows and captions): "class (process)", comma-separated ("" = none). seen: a Map
; that also keeps each one's rect, by its name and rect (the story samples the monitor, then judges by the crop).
ForeignAbove(wallHwnd, x0, y0, x1, y1, seen := 0) {
    found := "", rc := Buffer(16), h := DllCall("GetTopWindow", "ptr", 0, "ptr"), me := DllCall("GetCurrentProcessId")
    while h && h != wallHwnd {
        cloaked := 0, DllCall("dwmapi\DwmGetWindowAttribute", "ptr", h, "uint", 14, "uint*", &cloaked, "uint", 4)
        DllCall("GetWindowThreadProcessId", "ptr", h, "uint*", &pid := 0)
        if pid != me && !cloaked && DllCall("IsWindowVisible", "ptr", h) && DllCall("GetWindowRect", "ptr", h, "ptr", rc)
            && (l := NumGet(rc, 0, "int")) < x1 && (r := NumGet(rc, 8, "int")) > x0 && (t := NumGet(rc, 4, "int")) < y1 && (b := NumGet(rc, 12, "int")) > y0
            try found .= (found ? ", " : "") (name := WinGetClass(h) " (" WinGetProcessName(h) ")"), seen && (seen[name " " l "," t "," r "," b] := [l, t, r, b])
        h := DllCall("GetWindow", "ptr", h, "uint", 2, "ptr")   ; GW_HWNDNEXT
    }
    return found
}

SettingsShot(file) {   ; the settings panel alone; exits when done
    global IMG_DIR
    IMG_DIR := "..\images"                         ; the panel reads A_ScriptDir\IMG_DIR (tools\..\images), not REPO
    SettingsOpen(), Sleep(900)                     ; built and painted
    hw := pnl.gui.Hwnd, MouseGetPos(&mx, &my), WinGetPos(&x, &y, &w, &h, hw)
    mi := Buffer(40, 0), NumPut("uint", 40, mi), DllCall("GetMonitorInfoW", "ptr", CurrentMonitor(), "ptr", mi)
    if mx >= x && mx < x + w && my >= y && my < y + h   ; a cursor on the panel lights up a hover look: slide the panel aside
        WinMove mx > x + w // 2 ? NumGet(mi, 20, "int") : NumGet(mi, 28, "int") - w, y, , , hw   ; to rcWork's left or right
    SendMessage 0x128, 0x10002, 0, hw              ; WM_UPDATEUISTATE, clear UISF_HIDEFOCUS: the focus ring, as after a first Tab
    Sleep 400
    ; Taller than the screen: only what has been on it gets painted, and DWM keeps that (seen: the bar below the screen stayed
    ; blank). So the panel is raised a screen at a time until its bottom is on it, each time repainted whole before going on
    ; (a wait alone raced the slower painters: the sample, the shortcuts and the bar came out blank).
    while y + h > (b := NumGet(mi, 16, "int")) {  ; rcMonitor's bottom
        y := Max(y - b + NumGet(mi, 8, "int"), b - h), WinMove(, y, , , hw)
        DllCall("RedrawWindow", "ptr", hw, "ptr", 0, "ptr", 0, "uint", 0x585)   ; INVALIDATE ERASE ALLCHILDREN UPDATENOW FRAME
        DllCall("dwmapi\DwmFlush"), Sleep(200)
    }
    Capture(0, 0, w, h, file, hw)
    PanelClose()
    ExitApp
}

DemoWindow(spec, title, show := "NA", s := 1) {   ; an app-like window, shown without activation (or Show's options), at scale s, with a system icon (WM_SETICON)
    Z(n) => Round(n * s)
    w := Z(spec[2]), h := Z(spec[3]), night := InStr("1E1E1E 202020 0C0C0C", spec[4])
    win := Gui("-DPIScale", title), win.BackColor := spec[4], win.MarginX := 0, win.MarginY := 0
    win.AddText("x0 y0 w" w " h" Z(64) " Background" spec[5])
    switch spec[8] {
    case "cat":                                    ; the shipped picture, as a photo viewer would show it
        win.AddPicture("x" (w - Z(560)) // 2 " y" Z(120) " w" Z(560) " h" Z(560) " BackgroundTrans", REPO "\images\chill_few.png")
    case "keys":                                   ; a calculator's display and keypad
        win.SetFont("s" Z(40) " c202020", "Segoe UI"), win.AddText("x" Z(40) " y" Z(110) " w" w - Z(80) " Right BackgroundTrans", "42")
        Loop 20
            win.AddText(Format("x{} y{} w{} h{} BackgroundE9E9E9", Z(24 + Mod(A_Index - 1, 4) * 150), Z(260 + (A_Index - 1) // 4 * 140), Z(138), Z(128)))
    default:
        win.SetFont("s" Z(14) " c" (night ? (spec[8] = "term" ? "4CC2FF" : "9CDCFE") : "404040"), spec[8] = "lines" ? "Segoe UI" : "Consolas")
        text := Map("code", ["## Day 1 — 台北 Taipei", "- [x] 101 observatory", "- [ ] 夜市 night market", "", "## Day 2 — 九份 Jiufen", "- [ ] tea house", "- [ ] lanterns"]
            , "term", ["PS> git status", "On branch main", "nothing to commit, working tree clean", "PS> meow", "=^.^=", "PS> _"]
            , "lines", ["Re: Friday lunch?", "Weekly update — draft", "Your package is on its way", "相片已分享 Photos shared", "Meeting notes"])[spec[8]]
        for i, line in text
            win.AddText("x" Z(48) " y" Z(70 + i * 52) " w" w - Z(96) " BackgroundTrans", line)
    }
    win.Show(show " w" w " h" h)
    hi := LoadPicture(spec[6], "Icon" spec[7] " w32 h32", &kind)
    if hi && kind = 1                              ; IMAGE_ICON
        DllCall("SendMessageW", "ptr", win.Hwnd, "uint", 0x80, "ptr", 1, "ptr", hi)   ; WM_SETICON, ICON_BIG
    return win
}

Capture(x, y, w, h, file, hwnd := 0) {   ; screen rect -> PNG, DWM's composition included (CAPTUREBLT); or just window hwnd's own pixels
    sdc := DllCall("GetDC", "ptr", 0, "ptr"), mdc := DllCall("CreateCompatibleDC", "ptr", sdc, "ptr")
    hbm := DllCall("CreateCompatibleBitmap", "ptr", sdc, "int", w, "int", h, "ptr"), ob := DllCall("SelectObject", "ptr", mdc, "ptr", hbm, "ptr")
    ok := hwnd ? DllCall("PrintWindow", "ptr", hwnd, "ptr", mdc, "uint", 2)   ; PW_RENDERFULLCONTENT: the caption too, the invisible frame stays black
        : DllCall("BitBlt", "ptr", mdc, "int", 0, "int", 0, "int", w, "int", h, "ptr", sdc, "int", x, "int", y, "uint", 0x40CC0020)
    DllCall("SelectObject", "ptr", mdc, "ptr", ob), DllCall("DeleteDC", "ptr", mdc), DllCall("ReleaseDC", "ptr", 0, "ptr", sdc)
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &bm := 0)
    saved := SavePng(bm, file)
    DllCall("gdiplus\GdipDisposeImage", "ptr", bm), DllCall("DeleteObject", "ptr", hbm)
    FileAppend "capture " w "x" h " at " x "," y ": blt " ok ", saved " saved " -> " file "`n", "*"
}

Wallpaper(night, X, Y, W, H) {   ; backdrop window over one monitor (not topmost, not activated, not Alt+Tab-eligible)
    bm := NewBitmap(W, H), gr := Canvas(bm)
    Fill(gr, FadeBrush(0, 0, W, H, 60, night ? [["0B1530", 255, 0], ["1C3A8A", 255, 0.55], ["0A0F24", 255, 1]]
        : [["DCE6F2", 255, 0], ["A9C1E0", 255, 0.55], ["EEF2F7", 255, 1]]), W, H)
    RadialFill(gr, W * 0.66, H * 0.62, 560, 420, [["2F6FEB", night ? 220 : 150, 0], ["2F6FEB", 0, 1]])
    RadialFill(gr, W * 0.22, H * 0.30, 420, 300, [["F59E0B", night ? 90 : 120, 0], ["F59E0B", 0, 1]])
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    win := Gui("-Caption +ToolWindow -DPIScale"), win.MarginX := 0, win.MarginY := 0
    win.AddPicture("x0 y0 w" W " h" H, "HBITMAP:" ToHbm(bm))
    win.Show("NA x" X " y" Y " w" W " h" H)
    return win
}
