# MeowTab roadmap

Where MeowTab goes after the 0.1 preview. Each item says what to build, why, and how we'll know it's done, so it can be picked up on its own (by a person or a coding agent) without the history of earlier sessions.

**Principles**, in order, when they conflict:

1. **Fast and light first.** Opening the switcher and moving the selection must feel instant. If a visual effect costs noticeable latency or CPU, the effect gives way.
2. **Native at a glance, more refined up close.** Anyone should recognise Windows 11's Alt+Tab. The details (materials, edges, motion) should feel softer and more carefully made than the original.
3. **The peek is the soul.** The mood picture on the pane's edge must always be fully visible, never cramped or cut by the screen edge.
4. **Privacy.** Screenshots and recordings for docs only ever show demo windows over a stand-in wallpaper, never the user's real windows (see `readme-shots` in [How to capture](#how-to-capture-screenshots-and-the-gif)).

Code map: `meowtab.ahk` holds settings, hotkeys and switching; `alttab-native.ahk` the pane (theme, acrylic, layout, drawing, thumbnails, mouse); `alttab-velvet.ahk` the Velvet look's drawing; `alttab-icons.ahk` the app icons; `alttab-peek.ahk` the peeking picture; `settings-*.ahk` the settings panel; `tests\meowtab.test.ahk` the integration test (`ALL PASSED` required before merging).

---

## 1. Many windows: fixed-size tiles and a smooth scroll bar

**Done**: from 9 windows the switcher shows a fixed 3-column grid with smooth scrolling and a Windows 11-style scroll bar. The layout and scrolling rules live in `openspec/specs/switcher-grid/spec.md`.

**Discarded:** ~~up to 4 columns on a wide work area~~. Four tiles fit at full size on every ordinary 1080p screen, so this would almost always replace the 3 columns Windows uses.

## 2. Custom shortcut bindings

**Done**: the switcher's shortcut (Alt+Tab by default; with Shift it goes back) and that of the new switcher that stays open (Ctrl+Alt+Tab, as in Windows) can be changed in the settings panel's **SHORTCUTS** section, which captures the keys pressed. Both are saved in `settings.ini` in readable form, and a value that can't work falls back to its default with the usual notification.

## 3. The "Velvet" look, and whether to offer a choice

