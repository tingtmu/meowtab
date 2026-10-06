#Requires AutoHotkey v2.0
; Parity test for cutout.ahk: every fixture in tests\cutout\fixtures goes through CutoutFile and is compared
; with what cutout.py made of it (tests\cutout\expected.txt + expected\*.png). Per fixture: same status; crop
; box within 2 px; alpha IoU (alpha > 20) >= 0.98 against the expected picture, aligned by their boxes.
; Run from the repo root:  AutoHotkey64.exe /ErrorStdOut tests\cutout.test.ahk [folder] | more
; folder = another set with the same layout (fixtures\, expected\, expected.txt), e.g. a local private one.
#Include %A_LineFile%\..\..\gdip-helpers.ahk
#Include %A_LineFile%\..\..\cutout.ahk

global fails := 0
si := Buffer(24, 0), NumPut("uint", 1, si)   ; GdiplusStartupInput
DllCall("gdiplus\GdiplusStartup", "ptr*", &gdipToken := 0, "ptr", si, "ptr", 0)

Check(label, got, want) {
    global fails
    ok := got = want
    fails += !ok
    FileAppend (ok ? "PASS " : "FAIL ") label (ok ? "" : "`n     got:  " got "`n     want: " want) "`n", "*"
}

Info(text) => FileAppend("     " text "`n", "*")

; Picture file -> {w, h, px}: px = w*h*4 bytes, B G R A rows, no padding. 0 = unreadable.
LoadPixels(file) {
    if DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", file, "ptr*", &bm := 0)
        return 0
    DllCall("gdiplus\GdipGetImageWidth", "ptr", bm, "uint*", &w := 0), DllCall("gdiplus\GdipGetImageHeight", "ptr", bm, "uint*", &h := 0)
    rc := Buffer(16), NumPut("int", 0, "int", 0, "int", w, "int", h, rc), bd := Buffer(32, 0)
    DllCall("gdiplus\GdipBitmapLockBits", "ptr", bm, "ptr", rc, "uint", 1, "int", 0x26200A, "ptr", bd)   ; ReadOnly, 32bppARGB
    stride := NumGet(bd, 8, "int"), bits := NumGet(bd, 16, "ptr"), px := Buffer(w * h * 4)
    Loop h
        DllCall("RtlMoveMemory", "ptr", px.Ptr + (A_Index - 1) * w * 4, "ptr", bits + (A_Index - 1) * stride, "ptr", w * 4)
    DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", bm, "ptr", bd), DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    return {w: w, h: h, px: px}
}

; Both pictures are laid on the source plane by their crop boxes (a = result, b = expected; each is
; {w, h, px, left, top}); outside its own square a picture counts as transparent. Returns the alpha IoU
; (alpha > 20), mean |alpha diff| over pixels either has, mean RGB diff over pixels both hold opaque.
Compare(a, b) {
    x0 := Min(a.left, b.left), x1 := Max(a.left + a.w, b.left + b.w)
    y0 := Min(a.top, b.top), y1 := Max(a.top + a.h, b.top + b.h)
    both := either := dA := nOpaque := dRgb := 0
    Loop y1 - y0 {
        sy := y0 + A_Index - 1, ay := sy - a.top, by := sy - b.top
        aRow := ay >= 0 && ay < a.h, bRow := by >= 0 && by < b.h
        Loop x1 - x0 {
            sx := x0 + A_Index - 1, ax := sx - a.left, bx := sx - b.left
            oa := aRow && ax >= 0 && ax < a.w ? (ay * a.w + ax) * 4 : -1
            ob := bRow && bx >= 0 && bx < b.w ? (by * b.w + bx) * 4 : -1
            pa := oa < 0 ? 0 : NumGet(a.px, oa + 3, "uchar"), pb := ob < 0 ? 0 : NumGet(b.px, ob + 3, "uchar")
            if pa > 20 && pb > 20
                both++
            if pa > 20 || pb > 20
                either++, dA += Abs(pa - pb)
            if pa > 250 && pb > 250 {
                nOpaque++
                Loop 3
                    dRgb += Abs(NumGet(a.px, oa + A_Index - 1, "uchar") - NumGet(b.px, ob + A_Index - 1, "uchar"))
            }
        }
    }
    return {iou: either ? both / either : 1, dAlpha: either ? dA / either : 0, dRgb: nOpaque ? dRgb / nOpaque / 3 : 0}
}

CheckPicture(name, r, root, left, top, dest) {
    got := LoadPixels(dest), want := LoadPixels(root "\expected\" name ".png")
    Check(name " output readable", !!got && !!want, true)
    if !got || !want
        return
    Check(name " output is " r.side "x" r.side, got.w "x" got.h, r.side "x" r.side)
    got.left := r.left, got.top := r.top, want.left := left, want.top := top
    m := Compare(got, want)
    Info(Format("alpha IoU {:.4f}, mean |alpha diff| {:.3f}, mean RGB diff {:.3f}", m.iou, m.dAlpha, m.dRgb))
    Check(name " alpha IoU >= 0.98", m.iou >= 0.98 ? "ok" : Format("{:.4f}", m.iou), "ok")
}

CheckFixture(root, line) {
    f := StrSplit(line, " ")
    name := f[1], status := Integer(f[2]), left := Integer(f[3]), top := Integer(f[4]), side := Integer(f[5])
    dest := A_Temp "\cutout-test-" name ".png"
    try FileDelete dest
    try
        r := CutoutFile(root "\fixtures\" name ".png", dest)
    catch as e {
        Check(name " runs", e.Message, "no error")
        return
    }
    Check(name " status", r.status, status)
    if r.status = status && status <= 1 {
        near := Abs(r.left - left) <= 2 && Abs(r.top - top) <= 2 && Abs(r.side - side) <= 2
        Check(name " box (left top side) within 2 px", near ? left " " top " " side : r.left " " r.top " " r.side, left " " top " " side)
        Check(name " output written", !!FileExist(dest), true)
        FileExist(dest) && CheckPicture(name, r, root, left, top, dest)
    }
    try FileDelete dest
}

root := RTrim(A_Args.Length ? A_Args[1] : A_ScriptDir "\cutout", "\")
list := FileExist(root "\expected.txt") ? FileRead(root "\expected.txt") : ""
Check("expected.txt found in " root, list != "", true)
for line in StrSplit(list, "`n", "`r")
    if line != "" && SubStr(line, 1, 1) != "#"
        CheckFixture(root, line)
FileAppend (fails ? fails " FAILED" : "ALL PASSED") "`n", "*"
ExitApp fails
