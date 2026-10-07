; settings.ini <-> the Settings block, plus the file work behind the Settings… panel: validated loading,
; saving, importing pictures. #Included by settings-panel.ahk; functions only (globals
; defined here are set late in the auto-execute section, so SettingsLoad must not rely on them).

; Keys settings.ini may set: [name, kind, low, high]. A key applies only if the running script defines it
; (PEEK_* exist in meowtab.ahk only, IMG_ROWS in meowtab-classic.ahk only). The panel edits the first seven.
SettingsSchema() => [["FONT_NAME", "font"], ["FONT_SIZE", "int", 10, 24], ["IMG_PREFIX", "prefix"]
    , ["SOME_FROM", "int", 2, 29], ["MANY_FROM", "int", 3, 30], ["PEEK_MIN", "num", 0.3, 1], ["PEEK_MAX", "num", 0.3, 1]
    , ["LIST_WIDTH", "int", 300, 4000], ["MAX_ROWS", "int", 3, 50], ["PREVIEW_W", "int", 0, 4000]
    , ["IMG_SIZE", "int", 40, 600], ["IMG_ROWS", "int", 0, 50], ["WM_PROCESS", "process"]]

SettingsFile() => A_ScriptDir "\settings.ini"
; Folder of the repo's own files (assets\). A compiled exe has no source files (A_LineFile is
; "*#1"), so there they sit next to the exe; as .ahk, next to this file (also when a test includes it).
AppDir() => A_IsCompiled ? A_ScriptDir "\" : RegExReplace(A_LineFile, "[^\\]+$")
Moods() => ["few", "some", "many"]
MoodOf(n) => n < SOME_FROM ? 1 : n < MANY_FROM ? 2 : 3              ; window count -> 1 few, 2 some, 3 many
MoodImage(prefix, mood) => A_ScriptDir "\" IMG_DIR "\" prefix "_" mood ".png"
PendingImage(mood) => A_ScriptDir "\" IMG_DIR "\custom_" mood ".pending.png"   ; picked in the panel, not saved yet

; Startup: remember the built-in defaults, then overlay settings.ini. Every value is checked (type, range,
; installed font, existing images); a bad one keeps its default and is reported once (tray tip + debug log).
SettingsLoad() {
    global SETTINGS_DEFAULTS := Map(), SETTINGS_ISSUES := []
    for s in SettingsSchema()
        if SettingsHas(s[1])
            SETTINGS_DEFAULTS[s[1]] := SettingsGet(s[1])
    if !FileExist(file := SettingsFile())
        return
    for s in SettingsSchema() {
        if !SETTINGS_DEFAULTS.Has(s[1])
            continue
        try raw := Trim(IniRead(file, "settings", s[1], Chr(1)))
        catch as e
            return SettingsWarn(["settings.ini can't be read (" e.Message ")"])
        if raw = Chr(1)                                      ; not in the file
            continue
        v := SettingsCheck(s, raw, SETTINGS_DEFAULTS[s[1]], &why)
        if why != ""
            SETTINGS_ISSUES.Push(s[1] " = " raw ": " why)
        SettingsSet(s[1], v)
    }
    SettingsPair("SOME_FROM", "MANY_FROM"), SettingsPair("PEEK_MIN", "PEEK_MAX")
    if SETTINGS_ISSUES.Length
        SettingsWarn(SETTINGS_ISSUES)
}

