# MeowTab

**Alt+Tab the Windows 11 way, with a cat peeking over the edge.**

MeowTab replaces Alt+Tab with a switcher that looks like the one built into Windows 11: live previews of your windows in a grid, on a frosted acrylic pane that follows light and dark mode. Then it adds one small, silly thing: a picture peeks over the pane's top-left edge, and it changes with how many windows you have open. A sleepy cat when you have a few, a cat sitting up straight when it's getting crowded. Swap in your own pictures and let your pet, your mascot or your boss judge your window count.

![MeowTab](docs/meowtab.png)

> **Status: early preview (0.1).** MeowTab grew out of [peek-alttab](https://github.com/tingtmu/peek-alttab) and is being polished into a full app; see the [roadmap](ROADMAP.md).

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Install with WinGet or Scoop](#install-with-winget-or-scoop)
- [Check the download](#check-the-download)
- [Usage](#usage)
- [Settings panel](#settings-panel)
- [Use your own pictures](#use-your-own-pictures)
- [Two styles](#two-styles)
- [Settings](#settings)
- [Remove MeowTab](#remove-meowtab)
- [How it works](#how-it-works)
- [Building the exe](#building-the-exe)
- [Releasing](#releasing)
- [Tests](#tests)
- [Known issues](#known-issues)
- [Roadmap](#roadmap)
- [License](#license)

## Features

- **Looks native.** A grid of live window thumbnails, each with its app icon and title, on Windows 11's own acrylic material. The selection gets the accent-coloured ring Windows uses. Light or dark follows your Windows mode, and the ring follows your accent colour.

  ![MeowTab in dark mode](docs/meowtab-dark.png)

- **The peek.** A mood picture sits on the pane's top-left edge, slides up when the switcher opens and rises a little higher the more windows you have:

  | Mood | Windows (default) | Default picture |
  | --- | --- | --- |
  | few | 1-2 | a cat curled up asleep |
  | some | 3-7 | a cat lounging |
  | many | 8+ | a cat sitting up, very much awake |

- **Your own pictures.** Pick or drop them in the settings panel. **Clean background** cuts out a plain light background and crops to a square, built in.
- **Keyboard and mouse.** Tab and the arrow keys move through the grid (Up and Down change rows), Delete closes a window and keeps the switcher open, Esc cancels. Hover a tile for its close button; click a tile to switch to it.
- **Your current screen only.** Only windows on the focused monitor are listed, most recently used first. Windows hides windows on other virtual desktops, and tiling window managers such as GlazeWM hide other workspaces, so this means the desktop or workspace you're on. Recency comes from window activations, not stacking order, so a re-tile doesn't shuffle the list.
- **Readable titles in any language.** Titles use Noto Sans TC when it's installed (clear for mixed Chinese and English), otherwise Segoe UI. Any installed font works, set from the settings panel.

## Requirements

- Windows 11, 64-bit. The acrylic pane needs version 22H2 or later; older builds get a solid pane.
- [AutoHotkey](https://www.autohotkey.com/) v2.0 or newer, only to run the `.ahk` scripts from source. The `.exe` files in the [download](#quick-start) need nothing else.

## Quick start

1. Open the [latest release](https://github.com/tingtmu/meowtab/releases/latest). Its notes give the hashes and virus-scan links for the files (see [Check the download](#check-the-download)). Download `meowtab.zip` there, or straight from [this link](https://github.com/tingtmu/meowtab/releases/latest/download/meowtab.zip).
2. Unzip it into a folder of your own, such as Documents. Keep the folder together: the exe finds its pictures beside it.
3. Double-click `meowtab.exe`, then hold **Alt** and press **Tab**. The first time, MeowTab asks whether to put an icon on your desktop (it opens the settings panel); either answer is remembered.

`meowtab-classic.exe` is the [other style](#two-styles). No AutoHotkey needed.

**From source instead** (with [AutoHotkey v2](https://www.autohotkey.com/) installed): get the code with **Code > Download ZIP** on this page (then unzip it into a folder of your own), or

```
git clone https://github.com/tingtmu/meowtab.git
```

and double-click `meowtab.ahk`.

Double-click the tray icon (a sleepy cat) to open the [settings panel](#settings-panel). Right-click it to reload or exit, or to tick **Desktop icon**, which puts a shortcut on your desktop that opens the panel.

**Run at login:** press `Win+R`, type `shell:startup`, and put a shortcut to `meowtab.exe` (or `meowtab.ahk`) in the folder that opens.

**With GlazeWM (optional):** add it to `startup_commands` in GlazeWM's `config.yaml`:

```yaml
general:
  startup_commands: ['shell-exec C:\path\to\meowtab\meowtab.ahk']
```

To make MeowTab exit when GlazeWM quits, put this in `%APPDATA%\MeowTab\settings.ini` (the settings panel keeps the line when it saves):

```ini
[settings]
WM_PROCESS=glazewm.exe
```

**Good to know**

- Windows doesn't let a normal app's hotkeys reach an elevated (administrator) window, so while one is focused you get the built-in Alt+Tab. To cover those windows too, run MeowTab as administrator.
- It never connects to the network. Your settings and pictures stay on your PC, in `%APPDATA%\MeowTab`.

## Install with WinGet or Scoop

Both install the same files as the download and keep them up to date. Exit MeowTab from the tray before you update or uninstall it. Your settings and pictures stay in `%APPDATA%\MeowTab` through updates and uninstalls ([Remove MeowTab](#remove-meowtab) says how to delete them).

**WinGet** (built into Windows 11):

```
winget install tingtmu.MeowTab
```

Then open a new terminal and run `meowtab` (or `meowtab-classic`). WinGet adds no Start menu entry; the first run offers a desktop icon instead. Update with `winget upgrade tingtmu.MeowTab`, remove with `winget uninstall tingtmu.MeowTab`.

**Scoop** (buckets need git: `scoop install git`):

```
scoop bucket add meowtab https://github.com/tingtmu/meowtab
scoop install meowtab/meowtab
```

MeowTab starts by itself once installed (and after each update); later, start it from the Start menu: **Scoop Apps > MeowTab** (or **MeowTab Classic**). Update with `scoop update` (it refreshes the bucket) and then `scoop update meowtab`, remove with `scoop uninstall meowtab`.

## Check the download

Each release has a `SHA256SUMS.txt`, and its notes repeat the SHA-256 of `meowtab.zip`, `meowtab.exe` and `meowtab-classic.exe`, each with a [VirusTotal](https://www.virustotal.com) report link. To check your download, put `meowtab.zip` and `SHA256SUMS.txt` in one folder and run this in PowerShell there (it prints `True` when they match):

```
(Get-FileHash .\meowtab.zip).Hash -eq (Select-String -Path .\SHA256SUMS.txt -Pattern ' meowtab\.zip$').Line.Split(' ')[0]
```

What that tells you, and what it doesn't:

- The hashes come from the [GitHub Actions build](.github/workflows/build.yml) of the tagged source. A zip that matches is the file that was built and scanned; one that doesn't is a damaged or altered download, so don't run it.
- A VirusTotal report is a set of automated scans. They are heuristic, so a clean report is no guarantee, and a few engines sometimes flag exes compiled from AutoHotkey scripts even though nothing is wrong. The report for each file is linked from the notes, and the source is all here to read.
- The exes aren't code-signed, so Windows SmartScreen may show "Windows protected your PC" the first time. Choose **More info**, then **Run anyway**, once you've checked the hash.

## Usage

Hold **Alt**, then:

| Keys | Action |
| --- | --- |
| `Tab` / `Shift+Tab` | Next / previous window |
| `Right` / `Left` | Next / previous window |
| `Down` / `Up` | The tile below / above |
| Release `Alt` | Switch to the selected window |
| `Esc` | Cancel without switching |
| `Delete` | Close the selected window and keep the switcher open |

With **Alt** still held, the mouse works too: click a tile to switch to it, or hover it and click its **×** to close that window. When there are more windows than fit, scroll with the mouse wheel or drag the scroll bar on the pane's right side.

The first Tab picks the window you were in before. Apps that ask "save changes?" on close stay in the list until you answer.

## Settings panel

Double-click the tray icon, or right-click it and choose **Settings…**. The desktop icon (tray menu > **Desktop icon**) opens it too.

![Settings panel](docs/settings.png)

- **Mood images.** One card per mood. Click a card to choose a picture (PNG, JPG, BMP or GIF), or drag a file onto it. The `−  3  +` steppers set where "some" and "many" start.
- **Clean background** (`✧ Clean`, on a card with your own picture) removes a plain light background and crops the picture to a square.
- **Peek height.** How much of the picture shows above the pane with a single window, and once the count reaches "many". The two little scenes preview it with your own pictures.
- **Title font.** Any installed font, at 10 to 24 pt.

**Save** (or Enter) writes `%APPDATA%\MeowTab\settings.ini` and reloads it. **Cancel** (or Esc) changes nothing. **Reset to defaults** removes the panel's settings from `settings.ini`; it never deletes pictures and keeps lines you added yourself, such as `WM_PROCESS`.

The panel is built when you open it and freed when you close it, so it never slows Alt+Tab down.

## Use your own pictures

The settings panel is the easy way. Your pictures are copied into `%APPDATA%\MeowTab\images\` as `custom_few.png`, `custom_some.png` and `custom_many.png`; the shipped `chill_*` cats are never overwritten. Large pictures are scaled down to 1024 px and photos are turned upright.

By hand: put three PNGs in `%APPDATA%\MeowTab\images\` named `<prefix>_few.png`, `<prefix>_some.png` and `<prefix>_many.png`, set `IMG_PREFIX=<prefix>` in `settings.ini`, then **Reload Script** from the tray menu.

Tips:

- A **square PNG with a transparent background** works best. Any resolution is fine; a non-square picture keeps its shape.
- How much of the picture peeks out ignores transparent padding, so a small subject in a big canvas still peeks properly.
- A missing file just means no picture for that mood.

Pull requests adding picture sets to `images/` are welcome. Please only submit art you made yourself or art whose license allows redistribution.

## Two styles

| Script | Look |
| --- | --- |
| `meowtab.ahk` (main) | Windows 11 style: a grid of live previews on acrylic, the picture peeking over the top-left edge. |
| `meowtab-classic.ahk` | The original layout: a list of titles with one large preview beside it, the picture inside the pane's bottom-left corner. |

Run only one at a time; both replace Alt+Tab. The other `.ahk` files are parts the two scripts include, not meant to be run on their own.

## Settings

The block at the top of each script holds the built-in defaults; `%APPDATA%\MeowTab\settings.ini` overrides them. The settings panel writes it, and you can add lines by hand under `[settings]` (as `NAME=value`) for the keys marked *ini*. Every value read from `settings.ini` is checked: an invalid one falls back to its default, an out-of-range one is clamped, and a tray notification says which. A `settings.ini` from an older checkout (where it sat beside the script) is no longer read: move it to `%APPDATA%\MeowTab` by hand, and any `custom_*.png` from `images\` into its `images\` folder.

| Setting | Default | Applies to | Set in | What it does |
| --- | --- | --- | --- | --- |
| `FONT_NAME` | Noto Sans TC (else Segoe UI) | both | panel | Title font (classic: list font). |
| `FONT_SIZE` | `10` / `16` | main / classic | panel | Text size in points (10-24). |
| `IMG_PREFIX` | `chill` | both | panel | Pictures are `<prefix>_few.png`, `_some.png`, `_many.png`. The panel uses `custom`. |
| `SOME_FROM` | `3` | both | panel | Fewest windows that count as "some". |
| `MANY_FROM` | `8` | both | panel | Fewest windows that count as "many" (2 ≤ `SOME_FROM` < `MANY_FROM` ≤ 30). |
| `PEEK_MIN` | `0.72` | main | panel | Share of the picture shown above the pane with 1 window. |
| `PEEK_MAX` | `0.95` | main | panel | Share shown at `MANY_FROM + 4` windows and beyond (0.30-1.00, above `PEEK_MIN`). |
| `IMG_SIZE` | `250` / `100` | main / classic | ini | Picture size in pixels. |
| `WM_PROCESS` | empty | both | ini | Exit when this process is gone, e.g. `glazewm.exe`. |
| `LIST_WIDTH` | `700` | classic | ini | List width in pixels. |
| `MAX_ROWS` | `15` | classic | ini | Longer lists scroll. |
| `PREVIEW_W` | `800` | classic | ini | Preview width in pixels; `0` turns it off. |
| `IMG_ROWS` | `12` | classic | ini | The list covers the picture only beyond this many windows. |

`meowtab.ahk` also has a **Native look** block of constants just below the settings (pane padding, tile sizes and gaps, the selection ring, the close button, light and dark colours), each line commented, for tinkering.

## Remove MeowTab

If you ticked **Desktop icon** in the tray menu, untick it (that removes the shortcut). Then exit MeowTab from the tray and delete the folder you unzipped it into (or run the uninstall command under [Install with WinGet or Scoop](#install-with-winget-or-scoop)), and any startup shortcut you added. Your settings and pictures stay in `%APPDATA%\MeowTab`, as described under [Settings](#settings) and [Use your own pictures](#use-your-own-pictures), so a later install picks them up. To delete them too:

```
Remove-Item "$env:APPDATA\MeowTab" -Recurse
```

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

It needs AutoHotkey v2 (found in its usual install folders, or pass `-Base <path to AutoHotkey64.exe>`). The compiler, Ahk2Exe, comes from `-Ahk2Exe <path>`, the `AHK2EXE` environment variable or AutoHotkey's `Compiler` folder; failing those, the latest [Ahk2Exe release](https://github.com/AutoHotkey/Ahk2Exe/releases) is downloaded into `build\` (nothing is installed). The result is `dist\meowtab\` and `dist\meowtab.zip`, which holds only the two exes, the `chill_*` pictures, this README and the license.

**Clean background** is C (`cutout.c`) compiled to machine code stored in `cutout-mcode.ahk`, so neither the scripts nor the exes need a compiler. `build-mcode.ps1` regenerates it from `cutout.c` with a pinned, hash-checked [Zig](https://ziglang.org); run it after editing `cutout.c`. CI checks the file is up to date.

[GitHub Actions](.github/workflows/build.yml) builds the zip from a version tag, with pinned, hash-checked copies of AutoHotkey and Ahk2Exe.

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

## Tests

From the repo root (close any running copy first; adjust the path if AutoHotkey is installed elsewhere):

```
& "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut tests\meowtab.test.ahk | more
```

`tests\meowtab.test.ahk` opens a few temporary windows, drives the real switching code and prints `PASS`/`FAIL` per check, ending with `ALL PASSED`. It covers recency order (including after a re-tile), Alt+Tab, Alt+Tab+Tab, the live previews being registered and released, the arrow keys, the grid for many windows with its scrolling and scroll bar, and switching and closing with the mouse. It needs an unlocked, connected desktop.

`tests\cutout.test.ahk` checks **Clean background** against the expected results in `tests/cutout/`; CI runs it too.

`tools\readme-shots.ahk` takes the screenshots above from the real pane. It lists only its own demo windows over a stand-in wallpaper, so none of your own windows can end up in an image.

## Known issues

- Preview corners are square at the bottom (Windows' own are rounded).
- Ctrl+Alt+Tab (the switcher that stays open without holding Alt) isn't supported yet.
- Only the focused monitor's windows are listed, so on a monitor without windows Alt+Tab does nothing.

## Roadmap

A softer "Velvet" look, a new demo GIF and more are planned: see [ROADMAP.md](ROADMAP.md).

## License

MIT. See [LICENSE](LICENSE).

The default cat pictures (and the icon made from one) are AI-generated placeholders, included under the same license.
