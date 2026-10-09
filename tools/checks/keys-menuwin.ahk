#Requires AutoHotkey v2.0
#SingleInstance Off
; keys-menuwin.ahk: one window with a menu bar, in a process of its own, for keys.ahk (which starts it; never run it by hand).
; A lone Alt on a window with a menu bar starts a modal menu loop in that window's thread. In the checking script's own
; thread that loop would hold the script up (and could not be ended), so the window lives here.
; Args: <parent pid> <title> <x> <y>. It exits when the parent is gone, when it is closed, or after 2 minutes.
OnError((e, *) => (FileAppend("ERR " e.Message " (line " e.Line ")`n", "*"), ExitApp(3)))
SetTimer(() => ExitApp(2), -120000)
parent := A_Args[1]
fm := Menu(), fm.Add("&Open", (*) => 0)
bar := MenuBar(), bar.Add("&File", fm)
w := Gui(, A_Args[2]), w.MenuBar := bar, w.OnEvent("Close", (*) => ExitApp())
w.Show("x" A_Args[3] " y" A_Args[4] " w300 h200")
SetTimer(() => ProcessExist(parent) || ExitApp(), 500)
