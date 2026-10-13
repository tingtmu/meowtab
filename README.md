# MeowTab

**Alt+Tab the Windows 11 way, with a cat peeking over the edge.**

English | [繁體中文](README.zh-TW.md)

MeowTab replaces Alt+Tab with live window previews on a frosted acrylic pane that follows light and dark mode. Its default look, Velvet, is native at a glance and softer and warmer up close; the Windows 11 look copies Windows' own. A picture peeks over the top-left edge and changes with how many windows you have open. A sleepy cat when you have a few, a cat sprawled belly up when it's getting crowded. Swap in your own pictures and let your pet, your mascot or your boss judge your window count.

![MeowTab](docs/meowtab.png)
*Velvet (default)*

![MeowTab in the Windows 11 look](docs/meowtab-windows11.png)
*Windows 11*

![MeowTab with an animated cat peeking over the pane](docs/meowtab-gif.gif)

Any mood can have a GIF picked for it, and it plays in the peek.
MeowTab ships one, `chill.gif`, in its `images` folder (the PNG cats stay the default).

> **Status: early preview.** MeowTab grew out of [peek-alttab](https://github.com/tingtmu/peek-alttab) and is being polished into a full app; see the [roadmap](ROADMAP.md).

## Features

- **Two looks.** Live thumbnails with app icons and titles on acrylic. **Velvet** adds warm glass, rounder tiles, a soft selection outline and faded rows at the pane's edge; **Windows 11** uses Windows' accent-coloured ring. Both follow your Windows mode and accent colour.
- **The peek.** A mood picture slides up over the pane's top-left edge and rises higher as you open more windows:

  | Mood | Windows (default) | Default picture |
  | --- | --- | --- |
  | few | 1-2 | a cat curled up asleep |
  | some | 3-7 | a cat lounging |
  | many | 8+ | a cat sprawled belly up, too tired to care... |

- **Your own pictures.** Pick or drop them in the settings panel; **Clean background** cuts out a plain light background and crops to a square.
- **Keyboard and mouse.** Move through the grid, close windows or click a tile to switch to it.
- **Every monitor.** Windows are listed most recently used first; the pane opens on the active window's monitor (else the cursor's). Only the current virtual desktop and visible window-manager workspaces are listed. A re-tile doesn't shuffle the list. Tick **Only this monitor's windows** to limit it to the pane's monitor.
- **Readable titles.** Noto Sans TC when installed, otherwise Segoe UI; pick any installed font in the panel.

![MeowTab in dark mode](docs/meowtab-dark.png)
*Velvet (default)*

![MeowTab in the Windows 11 look, in dark mode](docs/meowtab-windows11-dark.png)
*Windows 11*

## Quick start

