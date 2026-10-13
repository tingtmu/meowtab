# run.ps1 runs a checks script (shots.ahk, timing.ahk, stay.ahk, keys.ahk or opens.ahk) against a source root, which stays untouched:
# the AutoHotkey wrapper (and, for timing, stay and opens, an instrumented COPY of the root's sources) is generated under
# build\checks\gen\. Options:
#   shots   [-Out <dir>] [-Tag <name>] [-Theme light,dark] [-Scenes abcdm]       timing  [-Out <dir>] [-Tag <name>] [-Wrap <fn>,...] [-Gif <file>]
#                                                                                        [-Picture <file>] [-Alternate]
#   stay    [-Out <dir>] [-Tag <name>]   (stay-open timings)                     keys    (Win+Q: no Start menu, no menu bar)
#   opens   [-Out <dir>] [-Tag <name>] [-Count <n>] [-Picture <file>]   (n opens, default 200: handles and memory stay flat, no timer runs after)
# -Gif <file> (timing) puts that GIF on every mood in place of the root's pictures (lib.ahk's Stage), and adds -gif to the default tag.
# -Picture <file> (timing, opens) imports that picture into the new data folder as the panel's Save does (pane.png, with
# PANE_PICTURE=pane.png in its settings.ini), so the app loads it at startup as a user's; adds -pic to the default tag. The run prints
# the size the app loaded it at.
# -Alternate (timing) opens on 3 and 6 demo windows by turns in place of 30, so every open has a new pane size; adds -alt to the
# default tag.
# -Effects on|off (any mode) sets ANIM_EFFECTS, in place of Windows' Animation effects: Velvet's motion and a GIF's playback follow it.
# -Look velvet|windows11 (any mode) runs the app in that look: the wrapper writes PANE_LOOK into the new data folder's settings.ini, as
# the test does; without it nothing is written and the app's default applies. The run prints the look the app runs in.
# -Root is the source folder to check (default: the repo root); point it at another one, such as an exported older commit, to compare
# before and after. -Tag names the run (default: the root's folder name, plus -<look> with -Look); -Out defaults to build\checks\<tag>;
# -Ahk defaults to the first AutoHotkey v2 found under $env:ProgramFiles or $env:LOCALAPPDATA\Programs; -Validate only load-checks
# (no windows, no input).
# Run from the repo root:  powershell -ExecutionPolicy Bypass -File tools\checks\run.ps1 shots|timing|stay|keys|opens [-Root <dir>] ...
#                          powershell -ExecutionPolicy Bypass -File tools\checks\run.ps1 shots -Theme light -Scenes a
#                          powershell -ExecutionPolicy Bypass -File tools\checks\run.ps1 timing -Look velvet -Validate
# Exit code: 0 ok, 1 a check failed (keys, opens), 2 the safety exit (2 minutes; opens: its n opens' time), 3 an error in the run, 4 the
# privacy guard refused a capture (shots) or no screen, so nothing was shown or sent (stay, keys, opens), 5 a stray AutoHotkey window
# was already on screen (nothing was started). Keep hands off the mouse and keyboard while it runs (about 40 s, per theme for shots;
# 25 s for keys; 2.5 min for 200 opens), except with -Validate.
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet('shots', 'timing', 'stay', 'keys', 'opens')][string]$Mode,
    [string]$Root,                               # the source folder to check (default: the repo root), e.g. an exported older commit
    [string]$Out, [string]$Tag,
    [ValidateSet('velvet', 'windows11')][string]$Look,   # the pane's look (default: the app's own default)
    [string[]]$Theme = @('light', 'dark'), [string]$Scenes = 'abcdm',
    [string[]]$Wrap = @(),                       # timing: more functions to wrap and time (ScrollTick, SelectTile, PaneWheel always)
    [int]$Count = 200,                           # opens: how many
    [string]$Gif,                                # timing: this GIF on every mood (default: the root's pictures)
    [string]$Picture,                            # timing, opens: this background picture, as pane.png (default: none)
    [switch]$Alternate,                          # timing: open on 3 and 6 windows by turns (default: 30)
    [ValidateSet('on', 'off')][string]$Effects,  # ANIM_EFFECTS (default: Windows' Animation effects)
    [switch]$Validate,                           # only generate and load-check (no windows, no input)
    [string]$Ahk                                 # AutoHotkey64.exe (default: the first of the two usual v2 install paths that exists, below)
)
$ErrorActionPreference = 'Stop'
$Theme = @($Theme -split ',')                    # powershell -File passes a list such as light,dark as one string
$Wrap = @($Wrap -split ',')
$checks = $PSScriptRoot
$repo = Split-Path (Split-Path $checks)          # tools\checks -> the repo root
if (-not $Root) { $Root = $repo }
if (-not $Ahk) {
    $candidates = @("$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe", "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe")
    $Ahk = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $Ahk) { throw "AutoHotkey v2 not found (looked for $($candidates -join ' and ')): pass -Ahk <path to AutoHotkey64.exe>" }
}
$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
if (-not (Test-Path -LiteralPath "$Root\meowtab.ahk")) { throw "no meowtab.ahk in $Root" }
if ($Gif) { $Gif = (Resolve-Path -LiteralPath $Gif).Path }   # relative: to where it was started from
if ($Picture) { $Picture = (Resolve-Path -LiteralPath $Picture).Path }
if (-not $Tag) {                                 # each look's runs apart, the GIF's, the picture's and the alternating ones too
    $Tag = (Split-Path $Root -Leaf) + $(if ($Look) { "-$Look" }) + $(if ($Gif) { '-gif' }) + $(if ($Picture) { '-pic' }) + $(if ($Alternate) { '-alt' })
}
if (-not $Out) { $Out = Join-Path $repo "build\checks\$Tag" }
$Out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
$gen = Join-Path $repo "build\checks\gen\$Tag-$Mode"
if (Test-Path $gen) { Remove-Item $gen -Recurse -Force }
New-Item -ItemType Directory -Force $gen, $Out | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)

