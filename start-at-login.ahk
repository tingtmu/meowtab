; Start at login for meowtab.ahk and meowtab-classic.ahk (#Included by settings-panel.ahk; tray menu > Start at login):
; a shortcut in the user's Startup folder that starts the switcher when they sign in. MeowTab's exe makes it on its first
; run (Classic's never by itself), and each start of the exe points it at the exe again if the app folder moved. Windows'
; own switch for it (Settings > Apps > Startup, Task Manager) is a value under StartupApproved: the check mark shows both.
; Everything here runs at startup or on a click; nothing stays behind (no timers or hooks while idle).

global STARTUP_APPROVED := "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder"

; Where the shortcut goes. A script may set STARTUP_DIR before including the switcher (the test does); read here, not at
; top level, so the startup code sees it.
StartupDir() => IsSet(STARTUP_DIR) ? STARTUP_DIR : A_Startup
StartupLink() => StartupDir() "\" ScriptBase() ".lnk"

StartAtLoginMark() {   ; the tray menu's check mark: it will start at login (the shortcut is there and Windows' switch on)
    StartAtLoginOn() ? A_TrayMenu.Check("Start at login") : A_TrayMenu.Uncheck("Start at login")
}
StartAtLoginOn() => FileExist(StartupLink()) != "" && !StartAtLoginOff()
; Windows' switch: a REG_BINARY named after the shortcut file, its first byte 02 when on, 03 (then the time) when off. No
; value is on too, so deleting it turns the switch on again.
StartAtLoginOff() => Integer("0x" SubStr(RegRead(STARTUP_APPROVED, ScriptBase() ".lnk", "") "00", 1, 2)) & 1

StartAtLoginToggle(*) {   ; tray menu click: on -> the shortcut removed; else made (or made again) with Windows' switch on
    err := StartAtLoginOn() ? StartAtLoginRemove() : StartAtLoginMake()
    StartAtLoginMark()
    if err
        TrayTip "Couldn't change start at login: " err, ScriptBase(), "Icon! Mute"
}

; The shortcut starts the switcher as the desktop icon does, without /settings. "" = ok, else the error.
StartupMake() => ShortcutMake(StartupLink(), "", "Start " ScriptBase() " when you sign in")
StartAtLoginMake() => StartupMake() || StartAtLoginClear()

StartAtLoginRemove() {
    try FileDelete StartupLink()
    catch as e
        return e.Message
    return StartAtLoginClear()
}

StartAtLoginClear() {   ; Windows' switch back to on: the shortcut's value deleted, if it has one
    if RegRead(STARTUP_APPROVED, ScriptBase() ".lnk", "") = ""
        return ""
    try RegDelete STARTUP_APPROVED, ScriptBase() ".lnk"
    catch as e
        return e.Message
    return ""
}

; A shortcut there that starts another copy of target (the app folder moved) is made again; one that starts something else
; (a run from source's AutoHotkey) is left alone, and Windows' switch stays as it is. "" = ok or nothing to do, else the error.
StartAtLoginRepoint(target) {
    if !FileExist(StartupLink())
        return ""
    try FileGetShortcut StartupLink(), &was           ; a damaged one (was left unset) is made again too
    if IsSet(was) && was != "" {
        SplitPath was, &old
        SplitPath target, &new
        if was = target || old != new
            return ""
    }
    return StartupMake()
}

; At startup: the exe points the shortcut at itself (a run from source never does), then the check mark.
StartAtLoginStart() {
    if A_IsCompiled && (err := StartAtLoginRepoint(A_ScriptFullPath))
        TrayTip "Couldn't update start at login: " err, ScriptBase(), "Icon! Mute"
    StartAtLoginMark()
}

; The exe's first run (DesktopWelcome, before its question): MeowTab starts at login from then on, Classic only once
; ticked. true = it will.
StartAtLoginWelcome() {
    if !SettingsHas("PEEK_MIN")                       ; Classic (the peek is MeowTab's alone)
        return false
    if err := StartAtLoginMake()
        TrayTip "Couldn't set it to start at login: " err, ScriptBase(), "Icon! Mute"
    StartAtLoginMark()
    return !err
}
