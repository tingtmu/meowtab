; Background removal for mood pictures, natively: cutout.c's machine code (cutout-mcode.ahk, built by
; build-mcode.ps1) runs on a worker thread; this file loads the picture with GDI+, crops and saves the result.
; Functions only (the job list is the one global). Needs gdip-helpers.ahk (SavePng, ExifTurn) and GDI+ started.
#Include %A_LineFile%\..\cutout-mcode.ahk

; Synchronous: src -> cleaned, square-cropped PNG at dest (may be src). Returns {status, msg, changed, w, h,
; left, top, side}; status is cutout.c's code, or 21 unreadable, 22 too large, 23 couldn't write.
CutoutFile(src, dest) {
    j := CutoutStart(src)
    if !j.HasOwnProp("thread")
        return j
    if DllCall("WaitForSingleObject", "ptr", j.thread, "uint", 0xFFFFFFFF, "uint") = 0
        return CutoutEnd(j, dest)
    j.cancelled := true, CUTOUT_JOBS.Push(j), SetTimer(CutoutPoll, 30)   ; keep its buffers until it ends
    return CutoutSay(20, j, "couldn't wait for the worker")
}

; Asynchronous, in place: done({changed, msg}) once the worker has ended. Polled only while a job runs; the
; job keeps its buffers referenced until then, so closing the panel mid-run is safe.
CutoutRun(file, done) {
    j := CutoutStart(file)
    if !j.HasOwnProp("thread")
        return done({changed: false, msg: j.msg})
    j.done := done, j.cancelled := false
    CUTOUT_JOBS.Push(j)
    SetTimer CutoutPoll, 30
}

CutoutPoll() {
    global CUTOUT_JOBS
    ended := [], still := []
    for j in CUTOUT_JOBS                              ; only WAIT_OBJECT_0 means the thread has ended
        (DllCall("WaitForSingleObject", "ptr", j.thread, "uint", 0, "uint") = 0 ? ended : still).Push(j)
    CUTOUT_JOBS := still
    if !still.Length
        SetTimer CutoutPoll, 0
    for j in ended {
        if j.cancelled {
            DllCall("CloseHandle", "ptr", j.thread)   ; nobody wants it any more: no save, no done()
            continue
        }
        try r := CutoutEnd(j, j.src), done := j.done, done({changed: r.changed, msg: r.msg})
        catch as e                                    ; one failing job must not strand the others
            OutputDebug "meowtab: cleaning " j.src " failed (" e.Message ")"
    }
}

; The panel closed: running jobs are dropped as their threads end (a thread can't be killed, so it finishes
; on its own buffers; its result is never saved, which would resurrect a deleted pending file).
CutoutCancel() {
    for j in CUTOUT_JOBS
        j.cancelled := true
}

; Load the picture and start cutout_run on a thread. Returns the job {src, w, h, px, scratch, orig, buf,
; thread}, or a finished result (see CutoutFile) when it can't start.
CutoutStart(src) {
    j := CutoutLoad(src)
    if j.HasOwnProp("status")
        return j
    if !entry := CutoutEntry()
        return CutoutSay(20, j, "machine code unavailable")
    try {
        j.scratch := Buffer(CutoutScratch(j.w, j.h))
        j.orig := ""
        if j.w = j.h                                  ; only a square picture can come out unchanged
            j.orig := Buffer(j.px.Size), DllCall("RtlMoveMemory", "ptr", j.orig, "ptr", j.px, "uptr", j.px.Size)
    } catch MemoryError
        return CutoutSay(20, j, "out of memory")
    j.buf := Buffer(56, 0), j.src := src               ; CutoutJob, layout in cutout.c
    NumPut("ptr", j.px.Ptr, "int64", j.scratch.Size, "ptr", j.scratch.Ptr, "int", j.w, "int", j.h, "int", 1, "int", -1, j.buf)
    if !th := DllCall("CreateThread", "ptr", 0, "uptr", 0, "ptr", entry, "ptr", j.buf, "uint", 0, "ptr", 0, "ptr")
        return CutoutSay(20, j, "couldn't start a thread")
    j.thread := th
    return j
}

; Scratch bytes cutout.c may carve (setup + carve_edt): 15 bytes per pixel, the padded distance plane (4 bytes
; per pixel of (w + 2P) x (h + 2P), P = closing radius + 2, the radius at most 4 * min(longest side, 15600) / 780
; + 1), its row arrays, and slack for the histograms and alignment. Never more than the old 64 bytes per pixel
; + 1 MiB, so the outcome can only differ from a roomy buffer by cutout.c's status 20 (checked in its carve).
CutoutScratch(w, h) {
    p := 4 * Min(Max(w, h, 39), 15600) // 780 + 4, pw := w + 2 * p
    return Min(64 * w * h + 1048576, 15 * w * h + 4 * pw * (h + 2 * p) + 12 * pw + 65536)
}

