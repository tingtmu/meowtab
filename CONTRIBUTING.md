# Contributing to MeowTab

For developers and coding agents. See [README.md](README.md) for installing and using the app.

## Running from source

**From source** (with [AutoHotkey](https://www.autohotkey.com/) v2.0 or newer installed): get the code with **Code > Download ZIP** on the [repo's page](https://github.com/tingtmu/meowtab) (then unzip it into a folder of your own), or

```
git clone https://github.com/tingtmu/meowtab.git
```

and double-click `meowtab.ahk`.

There are two scripts:

| Script | Look |
| --- | --- |
| `meowtab.ahk` (main) | Draws the Velvet look by default, or the Windows 11 look: a grid of live previews on acrylic, the picture peeking over the top-left edge. |
| `meowtab-classic.ahk` | The original layout: a list of titles with one large preview beside it, the picture inside the pane's bottom-left corner. |

Run only one at a time; both replace Alt+Tab. The other `.ahk` files are parts the two scripts include, not meant to be run on their own.

## Code map

- `meowtab.ahk`: settings, hotkeys and switching
- `meowtab-classic.ahk`: the second script, with the original list layout
- `windows.ahk`: the window listing and recency, the current monitor and its work area (shared by both scripts and the settings panel)
- `alttab-native.ahk`: the switcher's pane (theme, acrylic, the pane's surface, live thumbnails, the mouse)
- `alttab-grid.ahk`: the tiles' layout, scrolling, selection moves and the scroll bar
- `alttab-draw.ahk`: drawing the pane (`Render` and its helpers)
- `alttab-velvet.ahk`: the Velvet look's drawing
- `pane-picture.ahk`: the background picture behind the tiles
- `alttab-icons.ahk`: the app icons
- `alttab-peek.ahk`: the peeking picture
- `settings-panel.ahk`: the settings panel (opening, layout, the shortcut capture, Save and Reset)
- `settings-events.ahk`: the panel's message and input handlers (painting, keys, mouse, scrolling, the steppers, sliders and cards)
- `settings-pictures.ahk`: the panel's pictures: picking and dropping them on the cards, GIF playback on the cards, Clean background, the background picture
- `settings-paint.ahk`: the panel's drawing
- `settings-mini.ahk`: the switcher in miniature (the LOOK cards, the peek scenes, the title sample)
- `settings-store.ahk`: loading, checking and saving `settings.ini`, and the file work of importing pictures
- `gdip-helpers.ahk`: small GDI+ helpers shared by the pane and the panel
- `gif.ahk`: animated GIFs, read as frames and written back
- `cutout.ahk`, `cutout-gif.ahk`, `cutout-mcode.ahk`: Clean background (a still picture, an animated GIF, and the machine code built from `cutout.c`, never edited by hand)
- `desktop-icon.ahk`: the Desktop icon shortcut on the tray menu
- `start-at-login.ahk`: the Start at login shortcut on the tray menu (in the Startup folder, with Windows' own switch for it)
- `tests\meowtab.test.ahk`: the integration test, which runs its checks from parts beside it in `tests\` (`ALL PASSED` required before merging)

`meowtab.ahk` also has a **Native look** block of constants just below the settings (pane padding, tile sizes and gaps, the selection ring, the close button, light and dark colours), each line commented, for tinkering. Velvet's palettes and sizes sit next to the Windows 11 ones (`VELVET_LIGHT` and `VELVET_DARK` beside `LIGHT_PAL` and `DARK_PAL`).

## How it works

For the curious, all in AutoHotkey v2 with plain Win32 calls:

- **Acrylic without stealing focus.** The pane is a popup that is never activated, so your window keeps the keyboard until you switch. Windows only draws acrylic for an active-looking window, so MeowTab asks DWM for the transient (flyout) backdrop, turns non-client rendering on and marks the frame active (`WM_NCACTIVATE`) without activating anything.
- **Live previews** are DWM thumbnails, cropped to each window's visible frame.
- **Everything else on the pane** (headers, icons, titles, the ring) is drawn with GDI+ into a 32-bit surface with real per-pixel alpha, so the acrylic shows through where nothing is drawn.
- **The peek** is a separate click-through window that shows only the part of the picture above the pane's edge, so nothing of it shows blurred through the glass.

## Building the exe

`build.ps1` compiles both scripts and packs a zip:

```
powershell -ExecutionPolicy Bypass -File build.ps1
```

It needs AutoHotkey v2 (found in its usual install folders, or pass `-Base <path to AutoHotkey64.exe>`). The compiler, Ahk2Exe, comes from `-Ahk2Exe <path>`, the `AHK2EXE` environment variable or AutoHotkey's `Compiler` folder; failing those, the latest [Ahk2Exe release](https://github.com/AutoHotkey/Ahk2Exe/releases) is downloaded into `build\` (nothing is installed). The result is `dist\meowtab\` and `dist\meowtab.zip`, which holds only the two exes, the three `chill_*.png` pictures, `images\chill.gif` (the shipped animated cat), `README.md` and the license.

**Clean background** is C (`cutout.c`) compiled to machine code stored in `cutout-mcode.ahk`, so neither the scripts nor the exes need a compiler. `build-mcode.ps1` regenerates it from `cutout.c` with a pinned, hash-checked [Zig](https://ziglang.org); run it after editing `cutout.c`. CI checks the file is up to date.

[GitHub Actions](.github/workflows/build.yml) builds the zip from a version tag, with pinned, hash-checked copies of AutoHotkey and Ahk2Exe.

## Tests

From the repo root (close any running copy first; adjust the path if AutoHotkey is installed elsewhere):

```
& "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut tests\meowtab.test.ahk velvet | more
```

Its argument is the look to test in: `velvet` as above, or `windows11`. Without one, it runs in the default look.

`tests\meowtab.test.ahk` opens a few temporary windows, drives the real switching code and prints `PASS`/`FAIL` per check, ending with `ALL PASSED`. It covers recency order (including after a re-tile), Alt+Tab, Alt+Tab+Tab, the live previews being registered and released, the arrow keys, the grid for many windows with its scrolling and scroll bar, and switching and closing with the mouse. It also checks the shortcuts: how `settings.ini` values are read and refused, Alt+Tab and a custom Ctrl+Q driven with real keys, and the stay-open switcher (Enter, Esc, a shortcut while it's open, typing blocked, a click outside). In the settings panel it captures shortcuts with real keys: Alt+Tab opens no switcher, refused combinations keep the old value, Esc cancels, and no way of ending a capture leaves the hotkeys suspended. It scrolls the panel in a small room, and picks a look on the Look cards (a click, then Space): the card is marked, the previews redraw, and Save writes the look; Classic's own panel has no Look section. It needs an unlocked, connected desktop.

`tests\cutout.test.ahk` checks **Clean background** against the expected results in `tests/cutout/`; CI runs it too.

`tools\readme-shots.ahk` takes the README's screenshots from the real pane. It lists only its own demo windows over a stand-in wallpaper, so none of your own windows can end up in an image.

`tools\checks\run.ps1` repeats the many-windows checks: `shots` captures the grid in light and dark (8 to 30 windows, mid-scroll, a real drag of the scroll bar), and `timing` times each frame. `stay` times the stay-open switcher the same way, and `keys` checks that Win+Q as the shortcut, a lone Alt or Win in the stay-open switcher, and a Win+Q capture in the settings panel open no Start menu or menu bar. `-Look velvet` or `-Look windows11` runs any of them in that look. All of them list only their own demo windows, write to `build\checks\` and need the mouse and keyboard left alone for about a minute. `tools\checks\control.ahk` times plain computation for comparison.

Screenshots and recordings for docs only ever show demo windows over a stand-in wallpaper, never the user's real windows. See [How to capture screenshots and the GIF](ROADMAP.md#how-to-capture-screenshots-and-the-gif) for `readme-shots` usage.

## Releasing

1. Bump `;@Ahk2Exe-SetVersion` at the top of both `meowtab.ahk` and `meowtab-classic.ahk`, and commit.
2. Tag and push only that tag (this clone also carries old peek-alttab tags, so never `--tags`):

   ```
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

3. CI builds the zip and makes a **draft** release with `meowtab.zip` and `SHA256SUMS.txt`. It fails, with no release, if the tag and the stamped version differ.
4. Download the draft's files and check them. `VT_API_KEY` must hold a [VirusTotal](https://www.virustotal.com/gui/my-apikey) API key (the free one is enough); set it once with `setx VT_API_KEY <key>` and open a new terminal, rather than typing it into a command you run. The run takes a few minutes:

   ```
   gh release download vX.Y.Z -D C:\tmp\meowtab-release
   powershell -ExecutionPolicy Bypass -File tools\release-checks.ps1 C:\tmp\meowtab-release
   ```

   It checks every hash in `SHA256SUMS.txt`, uploads the zip and both exes to VirusTotal (public there), and prints a Markdown table. Paste it into the release notes, along with a line on what the scans do and don't show, and look into any detection.
5. Publish the draft.
6. Update the packages:
   - Scoop: `& "$(scoop prefix scoop)\bin\checkver.ps1" -App meowtab -Dir .\bucket -Update` rewrites `bucket\meowtab.json` (version, URL, and the hash from `SHA256SUMS.txt`); commit and push it.
   - WinGet: `wingetcreate update tingtmu.MeowTab --urls https://github.com/tingtmu/meowtab/releases/download/vX.Y.Z/meowtab.zip --version X.Y.Z --submit` opens the pull request against `microsoft/winget-pkgs`.
7. Review the Quick start, `README.zh-TW.md` (the Traditional Chinese README) and root `llms.txt` whenever install commands or WinGet's pending status change.

## Pull requests

Pull requests adding picture sets to `images/` are welcome. Please only submit art you made yourself or art whose license allows redistribution.

`tests\meowtab.test.ahk` must print `ALL PASSED` before merging.

When a change touches `README.md`, keep `README.zh-TW.md` in step: the same sections, images, links and code blocks, with code blocks, commands, file names, keys and the app's English UI labels left exactly as they are.