; One value from the ini -> the value to use; why gets a reason when it falls back or is clamped.
SettingsCheck(s, raw, def, &why) {
    why := ""
    switch s[2] {
    case "int", "num":
        if !(s[2] = "int" ? IsInteger(raw) : IsNumber(raw))
            return (why := "not a " (s[2] = "int" ? "whole " : "") "number, using " Num(def), def)
        v := Min(Max(s[2] = "int" ? Integer(raw) : Round(Float(raw), 2), s[3]), s[4])
        if v != raw
            why := "outside " Num(s[3]) "–" Num(s[4]) ", using " Num(v)
        return v
    case "font":
        return FontInstalled(raw) ? raw : (why := "font not installed, using " def, def)
    case "prefix":
        if !RegExMatch(raw, "^[\w-]{1,40}$")
            return (why := "not a plain name, using " def, def)
        for mood in Moods()
            if FileExist(MoodImage(raw, mood))
                return raw
        return (why := "no " raw "_*.png images in " IMG_DIR ", using " def, def)
    case "process":
        if raw = "" || RegExMatch(raw, "i)^[^\\/:*?`"<>|]{1,80}\.exe$")
            return raw
        return (why := "expected a process name like glazewm.exe", def)
    }
}

SettingsPair(lo, hi) {   ; lo must stay below hi, else both go back to their defaults
    if !SETTINGS_DEFAULTS.Has(lo) || SettingsGet(lo) < SettingsGet(hi)
        return
    SETTINGS_ISSUES.Push(lo " must be below " hi ", using " Num(SETTINGS_DEFAULTS[lo]) " and " Num(SETTINGS_DEFAULTS[hi]))
    SettingsSet(lo, SETTINGS_DEFAULTS[lo]), SettingsSet(hi, SETTINGS_DEFAULTS[hi])
}

SettingsWarn(issues) {
    for s in issues
        OutputDebug "MeowTab settings.ini: " s
    TrayTip "settings.ini: " issues[1] (issues.Length > 1 ? "  (+" issues.Length - 1 " more)" : "")
        . "`nThe built-in default is used instead.", "MeowTab", "Icon! Mute"
}

Num(v) => IsFloat(v) ? RTrim(RTrim(Format("{:.2f}", v), "0"), ".") : v   ; 0.3 rather than 0.29999999999999999

SettingsHas(k) {   ; does the running script define this setting?
    try return (%k%, true)
    return false
}
SettingsGet(k) {
    global
    return %k%
}
SettingsSet(k, v) {
    global
    %k% := v
}

SettingsCreate(file) {   ; a new settings.ini starts as UTF-16, which keeps any font name intact
    if !FileExist(file)
        FileAppend "[settings]`n", file, "UTF-16"
}

; Panel values (Map) -> settings.ini. A value equal to the built-in default removes its key; keys the panel
; doesn't edit (WM_PROCESS, LIST_WIDTH, ...) are left alone. "" = ok, else the error.
SettingsWrite(vals) {
    file := SettingsFile()
    try {
        SettingsCreate(file)
        for k, v in vals
            if v = SETTINGS_DEFAULTS[k]
                IniDelete file, "settings", k
            else
                IniWrite IsFloat(v) ? Format("{:.2f}", v) : v, file, "settings", k
    } catch as e
        return e.Message
    return ""
}

; Reset: remove the panel's keys; the file goes too unless it holds other lines (e.g. WM_PROCESS, or the
; [state] section the desktop icon's first-run question leaves). "" = ok.
SettingsReset() {
    if !FileExist(file := SettingsFile())
        return ""
    try {
        for i, s in SettingsSchema()
            if i <= 7
                IniDelete file, "settings", s[1]
        rest := "", sections := ""
        try rest := IniRead(file, "settings")
        try sections := IniRead(file)
        if rest = "" && (sections = "" || sections = "settings")
            FileDelete file
    } catch as e
        return e.Message
    return ""
}

; ----- Pictures -----