Windows 11, 64-bit. The acrylic pane needs 22H2 or later; older builds get a solid pane. The released exes need no AutoHotkey. Exit MeowTab from the tray before updating or removing it; settings and pictures stay in `%APPDATA%\MeowTab` unless you [remove them too](#remove-meowtab).

**PowerShell** (5.1 or 7): install the latest release and start it, without administrator rights or a package manager. The readable [helper source](https://github.com/tingtmu/meowtab/blob/main/tools/install.ps1) downloads the ZIP and checksum from the same release and verifies it before installing.

```powershell
& ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/tingtmu/meowtab/main/tools/install.ps1').Content))
```

It installs to `%LOCALAPPDATA%\Programs\MeowTab`. Update by running the same command again; remove by deleting that folder. Launch later with `& "$env:LOCALAPPDATA\Programs\MeowTab\meowtab.exe"`. The installed tag is in `.zip-install.json` in that folder; the exe's file version also reports it.

AI agents: read the concise [installation and update guide](https://raw.githubusercontent.com/tingtmu/meowtab/main/llms.txt).

**WinGet** (built into Windows 11; waiting for Microsoft's approval, so until then use Scoop or the ZIP):

```
winget install tingtmu.MeowTab
```

Open a new terminal and run `meowtab` (or `meowtab-classic`). WinGet adds no Start menu entry. Update with `winget upgrade tingtmu.MeowTab`; remove with `winget uninstall tingtmu.MeowTab`.

**Scoop** (buckets need git: `scoop install git`):

```
scoop bucket add meowtab https://github.com/tingtmu/meowtab
scoop install meowtab/meowtab
```

It starts after installation and each update; later use **Scoop Apps > MeowTab** (or **MeowTab Classic**) in the Start menu. Update with `scoop update`, then `scoop update meowtab`; remove with `scoop uninstall meowtab`.

**Portable ZIP:** download `meowtab.zip` from the [latest release](https://github.com/tingtmu/meowtab/releases/latest) or [direct link](https://github.com/tingtmu/meowtab/releases/latest/download/meowtab.zip), [check the download](#check-the-download), unzip it into your own folder and keep that folder together. Double-click `meowtab.exe`. Update by downloading and unzipping the latest release again; remove by deleting the app folder.

**First run:** the first time it starts, MeowTab asks whether to put an icon on your desktop (it opens the settings panel); either answer is remembered. Then hold **Alt** and press **Tab**. Double-click the sleepy-cat tray icon to open the panel; right-click to reload, exit or tick **Desktop icon**.

`meowtab-classic.exe` is the original layout: a list of titles with one large preview beside it, and the picture inside the pane's bottom-left corner. Run only one of the two at a time. Running from source is in [CONTRIBUTING.md](CONTRIBUTING.md).

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

With **Alt** held, click a tile to switch, or hover it and click its **×** to close it. Scroll with the mouse wheel or drag the scroll bar on the pane's right. The first Tab picks the window you were in before; apps asking "save changes?" stay listed until you answer.

**Ctrl+Alt+Tab** opens a switcher that stays open once you let go. The same keys and mouse work; **Enter** switches and **Esc** cancels. Clicking outside closes it and passes the click through, so clicking a window switches to it. Other keys do nothing while it's open.

Both shortcuts can be changed in the [settings panel](#settings-panel), for example to Win+Q. Classic keeps Alt+Tab and has no stay-open switcher, and its panel has no **Look**, **Background** or **Shortcuts** section.

## Settings panel

Double-click the tray icon, or right-click and choose **Settings…**. The desktop icon opens it too.

![Settings panel](docs/settings.png)

- **Mood images.** Click a mood card to choose a PNG, JPG, BMP or GIF, or drop one onto it. The picker opens in the shipped `images` folder (`chill.gif` and `chill_*.png`). GIFs play on cards and in the peek; the steppers set where "some" and "many" start.
- **Clean background.** **✧ Clean** on your picture's card removes a plain light background and crops to a square. GIFs are cleaned frame by frame and cropped to one square, with hard edges because GIF has no soft transparency.
- **Peek height.** Set how much shows with one window and at "many"; two scenes preview your pictures.
- **Look.** Click **Velvet** or **Windows 11**, or press Space on its card. A check marks your choice, **in use** the current look; the scenes and title sample preview it, and **Save** applies it.
- **Background.** Click the card or drop a picture onto it; **Remove** returns to plain glass and **Save** applies it. Builds before 22H2 have no Background section.
- **Title font.** Any installed font, at 10 to 24 pt.
- **Windows.** Tick **Only this monitor's windows** to list only the windows on the monitor the pane opens on; unticked (the default), every monitor's windows are listed.
- **Shortcuts.** Click **Switch windows** or **Stay open**, then press the combination; **Esc** keeps the old one. Switching takes Alt, Ctrl or Win with one key; Shift goes back. Unusable or already-used combinations are refused with a reason. **Defaults** restores Alt+Tab and Ctrl+Alt+Tab.

Velvet's motion and GIFs in both looks and on the panel follow Windows' **Animation effects** setting (Settings > Accessibility > Visual effects). With it off, nothing moves and GIFs show their first frame. On small screens, scroll the panel with the wheel or its right-hand scroll bar; the buttons stay at the bottom and fields you Tab to scroll into view.

**Save** (or Enter) writes `%APPDATA%\MeowTab\settings.ini` and reloads it. **Cancel** (or Esc) changes nothing. **Reset to defaults** removes the panel's settings, keeps pictures and lines you added yourself (such as `WM_PROCESS`), and turns off the background picture.

### Your own pictures

Your pictures are copied to `%APPDATA%\MeowTab\images\` as `custom_few.png`, `custom_some.png` and `custom_many.png`; shipped cats are never overwritten. Photos are turned upright and large pictures scaled down to 1024 px. GIFs become `custom_<mood>.gif`, scaled down to 512 px if larger; a GIF with more than 100 frames is refused. The background picture becomes `pane.png`, upright and at most 2560 px, softly blended over the glass; a GIF uses its first frame.

By hand: put `<prefix>_few.png`, `<prefix>_some.png` and `<prefix>_many.png` (or `.gif`) in `%APPDATA%\MeowTab\images\`, set `IMG_PREFIX=<prefix>` in `settings.ini`, then **Reload Script** from the tray. A GIF wins over a PNG of the same name and plays at most its first 100 frames.

Tips: a square PNG with a transparent background works best; any resolution is fine and non-square pictures keep their shape. Transparent padding doesn't affect peek height. A missing file means no picture for that mood.

## Settings reference

The panel writes `%APPDATA%\MeowTab\settings.ini`, overriding built-in defaults. Add keys marked *ini* under `[settings]` as `NAME=value`. Invalid values fall back to defaults, out-of-range values are clamped, and a tray notification says which. Older checkouts' settings beside the script are no longer read: move them to `%APPDATA%\MeowTab`, and `custom_*.png` to its `images\` folder.

<details><summary>settings.ini keys</summary>

| Setting | Default | Applies to | Set in | What it does |
| --- | --- | --- | --- | --- |
| `FONT_NAME` | Noto Sans TC (else Segoe UI) | both | panel | Title font (classic: list font). |
| `FONT_SIZE` | `10` / `16` | main / classic | panel | Text size in points (10-24). |
| `IMG_PREFIX` | `chill` | both | panel | Pictures are `<prefix>_few.png`, `_some.png`, `_many.png`, or `.gif` for any of them. The panel uses `custom`. |
| `SOME_FROM` | `3` | both | panel | Fewest windows that count as "some". |
| `MANY_FROM` | `8` | both | panel | Fewest windows that count as "many" (2 ≤ `SOME_FROM` < `MANY_FROM` ≤ 30). |
| `PEEK_MIN` | `0.80` | main | panel | Share of the picture shown above the pane with 1 window. |
| `PEEK_MAX` | `0.95` | main | panel | Share shown at `MANY_FROM + 4` windows and beyond (0.30-1.00, above `PEEK_MIN`). |
| `SWITCH_KEYS` | `Alt+Tab` | main | panel | The switcher's shortcut: Alt, Ctrl or Win held with one key; with Shift it goes back. |
| `STAY_KEYS` | `Ctrl+Alt+Tab` | main | panel | Opens the switcher that stays open once you let go. |
| `PANE_LOOK` | `velvet` | main | panel | The switcher's look: `velvet` or `windows11`. |
| `MONITORS` | `all` | both | panel | Which monitors' windows are listed: `all`, or `current` for only the monitor the pane opens on (any letter case; the panel's **Only this monitor's windows**). |
| `PANE_PICTURE` | empty | main | panel | The pane's background picture: its file name in `%APPDATA%\MeowTab\images` (the panel sets `pane.png`). Empty means none, plain glass. A missing file falls back to none, with a notification. |
| `IMG_SIZE` | `250` / `100` | main / classic | ini | Picture size in pixels. Each GIF frame is kept decoded, so long GIFs on every mood take about 75 MB at the default 250 and about 430 MB at the maximum 600 (three 100-frame GIFs). |
| `WM_PROCESS` | empty | both | ini | Exit when this process is gone, e.g. `glazewm.exe`. |
| `LIST_WIDTH` | `700` | classic | ini | List width in pixels. |
| `MAX_ROWS` | `15` | classic | ini | Longer lists scroll. |
| `PREVIEW_W` | `800` | classic | ini | Preview width in pixels; `0` turns it off. |
| `IMG_ROWS` | `12` | classic | ini | The list covers the picture only beyond this many windows. |

</details>

## Check the download

Each release has `SHA256SUMS.txt`; its notes repeat the ZIP and both exes' SHA-256 hashes with [VirusTotal](https://www.virustotal.com) links. Put `meowtab.zip` and `SHA256SUMS.txt` in one folder and run this in PowerShell there (`True` means they match):

```
(Get-FileHash .\meowtab.zip).Hash -eq (Select-String -Path .\SHA256SUMS.txt -Pattern ' meowtab\.zip$').Line.Split(' ')[0]
```

The hashes come from the [GitHub Actions build](.github/workflows/build.yml) of tagged source. A match means it is the file that was built and scanned; a mismatch means a damaged or altered download, so don't run it. VirusTotal scans are heuristic: a clean report is no guarantee, and some engines flag AutoHotkey exes even when nothing is wrong. The source is here to read. The exes aren't code-signed; if SmartScreen says "Windows protected your PC", choose **More info**, then **Run anyway**, once you've checked the hash.

## Remove MeowTab

If you ticked **Desktop icon** in the tray menu, untick it (that removes the shortcut). Exit from the tray, then delete the app folder or use your uninstall command in [Quick start](#quick-start). Remove any startup shortcut you added. Settings and pictures remain in `%APPDATA%\MeowTab` for a later install; to delete them too:

```
Remove-Item "$env:APPDATA\MeowTab" -Recurse
```

## Good to know

- **Administrator windows.** Windows blocks a normal app's hotkeys while an elevated window is focused, so you get built-in Alt+Tab. Run MeowTab as administrator to cover those windows.
- **No network.** MeowTab never connects to the network; settings and pictures stay on your PC in `%APPDATA%\MeowTab`.
- **Run at login.** Press `Win+R`, type `shell:startup` and put a shortcut to `meowtab.exe` (or `meowtab.ahk`) in that folder.
- **Known issues.** Preview corners are square at the bottom. With **Only this monitor's windows** ticked (`MONITORS=current`), Alt+Tab does nothing on a monitor without windows.

**GlazeWM (optional):** add MeowTab to `startup_commands` in its `config.yaml`:

```yaml
general:
  startup_commands: ['shell-exec C:\path\to\meowtab\meowtab.ahk']
```

To exit when GlazeWM quits, add this to `%APPDATA%\MeowTab\settings.ini` (the panel keeps it when saving):

```ini
[settings]
WM_PROCESS=glazewm.exe
```

## More

[Roadmap](ROADMAP.md) · [Issues](https://github.com/tingtmu/meowtab/issues) · [Contributing](CONTRIBUTING.md) · MIT licence: [LICENSE](LICENSE).

The default cat pictures and the icon made from one are AI-generated placeholders, included under the same licence.
