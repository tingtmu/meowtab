#Requires AutoHotkey v2.0
#SingleInstance Off
; README screenshots of the real MeowTab, captured from the screen (needs a connected, unlocked desktop). Privacy: only
; this script's own windows can end up in the image.
;   light | dark: the pane with its acrylic, live DWM thumbnails and the peeking picture. Only this script's demo windows are
;     listed (neutral titles, fake contents), over a stand-in wallpaper covering the monitor the pane opens on; the capture is
;     cropped to the pane and the picture, and not taken if a window that isn't ours is above the wallpaper inside the crop.
;     [windows]: how many demo windows to list (default 5; 12 and more reach PEEK_MAX).
;   settings: the settings panel alone (its own pixels), with default settings: it runs on an empty temporary data
;     folder, so the user's own settings.ini is neither read nor written. At this display's own scale: docs\settings.png's 816x986 framing needs a 150 % display.
; Run from the repo root:  AutoHotkey64.exe /ErrorStdOut tools\readme-shots.ahk <light | dark> [out.png] [windows]
;                          AutoHotkey64.exe /ErrorStdOut tools\readme-shots.ahk settings <out.png>
; (default out: docs\meowtab.png / docs\meowtab-dark.png). Keep hands off the mouse and keyboard for ~5 s.
DATA_DIR := A_Temp "\meowtab-shots-" A_TickCount   ; a new, empty data folder: default settings, and the user's own are never read or changed
OnExit((*) => (DirExist(DATA_DIR) && DirDelete(DATA_DIR, true), 0))
#Include %A_LineFile%\..\..\meowtab.ahk