; Any GDI+-readable picture -> dest as PNG, turned upright (EXIF) and at most 1024 px, so the switchers'
; startup stays quick. A PNG that needs neither is copied as is. "" = ok, else why not.
ImportImage(src, dest) {
    if DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", src, "ptr*", &bm := 0)
        return "can't read that file as a picture (PNG, JPG, BMP or GIF)"
    if turn := ExifTurn(bm)
        DllCall("gdiplus\GdipImageRotateFlip", "ptr", bm, "int", turn)
    DllCall("gdiplus\GdipGetImageWidth", "ptr", bm, "uint*", &w := 0), DllCall("gdiplus\GdipGetImageHeight", "ptr", bm, "uint*", &h := 0)
    s := Min(1, 1024 / Max(w, h, 1))
    if s = 1 && !turn && src ~= "i)\.png$" {
        DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
        try FileCopy src, dest, 1
        catch as e
            return "couldn't copy it (" e.Message ")"
        return ""
    }
    gr := Canvas(out := NewBitmap(dw := Max(1, Round(w * s)), dh := Max(1, Round(h * s))))
    DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gr, "int", 7)   ; HighQualityBicubic
    DllCall("gdiplus\GdipDrawImageRectI", "ptr", gr, "ptr", bm, "int", 0, "int", 0, "int", dw, "int", dh)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr), DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    ok := SavePng(out, dest), DllCall("gdiplus\GdipDisposeImage", "ptr", out)
    return ok ? "" : "couldn't write " dest
}

; Save: pending pictures become custom_<mood>.png; moods without one get a copy of the current set's
; picture (or lose a stale one), so the "custom" set always shows what the panel showed. "" = ok.
ImagesCommit(prefix) {
    for mood in Moods() {
        pend := PendingImage(mood), live := MoodImage("custom", mood), cur := MoodImage(prefix, mood)
        try {
            if FileExist(pend)
                FileMove pend, live, 1
            else if prefix != "custom"
                FileExist(cur) ? FileCopy(cur, live, 1) : FileExist(live) && FileDelete(live)
        } catch as e
            return "couldn't save the " mood " picture (" e.Message ")"
    }
    return ""
}

PendingClear() {   ; drop unsaved pictures (and any leftover backups of them)
    Loop Files A_ScriptDir "\" IMG_DIR "\custom_*.pending.png*"
        try FileDelete A_LoopFileFullPath
        catch as e
            OutputDebug "meowtab: couldn't delete " A_LoopFileFullPath " (" e.Message ")"
}

; ----- Fonts -----

FontInstalled(name) {   ; does GDI give us this face (not a substitute)?
    if StrLen(name) > 31
        return false
    dc := DllCall("GetDC", "ptr", 0, "ptr"), face := Buffer(128, 0)
    f := DllCall("CreateFontW", "int", 0, "int", 0, "int", 0, "int", 0, "int", 400, "uint", 0, "uint", 0, "uint", 0
        , "uint", 1, "uint", 0, "uint", 0, "uint", 0, "uint", 0, "str", name, "ptr")
    o := DllCall("SelectObject", "ptr", dc, "ptr", f, "ptr")
    DllCall("GetTextFaceW", "ptr", dc, "int", 64, "ptr", face)
    DllCall("SelectObject", "ptr", dc, "ptr", o), DllCall("DeleteObject", "ptr", f), DllCall("ReleaseDC", "ptr", 0, "ptr", dc)
    return StrGet(face) = name
}

FontFamilies() {   ; installed families, sorted, without @vertical and symbol fonts
    found := Map(), found.CaseSense := false
    lf := Buffer(92, 0), NumPut("uchar", 1, lf, 23)      ; LOGFONTW, DEFAULT_CHARSET: every family
    cb := CallbackCreate(Each, "F", 4), dc := DllCall("GetDC", "ptr", 0, "ptr")
    DllCall("EnumFontFamiliesExW", "ptr", dc, "ptr", lf, "ptr", cb, "ptr", 0, "uint", 0)
    DllCall("ReleaseDC", "ptr", 0, "ptr", dc), CallbackFree(cb)
    out := []
    for name in found                                    ; a Map enumerates in key order
        out.Push(name)
    return out
    Each(plf, ptm, type, lp) {
        name := StrGet(plf + 28, 32, "UTF-16")
        if SubStr(name, 1, 1) != "@" && NumGet(plf, 23, "uchar") != 2   ; SYMBOL_CHARSET
            found[name] := 1
        return 1
    }
}
