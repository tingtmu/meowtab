; Desktop icon for peek-alttab.ahk and elegant-alttab.ahk (#Included by settings-panel.ahk; tray menu > Desktop icon):
; a shortcut on the desktop that starts the switcher (or reloads it, #SingleInstance Force) and opens its
; Settings panel through the /settings switch. The exe's first run offers to create it once. Everything
; here runs at startup or on a click; nothing stays behind (no timers or hooks while idle).

global DESKTOP_DIR := A_Desktop                       ; where the shortcut goes (a test points it elsewhere)

ScriptBase() => RegExReplace(A_ScriptName, "\.[^.]+$")   ; "peek-alttab" for peek-alttab.exe and .ahk
DesktopLink() => DESKTOP_DIR "\" ScriptBase() ".lnk"

DesktopIconMark() {   ; the tray menu's check mark follows the shortcut file
    DesktopIconExists() ? A_TrayMenu.Check("Desktop icon") : A_TrayMenu.Uncheck("Desktop icon")
}
DesktopIconExists() => FileExist(DesktopLink()) != ""

DesktopIconToggle(*) {   ; tray menu click: remove the shortcut if there is one, else create it
    err := DesktopIconExists() ? DesktopIconRemove() : DesktopIconMake()
    DesktopIconMark()
    if err
        TrayTip "Couldn't change the desktop icon: " err, ScriptBase(), "Icon! Mute"
}

; The exe is its own target and icon. As .ahk the target is AutoHotkey running the script, with the
; shortcut icon from assets\ (AutoHotkey's own icon if that file isn't there). "" = ok, else the error.
DesktopIconMake() {
    name := ScriptBase(), desc := "Open " name " settings", ico := AppDir() "assets\peek-alttab.ico"
    try {
        if A_IsCompiled
            FileCreateShortcut A_ScriptFullPath, DesktopLink(), A_ScriptDir, "/settings", desc, A_ScriptFullPath
        else
            FileCreateShortcut A_AhkPath, DesktopLink(), A_ScriptDir, '"' A_ScriptFullPath '" /settings', desc
                , FileExist(ico) ? ico : A_AhkPath
    } catch as e
        return e.Message
    return ""
}

DesktopIconRemove() {
    try FileDelete DesktopLink()
    catch as e
        return e.Message
    return ""
}

; At startup: set the check mark; "/settings" (the shortcut's argument) opens the panel once the script is
; up (a timer, so everything SettingsOpen needs is initialised); the exe's first run asks about the icon.
DesktopIconStart() {
    DesktopIconMark()
    for a in A_Args
        if a = "/settings"
            return SetTimer(SettingsOpen, -300)
    if DesktopWelcomeDue()
        SetTimer(DesktopWelcome, -1500)
}

DesktopWelcomeDue() => A_IsCompiled && !DesktopIconExists() && IniRead(SettingsFile(), "state", "welcomed", 0) != 1

; A timer's own thread, so hotkeys (Alt+Tab) keep working while the question is open. Either answer is
; remembered in settings.ini ([state]); the panel's Reset leaves that section alone.
DesktopWelcome() {
    name := ScriptBase()
    yes := MsgBox(name " is running: hold Alt and press Tab.`n`nPut an icon on the desktop? It opens the settings, "
        . "where you can choose your own pictures.", name, "YesNo Iconi") = "Yes"
    try {
        SettingsCreate(SettingsFile())
        IniWrite 1, SettingsFile(), "state", "welcomed"
    } catch as e
        OutputDebug name ": couldn't remember the answer (" e.Message ")"
    if yes && (err := DesktopIconMake())
        TrayTip "Couldn't create the desktop icon: " err, name, "Icon! Mute"
    DesktopIconMark()
}
