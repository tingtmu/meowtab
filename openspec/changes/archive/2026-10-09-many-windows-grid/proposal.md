# Proposal

## Why

With many windows the thumbnails shrink step by step (down to 40 %), then the grid scrolls row by row with no scroll bar, and the pane's height changes with the window count. It is the README's first known issue and ROADMAP item 1. Windows' own Alt+Tab instead switches to a fixed 3-column grid with a scroll bar from 9 windows.

## What Changes

- **1-8 windows:** unchanged, today's layout (tile widths follow each window's shape, rows centred).
- **9 or more: a fixed grid.** 3 columns of same-size tiles, with each thumbnail fitted and centred in its tile. The tile size depends only on the screen, so tiles never shrink as windows are added. The pane shows as many full rows as fit under the picture at its highest peek and keeps that height. The next row peeks in at the pane's edge.
- **Smooth scrolling** (ease-out, about 120 ms). The keyboard scrolls just enough to keep the selection fully visible, the wheel moves one row per notch, and dragging the scroll bar scrolls directly.
- **Windows 11-style scroll bar** in the right padding, only when rows overflow: 3 px, 6 px with the mouse near, fading about a second after scrolling stops.
- **Live thumbnails** are cropped where a row is cut by the pane's edge, and hidden (not released) while scrolled out of view.
- The test gains grid and scrolling checks. The README drops the known issue. In the ROADMAP, item 1 is marked done and the edge fade moves to item 3.
- **Out of scope:** the soft fade at the pane's edges (moved to Velvet, item 3, at the author's choice), 4 columns on ultrawide screens, a setting for the 9-window threshold (a constant, as with the other look constants), and the classic switcher.

## Capabilities

### New Capabilities
- `switcher-grid`: how the switcher lays out its window tiles, and how it scrolls when they don't all fit under the picture.

### Modified Capabilities
None.

## Impact

`alttab-native.ahk` (layout, scrolling, drawing, thumbnails, mouse) and `meowtab.ahk` (new look constants and the bar's palette colours). Also `tests\meowtab.test.ahk`, `README.md` and `ROADMAP.md`. No change to `settings.ini`, the settings panel, the pictures or `meowtab-classic.ahk`.
