#Requires AutoHotkey v2.0
#SingleInstance Off
; README screenshots of the real MeowTab pane: acrylic, live DWM thumbnails and the peeking picture, captured
; from the screen (needs a connected, unlocked desktop). Privacy: only this script's demo windows are listed
; (neutral titles, fake contents), over a stand-in wallpaper covering the monitor the pane opens on, and the
; capture is cropped to the pane and the picture - nothing of your own windows can end up in the image.
; Run from the repo root:  AutoHotkey64.exe /ErrorStdOut tools\readme-shots.ahk <light | dark> [out.png]
; (default out: docs\meowtab.png / docs\meowtab-dark.png). Keep hands off the mouse and keyboard for ~5 s.
#Include %A_LineFile%\..\..\meowtab.ahk

REPO := RegExReplace(A_LineFile, "\\[^\\]+\\[^\\]+$")   ; the folder above tools\
global imgs := [], spans := []                 ; the include looked for the pictures next to this script: load the repo's
for mood in ["few", "some", "many"]
    imgs.Push(ScaledBitmap(REPO "\" IMG_DIR "\" IMG_PREFIX "_" mood ".png", IMG_SIZE, &span)), spans.Push(span)

which := A_Args.Length ? A_Args[1] : "light"
out := A_Args.Length > 1 ? A_Args[2] : REPO "\docs\meowtab" (which = "dark" ? "-dark" : "") ".png"
if !RegExMatch(out, "^([A-Za-z]:)?\\")         ; relative: to where it was started from
    out := A_InitialWorkingDir "\" out
DEMO := [["Trip plan — 旅行計畫.md", 1500, 950, "1E1E1E", "3C3C3C", "shell32.dll", 71, "code"]
    , ["小算盤 Calculator", 640, 980, "F3F3F3", "0067C0", "shell32.dll", 24, "keys"]
    , ["Photos — sleepy cat.png", 1400, 900, "202020", "2B2B2B", "imageres.dll", 68, "cat"]
    , ["收件匣 Inbox", 1400, 900, "FFFFFF", "0F6CBD", "shell32.dll", 157, "lines"]
    , ["Terminal", 1200, 700, "0C0C0C", "1F1F1F", "imageres.dll", 312, "term"]]
made := []
for spec in DEMO
    made.Push(DemoWindow(spec))
Sleep 800
mi := Buffer(40, 0), NumPut("uint", 40, mi), DllCall("GetMonitorInfoW", "ptr", CurrentMonitor(), "ptr", mi)   ; where the pane opens
ml := NumGet(mi, 4, "int"), mt := NumGet(mi, 8, "int"), mr := NumGet(mi, 12, "int"), mb := NumGet(mi, 16, "int")   ; rcMonitor
wall := Wallpaper(which = "dark", ml, mt, mr - ml, mb - mt)   ; covers that whole monitor: nothing of yours shows
Sleep 300
wins := [], idx := 2, cycling := true, dark := which = "dark"
for win in made
    wins.Push(win.Hwnd)
ShowPane(true), Critical("Off")
if which = "dark"                                  ; the hover look on tile 3 (the selection is tile 2)
    hover := 3, hoverX := false, Render(surf), Present()
Sleep(700), DllCall("dwmapi\DwmFlush")
g.GetPos(&px, &py, &pw, &ph), WinGetPos(&kx, &ky, &kw, &kh, peek.Hwnd)
x0 := Max(px - 48, ml), y0 := Max(Min(ky, py) - 32, mt)   ; crop to the pane, the picture and a margin, inside that monitor
Capture(x0, y0, Min(px + pw + 48, mr) - x0, Min(py + ph + 48, mb) - y0, out)
Finish(false)
for win in made
    win.Destroy()
wall.Destroy()
ExitApp

DemoWindow(spec) {   ; an app-like window, shown without activation, with a system icon (WM_SETICON)
    w := spec[2], h := spec[3], night := InStr("1E1E1E 202020 0C0C0C", spec[4])
    win := Gui("-DPIScale", spec[1]), win.BackColor := spec[4], win.MarginX := 0, win.MarginY := 0
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

Capture(x, y, w, h, file) {   ; screen rect -> PNG, DWM's composition included (CAPTUREBLT)
    sdc := DllCall("GetDC", "ptr", 0, "ptr"), mdc := DllCall("CreateCompatibleDC", "ptr", sdc, "ptr")
    hbm := DllCall("CreateCompatibleBitmap", "ptr", sdc, "int", w, "int", h, "ptr"), ob := DllCall("SelectObject", "ptr", mdc, "ptr", hbm, "ptr")
    ok := DllCall("BitBlt", "ptr", mdc, "int", 0, "int", 0, "int", w, "int", h, "ptr", sdc, "int", x, "int", y, "uint", 0x40CC0020)
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
