; #Included by meowtab.test.ahk where its settings panel checks run: these top-level lines run there, in order.
; The settings panel: its room and scrolling, the shortcut capture, LOOK cards, the WINDOWS tick box (gif-panel, pane-panel.ahk), Classic's.

Field(j) {   ; the open settings panel's shortcut field j (1 = switching, 2 = staying open)
    for hwnd, e in pnl.el
        if e.kind = "keys" && e.j = j
            return e.ctl
}

SaveAt() {   ; where the open settings panel's Save is on the screen: "x,y" of the bar's rightmost button
    for hwnd, e in pnl.el
        if e.kind = "button" && e.ctl.Gui = pnl.gui && (!IsSet(save) || e.x > save.x)
            save := e
    WinGetPos(&x, &y, , , save.ctl)
    return x "," y
}

Whole(ctl) => (ctl.GetPos(, &y, , &h), y >= pnl.off && y + h <= pnl.off + pnl.viewH)   ; a control of the panel's page shows whole

; settings.ini's shortcut lines ("" = none).
KeysLines() => Trim(IniRead(DATA_DIR "\settings.ini", "settings", "SWITCH_KEYS", "") " " IniRead(DATA_DIR "\settings.ini", "settings", "STAY_KEYS", ""))

; The open panel's LOOK cards whose painter, run as WM_DRAWITEM runs it, draws the pick's check: its accent disc in the well's
; corner (PaintLook), read above the check itself.
Marked() {
    s := "", sdc := DllCall("GetDC", "ptr", 0, "ptr"), dc := DllCall("CreateCompatibleDC", "ptr", sdc, "ptr")
    for hwnd, e in pnl.el
        if e.kind = "look" {
            bm := DllCall("CreateCompatibleBitmap", "ptr", sdc, "int", e.w, "int", e.h, "ptr"), ob := DllCall("SelectObject", "ptr", dc, "ptr", bm, "ptr")
            paint := e.paint, paint(dc, e.w, e.h, 0)
            s .= DllCall("GetPixel", "ptr", dc, "int", e.w - Dpx(13), "int", Dpx(9), "uint") = Bgr(LOOK.accent) ? " " e.lk : ""
            DllCall("SelectObject", "ptr", dc, "ptr", ob), DllCall("DeleteObject", "ptr", bm)
        }
    DllCall("DeleteDC", "ptr", dc), DllCall("ReleaseDC", "ptr", 0, "ptr", sdc)
    return Trim(s)
}

Tick() {   ; the open settings panel's WINDOWS tick box (its element)
    for hwnd, e in pnl.el
        if e.kind = "tick"
            return e
}

