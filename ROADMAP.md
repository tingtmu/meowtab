# MeowTab roadmap

Where MeowTab goes after the 0.1 preview. Each item says what to build, why, and how we'll know it's done, so it can be picked up on its own (by a person or a coding agent) without the history of earlier sessions.

**Principles**, in order, when they conflict:

1. **Fast and light first.** Opening the switcher and moving the selection must feel instant. If a visual effect costs noticeable latency or CPU, the effect gives way.
2. **Native at a glance, more refined up close.** Anyone should recognise Windows 11's Alt+Tab. The details (materials, edges, motion) should feel softer and more carefully made than the original.
3. **The peek is the soul.** The mood picture on the pane's edge must always be fully visible, never cramped or cut by the screen edge.
4. **Privacy.** Screenshots and recordings for docs only ever show demo windows over a stand-in wallpaper, never the user's real windows (see `readme-shots` in [How to capture](#how-to-capture-screenshots-and-the-gif)).

Code map: `meowtab.ahk` holds settings, hotkeys and switching; `alttab-native.ahk` the pane (theme, acrylic, layout, drawing, thumbnails, mouse); `alttab-icons.ahk` the app icons; `alttab-peek.ahk` the peeking picture; `settings-*.ahk` the settings panel; `tests\meowtab.test.ahk` the integration test (`ALL PASSED` required before merging).

---

## 1. Many windows: fixed-size tiles and a smooth scroll bar

**Done**: from 9 windows the switcher shows a fixed 3-column grid with smooth scrolling and a Windows 11-style scroll bar. The layout and scrolling rules live in `openspec/specs/switcher-grid/spec.md`.

**Discarded:** ~~up to 4 columns on a wide work area~~. Four tiles fit at full size on every ordinary 1080p screen, so this would almost always replace the 3 columns Windows uses.

## 2. Custom shortcut bindings

**Today:** opening and cycling the switcher are tied to Alt+Tab and Alt+Shift+Tab; releasing Alt switches to the selected window. There is no way to choose another combination from settings, which makes conflicts with a window manager or another app harder to work around.

**Plan:**

- Add a **SHORTCUTS** section to the settings panel with key capture for forward and backward cycling, showing the current combinations in readable form. Keep Alt+Tab and Alt+Shift+Tab as the defaults, with one reset action.
- **Keep the hold-and-release behaviour.** Both bindings share a hold modifier: hold it to keep the pane open, press the chosen keys to cycle, release it to switch. Arrows and Esc keep working inside the pane. The later Ctrl+Alt+Tab mode can have its own binding once it exists.
- **Validate before saving.** Reject duplicates and unsupported combinations, and check that the new bindings can be registered. If registration fails, keep the working bindings and explain the problem. Invalid values in `settings.ini` fall back to the defaults with a notification, as other settings do.
- Save the bindings in `settings.ini` and apply them through the settings panel's existing reload flow. Keep ordinary typing available while the pane is closed, and suspend switching shortcuts while the user captures a new combination.

**Done when:** the defaults behave as today; a custom forward/backward pair survives a restart and reset restores the defaults; invalid bindings leave a working switcher; and the integration test covers cycling, release-to-switch and cancellation with custom bindings within item 4's performance budgets.

## 3. The "Velvet" look, and whether to offer a choice

### 3.1 Velvet: native at a glance, Apple-like up close

The user's brief: *an ambient, elegant minimalism with a soft and warm feeling, subtle and non-glaring, creating a velvety, tactile, Apple-like aesthetic.* Directions to explore (prototype first, judge by eye on light and dark wallpapers):

- **Material:** keep the system acrylic, but lay a faint warm tint over it in our own surface (light: warm white about 10-18 %; dark: warm graphite) and an extremely fine grain (the old glass look had one) for a velvety, less plasticky feel.
- **Edges and depth:** larger, continuous-looking corners (pane about 16 px, tiles about 12-14 px), a soft inner highlight along the top edge, and a deeper but very diffuse shadow. Avoid any hard 1 px lines. The 0.1 border refinement is the first step.
- **Partial rows:** when the grid scrolls (9 or more windows), a soft fade at the pane's top and bottom edges hints there's more.
- **Selection:** replace the hard 4 px accent ring with something gentler, such as a slightly lifted tile (subtle glow or shadow, about a 2 % scale-up) plus a thin, softly tinted accent outline. It must stay obvious at a glance, also for colour-blind users (test with a greyscale screenshot).
- **Header strip:** blend it into the tile (a soft frosted gradient) instead of a solid white bar; titles in the medium weight of the title font.
- **Motion:** the pane fades and scales in (about 120 ms, spring-like ease), the selection glides between tiles (about 90 ms), and the cat gives a small settle bounce when it lands. Everything is skipped when Windows' "Animation effects" setting is off.
- **Close button:** round and muted, turning red only under the cursor.