; Picture -> {w, h, px}: B,G,R,A rows without padding, EXIF turned upright; or a result with status 21 / 22.
CutoutLoad(src) {
    if DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", src, "ptr*", &bm := 0)
        return CutoutSay(21)
    try {
        if turn := ExifTurn(bm)
            DllCall("gdiplus\GdipImageRotateFlip", "ptr", bm, "int", turn)
        DllCall("gdiplus\GdipGetImageWidth", "ptr", bm, "uint*", &w := 0), DllCall("gdiplus\GdipGetImageHeight", "ptr", bm, "uint*", &h := 0)
        if !w || !h
            return CutoutSay(21)
        if w * h > 4194304                            ; 4 megapixels: refused before allocating anything
            return CutoutSay(22, {w: w, h: h})
        try px := Buffer(w * h * 4)
        catch MemoryError
            return CutoutSay(20, {w: w, h: h}, "out of memory")
        rc := Buffer(16), NumPut("int", 0, "int", 0, "int", w, "int", h, rc)
        bd := Buffer(32, 0), NumPut("uint", w, "uint", h, "int", w * 4, "int", 0x26200A, "ptr", px.Ptr, bd)
        if DllCall("gdiplus\GdipBitmapLockBits", "ptr", bm, "ptr", rc, "uint", 5, "int", 0x26200A, "ptr", bd)   ; ReadOnly | UserInputBuf, 32bppARGB
            return CutoutSay(21)
        DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", bm, "ptr", bd)
        return {w: w, h: h, px: px}
    } finally
        DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
}

; The worker has ended: read the outcome; for 0 / 1 write the crop to dest (skipped when nothing would change
; in place). "Unchanged" = the crop is the whole picture and its pixels are the input's.
CutoutEnd(j, dest) {
    DllCall("CloseHandle", "ptr", j.thread)
    st := NumGet(j.buf, 36, "int")
    j.left := NumGet(j.buf, 40, "int"), j.top := NumGet(j.buf, 44, "int"), j.side := NumGet(j.buf, 48, "int")
    if st > 1 || st < 0
        return CutoutSay(st, j, "internal error " st)
    if j.side * j.side > 16777216                     ; a very long thin picture: its square would be huge
        return CutoutSay(22, j)
    same := j.left = 0 && j.top = 0 && j.side = j.w && j.side = j.h
        && (st = 1 || DllCall("ntdll\RtlCompareMemory", "ptr", j.orig, "ptr", j.px, "uptr", j.px.Size, "uptr") = j.px.Size)
    if !(same && dest = j.src) && !CutoutSave(j, dest)
        return CutoutSay(23, j, "couldn't write " dest)
    return CutoutSay(st, j, "", same)
}

CutoutSave(j, dest) {   ; side x side transparent canvas, the box's part of the picture copied in (clipped); true = saved
    s := j.side, x0 := Max(j.left, 0), x1 := Min(j.left + s, j.w)
    try out := Buffer(s * s * 4, 0)
    catch MemoryError
        return false
    if x1 > x0
        Loop Min(j.top + s, j.h) - (y0 := Max(j.top, 0)) {
            y := y0 + A_Index - 1
            DllCall("RtlMoveMemory", "ptr", out.Ptr + ((y - j.top) * s + x0 - j.left) * 4, "ptr", j.px.Ptr + (y * j.w + x0) * 4, "uptr", (x1 - x0) * 4)
        }
    if DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", s, "int", s, "int", s * 4, "int", 0x26200A, "ptr", out, "ptr*", &bm := 0)
        return false
    ok := SavePng(bm, dest), DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
    return ok
}

; Status -> result {status, msg, changed, w, h, left, top, side} with the panel's messages (shown under the
; cards). same = done, but the picture stays as it was; why = failure detail.
CutoutSay(st, j := {}, why := "", same := false) {
    static skips := Map(10, "background not uniform (border colours vary)", 11, "background is not light"
        , 12, "no dark outline found", 13, "no background reachable from the border (subject touches all edges?)"
        , 14, "nothing visible after processing", 21, "not a readable image file", 22, "too large to clean")
    ok := st = 0 || st = 1
    msg := same ? "already clean" : st = 0 ? "background removed" : st = 1 ? "already transparent, cropped to a square"
        : skips.Has(st) ? "left as is: " skips[st] : "cleaning failed" (why != "" ? " (" why ")" : "")
    return {status: st, msg: msg, changed: ok && !same, w: j.HasOwnProp("w") ? j.w : 0, h: j.HasOwnProp("h") ? j.h : 0
        , left: ok ? j.left : 0, top: ok ? j.top : 0, side: ok ? j.side : 0}
}

CutoutEntry() {   ; machine code -> executable memory, once: copied while read-write, then read + execute only
    static entry := 0
    if entry
        return entry
    m := CutoutMcode(), n := m.size
    mem := DllCall("VirtualAlloc", "ptr", 0, "uptr", n, "uint", 0x3000, "uint", 0x04, "ptr")   ; MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE
    if !mem
        return 0
    ok := DllCall("Crypt32\CryptStringToBinaryW", "str", m.code, "uint", 0, "uint", 1, "ptr", mem, "uint*", &n, "ptr", 0, "ptr", 0)   ; base64
        && n = m.size && DllCall("VirtualProtect", "ptr", mem, "uptr", n, "uint", 0x20, "uint*", &old := 0)   ; PAGE_EXECUTE_READ
    if !ok
        return (DllCall("VirtualFree", "ptr", mem, "uptr", 0, "uint", 0x8000), 0)   ; MEM_RELEASE
    DllCall("FlushInstructionCache", "ptr", DllCall("GetCurrentProcess", "ptr"), "ptr", mem, "uptr", n)
    return entry := mem + m.entry
}

global CUTOUT_JOBS := []
