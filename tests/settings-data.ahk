; #Included by meowtab.test.ahk where its settings and data checks run: these top-level lines run there, in order.
; The data folder, settings.ini and pictures (gif-files, pane-files and pane-draw.ahk), then the shortcuts, with real keys.

AppFiles() {   ; settings.ini beside meowtab.ahk and the files in its images\ (name, size, time): the test must not change them
    s := ""
    for pat in [AppDir() "settings.ini", AppDir() IMG_DIR "\*"]
        Loop Files pat
            s .= A_LoopFileName " " A_LoopFileSize " " A_LoopFileTimeModified "`n"
    return s
}

; A shortcut through KeysParse: "readable hotkey-name", or why it's refused.
Parsed(text, stay := false, other := "") => (why := KeysParse(text, stay, other, &keys, &hk)) = "" ? keys " " hk : why

; User data goes to DATA_DIR (the user's AppData\MeowTab in real use), never next to the script.
got := ""
Loop Files DATA_DIR "\*", "FD"
    got .= A_LoopFileName " "
Check("data folder is new and empty, but for the settings.ini of the look to test in", Trim(got), A_Args.Length ? "settings.ini" : "")
before := AppFiles()
Check("saving settings: no error", SettingsWrite(Map("FONT_SIZE", 14)), "")
Check("saving settings creates <data>\settings.ini", IniRead(DATA_DIR "\settings.ini", "settings", "FONT_SIZE", ""), 14)
src := DATA_DIR "\src.png", bm := NewBitmap(8, 8), SavePng(bm, src), DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
imp := ""
for mood in Moods()
    imp .= ImportImage(src, PendingImage(mood))
Check("importing pictures: no error", imp, "")
Check("pending pictures sit in <data>\images", FileExist(DATA_DIR "\images\custom_few.pending.png") != "", true)
PendingClear()
Check("PendingClear sweeps the user folder", FileExist(DATA_DIR "\images\custom_*.pending.png") "", "")
for mood in Moods()
    ImportImage(src, PendingImage(mood))
Check("saving pictures: no error", ImagesCommit("chill"), "")
Check("saving pictures puts custom_* in <data>\images", FileExist(DATA_DIR "\images\custom_few.png") != "" && FileExist(DATA_DIR "\images\custom_many.png") != "", true)
Check("and no pending file is left", FileExist(DATA_DIR "\images\*.pending.png") "", "")
Check("the lookup finds the user folder first", MoodImage("custom", "some"), DATA_DIR "\images\custom_some.png")
Check("else falls back to the app folder", MoodImage("chill", "some"), A_ScriptDir "\" IMG_DIR "\chill_some.png")
FileCopy src, DATA_DIR "\images\chill_some.png"
Check("a user set of the same name wins", MoodImage("chill", "some"), DATA_DIR "\images\chill_some.png")
#Include %A_LineFile%\..\gif-files.ahk
Check("the app's settings.ini and images\ are unchanged", AppFiles(), before)
IniWrite "glass", DATA_DIR "\settings.ini", "settings", "PANE_LOOK"
runLook := PANE_LOOK, PANE_LOOK := lookDefault, SettingsLoad()   ; a reload from the built-in look, as a restart has it
Check("PANE_LOOK=glass in settings.ini: a reload gives the default look and reports the line"
    , PANE_LOOK ", " SETTINGS_ISSUES.Length ": " (SETTINGS_ISSUES.Length ? SETTINGS_ISSUES[1] : "")
    , lookDefault ", 1: PANE_LOOK = glass: expected velvet or windows11, using " lookDefault)
PANE_LOOK := runLook, A_Args.Length ? IniWrite(runLook, DATA_DIR "\settings.ini", "settings", "PANE_LOOK") : IniDelete(DATA_DIR "\settings.ini", "settings", "PANE_LOOK")   ; this run's look again
IniWrite "curent", DATA_DIR "\settings.ini", "settings", "MONITORS"
SettingsLoad()                             ; a reload from the built-in all
Check("MONITORS=curent in settings.ini: a reload lists all monitors and reports the line"
    , MONITORS ", " SETTINGS_ISSUES.Length ": " (SETTINGS_ISSUES.Length ? SETTINGS_ISSUES[1] : "")
    , "all, 1: MONITORS = curent: expected all or current, using all")
IniWrite "CURRENT", DATA_DIR "\settings.ini", "settings", "MONITORS"
SettingsLoad()
Check("MONITORS=CURRENT in settings.ini reads as current", MONITORS ", " SETTINGS_ISSUES.Length, "current, 0")
MONITORS := "all", IniDelete(DATA_DIR "\settings.ini", "settings", "MONITORS")   ; the built-in again
#Include %A_LineFile%\..\pane-files.ahk
#Include %A_LineFile%\..\pane-draw.ahk

; Shortcuts: SWITCH_KEYS / STAY_KEYS as settings.ini has them (KeysParse), registered by KeysRegister. Custom ones are
; checked holding Ctrl: if a check goes wrong, a held Win or Alt could open Start or a menu bar.
Check("shortcuts in any order and case come back readable, with their hotkey names"
    , Parsed("alt+tab") ", " Parsed("shift+alt+ctrl+tab", true) ", " Parsed("win+q"), "Alt+Tab !Tab, Ctrl+Alt+Shift+Tab ^!+Tab, Win+Q #q")
Check("Alt+Esc is refused", Parsed("Alt+Esc"), "Escape is used inside the switcher")
Check("Shift+Tab is refused", Parsed("Shift+Tab"), "it needs Alt, Ctrl or Win")
Check("Ctrl+Alt+Q is refused for switching", Parsed("Ctrl+Alt+Q"), "switching takes only one of Alt, Ctrl and Win")
Check("Alt+Shift+Q is refused for switching", Parsed("Alt+Shift+Q"), "Shift is kept for going back")
Check("Win+L is refused", Parsed("Win+L"), "Windows keeps Win+L for locking the screen")
Check("staying open on Alt+Shift+Tab is refused while switching is Alt+Tab", Parsed("Alt+Shift+Tab", true, "Alt+Tab"), "going back already uses it")
IniWrite "Alt+Esc", DATA_DIR "\settings.ini", "settings", "SWITCH_KEYS"
SettingsLoad()                             ; a reload: the built-in shortcuts are still set
Check("SWITCH_KEYS=Alt+Esc in settings.ini: a reload gives Alt+Tab and reports the line"
    , SWITCH_KEYS ", " SETTINGS_ISSUES.Length ": " (SETTINGS_ISSUES.Length ? SETTINGS_ISSUES[1] : "")
    , "Alt+Tab, 1: SWITCH_KEYS = Alt+Esc: Escape is used inside the switcher, using Alt+Tab")
IniWrite "Ctrl+Tab", DATA_DIR "\settings.ini", "settings", "SWITCH_KEYS"
IniWrite "Ctrl+Shift+Tab", DATA_DIR "\settings.ini", "settings", "STAY_KEYS"
SettingsLoad()
Check("switching on Ctrl+Tab and staying open on Ctrl+Shift+Tab clash: both get their defaults", SWITCH_KEYS ", " STAY_KEYS ", " SETTINGS_ISSUES.Length
    , "Alt+Tab, Ctrl+Alt+Tab, 1")
IniDelete DATA_DIR "\settings.ini", "settings", "STAY_KEYS"

iw := Gui(, "alttab-test I"), ed := iw.AddEdit("w280 h180"), iw.Show("w300 h200"), guis.Push(iw), names[iw.Hwnd] := "I"
DllCall("imm32\ImmAssociateContext", "ptr", ed.Hwnd, "ptr", 0, "ptr")   ; no IME: a sent q types a q, a Chinese one would take it
for n in ["D", "C", "B"]
    Act(h[n])
Act(iw.Hwnd)                               ; recency: I B C D
Press("{LAlt down}{Tab}"), Press("{Tab}"), Press("{LAlt up}", 300)
Check("real keys: Alt held, Tab twice, Alt released goes to 3rd (C)", names.Get(WinExist("A"), "?"), "C")
SWITCH_KEYS := "Ctrl+Q", KeysRegister()    ; recency C I B D: Q -> I, B, D, Shift+Q -> B
Press("{LCtrl down}q"), Press("q"), Press("q"), Press("+q"), Press("{LCtrl up}", 300)
Check("Ctrl+Q bound: Ctrl held, Q three times, Shift+Q, Ctrl released goes to 3rd (B)", names.Get(WinExist("A"), "?"), "B")
Press("{LCtrl down}q"), wasOpen := cycling, Press(wasOpen ? "{Esc}" : ""), Press("{LCtrl up}", 300)   ; not opened: Ctrl+Esc would open Start
Check("Ctrl held, Q, Esc, Ctrl released: the pane closes and the same window stays (B)", wasOpen " " cycling " " names.Get(WinExist("A"), "?"), "1 0 B")
Press("{LCtrl down}q"), at := idx, Press("{Right}"), at .= " " idx, Press("{LCtrl up}", 300)   ; recency B C I D: Right -> I
Check("Ctrl held, Q, Right: the selection moves a tile", at, "2 3")
Act(iw.Hwnd), ed.Value := "", Press("q")
Check("with the pane closed, a plain q reaches the Edit", ed.Value, "q")
Check("saving Ctrl+Q: no error", SettingsWrite(Map("SWITCH_KEYS", "Ctrl+Q")), "")
SWITCH_KEYS := "Alt+Tab", SettingsLoad(), KeysRegister()   ; as a restart does; recency I B C D
Press("{LCtrl down}q"), wasOpen := cycling, Press("{LCtrl up}", 300)
Check("then a load and registering again: Ctrl+Q still opens the pane and switches (B)", SWITCH_KEYS " " wasOpen " " names.Get(WinExist("A"), "?"), "Ctrl+Q 1 B")
Check("SettingsReset: no error", SettingsReset(), "")
SWITCH_KEYS := "Alt+Tab", SettingsLoad(), KeysRegister()   ; recency B I C D
Press("{LCtrl down}q"), ctrlQ := cycling, Press("{LCtrl up}"), Press("{LAlt down}{Tab}"), altTab := cycling, Press("{LAlt up}", 300)
Check("then a load: Alt+Tab is back and opens the pane, Ctrl+Q doesn't (I)", SWITCH_KEYS " " ctrlQ " " altTab " " names.Get(WinExist("A"), "?")
    , "Alt+Tab 0 1 I")

; The stay-open mode (STAY_KEYS, Ctrl+Alt+Tab): the pane stays once every key is up. Enter switches, Esc or a click off it
; closes it, and other keys are blocked meanwhile.
Press("{LCtrl down}{LAlt down}{Tab}"), Press("{LAlt up}{LCtrl up}", 300)   ; recency I B C D: on B
Check("Ctrl+Alt+Tab, then every key released: the pane stays open on the previous window (B)", cycling " " names.Get(wins[idx], "?"), "1 B")
Press("{Right}"), Press("{Right}"), Press("{Enter}", 300)
Check("then Right, Right, Enter goes to the 4th window (D)", cycling " " names.Get(WinExist("A"), "?"), "0 D")
Press("{LCtrl down}{LAlt down}{Tab}"), Press("{LAlt up}{LCtrl up}"), at := idx   ; recency D I B C: on I
Press("{LAlt down}{Tab}"), Press("{LAlt up}", 300)
Check("open again, Alt held, Tab, Alt released: the selection moves a tile, and the pane stays open", at " " idx " " cycling, "2 3 1")
Press("{Esc}", 300)
Check("then Esc closes it, and the same window stays (D)", cycling " " names.Get(WinExist("A"), "?"), "0 D")
mi := Buffer(40, 0), NumPut("uint", 40, mi), DllCall("GetMonitorInfoW", "ptr", CurrentMonitor(), "ptr", mi)
WinMove(NumGet(mi, 20, "int"), NumGet(mi, 24, "int"), , , h["C"]), Sleep(100)   ; to the work area's top-left: the pane is centred
WinGetPos(&cx, &cy, , &ch, h["C"])                                               ; and at most PANE_MAX_W wide
Press("{LCtrl down}{LAlt down}{Tab}"), Press("{LAlt up}{LCtrl up}"), wasOpen := cycling   ; on I
Press("{Click " cx + 40 " " cy + ch // 2 "}", 300)
Check("a click on a window outside the pane closes the pane, and that window becomes active (C)", wasOpen " " cycling " " names.Get(WinExist("A"), "?")
    , "1 0 C")
Act(iw.Hwnd), ed.Value := ""               ; recency I C D B
Press("{LCtrl down}{LAlt down}{Tab}"), Press("{LAlt up}{LCtrl up}"), Press("q")
Check("a letter typed while the pane stays open doesn't reach the Edit, and the pane stays open", cycling " " StrLen(ed.Value), "1 0")
Press("{Esc}"), Press("q")
Check("after Esc, a letter reaches the Edit", ed.Value, "q")
Check("Ctrl and Alt aren't left down after a Ctrl+Alt+Tab open and Esc", GetKeyState("Ctrl") " " GetKeyState("Alt"), "0 0")