Constraint: DWM thumbnails are always rectangular and drawn on top of our surface, so we can't round their corners. Frame them with a consistent inset "mat" instead.

### 3.2 Should users pick the look? Recommendation: yes, one small choice

- Add a **LOOK** section to the settings panel with two picture cards, like the mood cards: **Velvet** (the default once it's polished) and **Windows 11** (today's faithful look). Both follow Windows' light and dark mode automatically (already done for Windows 11), so there is no separate light/dark switch.
- Two visual options in one control isn't overwhelming; three or more, or separate colour knobs, would be.
- Later, consider folding the classic list switcher (`meowtab-classic.ahk`) into the same picker as a third look ("List"). That would leave one exe and one tray icon instead of two separate apps, and simplify releases.

**Done when** both looks pass the test suite, switching looks needs no restart (or re-opens the pane cleanly), and each look has light and dark README screenshots.

## 4. Performance and resources

The 0.1 preview already feels smooth, so this is a guardrail, not a project. Budgets to keep, on a 1080p / 150 % machine:

| What | Budget | Measured |
| --- | --- | --- |
| Alt+Tab to pane visible | ≤ 30 ms | 0.1: under 16 ms per open. 30 windows: 15 ms median, 28 ms max |
| Moving the selection (full redraw) | ≤ 4 ms | 0.1: about 1.6 ms for 20 tiles at 100 %. 30 windows at 150 %: 4.7 ms median (6.9 ms before the grid) |
| A scroll frame (keys, wheel, drag) | ≤ 8 ms | 30 windows: about 5 ms median; up to 4 % of frames over 8 ms, the worst 15-29 ms |
| While closed | no timers, 0 % CPU | only the window-activation hook |
| 200 opens | no growth in GDI / USER handles or memory | flat |

When adding Velvet effects, cache what doesn't change per frame (tint, grain, header backgrounds) instead of re-rendering it. Measure with `QueryPerformanceCounter` before and after. If an effect breaks a budget, drop or simplify it.

**How to measure**, so new numbers compare with these: time the code that makes each frame with `QueryPerformanceCounter`, on 30 demo windows. The open is `CollectWindows` plus `ShowPane`, not counting the wait for the next screen refresh. A Tab step is one `Step(1)`, every 33 ms for 2 s. A scroll frame is one `ScrollTick`: while Tab is held, over 24 wheel notches, and during a real drag of the scroll bar. Report the median, the maximum and how many frames go over 8 ms. Also time a fixed 5 ms of plain computation, which shows how often the machine itself pauses the process. `tools\checks\run.ps1 timing` does this, and `tools\checks\control.ahk` times the plain computation.

The 30-window numbers are from 2026-10-09, over Remote Desktop: 1920 × 1080 at 150 %, about 30 frames a second, Balanced power plan. There, the plain computation went over 8 ms in 28 % of runs, so MeowTab's rare slow frames were most likely the machine's pauses. Scrolling looked uneven over Remote Desktop, as expected at 30 frames a second: judge it on the local screen first. If it still hitches there, try timing frames to the screen's refresh (AutoHotkey's timer ticks every 15.6 ms, which drifts against 60 Hz) and redrawing less per frame (drawing is about 4.6 of the 5 ms).

## 5. Release checks and easier installation

**Today:** users run the source or build the exe themselves. CI can build a zip from a version tag, but there are no published scan reports or WinGet / Scoop packages to help people check a download and get started quickly.

**Plan**, in order:

- **First release:** tag `v0.1.0` so CI builds `meowtab.zip`, then publish it as a GitHub release and switch the README's quick start back to "download and run".
- **Public checks:** scan the compiled exes and final release zip with VirusTotal, and publish report links and SHA-256 hashes beside the download. The reports must refer to the exact shipped files; repeat the checks whenever a build changes. Investigate detections and document the findings. Describe the results as checks on those files, with their limitations, so users can judge the evidence.
- **Package installation:** once the release files and layout are stable, submit a WinGet manifest and a Scoop manifest using versioned GitHub release URLs and matching hashes. Install the built app with its pictures, preserve settings and custom pictures through upgrades, and document installation, updating and removal in the README.
- **Keep releases in step:** update the reports, hashes and both package manifests for each release, so the package managers deliver the same version as the direct download.

**Done when:**

- The release page links to scan results and hashes for its exact files, and the README makes them easy to find before downloading.
- Both WinGet and Scoop can install and launch MeowTab on a clean Windows machine without a separate AutoHotkey install.
- An upgrade keeps the user's settings and pictures, and removal works as documented.

