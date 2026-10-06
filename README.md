# peek-alttab

A frosted-glass Alt+Tab replacement for Windows, written in AutoHotkey v2. It shows a live preview of the selected window, and a little mood image peeks over the edge of the pane, changing with how many windows you have open.

<!-- TODO: demo GIF -->
<!-- ![demo](docs/demo.gif) -->

## Features

- Frosted-glass pane with a live preview (DWM thumbnail) of the highlighted window.
- A "mood image" that follows your window count: **few** (1-2) says "cozy ♡", **some** (3-7) says "nice ✌", **many** (8+) says "too many…".
- Lists only the windows on the focused monitor, most recently used first. Windows cloaks windows on other virtual desktops, and tiling window managers (such as GlazeWM) cloak hidden workspaces, so in practice this means the current desktop or workspace.
- Works with or without a tiling window manager. Recency is tracked from foreground changes rather than Z-order, so a re-tile does not shuffle the list.
- Close the selected window with Alt+Delete and the list stays open.
- Soft selection pill that glides between rows, a gentle fade-in on open, and a faint glow around the preview tinted from the selected app's icon colour.
- Bring your own images: three PNGs and a one-line setting.

## Two styles

Run **only one** of these at a time. Both replace Alt+Tab.

| Script | Look |
| --- | --- |
| `peek-alttab.ahk` (main) | Glass look. The image peeks over the pane's top-left edge from behind, slides up when the pane opens, and glides when the window count changes. |
| `elegant-alttab.ahk` | Simpler pane. The image sits inside the pane's bottom-left corner. |

`alttab-glass.ahk` is a helper that `peek-alttab.ahk` includes. It is not meant to be run directly.

## Requirements

