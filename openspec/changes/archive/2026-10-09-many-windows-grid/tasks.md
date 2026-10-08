# Tasks

Groups 1-3 change the same files (`alttab-native.ahk`, `meowtab.ahk`, `tests\meowtab.test.ahk`), so they run in order, each by an Opus agent; 3.3 can go to Sonnet. While they run, a Sonnet agent prepares the scripts for 4.1 and 4.2 in the scratchpad and takes an 8-window baseline capture on today's code; it touches no repo files. Every group ends with `tests\meowtab.test.ahk` printing `ALL PASSED`.

## 1. The fixed grid

- [x] 1.1 In `GridLayout`, from `GRID_FROM` windows, lay out the grid as described in design.md ("Grid tiles", "Rows sized for the picture's highest peek"). Up to 8 windows stay as they are, and for now the grid still scrolls by whole rows. Add `GRID_FROM` and `GRID_COLS` to the Native look block, and the optional DPI scale. The test loads no pictures, so it passes in the picture's height itself. Verify with test checks that set `wins` directly (repeating A-D is fine), as the Alt+Down/Up check does:
  - on 1920×1032: 8 windows get the shaped layout. 9 make 3 rows of 3 in columns. 20 and 50 give tiles the same size as 9, and as tall as the 8-window tiles;
  - at scale 1.5 on 1920×1008: the pane is equally tall for 9, 12, 30 and 50 windows, and the pane plus the picture at its highest peek fit in the work area;
  - Down/Up: with 12 windows, 2 → 5 → 8 → 5; with 10 windows, 9 → 10, then it stays on 10.

## 2. Smooth scrolling

- [x] 2.1 Scroll by a pixel offset toward a goal (design.md: "One scroller", "Animation", "A close keeps the offset", "Closed means idle"). Rows partly in view are drawn, cut just inside the pane's edge. Add `SCROLL_MS`. Verify with test checks on 12-20 windows:
  - Tab from the second row into the third moves the goal by one row. There the selected tile is at least the padding inside the pane, and the fourth row's top is in view;
  - Tab from the last window selects the first, with goal 0;
  - an open with Shift+Tab starts at the bottom (offset = goal at once);
  - at the top, one wheel notch scrolls one row and the selection moves to the new top row. At the end, a notch changes nothing;
  - closing a window while scrolled keeps the offset;
  - `Finish` during a scroll leaves no scroll running.
- [x] 2.2 Thumbnails as described in design.md ("registered on first sight, cropped each frame, hidden instead of released"). Verify with test checks: at open, only tiles at least partly in view have a thumbnail; scrolling down and back registers no tile twice; and none are left after `Finish` (the existing check). The crop itself is checked on captures in 4.1.
- [x] 2.3 The mouse in content coordinates, with hover recomputed each frame. Update the test's `ClickTile` for the offset. Verify with test checks: a click on a tile in a scrolled grid switches to it, and a press and release over different tiles, with a scroll in between, do nothing.

## 3. Scroll bar and docs

- [x] 3.1 Draw the bar (spec: "A Windows 11-style scroll bar"; design.md: "Scroll bar"). Put its sizes in the Native look block and a `bar` colour in both palettes. Verify with test checks: with 12 windows the bar shows at open and is gone about 1.5 s later (stop `WatchAlt`, as the mouse checks do); with 8 windows it never shows.
- [x] 3.2 Drag the thumb as described in design.md, with the same selection rule as the wheel, and keep the glass live through the press (design.md: "A press keeps the glass live"). Verify: a test check that calls the drag step with the pointer at the track's top and bottom (no real input) gets offset 0 and the last offset. A real drag on demo windows is done in 4.1.
- [x] 3.3 Docs. In `README.md`: drop the known issue about shrinking and the missing scroll bar; add the scroll bar to the mouse paragraph; mention the grid and scrolling under Tests; and remove fixed-size tiles from the Roadmap line. In `ROADMAP.md`: mark item 1 done as item 7 is, pointing to `openspec/specs/switcher-grid/spec.md` (the commit doesn't exist yet), and move the edge fade into item 3.1. Verify: `README.md` has no "shrink" and no "no scroll bar"; `ROADMAP.md` item 1 reads as done, and item 3.1 lists the fade.

## 4. Whole-feature checks

- [x] 4.1 Captures, light and dark, only with demo windows over the stand-in wallpaper (`tools\readme-shots.ahk` with a window count, or a scratchpad copy for scrolled states):
  - 8 windows;
  - 9, 12 and 30 windows right after opening;
  - a frame mid-scroll with a half-cut row;
  - the wide bar during a real drag.

  Verify by looking at each image: 8 windows match the baseline; the grid, the bar and the peeking next row show; a cut row's thumbnails show the top of each window at the normal scale; nothing is drawn past the pane's edge; the picture is whole; the glass stays live (not flat grey) in the drag capture; and the pane has the same size and position at 9, 12 and 30 windows (logged with each capture).
- [x] 4.2 Time 30 demo windows with `QueryPerformanceCounter` around each frame (temporary code, not committed). Cover Tab held, the wheel, a drag, and the open (Alt+Tab to visible). Verify: no frame over about 8 ms, and the open within 30 ms. Report the maximum and the median of each.

## Workflow follow-up

- An independent Opus review of the whole diff before the commit.
- Archive with `openspec archive many-windows-grid --yes`, which creates `openspec/specs/switcher-grid/spec.md`. Then Haiku makes one commit with the code, the docs and the archived change. No push without the author's OK.
