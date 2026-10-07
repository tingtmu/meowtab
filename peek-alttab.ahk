#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-SetName peek-alttab
;@Ahk2Exe-SetDescription Windows 11 style Alt+Tab switcher with a peeking mood image
;@Ahk2Exe-SetVersion 1.1.0
;@Ahk2Exe-SetCopyright MIT`, tingwei
;@Ahk2Exe-SetMainIcon assets\peek-alttab.ico
; Alt+Tab limited to the focused monitor. Windows cloaks windows on other virtual desktops, and
; tiling WMs like GlazeWM cloak hidden workspaces, so this == "current desktop / workspace".
; Hold Alt, press Tab / Shift+Tab or the arrow keys to move, release Alt to switch, Esc to cancel.
; While Alt is held the mouse works too: click a tile to switch, its X to close that window.

; ===== Settings: built-in defaults. Tray icon > Settings… saves overrides to settings.ini, which wins. =====
; (Or edit these, then right-click tray icon > Reload Script.)
FONT_NAME  := FontInstalled("Noto Sans TC") ? "Noto Sans TC" : "Segoe UI"   ; tile titles: Latin + Traditional Chinese; else Segoe UI (CJK falls back)
FONT_SIZE  := 10      ; title size in points (the tile headers grow to fit)
IMG_DIR    := "images" ; folder of the mood images, relative to this script
IMG_PREFIX := "chill" ; mood images in IMG_DIR: <prefix>_few.png, <prefix>_some.png, <prefix>_many.png
SOME_FROM  := 3       ; window counts: few = 1 .. SOME_FROM-1, some = SOME_FROM .. MANY_FROM-1,
MANY_FROM  := 8       ; many = MANY_FROM and up (2 <= SOME_FROM < MANY_FROM <= 30)
IMG_SIZE   := 250     ; image peeking over the pane's top-left edge, in pixels
PEEK_MIN   := 0.72    ; share of the image's art (transparent padding ignored) above the pane at 1 window,
PEEK_MAX   := 0.95    ; rising evenly to this at MANY_FROM + 4 windows and beyond (0.30 .. 1.00)
WM_PROCESS := ""      ; optional: script exits when this process is gone, e.g. "glazewm.exe" ("" = never)
SettingsLoad()        ; settings.ini overrides (validated; see settings-panel.ahk)
; ==========================================================================

; ===== Native look (Windows 11 Alt+Tab): sizes in px at 96 dpi, scaled by A_ScreenDPI / 96; colours RRGGBB, alphas 0-255 =====
PANE_PAD    := 58      ; pane edge to the tiles on all sides (rows are centred, so short rows show more)
TILE_GAP    := 26      ; between tiles, across and down
TILE_H      := 0.22    ; tile height (header included), share of the work area's height
TILE_MIN    := 0.40    ; too many rows: thumbnails shrink step by step to this share of their height, then the grid scrolls
PANE_MAX_W  := 0.84    ; widest pane, share of the work area's width
ASPECT_MIN  := 0.75, ASPECT_MAX := 2.0  ; thumbnail slot width / height, clamped (else the window's own shape)
TILE_MIN_W  := 134     ; narrowest tile (as native), so a narrow window's title still reads; its thumbnail is centred in it
PANE_MARGIN := 16      ; screen room kept above the image and below the pane
TILE_R      := 12      ; tile corner radius
HEADER_H    := 40      ; header strip over the thumbnail; taller when the title font needs it (its line height + 24)
ICON_PX     := 16, ICON_X := 12, TITLE_X := 36   ; header: app icon size and left edge, the title's left edge
BIG_ICON    := 48      ; minimized window: its app icon, centred in the thumbnail slot (a thumbnail draws over it)
SEL_GAP     := 5, SEL_INNER := 2, SEL_RING := 4  ; selection, from the tile outwards: gap, inner stroke, accent ring
CLOSE_W     := 40, CLOSE_X := 12, CLOSE_LINE := 1.25   ; close button (header-high), its X: size and stroke
CLOSE_RGB   := "E81123", CLOSE_HOT := "C42B1C"   ; close button, and with the mouse on it
PEEK_X      := 24      ; image's left edge, from the pane's left edge
PEEK_MS     := 180, ANIM_TICK := 15   ; image slide-up / glide (ease-out cubic), animation timer period; ms
TEXT_HINT   := 4       ; GDI+ text: 4 AntiAlias (full CJK strokes), 3 AntiAliasGridFit; never ClearType on glass (fringes)
; Light / dark, as Windows mode (the taskbar's). pane: opaque fill where there's no acrylic (before build 22621);
; head / hot: header fill / hovered; slot: under the thumbnail; inner: the selection's inner stroke; ring: default accent
LIGHT_PAL := {pane: "F3F3F3", text: "000000", head: ["FFFFFF", 200], hot: ["FFFFFF", 240], slot: ["FFFFFF", 90]
    , inner: ["FFFFFF", 180], ring: "005FB8"}
DARK_PAL  := {pane: "202020", text: "FFFFFF", head: ["000000", 166], hot: ["000000", 110], slot: ["000000", 70]
    , inner: ["000000", 180], ring: "4CC2FF"}
; ==========================================================================

CoordMode "Mouse", "Screen"
if WM_PROCESS != ""
    SetTimer () => ProcessExist(WM_PROCESS) || ExitApp(), 2000

; Recency is tracked from foreground changes, not Z-order: tiling WMs re-tile with
; SetWindowPos, which reshuffles Z-order without anything being activated.
global mru := Map(), mruTick := 0   ; hwnd -> stamp of last activation (higher = newer)
for hwnd in WinGetList()            ; seed from Z-order so the first Alt+Tab is sensible
    mru[hwnd] := -A_Index
if a := WinExist("A")               ; the active window is the newest
    mru[DllCall("GetAncestor", "ptr", a, "uint", 3, "ptr")] := 0
global fgHook := CallbackCreate(OnForeground, "F", 7)
global fgHookH := DllCall("SetWinEventHook", "uint", 3, "uint", 3, "ptr", 0, "ptr", fgHook   ; EVENT_SYSTEM_FOREGROUND
    , "uint", 0, "uint", 0, "uint", 0, "ptr")                                               ; WINEVENT_OUTOFCONTEXT
OnExit((*) => (DllCall("UnhookWinEvent", "ptr", fgHookH), 0))   ; exit frees mru before it stops pumping events

global wins := [], idx := 0, cycling := false, opens := 0   ; listed windows (most recent first), the selected one; opens so far
global grid := 0, tiles := []                  ; the open pane's layout (GridLayout) and one tile per window
global thumbs := [], icons := Map(), surf := 0  ; per open: DWM thumbnails, app icons (hwnd -> [header, big]), drawing surface
global hover := 0, hoverX := false             ; tile under the mouse (0 = none), and whether on its close button
global mouseAt := 0, pressAt := 0, clickAt := 0, wheel := 0, tracking := false   ; mouse input, noted for the timers (see PaneMouse)
global dark := ThemeDark(), pal := LIGHT_PAL, accentRgb := LIGHT_PAL.ring  ; Windows mode; this open's palette and ring colour
DllCall("LoadLibrary", "str", "gdiplus")
si := Buffer(24, 0), NumPut("uint", 1, si)   ; GdiplusStartupInput
global gdipToken := 0                        ; GDI+ stays up: every open draws with it
DllCall("gdiplus\GdiplusStartup", "ptr*", &gdipToken, "ptr", si, "ptr", 0)
global imgs := [], spans := []                 ; mood images (few / some / many; 0 = none); spans: [top, bottom] rows of their art
for mood in ["few", "some", "many"]
    imgs.Push(ScaledBitmap(A_ScriptDir "\" IMG_DIR "\" IMG_PREFIX "_" mood ".png", IMG_SIZE, &span)), spans.Push(span)
MOOD_NOTES := ["cozy ♡", "nice ✌", "too many…"]  ; the moods' names in the Settings panel, same order as imgs
global titleFont := 0, titleFmt := 0, titleLineH := 0   ; tile titles (TitleInit): font, one-line format, line height in px
TitleInit()
; The pane: Windows 11's acrylic (the DWM system backdrop) on a popup that is never activated, not even by a
; click (NOACTIVATE). Everything else is drawn into `surf` and blitted on WM_ERASEBKGND.
global BACKDROP := VerCompare(A_OSVersion, "10.0.22621") >= 0   ; DWM system backdrop available (else an opaque pane)
global g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")
g.BackColor := "000000"                      ; GDI black = alpha 0: clear glass wherever Render leaves it
PaneInit(g.Hwnd)
OnMessage(0x14, PaneErase)                   ; WM_ERASEBKGND
for msg in [0x200, 0x201, 0x202, 0x203, 0x2A3, 0x20A]   ; WM_MOUSEMOVE, WM_LBUTTONDOWN / UP / DBLCLK, WM_MOUSELEAVE, WM_MOUSEWHEEL
    OnMessage(msg, PaneMouse)
OnMessage(0x1A, ThemeChanged)                ; WM_SETTINGCHANGE: light / dark mode switched
; The image lives in its own per-pixel-alpha window, stacked just below the pane; only its rows above the
; pane's top edge show. Click-through and never activated (LAYERED|TRANSPARENT|NOACTIVATE).
global peek := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08080020")
global peekDC := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")   ; holds the shown image for UpdateLayeredWindow
global peekK := 0, peekN := 0, peekFrom := 0, peekGoal := 0, peekT := 0, peekX := 0, peekEdge := 0, peekRim := 0   ; see PeekTo
SetTimer WarmUp, -200                        ; once startup is done: GDI+'s cold start, off the first Alt+Tab

!Tab::Step(1)
!+Tab::Step(-1)

#HotIf cycling
!Esc::Finish(false)
!Delete::CloseSelected()
!Right::Step(1)
!Left::Step(-1)
!Down::StepRow(1)
!Up::StepRow(-1)
#HotIf

; Tab / Shift+Tab / Right / Left: the next / previous tile, wrapping. The first press opens the pane.
Step(dir) {
    global wins, idx, cycling, opens
    Critical                          ; the mouse, image and WatchAlt timers wait: they read what this changes
    if cycling
        return SelectTile(Mod(idx - 1 + dir + wins.Length, wins.Length) + 1)
    wins := CollectWindows()
    if wins.Length = 0
        return
    cycling := true, opens += 1
    idx := 0                          ; current window not in the list: first Tab picks item 1
    fg := DllCall("GetAncestor", "ptr", WinExist("A"), "uint", 3, "ptr")   ; GA_ROOTOWNER
    for i, hwnd in wins
        if hwnd = fg {
            wins.RemoveAt(i), wins.InsertAt(1, fg), idx := 1
            break
        }
    idx := idx = 0 && dir < 0 ? wins.Length : Mod(idx - 1 + dir + wins.Length, wins.Length) + 1
    ShowPane(true)
    SetTimer WatchAlt, 20
}

; Down / Up: the tile in the row below / above whose centre is closest across; nothing past the last / first row.
StepRow(d) {
    Critical
    r := tiles[idx].row + d
    if r >= 1 && r <= grid.rows.Length
        SelectTile(Nearest(r, tiles[idx].x + tiles[idx].w / 2))
}

WatchAlt() {
    if DllCall("GetAsyncKeyState", "int", 0x12, "short") >= 0   ; VK_MENU: OS state, covers injected Alt
        Finish(true)
}

Finish(activate) {
    global cycling
    Critical                          ; a pending mouse timer then finds `cycling` off
    SetTimer WatchAlt, 0
    PeekHide(), g.Hide()
    PaneFree()                        ; thumbnails, icons, surface, mouse state
    cycling := false
    if activate && idx >= 1 && idx <= wins.Length && WinExist(wins[idx])
        WinActivate(wins[idx])
}

; Close tile i's window (0 = the selected one) and keep the pane open, like native Alt+Tab. The selection
; stays on its window (as it is once the close is done) while that one is open.
CloseSelected(i := 0) {
    global wins, idx
    hwnd := wins[i || idx], session := opens
    try WinClose(hwnd)
    Loop 20 {                     ; wait up to 1s; apps with a save prompt stay in the list
        if !IsOpen(hwnd)
            break
        Sleep 50
    }
    Critical                      ; WatchAlt must not run between `wins := alive` and the idx fix-up
    if !cycling || opens != session   ; Alt was released (or Esc) while waiting, perhaps Alt+Tab again since
        return
    sel := wins[idx], alive := [], at := 0   ; read now: Tab during the wait counts
    for h in wins
        if IsOpen(h)
            alive.Push(h), at := h = sel ? alive.Length : at
    if alive.Length = 0
        return Finish(false)
    wins := alive, idx := at || Min(idx, alive.Length)
    ShowPane(false)
}

; Exists and visible (apps that "close to tray" only hide their window).
IsOpen(hwnd) => WinExist(hwnd) && DllCall("IsWindowVisible", "ptr", hwnd)

; Lay out `wins` in the current monitor's work area and show the pane with the image over its top-left edge.
; fresh = a new open (the image slides up), else the count changed (it glides to its new height).
ShowPane(fresh) {
    static mon := 0                   ; an open stays on the monitor it opened on
    Critical
    if fresh
        mon := CurrentMonitor()
    mi := Buffer(40, 0), NumPut("uint", 40, mi)
    DllCall("GetMonitorInfoW", "ptr", mon, "ptr", mi)
    l := NumGet(mi, 20, "int"), t := NumGet(mi, 24, "int")   ; rcWork
    r := NumGet(mi, 28, "int"), b := NumGet(mi, 32, "int")
    n := wins.Length, k := MoodOf(n), sp := spans[k]
    up := imgs[k] ? Round(sp[1] + (sp[2] - sp[1]) * PeekShare(n)) : 0   ; image rows above the pane's edge
    art := Max(up - sp[1], 0)                                          ; of which art (the rest is padding)
    GridLayout(r - l, b - t, art)
    x := l + (r - l - grid.w) // 2, y := Max(t + (b - t - grid.h) // 2, t + grid.margin + art)   ; centred, under the art
    PaneShow(x, y, fresh)
    PeekTo(k, up, x + Round(PEEK_X * grid.S), y, fresh)
}

; Share of the art above the pane for n windows: PEEK_MIN at 1, evenly up to PEEK_MAX at MANY_FROM + 4 and beyond.
PeekShare(n) => PEEK_MIN + (PEEK_MAX - PEEK_MIN) * Min(Max(n - 1, 0) / (MANY_FROM + 3), 1)

; Monitor of the active window; falls back to the cursor's monitor (e.g. empty workspace).
CurrentMonitor() {
    hwnd := WinExist("A")
    if hwnd && !IsShell(hwnd)
        return DllCall("MonitorFromWindow", "ptr", hwnd, "uint", 2, "ptr")
    MouseGetPos &x, &y
    return DllCall("MonitorFromPoint", "int64", (y << 32) | (x & 0xFFFFFFFF), "uint", 2, "ptr")
}

OnForeground(hook, event, hwnd, idObject, *) {
    global mruTick
    if idObject != 0 || !hwnd           ; OBJID_WINDOW only
        return
    mru[hwnd] := ++mruTick
    owner := DllCall("GetAncestor", "ptr", hwnd, "uint", 3, "ptr")   ; GA_ROOTOWNER: a dialog counts for its app
    if owner && owner != hwnd
        mru[owner] := mruTick
}

; Alt+Tab-eligible windows on the current monitor, most recently activated first.
CollectWindows() {
    mon := CurrentMonitor()
    out := []
    for hwnd in WinGetList() {          ; Z-order breaks ties between never-activated windows
        try {   ; a window may close mid-scan
            if IsSwitchable(hwnd) && DllCall("MonitorFromWindow", "ptr", hwnd, "uint", 2, "ptr") = mon
                out.Push(hwnd)
        }
    }
    for hwnd in [mru*]                  ; forget closed windows (handles get reused)
        if !WinExist(hwnd)
            mru.Delete(hwnd)
    return SortByRecency(out)
}

; Stable insertion sort, newest first; lists are short.
SortByRecency(hwnds) {
    out := []
    for hwnd in hwnds {
        s := mru.Get(hwnd, -1e9), i := out.Length + 1
        while i > 1 && mru.Get(out[i - 1], -1e9) < s
            i--
        out.InsertAt(i, hwnd)
    }
    return out
}

IsShell(hwnd) {
    cls := WinGetClass(hwnd)
    return cls = "Progman" || cls = "WorkerW" || cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd"
}

IsSwitchable(hwnd) {
    if WinGetTitle(hwnd) = "" || IsShell(hwnd)
        return false
    ex := WinGetExStyle(hwnd)
    if ex & 0x08000000                                   ; WS_EX_NOACTIVATE
        return false
    if !(ex & 0x40000) {                                 ; not WS_EX_APPWINDOW
        if ex & 0x80                                     ; WS_EX_TOOLWINDOW
            return false
        if DllCall("GetWindow", "ptr", hwnd, "uint", 4, "ptr")  ; owned window
            return false
    }
    cloaked := 0                                         ; DWMWA_CLOAKED: other desktops, hidden workspaces, background UWP
    DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 14, "uint*", &cloaked, "uint", 4)
    return !cloaked
}

; The native look (theme, acrylic, grid, drawing, thumbnails, mouse), app icons, the peeking image (functions
; only); the Settings… panel and settings.ini. alttab-native.ahk goes first: its #Warn covers the rest.
#Include %A_LineFile%\..\alttab-native.ahk
#Include %A_LineFile%\..\alttab-icons.ahk
#Include %A_LineFile%\..\alttab-peek.ahk
#Include %A_LineFile%\..\settings-panel.ahk