- Windows 11.
- [AutoHotkey](https://www.autohotkey.com/) v2.0 or newer.
- Optional, only for `cutout.py`: Python with `Pillow`, `numpy` and `scipy`.

## Install / quick start

1. Install AutoHotkey v2.
2. Download or clone this repo:
   ```
   git clone https://github.com/tingtmu/peek-alttab.git
   ```
3. Double-click `peek-alttab.ahk`. That's it: hold Alt and press Tab.

Right-click the tray icon to reload or exit the script. Settings are edited at the top of the script, followed by **Reload Script** from the tray menu.

### Run at login

Press `Win+R`, type `shell:startup`, and put a shortcut to `peek-alttab.ahk` in the folder that opens.

### With GlazeWM (optional)

Add the script to `startup_commands` in GlazeWM's `config.yaml`:

```yaml
general:
  startup_commands: ['shell-exec C:\path\to\peek-alttab\peek-alttab.ahk']
```

Then set `WM_PROCESS := "glazewm.exe"` at the top of the script, so it exits when GlazeWM quits.

### Good to know

- Windows doesn't let a normal script's hotkeys reach an elevated (administrator) window, so while one is focused you get the native Alt+Tab. To cover those windows too, run the script as administrator.

## Usage

Hold **Alt**, then:

| Keys | Action |
| --- | --- |
| `Tab` | Next window |
| `Shift+Tab` | Previous window |
| `Down` / `Right` | Next window |
| `Up` / `Left` | Previous window |
| Release `Alt` | Switch to the highlighted window |
| `Esc` | Cancel without switching |
| `Delete` | Close the highlighted window and keep the list open |

The first Tab picks the previous window (the one you were in last). Apps that show a "save changes?" prompt on close stay in the list until the prompt is answered.

## Use your own images

The default images (sleepy orange cats in `images/chill_few.png`, `chill_some.png` and `chill_many.png`) are placeholders. Swap in your own:

1. Put three PNGs in `images/`, named `<prefix>_few.png`, `<prefix>_some.png` and `<prefix>_many.png`.
2. Set `IMG_PREFIX := "<prefix>"` at the top of the script.
3. Right-click the tray icon and choose **Reload Script**.

Tips:

- A **square PNG with a transparent background** works best. Any resolution is fine: images are scaled once at startup (bicubic) to `IMG_SIZE`. Non-square images are stretched to a square, so crop them first.
- A missing file just means no image for that mood.
- In `peek-alttab.ahk`, `IMG_PEEK` controls how much of the image shows above the pane (transparent padding is ignored). If your art shows too much or too little, tune it, and keep the values within 0.72 to 0.95.

### Cleaning up images with cutout.py

If your art is a sticker-style drawing with a dark outline on a plain light background, `cutout.py` can make it transparent and crop it to a tight square for you:

```
pip install pillow numpy scipy
python cutout.py images/dog_*.png
```

What it does:

- Removes the plain light background, keeping the subject (a white subject on a white background survives, as long as the outline is closed).
- Crops to a tight square with a little padding.
- Keeps your original next to the result as `<name>.png.bak-<timestamp>`.
- Images that are already transparent only get the crop, so running it twice is harmless.

Flags:

- `--preview` writes `<name>.preview.png` on a magenta background and changes nothing else, so you can check the result first.
- `--no-seal` turns off the "virtual bottom seal" that closes outlines left open at the bottom of the subject.

Limits: the background must be a near-uniform light colour, and the art needs a dark outline. Files that don't fit are skipped with a reason. JPG and BMP inputs are written out as a sibling `.png`, since those formats can't hold transparency.

### Share your image sets

Pull requests adding image sets to `images/` are welcome. Please only submit art you made yourself or art whose license allows redistribution.

## Settings

Edit the block at the top of the script, then **Reload Script** from the tray menu.

| Setting | Default | Applies to | What it does |
| --- | --- | --- | --- |
| `FONT_NAME` | `"Segoe UI"` | both | List font. |
| `FONT_SIZE` | `16` | both | Text size in points. |
| `LIST_WIDTH` | `700` | both | List width in pixels. |
| `MAX_ROWS` | `15` | both | Longer lists scroll. |
| `PREVIEW_W` | `800` | both | Live preview width in pixels, to the right of the list. `0` turns the preview off. Capped so it fits on screen. |
| `SEPARATOR` | `"   —   "` | both | Text between a window's title and its process name. |
| `IMG_DIR` | `"images"` | both | Folder of the mood images, relative to the script. |
| `IMG_PREFIX` | `"chill"` | both | Images are `<prefix>_few.png`, `<prefix>_some.png`, `<prefix>_many.png`. |
| `WM_PROCESS` | `""` | both | Optional. The script exits when this process is no longer running, e.g. `"glazewm.exe"`. Empty means never. |
| `IMG_SIZE` | `250` | peek | Image size in pixels. |
| `IMG_PEEK` | `[0.72 … 0.95]` | peek | Share of the image's art shown above the pane, by window count (1 window, 2 windows, ...; the last value is used for any larger count). Keep values within 0.72-0.95. |
| `IMG_SIZE` | `100` | elegant | Image size in pixels. |
| `IMG_ROWS` | `12` | elegant | The pane is tall enough that the list only covers the image beyond this many windows. |

`peek-alttab.ahk` also has a **"Glass look"** block of constants just below the settings (colours, light direction, shadow, grain, animation timings, selection pill, accent glow). It is there for tweaking; each line is commented.

## Tests

`tests/peek-alttab.test.ahk` is an integration test that includes `peek-alttab.ahk`. It opens a few temporary windows on your current desktop, then checks the real switching logic. Run it from the repo root (close any running copy of the script first):

```
& "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut tests\peek-alttab.test.ahk | more
```

It prints `PASS`/`FAIL` per check and ends with `ALL PASSED` (exit code 0) or the number of failures (exit code 1). It checks that:

- the window order follows recency (most recently used first),
- the order survives a Z-order reshuffle without any window being activated,
- Alt+Tab goes to the previous window, and again returns to the original,
- Alt+Tab+Tab lands on the third window,
- the live preview is registered while cycling and released afterwards,
- a window that isn't in the list (a tool window) is handled, and the first Tab picks the first entry,
- Alt+Down moves the selection like Tab.

The last checks can fail on multi-monitor setups when the test's tool window opens on another monitor. That is a test environment quirk, not a regression.

## License

MIT. See [LICENSE](LICENSE).

The default cat images are AI-generated placeholders, included in this repo under the same license.
