; #Included by meowtab.test.ahk where its start-at-login checks run: these top-level lines run there, in order.
; Start at login (start-at-login.ahk): its shortcut in STARTUP_DIR (in the test's data folder), Windows' switch for it as this
; test's own value under StartupApproved (meowtab.test.lnk, deleted again however the run ends), the re-pointing, Classic's.

LoginMark() {   ; the tray menu's third item and its check mark, as "Start at login: checked"
    m := A_TrayMenu.Handle, s := Buffer(128, 0)
    DllCall("GetMenuStringW", "ptr", m, "uint", 2, "ptr", s, "int", 64, "uint", 0x400)   ; MF_BYPOSITION
    return StrGet(s) ": " (DllCall("GetMenuState", "ptr", m, "uint", 2, "uint", 0x400) & 8 ? "checked" : "unchecked")   ; MF_CHECKED
}
LoginCleanup(*) {   ; this test's value under StartupApproved, if a check left one
    try RegDelete STARTUP_APPROVED, ScriptBase() ".lnk"
}
OnExit(LoginCleanup)
LoginApproved() => RegRead(STARTUP_APPROVED, ScriptBase() ".lnk", "none")   ; Windows' switch for the test's shortcut, as hex

LoginLink(&target, &args) {   ; the shortcut's target and arguments ("" if there's none)
    try FileGetShortcut(StartupLink(), &target, , &args)
    catch
        target := args := ""
}

DirCreate STARTUP_DIR
was := LoginMark(), StartAtLoginToggle(), LoginLink(&target, &args)
Check("a click on Start at login (after Desktop icon) puts a shortcut in the Startup folder that starts this script, and checks it"
    , was " -> " target " " args ", " LoginMark(), "Start at login: unchecked -> " A_AhkPath ' "' A_ScriptFullPath '", Start at login: checked')
RegWrite("020000000000000000000000", "REG_BINARY", STARTUP_APPROVED, ScriptBase() ".lnk"), StartAtLoginToggle()
Check("a second click removes the shortcut and Windows' value for it, and clears the check mark"
    , FileExist(StartupLink()) "[" LoginMark() "] " LoginApproved(), "[Start at login: unchecked] none")

; Windows' own switch (Settings > Apps > Startup): 02 on, 03 off. Off, the shortcut is still there but unchecked; a click
; turns it on again by deleting the value.
StartAtLoginToggle(), RegWrite("020000000000000000000000", "REG_BINARY", STARTUP_APPROVED, ScriptBase() ".lnk")
StartAtLoginMark(), got := LoginMark()
RegWrite("03000000A0B1C2D3E4F50607", "REG_BINARY", STARTUP_APPROVED, ScriptBase() ".lnk")
StartAtLoginMark(), got .= " | " LoginMark() " " (FileExist(StartupLink()) != ""), StartAtLoginToggle()
Check("Windows' switch on (02) leaves it checked, off (03) unchecks it with the shortcut still there; a click turns it on: checked, no value left"
    , got " -> " LoginMark() " " LoginApproved(), "Start at login: checked | Start at login: unchecked 1 -> Start at login: checked none")

; The exe at startup points a shortcut that starts another copy of it (its folder moved) at itself, as here at AutoHotkey
; for this script, and leaves one that's right, one that starts something else (a run from source's) and Windows' switch alone.
RegWrite("03000000A0B1C2D3E4F50607", "REG_BINARY", STARTUP_APPROVED, ScriptBase() ".lnk")
FileCreateShortcut(A_WinDir "\notepad.exe", StartupLink()), err := StartAtLoginRepoint(A_AhkPath), LoginLink(&other, &args)
SplitPath(other, &otherName), SplitPath(A_AhkPath, &ahkName), DirCreate(DATA_DIR "\moved"), FileAppend("", DATA_DIR "\moved\" ahkName)
FileCreateShortcut(DATA_DIR "\moved\" ahkName, StartupLink()), err .= StartAtLoginRepoint(A_AhkPath)
LoginLink(&target, &args), FileSetTime(20200101000000, StartupLink())
err .= StartAtLoginRepoint(A_AhkPath)
Check("a shortcut to another copy is made again to start this script, Windows' switch kept; one that's right, or starts something else, is left"
    , err otherName " | " target " " args " " LoginApproved() " " FileGetTime(StartupLink())
    , 'notepad.exe | ' A_AhkPath ' "' A_ScriptFullPath '" 03000000A0B1C2D3E4F50607 20200101000000')
LoginCleanup()

; The exe's first run (StartAtLoginWelcome, before its question): MeowTab's makes the shortcut; Classic's, in a process of its
; own on a data folder of its own, makes none.
FileDelete StartupLink()
classic := DATA_DIR "\classic-login.ahk", answer := DATA_DIR "\classic-login.txt", got := StartAtLoginWelcome() " " (FileExist(StartupLink()) != "")
FileOpen(classic, "w").Write("#NoTrayIcon`nOnError((e, *) => (FileAppend('error: ' e.Message, A_Args[1]), ExitApp(3)))`n"
    . "DATA_DIR := A_ScriptDir '\classic-login', STARTUP_DIR := A_ScriptDir '\startup'`n#Include " AppDir() "meowtab-classic.ahk`n"
    . "FileAppend(StartAtLoginWelcome() ' ' (FileExist(StartupLink()) != ''), A_Args[1]), ExitApp()`n")
Run('"' A_AhkPath '" /ErrorStdOut "' classic '" "' answer '"', , , &pid)
if stuck := ProcessWaitClose(pid, 10)
    ProcessClose(pid)
Check("the first run: MeowTab starts at login from then on (1 1), Classic never by itself (0 0)"
    , got " | " (FileExist(answer) ? FileRead(answer) : "no answer") (stuck ? ", then stuck" : ""), "1 1 | 0 0")
