; settings.ini <-> the Settings block, plus the file work behind the Settings… panel: validated loading,
; saving, importing pictures. #Included by settings-panel.ahk; functions only (globals
; defined here are set late in the auto-execute section, so SettingsLoad must not rely on them).

; Keys settings.ini may set: [name, kind, low, high]. A key applies only if the running script defines it
; (PEEK_*, *_KEYS and PANE_LOOK exist in meowtab.ahk only, IMG_ROWS in meowtab-classic.ahk only). The panel edits the first seven,
; *_KEYS, PANE_LOOK and MONITORS.
SettingsSchema() => [["FONT_NAME", "font"], ["FONT_SIZE", "int", 10, 24], ["IMG_PREFIX", "prefix"]
    , ["SOME_FROM", "int", 2, 29], ["MANY_FROM", "int", 3, 30], ["PEEK_MIN", "num", 0.3, 1], ["PEEK_MAX", "num", 0.3, 1]
    , ["LIST_WIDTH", "int", 300, 4000], ["MAX_ROWS", "int", 3, 50], ["PREVIEW_W", "int", 0, 4000]
    , ["IMG_SIZE", "int", 40, 600], ["IMG_ROWS", "int", 0, 50], ["WM_PROCESS", "process"]
    , ["SWITCH_KEYS", "keys"], ["STAY_KEYS", "keys"], ["PANE_LOOK", "look"], ["MONITORS", "monitors"]]

