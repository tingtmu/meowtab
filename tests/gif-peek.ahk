; #Included by meowtab.test.ahk where its peek checks run: these top-level lines run there, in order.
; A GIF in the peek (design.md 4-5), through the app's seam for Animation effects (ANIM_EFFECTS): a 3-frame GIF (MakeGif in
; gif-files.ahk, delays of 50, 500 and 100 ms) is the "few" picture for these checks only, the pane open on 1 window.

; An open, then for ms: "frame <f>, playing" (or "still") at once, then each frame it moves to, marked "(early)" if the frame
; before it lasted over 40 ms less than its delay, "(late)" if over 150 ms more.
PeekPlays(ms) {
    Open(1, 1), s := "frame " peekF (peekPlay ? ", playing" : ", still"), seen := "", f := peekF, t0 := t := A_TickCount
    while A_TickCount - t0 < ms {
        Wait(5)
        if peekF != f
            d := A_TickCount - t - delays[1][f + 1], seen .= (d < -40 ? " (early)" : d > 150 ? " (late)" : "") " " peekF, f := peekF, t := A_TickCount
    }
    return s (seen = "" ? "" : ", then" seen)
}
gifWas := {imgs: imgs, delays: delays, spans: spans, look: PANE_LOOK, effects: ANIM_EFFECTS, k: peekK}
DirCreate(DATA_DIR), gifPeek := MakeGif(DATA_DIR "\peek.gif", 3, 32), strip := GifStrip(gifPeek, IMG_SIZE, &span, &frameMs), FileDelete(gifPeek)
imgs := [strip, imgs[2], imgs[3]], delays := [frameMs, delays[2], delays[3]], spans := [span, spans[2], spans[3]]
PANE_LOOK := "velvet", ANIM_EFFECTS := true, plays := PeekPlays(1000), atClose := peekF, Finish(false), Wait(0)
closed := peekPlay " " DllCall("IsWindowVisible", "ptr", peek.Hwnd), closedAt := A_TickCount
while peekF = atClose && A_TickCount - closedAt < 700  ; longer than any of its delays, watched throughout (a whole loop takes 650 ms)
    Wait(5)
closed .= peekF = atClose ? ", stays" : ", moved on to " peekF
Check("a GIF in the peek plays from its first frame, each frame for its own delay, and loops after the third", plays, "frame 0, playing, then 1 2 0 1")
Check("after Finish its playback timer is off and the peek hidden: the frame stays put", closed, "0 0, stays")
Open(1, 1), freshAt := atClose " then " peekF, Finish(false), Wait(0)
Check("a fresh open starts at frame 0", freshAt, "1 then 0")
ANIM_EFFECTS := false, stillPlays := PeekPlays(700), Finish(false), Wait(0)
Check("with Animation effects off it shows its first frame, still", stillPlays, "frame 0, still")
PANE_LOOK := "windows11", ANIM_EFFECTS := true, w11Plays := PeekPlays(1000), Finish(false), Wait(0)
Check("it plays in the Windows 11 look too", w11Plays, "frame 0, playing, then 1 2 0 1")
imgs[2] := 0, Open(1, 1), PeekTo(2, peekGoal, peekX, peekEdge, false), PeekTo(1, peekGoal, peekX, peekEdge, false)   ; a mood with no picture, then back
back := peekF " " peekPlay, Finish(false), Wait(0)
Check("back from a mood with no picture, the GIF plays again from its first frame", back, "0 1")
imgs := gifWas.imgs, delays := gifWas.delays, spans := gifWas.spans, PANE_LOOK := gifWas.look, ANIM_EFFECTS := gifWas.effects
peekK := gifWas.k                          ; as before (the strip stays in peekDC: the next picture shown is selected over it)