# The wrapper: warnings to stdout (never a blocking dialog), the root's path, a new empty data folder (the user's own settings
# are never read or changed; with -Look, its settings.ini sets the look), then the includes. Right after the app's include, the
# look it runs in is printed ($sayLook: an older source without PANE_LOOK has only the Windows 11 look).
$head = @"
#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, Off
#Warn VarUnset, StdOut
#Warn Unreachable, StdOut
; generated by run.ps1 ($Mode, $Tag) for the source root $Root
SRC_ROOT := "$Root"
DATA_DIR := A_Temp "\meowtab-$Mode-" A_TickCount
OnExit((*) => (DirExist(DATA_DIR) && DirDelete(DATA_DIR, true), 0))

"@
if ($Look) { $head += 'DirCreate(DATA_DIR), IniWrite("' + $Look + '", DATA_DIR "\settings.ini", "settings", "PANE_LOOK")' + "`n" }
if ($Gif) { $head += 'GIF_ALL := "' + $Gif + '"' + "`n" }   # lib.ahk's Stage loads it for every mood
if ($Effects) { $head += 'ANIM_EFFECTS := ' + $(if ($Effects -eq 'on') { 'true' } else { 'false' }) + "`n" }
$sayLook = 'FileAppend("look: " (IsSet(PANE_LOOK) ? PANE_LOOK : "windows11 (no PANE_LOOK in this source)") "`n", "*")' + "`n"
if ($Picture) {
    # pane.png made by the panel's own import (its functions are defined before the include runs; GDI+ only for it, the app starts
    # its own; loaded first, as the app does, or each DllCall would unload it again), then the setting; once the app has started,
    # the size it loaded the picture at.
    $head += @"
DllCall("LoadLibrary", "str", "gdiplus"), RUN_SI := Buffer(24, 0), NumPut("uint", 1, RUN_SI)
DllCall("gdiplus\GdiplusStartup", "ptr*", &RUN_GDIP := 0, "ptr", RUN_SI, "ptr", 0)
if (RUN_WHY := PaneImport("$Picture") PaneCommit(false)) != ""
    FileAppend("can't use $($Picture): " RUN_WHY "``n", "*"), ExitApp(3)
DllCall("gdiplus\GdiplusShutdown", "ptr", RUN_GDIP), IniWrite("pane.png", DATA_DIR "\settings.ini", "settings", "PANE_PICTURE")

"@
    $sayLook += 'FileAppend("pane picture: " (IsSet(panePic) && panePic ? panePic.w "x" panePic.h " loaded at startup" : "none") "`n", "*")' + "`n"
}