; The open panel's WINDOWS tick box as its painter, run as WM_DRAWITEM runs it, draws it: "ticked" if its box is the accent,
; read between the box's top and the check (PaintTick), else "unticked".
TickBox() {
    e := Tick(), sdc := DllCall("GetDC", "ptr", 0, "ptr"), dc := DllCall("CreateCompatibleDC", "ptr", sdc, "ptr")
    bm := DllCall("CreateCompatibleBitmap", "ptr", sdc, "int", e.w, "int", e.h, "ptr"), ob := DllCall("SelectObject", "ptr", dc, "ptr", bm, "ptr")
    paint := e.paint, paint(dc, e.w, e.h, 0), c := DllCall("GetPixel", "ptr", dc, "int", Dpx(6) + Dpx(9), "int", (e.h - Dpx(18)) // 2 + Dpx(4), "uint")
    DllCall("SelectObject", "ptr", dc, "ptr", ob), DllCall("DeleteObject", "ptr", bm), DllCall("DeleteDC", "ptr", dc), DllCall("ReleaseDC", "ptr", 0, "ptr", sdc)
    return c = Bgr(LOOK.accent) ? "ticked" : "unticked"
}

WatchDraw(wParam, lParam, *) {   ; WM_DRAWITEM, ahead of the panel's own handler: the elements drawn (drawnEls)
    drawnEls[NumGet(lParam, 24, "ptr")] := true
}

; What fn's keys do to the panel: "menu mode" if they put its thread there (GetGUIThreadInfo: GUI_INMENUMODE 0x4, GUI_SYSTEMMENUMODE 0x8),
; else "no menu mode". That mode holds this thread up, timers too, so a helper process watches and ends it with an Alt tap.
MenuModeDuring(fn) {
    helper := DATA_DIR "\menu-watch.ahk", out := DATA_DIR "\menu-watch.txt"
    FileOpen(helper, "w").Write("
    (
    #NoTrayIcon
    seen := 'no menu mode', t := A_TickCount, info := Buffer(A_PtrSize = 8 ? 72 : 48)
    while seen = 'no menu mode' && A_TickCount - t < 2000 {
        NumPut('uint', info.Size, info)
        if DllCall('GetGUIThreadInfo', 'uint', A_Args[1], 'ptr', info) && NumGet(info, 4, 'uint') & 0xC
            seen := 'menu mode', SendEvent('{LAlt down}{LAlt up}')
        Sleep 20
    }
    FileAppend seen, A_Args[2]
    )")
    Run('"' A_AhkPath '" "' helper '" ' DllCall("GetWindowThreadProcessId", "ptr", pnl.gui.Hwnd, "ptr", 0, "uint") ' "' out '"', , , &pid)
    Wait(500), fn(), ProcessWaitClose(pid, 5)
    return FileExist(out) ? FileRead(out) : "no answer"
}

; The settings panel's room under GlazeWM: its top + bottom outer gaps from config.yaml's text (GlazeGaps), at 150 % (dpi 144).
glazeCfg := "
(
gaps:
  # Whether to scale the gaps with the DPI of the monitor.
  scale_with_dpi: true

  # Gap between adjacent windows.
  inner_gap: '3px'

  # Gap between windows and the screen edge.
  outer_gap:
    top: '46px'
    right: '10px'
    bottom: '6px'
    left: '10px'

window_effects:
  focused_window:
    border:
      enabled: true
      color: '#2da44e'
)"
Check("GlazeWM's gaps from the author's config: top 46 + bottom 6, scaled", GlazeGaps(glazeCfg, 144), 78)
Check("quoted keys, as YAML allows (`"gaps`":, 'outer_gap':, `"top`":), read the same"
    , GlazeGaps(StrReplace(StrReplace(StrReplace(glazeCfg, "gaps:", "`"gaps`":"), "outer_gap:", "'outer_gap':"), "top:", "`"top`":"), 144), 78)
Check("the { top, bottom } flow form reads the same",GlazeGaps("gaps:`n  outer_gap: { top: '46px', right: '10px', bottom: '6px', left: '10px' }  # bar`n", 144), 78)
Check("scale_with_dpi: false leaves them unscaled", GlazeGaps(StrReplace(glazeCfg, "scale_with_dpi: true", "scale_with_dpi: false"), 144), 52)
Check("a gaps: block with only single_window_outer_gap, or no gaps: block, is 0"
    , GlazeGaps("gaps:`n  inner_gap: 3`n  single_window_outer_gap:`n    top: 46`n    bottom: 6`n", 144) " " GlazeGaps("general:`n  focus_follows_cursor: false`n", 144), "0 0")
Check("a % value or empty text can't tell", "[" GlazeGaps(StrReplace(glazeCfg, "top: '46px'", "top: '5%'"), 144) "] [" GlazeGaps("", 144) "]", "[] []")

; The settings panel is never scaled: its window is its content plus the bottom bar, or the room, whichever is less, and the
; page scrolls under the bar. PANEL_ROOM sets the room for these checks: in 600 px (at 96 dpi) it overflows on any screen,
; in 3000 px it fits. The wheel notches are sent to the page, as a wheel over it sends them.
PANEL_ROOM := Dpx(600)
SettingsOpen(), Wait(500), WinGetPos(, , , &wh, pnl.gui), save := SaveAt()
Check("in a 600 px room the panel's window is as tall as the room, and its page overflows", wh " " (pnl.end > 0), PANEL_ROOM " 1")
pnl.hint.ctl.GetPos(, &hy, , &hh), pnl.gui.GetClientPos(, , , &ch)
Check("the hint line sits in the bottom bar, under the page's view", (pnl.hint.ctl.Gui = pnl.gui) " " (hy >= pnl.viewH && hy + hh <= ch), "1 1")
DllCall("SendMessageW", "ptr", pnl.page.Hwnd, "uint", 0x20A, "ptr", 0xFF880000, "ptr", 0), Wait(100)   ; a notch down
WinGetPos(, &py, , , pnl.page), WinGetPos(, &vy, , , pnl.view)
Check("a wheel notch scrolls the page up in its view, and Save stays put", pnl.off " " (vy - py) " " SaveAt()
    , Min(Dpx(60), pnl.end) " " Min(Dpx(60), pnl.end) " " save)
Act(pnl.gui.Hwnd), Tick().ctl.Focus(), Wait(100), was := Whole(Field(1))   ; the WINDOWS tick box, just before the shortcut fields
Press("{Tab}")
Check("Tab from the WINDOWS tick box to the hidden switch field scrolls it into view, whole", was " " (DllCall("GetFocus", "ptr") = Field(1).Hwnd) " " Whole(Field(1)), "0 1 1")
PanelClose(), PANEL_ROOM := Dpx(3000)
SettingsOpen(), Wait(500), save := SaveAt()
DllCall("SendMessageW", "ptr", pnl.page.Hwnd, "uint", 0x20A, "ptr", 0xFF880000, "ptr", 0), Wait(100)
Check("in a 3000 px room the page fits: no scroll bar, and a wheel notch scrolls nothing", pnl.end " " pnl.off " " (SaveAt() = save), "0 0 1")
PanelClose(), PANEL_ROOM := 0                     ; the desktop's room again

; The settings panel's SHORTCUTS row: a click on a field captures the next combination, with every key blocked and the
; hotkeys suspended meanwhile. Keys go only while a capture runs: otherwise Alt+Tab would switch and Esc close the panel.
SettingsWrite(Map("SWITCH_KEYS", "Ctrl+Q", "STAY_KEYS", "Ctrl+Alt+Q")), was := KeysLines()
err := SettingsWrite(Map("SWITCH_KEYS", "Alt+Tab", "STAY_KEYS", "Ctrl+Alt+Tab"))
Check("SettingsWrite with the default shortcuts leaves no shortcut lines in settings.ini", was " -> " err KeysLines(), "Ctrl+Q Ctrl+Alt+Q -> ")
FileDelete DATA_DIR "\settings.ini"
SettingsOpen(), Wait(500)                  ; shown and active
WinGetPos(, &wy, , &wh, pnl.gui), DllCall("GetMonitorInfoW", "ptr", CurrentMonitor(), "ptr", mi)
wt := NumGet(mi, 24, "int"), wb := NumGet(mi, 32, "int"), lf := Buffer(92), DllCall("GetObjectW", "ptr", pnl.f["body"], "int", 92, "ptr", lf)
Check("in the desktop's room the panel's window is inside the work area less Dpx(16), and its text is full size (10 pt)"
    , (wy >= wt && wy + wh <= wb && wh <= wb - wt - Dpx(16)) " " NumGet(lf, 0, "int"), "1 -" Round(10 * A_ScreenDPI / 72))
Field(2).Focus(), Press("+{Tab}")                 ; in view first (Shift+Tab to it), as a user sees a field before clicking it
ControlClick(Field(1)), Wait(100), was := (pnl.cap ? pnl.cap.j : 0) " " A_IsSuspended
Press(pnl.cap ? "{LCtrl down}q" : ""), Press("{LCtrl up}")
Check("a click on the switch field captures with the hotkeys suspended; Ctrl+Q then shows, the hotkeys back"
    , was ", " pnl.keys[1] " " A_IsSuspended, "1 1, Ctrl+Q 0")
ControlClick(Field(1)), Wait(100)
Press(pnl.cap ? "{LAlt down}{Tab}" : ""), Press("{LAlt up}", 300)
Check("a captured Alt+Tab shows as Alt+Tab, and no switcher opens (the panel stays active)"
    , pnl.keys[1] " " cycling " " (WinExist("A") = pnl.gui.Hwnd), "Alt+Tab 0 1")
ControlClick(Field(1)), Wait(100)
Press(pnl.cap ? "{LAlt down}{Esc}" : ""), Press("{LAlt up}", 300)
Check("Alt+Esc is refused with a reason, and the old value stays", pnl.keys[1] " | " pnl.note
    , "Alt+Tab | Alt+Escape can't be used: Escape is used inside the switcher.")
ControlClick(Field(2)), Wait(100)
Press(pnl.cap ? "{LAlt down}{LShift down}{Tab}" : ""), Press("{LShift up}{LAlt up}", 300)
Check("Alt+Shift+Tab for staying open is refused as a clash", pnl.keys[2] " | " pnl.note
    , "Ctrl+Alt+Tab | Alt+Shift+Tab can't be used: going back already uses it.")
ControlClick(Field(1)), Wait(100), was := IsObject(pnl.cap)
Press(was ? "{Esc}" : "", 300)
Check("Esc cancels the capture, and the panel stays open", was " " IsObject(pnl) " " (IsObject(pnl) && IsObject(pnl.cap)) " "
    . A_IsSuspended " " (IsObject(pnl) ? pnl.keys[1] : ""), "1 1 0 0 Alt+Tab")
Act(pnl.gui.Hwnd), ControlClick(Field(1)), Wait(100)   ; Alt let go before the blocked Q: unmasked, Windows sees Alt alone, and Down
                                                        ; then puts the panel in its system menu mode
got := MenuModeDuring(() => (Press(pnl.cap ? "{LAlt down}{q down}" : ""), Press("{LAlt up}"), Press("{q up}"), Press("{Down}", 300)))
Check("a captured Alt+Q with Alt let go before Q, then Down: the panel shows Alt+Q and isn't in menu mode", pnl.keys[1] ", " got, "Alt+Q, no menu mode")
got := ""
for how in ["a click elsewhere", "the panel losing focus", "the panel closing"] {   ; active first, as a real click makes it
    Act(pnl.gui.Hwnd), ControlClick(Field(1)), Wait(100), got .= how ": " A_IsSuspended
    switch A_Index {
    case 1: ControlClick(pnl.hint.ctl)
    case 2: Act(iw.Hwnd)
    case 3: PanelClose()
    }
    Wait(100), got .= " -> " A_IsSuspended (IsObject(pnl) && IsObject(pnl.cap) ? " still capturing" : "") "; "
}
Check("a capture ended by a click elsewhere, the panel losing focus or closing leaves no hotkey suspended", got
    , "a click elsewhere: 1 -> 0; the panel losing focus: 1 -> 0; the panel closing: 1 -> 0; ")
Act(iw.Hwnd), Press("{LAlt down}{Tab}"), wasOpen := cycling, Press("{LAlt up}", 300)
Check("closed without saving: no shortcut lines, and Alt+Tab opens the switcher again", "[" KeysLines() "] " wasOpen, "[] 1")

; The settings panel's LOOK cards, opened in this run's look with the built-in one as a restart has it (the reloads above took
; this run's for it). The whole page fits its room, so every element paints; the WM_DRAWITEMs after a pick are watched.
PANE_LOOK := lookDefault, SettingsLoad(), PANE_LOOK := runLook, PANEL_ROOM := Dpx(3000)
SettingsOpen(), Wait(500), other := runLook = "velvet" ? "windows11" : "velvet", cards := Map(), drawnEls := Map()
for hwnd, e in pnl.el
    if e.kind = "look"
        cards[e.lk] := e
was := pnl.look " " Marked(), OnMessage(0x2B, WatchDraw, -1)
ControlClick(cards[other].ctl), Wait(300), OnMessage(0x2B, WatchDraw, 0)
redrawn := 0
for hwnd, e in pnl.el
    redrawn += e.kind ~= "^(look|scene|sample)$" && drawnEls.Has(hwnd)
Check("a click on the " other " card picks it: it's marked instead of the " runLook " card, and both cards, the peek scenes and the title sample are drawn again"
    , was " -> " pnl.look " " Marked() ", " redrawn " drawn again", runLook " " runLook " -> " other " " other ", 5 drawn again")
got := "", want := ""
for lk in [other, runLook] {                      ; the click picked the other look; Space on this run's card picks it back
    if lk = runLook
        Act(pnl.gui.Hwnd), cards[lk].ctl.Focus(), Press("{Space}")
    SettingsWrite(PanelVals()), got .= lk ": " PanelVals().Get("PANE_LOOK", "none") " [" IniRead(DATA_DIR "\settings.ini", "settings", "PANE_LOOK", "") "] "
    want .= lk ": " lk " [" (lk = lookDefault ? "" : lk) "] "
}
Check("then Space on the " runLook " card picks it back. Save's values carry each pick, and settings.ini holds it as PANE_LOOK"
    . ", but no line for the built-in look (" lookDefault ")", got, want)
; The WINDOWS tick box (read off its painted box: TickBox): opened unticked, as MONITORS is all; Space ticks it and a click
; unticks it, Save's values and settings.ini following. Reset to defaults clears it; the panel opens ticked under current.
got := TickBox(), Act(pnl.gui.Hwnd), Tick().ctl.Focus(), Press("{Space}")
SettingsWrite(PanelVals()), got .= "; Space: " TickBox() " " PanelVals()["MONITORS"] " [" Ini("MONITORS") "]"
ControlClick(Tick().ctl), Wait(100)
SettingsWrite(PanelVals()), got .= "; a click: " TickBox() " " PanelVals()["MONITORS"] " [" Ini("MONITORS") "]"
Check("the WINDOWS tick box opens unticked; Space ticks it, and Save's values put MONITORS=current in settings.ini; a click unticks it, and no MONITORS line is left"
    , got, "unticked; Space: ticked current [current]; a click: unticked all []")
Press("{Space}"), SettingsWrite(PanelVals()), was := Ini("MONITORS"), err := SettingsReset()   ; ticked and saved, then Reset (PanelReset's file work)
PanelClose(), MONITORS := "current", SettingsOpen(), Wait(300), got := TickBox(), MONITORS := "all"
Check("Reset to defaults leaves no MONITORS line, and the panel opens ticked when MONITORS is current", was " -> " err "[" Ini("MONITORS") "], " got, "current -> [], ticked")
PanelClose(), PANEL_ROOM := 0
#Include %A_LineFile%\..\gif-panel.ahk
#Include %A_LineFile%\..\pane-panel.ahk
; Classic's own panel, opened by Classic in a process of its own on a data folder of its own: no LOOK section, as Classic has
; no PANE_LOOK (the panel shows the section where the script defines it), but the WINDOWS one, its label and tick box.
classic := DATA_DIR "\classic-panel.ahk", answer := DATA_DIR "\classic-panel.txt"
FileOpen(classic, "w").Write("#NoTrayIcon`nOnError((e, *) => (FileAppend('error: ' e.Message, A_Args[1]), ExitApp(3)))`n"
    . "DATA_DIR := A_ScriptDir '\classic'`n#Include " AppDir() "meowtab-classic.ahk`n" "
(
SettingsOpen(), n := 0, t := 0
for hwnd, e in pnl.el
    n += e.kind = 'look', t += e.kind = 'tick'
for l in pnl.labels
    n += l[1] = 'LOOK', t += l[1] = 'WINDOWS'
FileAppend(n ' LOOK elements, ' t ' WINDOWS elements, ' pnl.cards.Length ' picture cards', A_Args[1]), ExitApp()
)")
Run('"' A_AhkPath '" /ErrorStdOut "' classic '" "' answer '"', , , &pid)
if stuck := ProcessWaitClose(pid, 10)             ; still running after 10 s: an error dialog on its way out holds it
    ProcessClose(pid)
Check("Classic's own panel has no LOOK section but the WINDOWS one, and Classic exits with it open without an error"
    , (FileExist(answer) ? FileRead(answer) : "no answer") (stuck ? ", then stuck" : ""), "0 LOOK elements, 2 WINDOWS elements, 3 picture cards")
