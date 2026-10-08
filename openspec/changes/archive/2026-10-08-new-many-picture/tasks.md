# Tasks

## 1. Picture

- [x] 1.1 Turn `images/chill_4.png` into `images/chill_many.png`: crop to the art (alpha > 24), scale its longer side to 483 px with alpha-correct high-quality resampling, and centre it on a transparent 512×512 canvas. Verify: the measured art box is centred within 1 px, its longer side is 482-484 px, and the file is ≤ 300 KB.
- [x] 1.2 Check the edges at 200 % over white and over near-black. If a coloured fringe shows, clean the faint edge pixels and check again. Verify: before/after crops show no fringe.

## 2. In place

- [x] 2.1 Open the settings panel with default settings. The "too many…" card and the "12+ windows" peek scene must show the new cat with its face and both ears. Save a capture of the panel alone as `docs/settings.png`, framed like the current one (816×986). Verify: side by side with the old shot, only the cat differs.
- [x] 2.2 Open the switcher with 12 or more demo windows, over a stand-in wallpaper only. Verify: a capture shows the cat's face and both ears in full above the pane. (Checked at 1920×1200 and 100 %. The new art spans the same rows as the old picture within 1 px, so it peeks the same at 150 %.)
- [x] 2.3 Run `tests\meowtab.test.ahk`. Verify: it prints `ALL PASSED`.

## 3. Cleanup

- [x] 3.1 Delete `images/chill_4.png` so `build.ps1` ships only the three cats. Verify: `images\chill_*.png` matches exactly `chill_few`, `chill_some` and `chill_many`.

## Workflow follow-up

- Archive the change once verified (this creates `openspec/specs/mood-pictures/spec.md`).
- Commit the assets and `openspec/` together. No push.