$runs = New-Object 'System.Collections.Generic.List[string[]]'   # one argument list per AutoHotkey process
if ($Mode -eq 'shots') {
    $main = "#Include $Root\meowtab.ahk`n$sayLook#Include $checks\lib.ahk`n#Include $checks\shots.ahk`n"
    # One process per theme, so both start alike (the first real mouse press in a process is special at HEAD, see shots.ahk "m").
    if ($Validate) { $runs.Add([string[]]@($Out, ($Theme -join ','), $Scenes)) }
    else { foreach ($t in $Theme) { $runs.Add([string[]]@($Out, $t, $Scenes)) } }
}
elseif ($Mode -eq 'timing' -or $Mode -eq 'opens') {
    # An instrumented copy: each function to wrap that exists is renamed <name>__orig and wrapped by a function of the old name that
    # times the call into TimeLog, so timers and callers go through it. timing wraps the frame functions; opens, every function the
    # app hands SetTimer, so that opens.ahk sees any timer still running after the last close. The root's files are only read;
    # meowtab-classic.ahk isn't included (and has its own WatchAlt), so it isn't copied.
    $src = Join-Path $gen 'src'
    New-Item -ItemType Directory $src | Out-Null
    $texts = @{}
    foreach ($f in Get-ChildItem -LiteralPath $Root -Filter *.ahk -File | Where-Object Name -ne 'meowtab-classic.ahk') {
        $texts[$f.Name] = [IO.File]::ReadAllText($f.FullName)
    }
    $tmpl = @'

@FN@(p*) {
    t := Qpc()
    try return @FN@__orig(p*)
    finally TimeLog("@FN@", Qpc() - t)
}
'@
    $fns = @('ScrollTick', 'SelectTile', 'PaneWheel')
    if ($Mode -eq 'opens') {
        $rxTimer = [regex]'\bSetTimer\(?\s*([A-Za-z_]\w*)'   # a function handed to SetTimer by name (WM_PROCESS's check is a fat arrow)
        $fns = @($texts.Values | ForEach-Object { $rxTimer.Matches($_) } | ForEach-Object { $_.Groups[1].Value })
    }
    $wrappers = "; generated by run.ps1: $Mode wrappers`n"
    foreach ($fn in ($fns + $Wrap | Select-Object -Unique)) {
        $rx = [regex]"(?m)^$([regex]::Escape($fn))\("
        $hits = @($texts.Keys | Where-Object { $rx.IsMatch($texts[$_]) })
        if ($hits.Count -eq 0) { Write-Host "wrap: $fn is not defined in this source, skipped"; continue }
        if ($hits.Count -gt 1 -or $rx.Matches($texts[$hits[0]]).Count -gt 1) { throw "wrap: $fn is defined more than once" }
        $texts[$hits[0]] = $rx.Replace($texts[$hits[0]], "${fn}__orig(", 1)
        $wrappers += $tmpl.Replace('@FN@', $fn)
        Write-Host "wrap: $fn (in $($hits[0]))"
    }
    foreach ($name in $texts.Keys) { [IO.File]::WriteAllText((Join-Path $src $name), $texts[$name], $utf8) }
    [IO.File]::WriteAllText("$gen\wrap.ahk", $wrappers, $utf8)
    $main = "#Include $src\meowtab.ahk`n$sayLook#Include $gen\wrap.ahk`n#Include $checks\lib.ahk`n#Include $checks\$Mode.ahk`n"
    $runs.Add([string[]]$(if ($Mode -eq 'opens') { @($Out, $Tag, $Count) } elseif ($Alternate) { @($Out, $Tag, 'alternate') } else { @($Out, $Tag) }))
}
elseif ($Mode -eq 'stay') {
    # A copy in which CollectWindows is renamed CollectWindows__orig in the file that defines it (windows.ahk; meowtab.ahk in older
    # sources): stay-seam.ahk defines it again, listing only the demo windows. meowtab-classic.ahk is skipped (older sources have
    # their own copy in it, and it isn't included). The root's files are only read.
    $src = Join-Path $gen 'src'
    New-Item -ItemType Directory $src | Out-Null
    $rx = [regex]'(?m)^CollectWindows\('
    $defs = @()
    foreach ($f in Get-ChildItem -LiteralPath $Root -Filter *.ahk -File) {
        $t = [IO.File]::ReadAllText($f.FullName)
        if ($f.Name -ne 'meowtab-classic.ahk' -and $rx.IsMatch($t)) {
            $defs += @($f.Name) * $rx.Matches($t).Count
            $t = $rx.Replace($t, 'CollectWindows__orig(', 1)
        }
        [IO.File]::WriteAllText((Join-Path $src $f.Name), $t, $utf8)
    }
    if ($defs.Count -ne 1) { throw "expected one CollectWindows( definition in $Root\*.ahk (meowtab-classic.ahk aside), found $($defs.Count)$(if ($defs) { ': ' + ($defs -join ', ') })" }
    Write-Host "stay: CollectWindows renamed in $($defs[0])"
    $main = "#Include $src\meowtab.ahk`n$sayLook#Include $checks\lib.ahk`n#Include $checks\stay-seam.ahk`n#Include $checks\stay.ahk`n"
    $runs.Add([string[]]@($Out, $Tag))
}
else {
    # keys: the app starts with SWITCH_KEYS=Win+Q in the new data folder (the stay-open shortcut stays the default, Ctrl+Alt+Tab).
    $main = 'DirCreate(DATA_DIR), IniWrite("Win+Q", DATA_DIR "\settings.ini", "settings", "SWITCH_KEYS")' + "`n#Include $Root\meowtab.ahk`n$sayLook#Include $checks\keys.ahk`n"
    $runs.Add([string[]]@())
}