; Where the user's settings and pictures live, so replacing the app folder keeps them. A script may set DATA_DIR
; before including meowtab.ahk (the test and readme-shots do); read here, not at top level, so SettingsLoad sees it.
DataDir() => IsSet(DATA_DIR) ? DATA_DIR : A_AppData "\MeowTab"
UserImagesDir() => DataDir() "\images"
SettingsFile() => DataDir() "\settings.ini"
; Folder of the repo's own files (assets\). A compiled exe has no source files (A_LineFile is
; "*#1"), so there they sit next to the exe; as .ahk, next to this file (also when a test includes it).
AppDir() => A_IsCompiled ? A_ScriptDir "\" : RegExReplace(A_LineFile, "[^\\]+$")
Moods() => ["few", "some", "many"]
MoodOf(n) => n < SOME_FROM ? 1 : n < MANY_FROM ? 2 : 3              ; window count -> 1 few, 2 some, 3 many
UserImage(prefix, mood, ext := "png") => UserImagesDir() "\" prefix "_" mood "." ext   ; where the user's pictures are written
MoodImage(prefix, mood) {   ; user's first, then the app's; in each folder a .gif before a .png (missing: the app's .png)
    for dir in [UserImagesDir(), A_ScriptDir "\" IMG_DIR]
        for ext in ["gif", "png"]
            if FileExist(f := dir "\" prefix "_" mood "." ext)
                return f
    return f
}
; Picked in the panel, not saved yet: the mood's pending .gif, else its .png (whether or not there is one).
PendingImage(mood) => FileExist(g := UserImagesDir() "\custom_" mood ".pending.gif") ? g : UserImagesDir() "\custom_" mood ".pending.png"

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
    SettingsPair("SOME_FROM", "MANY_FROM"), SettingsPair("PEEK_MIN", "PEEK_MAX"), KeysPair()
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
        return (why := "no " raw "_*.png or .gif images found, using " def, def)
    case "process":
        if raw = "" || RegExMatch(raw, "i)^[^\\/:*?`"<>|]{1,80}\.exe$")
            return raw
        return (why := "expected a process name like glazewm.exe", def)
    case "keys":                                             ; a clash between the two is checked once both are read
        return (why := KeysParse(raw, s[1] = "STAY_KEYS", "", &keys, &hk)) ? (why .= ", using " def, def) : keys
    case "look":
        return raw = "velvet" || raw = "windows11" ? StrLower(raw) : (why := "expected velvet or windows11, using " def, def)
    case "monitors":
        return raw = "all" || raw = "current" ? StrLower(raw) : (why := "expected all or current, using " def, def)
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
    if FileExist(file)
        return
    DirCreate DataDir()
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
            if i <= 7 || s[2] ~= "^(keys|look|monitors)$" && SettingsHas(s[1])   ; the shortcuts and the look only where they apply: Classic keeps them
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

; ----- Shortcuts -----

; A shortcut as text, modifiers in any order and case ("shift+alt+tab") -> keys: its readable form, the modifiers in the
; order Win, Ctrl, Alt, Shift, then AHK's name for the key ("Alt+Shift+Tab"); hk: its hotkey name ("!+Tab"). stay: the
; stay-open shortcut, else the switch one; other: the other one's readable form, to refuse a clash ("" = no check).
; Loading, registering and the panel all go through it. "" = ok, else why it can't be used, for the user.
KeysParse(text, stay, other, &keys, &hk) {
    parts := StrSplit(text, "+", " `t"), key := parts.Length ? parts.Pop() : "", all := "+", keys := hk := "", held := 0
    for p in parts
        all .= p "+"
    for i, m in ["Win", "Ctrl", "Alt", "Shift"]
        if InStr(all, "+" m "+")
            keys .= m "+", hk .= SubStr("#^!+", i, 1), held += i < 4
    name := GetKeyName(key), vk := GetKeyVK(key)
    if key = "" || StrLen(hk) != parts.Length                ; no key, or a word that isn't a modifier (or one twice)
        || name ~= "i)^[LR]?(Win|Control|Alt|Shift)$|Button|Wheel"   ; a modifier or the mouse as the key
        return "not a shortcut like Alt+Tab"
    if !(vk || GetKeySC(key))                                ; this keyboard layout lacks it: Hotkey() would refuse it
        return key " isn't a key on this keyboard"
    keys .= StrLen(name) = 1 ? StrUpper(name) : name, hk .= name
    if !held
        return "it needs Alt, Ctrl or Win"
    if !stay && held > 1
        return "switching takes only one of Alt, Ctrl and Win"
    if !stay && InStr(keys, "Shift+")
        return "Shift is kept for going back"
    if vk = 0x1B || vk = 0x0D || vk = 0x2E || vk >= 0x25 && vk <= 0x28   ; Esc, Enter, Delete, the arrows (numpad ones too)
        return name " is used inside the switcher"
    if InStr(keys, "Win+") && name = "L"
        return "Windows keeps Win+L for locking the screen"
    if other != "" && keys = other
        return (stay ? "switching" : "the stay-open shortcut") " already uses it"
    if other != "" && (stay ? keys = KeysBack(other) : KeysBack(keys) = other)
        return stay ? "going back already uses it" : "going back (" KeysBack(keys) ") is the stay-open shortcut"
    return ""
}

KeysBack(keys) => RegExReplace(keys, "[^+]+$", "Shift+$0")   ; the switch shortcut -> going back (Shift is last of the modifiers)

KeysPair() {   ; the stay-open shortcut must differ from switching and going back, else both go back to their defaults
    if !SETTINGS_DEFAULTS.Has("STAY_KEYS")
        || !(why := KeysParse(stay := SettingsGet("STAY_KEYS"), true, SettingsGet("SWITCH_KEYS"), &keys, &hk))
        return
    SETTINGS_ISSUES.Push("STAY_KEYS = " stay ": " why ", using " SETTINGS_DEFAULTS["SWITCH_KEYS"] " and " SETTINGS_DEFAULTS["STAY_KEYS"])
    SettingsSet("SWITCH_KEYS", SETTINGS_DEFAULTS["SWITCH_KEYS"]), SettingsSet("STAY_KEYS", SETTINGS_DEFAULTS["STAY_KEYS"])
}

; ----- Pictures -----

; Any GDI+-readable picture -> dest as PNG, turned upright (EXIF) and at most 1024 px, so the switchers'
; startup stays quick. A PNG that needs neither is copied as is. An animated GIF stays one (ImportGif). dest's
; extension becomes .png or .gif, and the mood's picture in the other format goes. "" = ok, else why not.
ImportImage(src, dest) {
    SplitPath dest, , &dir
    try DirCreate dir                                    ; the user's images folder may not exist yet
    catch as e
        return "couldn't create " dir " (" e.Message ")"
    if DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", src, "ptr*", &bm := 0)
        return "can't read that file as a picture (PNG, JPG, BMP or GIF)"
    if turn := ExifTurn(bm)
        DllCall("gdiplus\GdipImageRotateFlip", "ptr", bm, "int", turn)
    DllCall("gdiplus\GdipGetImageWidth", "ptr", bm, "uint*", &w := 0), DllCall("gdiplus\GdipGetImageHeight", "ptr", bm, "uint*", &h := 0)
    if (n := GifCount(bm)) > 1
        return (DllCall("gdiplus\GdipDisposeImage", "ptr", bm), ImportGif(src, n, Max(w, h), RegExReplace(dest, "\.\w+$", ".gif")))
    s := Min(1, 1024 / Max(w, h, 1)), dest := RegExReplace(dest, "\.\w+$", ".png")
    if s = 1 && !turn && src ~= "i)\.png$" {
        DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
        try FileCopy src, dest, 1
        catch as e
            return "couldn't copy it (" e.Message ")"
        return DropTwin(dest)
    }
    gr := Canvas(out := NewBitmap(dw := Max(1, Round(w * s)), dh := Max(1, Round(h * s))))
    DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gr, "int", 7)   ; HighQualityBicubic
    DllCall("gdiplus\GdipDrawImageRectI", "ptr", gr, "ptr", bm, "int", 0, "int", 0, "int", dw, "int", dh)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr), DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    ok := SavePng(out, dest), DllCall("gdiplus\GdipDisposeImage", "ptr", out)
    return ok ? DropTwin(dest) : "couldn't write " dest
}

; An animated GIF of n frames, its longer side side px -> dest. Up to 512 px it's copied as is, keeping its own palette
; and timing; bigger, every frame is scaled to 512 px and written again with its delays. Over 100 frames: refused.
ImportGif(src, n, side, dest) {
    if n > 100
        return "too many frames (over 100)"
    if side <= 512 {
        try FileCopy src, dest, 1
        catch as e
            return "couldn't copy it (" e.Message ")"
        return DropTwin(dest)
    }
    ok := (frames := GifFrames(src, 512, &delays)).Length = n && GifWrite(frames, delays, dest)
    for f in frames
        DllCall("gdiplus\GdipDisposeImage", "ptr", f)
    return ok ? DropTwin(dest) : "couldn't write " dest
}

DropTwin(file) {   ; a mood has one picture: file's twin in the other format (.png / .gif) goes. "" = ok
    twin := RegExReplace(file, "\.\w+$", file ~= "i)\.gif$" ? ".png" : ".gif")
    try FileExist(twin) && FileDelete(twin)
    catch as e
        return "couldn't remove " twin " (" e.Message ")"
    return ""
}

; Save: pending pictures become custom_<mood>.png or .gif; moods without one get a copy of the current set's
; picture (or lose a stale one), so the "custom" set always shows what the panel showed. "" = ok.
ImagesCommit(prefix) {
    for mood in Moods() {
        pend := PendingImage(mood), cur := MoodImage(prefix, mood)
        if !FileExist(pend) && prefix = "custom"         ; the saved picture stays
            continue
        try {
            ext := FileExist(pend) ? SubStr(pend, -3) : FileExist(cur) ? SubStr(cur, -3) : ""
            if ext != ""
                FileExist(pend) ? FileMove(pend, UserImage("custom", mood, ext), 1) : FileCopy(cur, UserImage("custom", mood, ext), 1)
            for x in ["gif", "png"]                      ; the other format's picture goes, and a stale one
                if x != ext && FileExist(f := UserImage("custom", mood, x))
                    FileDelete f
        } catch as e
            return "couldn't save the " mood " picture (" e.Message ")"
    }
    return ""
}

PendingClear() {   ; drop unsaved pictures (and any leftover backups of them)
    Loop Files UserImagesDir() "\custom_*.pending.*"
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
