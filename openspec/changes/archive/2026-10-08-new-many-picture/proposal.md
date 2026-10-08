# Proposal

## Why

The author drew a new "too many…" cat, `images/chill_4.png`. It is untracked and stored at 1254 px and 1.6 MB, while the shipped set is 512 px and 200-300 KB. It needs to match the set before the first release (ROADMAP item 5) and the demo GIF (item 6) use it.

## What Changes

- Replace `images/chill_many.png` with the new art, framed like the other shipped pictures. The name stays the same, so `build.ps1` and the code are untouched.
- Refresh `docs/settings.png`, which shows the old cat on the "too many…" card.
- Delete `images/chill_4.png`. The old picture stays in git history.

## Capabilities

### New Capabilities
- `mood-pictures`: the shipped mood pictures, covering their framing and how they show above the pane.

### Modified Capabilities
None.

## Impact

Assets only: `images/chill_many.png` and `docs/settings.png`. No code changes.