$wrapper = Join-Path $gen "$Mode.ahk"
[IO.File]::WriteAllText($wrapper, $head + $main, $utf8)
Write-Host "run: $Mode on $Root, look: $(if ($Look) { $Look } else { "the app's default" })$(if ($Gif) { ", every mood: $Gif" })$(if ($Picture) { ", pane picture: $Picture" })$(if ($Alternate) { ', opens on 3 and 6 windows by turns' })`nwrapper: $wrapper`nout: $Out"
if (-not (Test-Path -LiteralPath $wrapper)) { throw "no wrapper at $wrapper" }
$ErrorActionPreference = 'Continue'
$worst = 0
foreach ($a in $runs) {
    # The argument list is a typed string[] of WHOLE arguments. (An `if` that yields a one-element array hands back a bare string,
    # and splatting a string passes it one character per argument: AutoHotkey then tried to open the script "/".)
    [string[]]$argv = @('/ErrorStdOut')
    if ($Validate) { $argv = @('/Validate') + $argv }
    $argv = $argv + @($wrapper) + $a
    Write-Host "cmd: $Ahk $($argv -join ' ')"
    $o = & $Ahk $argv | Out-String                            # the pipe makes PowerShell wait for the GUI process
    $code = $LASTEXITCODE
    $o
    "exit code: $code"
    if ($code -ne 0 -and $worst -eq 0) { $worst = $code }
    if ($code -ne 0 -and $code -ne 4) { break }               # 4 = a refused capture: the next theme can still run; anything else stops
}
exit $worst