REPO := RegExReplace(A_LineFile, "\\[^\\]+\\[^\\]+$")   ; the folder above tools\
global imgs := [], spans := []                 ; the include looked for the pictures next to this script: load the repo's
for mood in ["few", "some", "many"]
    imgs.Push(ScaledBitmap(REPO "\" IMG_DIR "\" IMG_PREFIX "_" mood ".png", IMG_SIZE, &span)), spans.Push(span)
SetTimer(() => ExitApp(2), -120000)            ; a stuck run must not leave a stand-in wallpaper over the screen

which := A_Args.Length ? A_Args[1] : "light"
if which = "settings" && A_Args.Length < 2     ; no default out: the shot in docs\ is framed on a 150 % display
    FileAppend("usage: readme-shots.ahk settings <out.png>`n", "*"), ExitApp(1)
out := A_Args.Length > 1 ? A_Args[2] : REPO "\docs\meowtab" (which = "dark" ? "-dark" : "") ".png"
if !RegExMatch(out, "^([A-Za-z]:)?\\")         ; relative: to where it was started from
    out := A_InitialWorkingDir "\" out
if which = "settings"
    SettingsShot(out)
DEMO := [["Trip plan — 旅行計畫.md", 1500, 950, "1E1E1E", "3C3C3C", "shell32.dll", 71, "code"]
    , ["小算盤 Calculator", 640, 980, "F3F3F3", "0067C0", "shell32.dll", 24, "keys"]
    , ["Photos — sleepy cat.png", 1400, 900, "202020", "2B2B2B", "imageres.dll", 68, "cat"]
    , ["收件匣 Inbox", 1400, 900, "FFFFFF", "0F6CBD", "shell32.dll", 157, "lines"]
    , ["Terminal", 1200, 700, "0C0C0C", "1F1F1F", "imageres.dll", 312, "term"]]
made := []
Loop A_Args.Length > 2 ? Max(Integer(A_Args[3]), 1) : DEMO.Length {   ; more than the specs: cycle through them, titles numbered
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
if dark                                            ; the hover look on tile 3 (the selection is tile 2)
    hover := 3, hoverX := false, Render(surf), Present()
Sleep 700
if !dark                                           ; light: no hover look, the pane would light up the tile under a resting cursor
    hover := 0, hoverX := false, mouseAt := 0, Render(surf), Present()
Sleep(100), DllCall("dwmapi\DwmFlush")
g.GetPos(&px, &py, &pw, &ph), WinGetPos(&kx, &ky, &kw, &kh, peek.Hwnd)
x0 := Max(px - 48, ml), y0 := Max(Min(ky, py) - 32, mt)   ; crop to the pane, the picture and a margin, inside that monitor
x1 := Min(px + pw + 48, mr), y1 := Min(py + ph + 48, mb)
if (foreign := ForeignAbove(wall.Hwnd, x0, y0, x1, y1)) = ""
    Capture(x0, y0, x1 - x0, y1 - y0, out)
else
    FileAppend "not captured, a window that isn't ours is above the stand-in wallpaper in the crop: " foreign "`n", "*"
Finish(false)
for win in made
    win.Destroy()
wall.Destroy()
ExitApp foreign = "" ? 0 : 4

; The windows above `wallHwnd` in the Z-order that are visible, not cloaked and inside the crop, other than the pane and the
; picture: "class (process)", comma-separated ("" = none).
ForeignAbove(wallHwnd, x0, y0, x1, y1) {
    found := "", rc := Buffer(16), h := DllCall("GetTopWindow", "ptr", 0, "ptr")
    while h && h != wallHwnd {
        cloaked := 0, DllCall("dwmapi\DwmGetWindowAttribute", "ptr", h, "uint", 14, "uint*", &cloaked, "uint", 4)
        if h != g.Hwnd && h != peek.Hwnd && !cloaked && DllCall("IsWindowVisible", "ptr", h) && DllCall("GetWindowRect", "ptr", h, "ptr", rc)
            && NumGet(rc, 0, "int") < x1 && NumGet(rc, 8, "int") > x0 && NumGet(rc, 4, "int") < y1 && NumGet(rc, 12, "int") > y0
            try found .= (found ? ", " : "") WinGetClass(h) " (" WinGetProcessName(h) ")"
        h := DllCall("GetWindow", "ptr", h, "uint", 2, "ptr")   ; GW_HWNDNEXT
    }
    return found
}

SettingsShot(file) {   ; the settings panel alone; exits when done
    global IMG_DIR
    IMG_DIR := "..\images"                         ; the panel reads A_ScriptDir\IMG_DIR (tools\..\images), not REPO
    SettingsOpen(), Sleep(900)                     ; built and painted
    hw := pnl.gui.Hwnd, MouseGetPos(&mx, &my), WinGetPos(&x, &y, &w, &h, hw)
    if mx >= x && mx < x + w && my >= y && my < y + h {   ; a cursor on the panel lights up a hover look: slide the panel aside
        mi := Buffer(40, 0), NumPut("uint", 40, mi), DllCall("GetMonitorInfoW", "ptr", CurrentMonitor(), "ptr", mi)   ; rcWork
        WinMove mx > x + w // 2 ? NumGet(mi, 20, "int") : NumGet(mi, 28, "int") - w, y, , , hw
    }
    SendMessage 0x128, 0x10002, 0, hw              ; WM_UPDATEUISTATE, clear UISF_HIDEFOCUS: the focus ring, as after a first Tab
    Sleep 400
    Capture(0, 0, w, h, file, hw)
    PanelClose()
    ExitApp
}

DemoWindow(spec, title) {   ; an app-like window, shown without activation, with a system icon (WM_SETICON)
    w := spec[2], h := spec[3], night := InStr("1E1E1E 202020 0C0C0C", spec[4])
    win := Gui("-DPIScale", title), win.BackColor := spec[4], win.MarginX := 0, win.MarginY := 0
    win.AddText("x0 y0 w" w " h64 Background" spec[5])
    switch spec[8] {
    case "cat":                                    ; the shipped picture, as a photo viewer would show it
        win.AddPicture("x" (w - 560) // 2 " y" 120 " w560 h560 BackgroundTrans", REPO "\images\chill_few.png")
    case "keys":                                   ; a calculator's display and keypad
        win.SetFont("s40 c202020", "Segoe UI"), win.AddText("x40 y110 w" w - 80 " Right BackgroundTrans", "42")
        Loop 20
            win.AddText(Format("x{} y{} w{} h{} BackgroundE9E9E9", 24 + Mod(A_Index - 1, 4) * 150, 260 + (A_Index - 1) // 4 * 140, 138, 128))
    default:
        win.SetFont("s14 c" (night ? (spec[8] = "term" ? "4CC2FF" : "9CDCFE") : "404040"), spec[8] = "lines" ? "Segoe UI" : "Consolas")
        text := Map("code", ["## Day 1 — 台北 Taipei", "- [x] 101 observatory", "- [ ] 夜市 night market", "", "## Day 2 — 九份 Jiufen", "- [ ] tea house", "- [ ] lanterns"]
            , "term", ["PS> git status", "On branch main", "nothing to commit, working tree clean", "PS> meow", "=^.^=", "PS> _"]
            , "lines", ["Re: Friday lunch?", "Weekly update — draft", "Your package is on its way", "相片已分享 Photos shared", "Meeting notes"])[spec[8]]
        for i, line in text
            win.AddText("x48 y" 70 + i * 52 " w" w - 96 " BackgroundTrans", line)
    }
    win.Show("NA w" w " h" h)
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