## 6. A new demo GIF: "Your Alt+Tab cat monitors your work stress"

About 10 s, looping seamlessly:

| Time | Beat | On screen | Caption |
| --- | --- | --- | --- |
| 0-2 s | Calm | 2 windows; Alt+Tab; the cat gently peeks up (few) | cozy ♡ |
| 2-5 s | Work piles up | demo windows open one after another (browser-like, terminal, notes, photos); the grid fills; the cat rises (some) | nice ✌ |
| 5-8 s | Chaos | 10+ windows appear rapidly; fast Alt+Tab cycling; the cat stares, more concerned (many) | too many… then a tiny "bro." |
| 8-10 s | Punchline | hold on the cat judging the screen | Your workload is now being supervised. |
| loop | | cut straight back to the calm 2-window frame | |

Production notes:

- **Privacy:** only demo windows with neutral titles and fake contents, over a stand-in wallpaper covering the monitor the pane opens on, like the README screenshots. No real browser, terminal or files of the user's.
- **Driving it:** a script, not real keystrokes. Open and close demo windows on a timeline and call `Step()` / `Finish()` directly (synthetic Alt key events are unreliable over Remote Desktop with a tiling WM; see the test's notes).
- **Captions:** the native look has no caption, so add them in post with ffmpeg `drawtext` (rounded label, soft shadow, the same font as the titles). A small speech bubble next to the cat could become a product feature later; it isn't needed for the GIF.
- **Recording:** ffmpeg `gdigrab` of the region at 30 fps. Export about 960 px wide with `palettegen` / `paletteuse`, under about 5 MB for `docs/demo.gif`, plus an MP4.
- The "increasingly concerned" cat depends on item 7's new picture. More mood levels (e.g. a fourth one at 15+ windows) would be a separate feature.

## 7. New "many" picture

**Done** in `4289dff`: `images/chill_many.png` is the author's new art, framed like the rest of the set. The framing rules live in `openspec/specs/mood-pictures/spec.md`.

## 8. macOS support, after the Windows release is stable

**Today:** MeowTab uses AutoHotkey and Windows APIs for hotkeys, window previews and drawing. Supporting macOS needs a native implementation of those parts, while keeping the peeking pictures and mood behaviour.

**Plan:**

- **Start with an existing switcher.** Evaluate [AltTab for macOS](https://github.com/lwouis/alt-tab-macos) as a reference or a possible fork. Check how its window switching, previews and shortcuts could support MeowTab's pane and pictures; record the approach and review its licence requirements before reusing code.
- **A small first preview:** forward/backward window cycling, release-to-switch, cancellation, custom shortcuts, and the three mood pictures with support for the user's own images. Keep the picture fully visible and measure opening and selection latency on real Mac hardware.
- **Fit the platform:** follow macOS light and dark appearance, explain required permissions during setup, and check minimized windows, full-screen apps, Spaces and multiple displays. Document the supported macOS versions and hardware for the preview.

**Done when:** a downloadable Mac preview works on the documented hardware and macOS versions; switching, permissions and picture placement have been checked on a real Mac; and its setup instructions and demo captures are ready, following the same privacy rules as Windows.

## Also on the list

- **Ctrl+Alt+Tab:** a switcher that stays open without holding Alt (arrows and Enter, Esc to close), like Windows.
- **Hover:** show the hover state immediately when the pane opens under the cursor, not only after the mouse moves.
- **Minimized windows:** verify their thumbnails live; Windows keeps a last image, otherwise MeowTab shows the big app icon.
- **An empty monitor:** Alt+Tab on a monitor with no windows currently does nothing. Consider falling back to all monitors.
- **Settings panel fit:** it scales down to fit, with room kept for a tiling WM's bar sized to the author's GlazeWM setup. Derive that room from the real work area instead.

## How to capture screenshots and the GIF

The capture script used for the 0.1 README lists only its own demo windows. It puts a stand-in wallpaper over the monitor where the pane opens, captures the pane with `BitBlt` (`CAPTUREBLT`, which includes the acrylic and the DWM thumbnails), and crops to the pane and the picture. It needs a connected desktop. A copy lives in `tools/readme-shots.ahk`; run it from the repo root with `AutoHotkey64.exe /ErrorStdOut tools\readme-shots.ahk light docs\meowtab.png` (or `dark`). A window count after the file lists more demo windows (`light out.png 12` reaches `PEEK_MAX`). `settings <out.png>` captures the settings panel alone with default settings; `docs/settings.png` is framed on a 150 % display.
