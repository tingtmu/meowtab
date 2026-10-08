# switcher-grid Specification

## Purpose
How the switcher lays out its window tiles and how it scrolls when they don't all fit under the mood picture, so tiles stay readable and the picture stays whole however many windows are open.

## Requirements

### Requirement: Up to 8 windows keep the shaped layout
With 1 to 8 windows, each tile SHALL be as wide as its window's shape (within the existing limits), in centred rows.

#### Scenario: Eight windows
- **WHEN** the switcher opens with 8 windows of different shapes on a 1080p screen
- **THEN** tile widths follow each window's shape, the rows are centred, and no scroll bar shows

#### Scenario: Back to eight
- **WHEN** closing a window from the switcher leaves 8 windows
- **THEN** the pane switches back to this layout

### Requirement: From 9 windows, a fixed 3-column grid
From 9 windows, tiles SHALL all be the same size and fill 3 columns left to right, row after row, each thumbnail fitted and centred in its tile. The tile size SHALL depend only on the screen's work area, so tiles never shrink as windows are added.

#### Scenario: The ninth window
- **WHEN** 9 windows are listed
- **THEN** the tiles form 3 rows of 3, lined up in columns

#### Scenario: Size doesn't depend on the count
- **WHEN** the switcher opens with 9, then 20, then 50 windows on a 1080p screen
- **THEN** the tiles have the same size each time, as tall as the tiles shown for 8 windows

### Requirement: The pane keeps one height under the picture
From 9 windows, the pane SHALL show at most as many full rows as fit under the mood picture at its highest peek. Once rows overflow, its height and position SHALL stay the same for any window count and scroll position, and the picture SHALL show in full.

#### Scenario: 9 to 50 windows at 150 %
- **WHEN** the switcher opens with 9, 12, 30 and 50 windows on a 1080p screen at 150 %
- **THEN** the pane has the same height and position each time, and the picture shows in full above it, inside the work area

#### Scenario: Closing a window from 12
- **WHEN** 12 windows are listed and the user closes one from the switcher
- **THEN** the pane neither moves nor changes size, and only the picture glides to its new height

#### Scenario: Scrolling
- **WHEN** the grid scrolls, by any means
- **THEN** the pane and the picture neither move nor change size

### Requirement: Rows are cut cleanly at the pane's edge
A row that doesn't fully fit SHALL be cut at the pane's top or bottom edge. The part inside the pane shows, live thumbnails included, cropped rather than squeezed. Nothing is drawn past the pane's edge.

#### Scenario: The next row peeks in
- **WHEN** the pane opens with 12 windows and 2 full rows fit
- **THEN** the top of the third row shows at the bottom edge, cut by it

#### Scenario: A row half scrolled out
- **WHEN** a row is half cut by the bottom edge, during a scroll or after a drag
- **THEN** its thumbnails show the top half of each window at the normal scale, ending at the edge

#### Scenario: Scrolling back
- **WHEN** a row scrolls out of view and back in
- **THEN** its live thumbnails show again at once, with no empty slot

### Requirement: Up and Down move within a column
In the grid, Down and Up SHALL select the tile in the same column one row down or up. When the row below is shorter, Down SHALL select its last tile. Past the first or the last row, they do nothing.

#### Scenario: Twelve windows
- **WHEN** 12 windows are listed, the second is selected, and the user presses Down, Down, then Up
- **THEN** the selection goes to the fifth, the eighth, then the fifth window

#### Scenario: A shorter last row
- **WHEN** 10 windows are listed, the ninth is selected, and the user presses Down twice
- **THEN** the tenth window is selected and stays selected

### Requirement: The grid scrolls to the selection
When the selection moves to a tile that isn't fully visible, the grid SHALL scroll smoothly (easing out over about 120 ms) just far enough that the tile sits as far inside the pane as the first row does when unscrolled. Part of the next row then stays in view, if there is one.

#### Scenario: Tab into a hidden row
- **WHEN** 12 windows show 2 full rows and Tab moves the selection from the second row to the third
- **THEN** within about 120 ms the grid has scrolled by one row, the third row sits where the second was, and the top of the fourth row shows at the bottom edge

#### Scenario: Wrapping around
- **WHEN** the last window is selected and the user presses Tab
- **THEN** the first window is selected and the grid scrolls back to the top

### Requirement: The wheel scrolls one row per notch
Each wheel notch SHALL scroll the grid by one row, smoothly, stopping at the first and last rows. If the selected tile is no longer fully visible, the selection SHALL move to the nearest fully visible tile, so releasing Alt never switches to a window out of view.

#### Scenario: One notch down
- **WHEN** 20 windows are listed, the grid is at the top with the first window selected, and the wheel turns one notch down
- **THEN** the grid scrolls by one row, and the selection moves to the nearest tile of the new top row

#### Scenario: At the end
- **WHEN** the last row is fully in view and the wheel turns down
- **THEN** nothing moves

### Requirement: A Windows 11-style scroll bar
When rows overflow, a thin rounded scroll bar SHALL show in the pane's right padding, its thumb sized and placed by the visible share and position. It is about 3 px wide, or about 6 px with the mouse near it (at 100 %, scaled with the display). It shows on opening and while scrolling, and fades out about a second after scrolling stops unless the mouse is near. Dragging its thumb SHALL scroll the grid directly.

#### Scenario: Opening with overflow
- **WHEN** the pane opens with more rows than fit
- **THEN** the thin bar shows and fades out about a second later; with no overflow, no bar shows at all

#### Scenario: Dragging the thumb
- **WHEN** the user moves the mouse near the bar, presses on its thumb and drags it down
- **THEN** the bar is wide while the mouse is near, the grid follows the pointer without easing, and the selection stays in view as with the wheel

### Requirement: The mouse on a scrolled grid
Hover and clicks SHALL apply to the tile under the pointer as the grid shows it at that moment, including during a scroll. A press and a release on the same tile switch to it, or close it if both are on its close button. If a scroll brought another tile under the pointer in between, nothing happens. Closing a window SHALL keep the scroll position. A press SHALL never turn the pane's live glass flat.

#### Scenario: Click in a scrolled grid
- **WHEN** the grid is scrolled down and the user clicks a tile
- **THEN** MeowTab switches to that tile's window

#### Scenario: Closing while scrolled
- **WHEN** the grid is scrolled down and the user closes a window with its close button
- **THEN** the following tiles move up to fill the gap and the view stays where it was

#### Scenario: Pressing without switching
- **WHEN** the user presses on the pane without switching or closing, such as on the scroll bar's thumb to drag it
- **THEN** the pane keeps its live acrylic glass throughout

### Requirement: Scrolling stays fast and stops when closed
A scroll frame, from the keyboard, the wheel or a drag, SHALL take at most about 8 ms on the development machine. Closing the pane SHALL stop every scroll and scroll-bar timer.

#### Scenario: Thirty windows
- **WHEN** 30 windows are listed and the grid is scrolled by keyboard, wheel and drag
- **THEN** no measured frame takes more than about 8 ms

#### Scenario: Closed mid-scroll
- **WHEN** Alt is released while the grid is still scrolling or the bar is fading
- **THEN** the pane closes and no MeowTab timer runs afterwards apart from the ones it had before opening