**Done**: the settings panel's new **LOOK** section picks between two looks on two picture cards, both following Windows' light and dark mode: **Velvet** (the default) and **Windows 11** (the faithful copy of Windows' own switcher). **Save** applies the pick. Velvet is softer and warmer up close: clear, faintly warm glass (a faint tint over the acrylic), rounder tiles with matted thumbnails, a lifted selection with a soft accent outline instead of the ring, and rows cut by the pane's edge that fade out. Its motion (the pane easing in, the selection lighting up in place, the picture settling with a small bounce) follows Windows' "Animation effects" setting: with it off, nothing moves. The settings panel no longer shrinks to fit: it always shows at full size, and its sections scroll under a bar fixed at the bottom with the hint line and the buttons.

**Later**: the classic list switcher (`meowtab-classic.ahk`) could be folded into the LOOK section as a third look, "List". That would leave one exe and one tray icon instead of two separate apps, and simplify releases. The catch: two options in one control isn't overwhelming, but three or more would be.

## 4. Performance and resources

The 0.1 preview already feels smooth, so this is a guardrail, not a project. Budgets to keep, on a 1080p / 150 % machine:

| What | Budget | Measured |
| --- | --- | --- |
| Alt+Tab to pane visible | ≤ 30 ms | 0.1: under 16 ms per open. 30 windows: 15 ms median, 28 ms max. Local screen: 15–21 ms median in either look; now and then one over 30 ms, in both looks and before Velvet's last change too |
| Moving the selection (full redraw) | ≤ 4 ms | 0.1: about 1.6 ms for 20 tiles at 100 %. 30 windows at 150 %: 4.7 ms median (6.9 ms before the grid). Local screen, 30 windows: 4.6 ms in the Windows 11 look, 6.5 ms in Velvet |
| A scroll frame (keys, wheel, drag) | ≤ 8 ms | 30 windows: about 5 ms median; up to 4 % of frames over 8 ms, the worst 15-29 ms. Local screen: 5.5–5.8 ms median in the Windows 11 look, 6.3–7.2 ms in Velvet |
| While closed | no timers, 0 % CPU | only the window-activation hook |
| 200 opens | no growth in GDI / USER handles or memory | flat (also in Velvet with its motion, at the local screen) |

When adding Velvet effects, cache what doesn't change per frame (tint, header backgrounds) instead of re-rendering it. Measure with `QueryPerformanceCounter` before and after. If an effect breaks a budget, drop or simplify it.

**Velvet's extra cost, accepted for now (2026-10-10).**
- **Measured** over Remote Desktop with 30 windows at 150 %, against the Windows 11 look:
  - about 3 ms more per open (15.8 ms against 12.6);
  - 1.1–1.5 ms more per frame (a Tab step is 6.2 ms against 4.8).
- **At the local screen (2026-10-12)**, with the selection lighting up in place (it used to glide), a Tab step is 6.5 ms against 4.6, about 1.9 ms more. The light-up costs about 0.5 ms of that, and the author accepted it.
- **Budgets:** Velvet keeps the open and scroll-frame budgets. At this load both looks already miss the step budget. Its base layer (tint, highlight) is already kept between opens.
- **Next, when this item is picked up:**
  - while the selection lights up, move only its tile's thumbnail, not every one;
  - cache each tile's unchanging pixels (frame, frost, icon, title), so a frame redraws only the hover and the selection;
  - cache the cut-row fade's per-frame brushes;
  - compare the looks with `tools\checks\run.ps1 timing -Look velvet` and `-Look windows11`.

**How to measure**, so new numbers compare with these: time the code that makes each frame with `QueryPerformanceCounter`, on 30 demo windows. The open is `CollectWindows` plus `ShowPane`, not counting the wait for the next screen refresh. A Tab step is one `Step(1)`, every 33 ms for 2 s. A scroll frame is one `ScrollTick`: while Tab is held, over 24 wheel notches, and during a real drag of the scroll bar. Report the median, the maximum and how many frames go over 8 ms. Also time a fixed 5 ms of plain computation, which shows how often the machine itself pauses the process. `tools\checks\run.ps1 timing` does this, and `tools\checks\control.ahk` times the plain computation. `tools\checks\run.ps1 stay` times the stay-open pane the same way: its opens (`Stay()`), `Finish` and its steps.

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

## 9. Animated GIF pictures

**Done**: a GIF picked for or dropped on a mood card is kept as a GIF and keeps moving in the peek, in both looks, and on the settings panel's cards and scenes. It shows still, as its first frame, with Windows' Animation effects off, and in `meowtab-classic`. **Clean background** works on a GIF frame by frame. `images/chill.gif` ships beside the three PNG cats, which stay the default. The demo GIF is in the README, under the screenshots. `PEEK_MIN`'s default went from 0.72 to 0.80, so the cat's lower part shows with 1 window.

## Also on the list

- **An empty monitor:** Alt+Tab on a monitor with no windows currently does nothing. Consider falling back to all monitors.

## How to capture screenshots and the GIF

The capture script used for the 0.1 README lists only its own demo windows. It puts a stand-in wallpaper over the monitor where the pane opens, captures the pane with `BitBlt` (`CAPTUREBLT`, which includes the acrylic and the DWM thumbnails), and crops to the pane and the picture. It needs a connected desktop. A copy lives in `tools/readme-shots.ahk`; run it from the repo root with `AutoHotkey64.exe /ErrorStdOut tools\readme-shots.ahk light docs\meowtab.png` (or `dark`). A window count after the file lists more demo windows (`light out.png 12` reaches `PEEK_MAX`), and a look after the count picks the pane's look (`light docs\meowtab-windows11.png 5 windows11`; the default is Velvet). A tint alpha after the look (0–255) takes the shot with Velvet's tint at that strength, to compare strengths (`light out.png 5 velvet 36`). `settings <out.png>` captures the settings panel alone, at its whole height, with default settings; `docs/settings.png` is framed on a 150 % display.
