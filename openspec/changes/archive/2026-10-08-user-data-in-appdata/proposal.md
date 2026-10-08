# Proposal

## Why

MeowTab saves `settings.ini` and the user's own pictures next to the exe. Package managers replace that folder: WinGet's portable upgrade and uninstall delete the extracted app folder, and Scoop moves each version into a new folder. Upgrades would lose the user's settings and pictures. ROADMAP item 5 requires that "an upgrade keeps the user's settings and pictures", so this has to change before the first release.

## What Changes

- `settings.ini` moves to `%APPDATA%\MeowTab\`, shared by `meowtab` and `meowtab-classic` as today. The folder is created when something is first saved.
- The user's pictures (`custom_*.png`, pending imports, and hand-made `<prefix>_*.png` sets) go to `%APPDATA%\MeowTab\images\`. The shipped `chill_*` set stays in the app's `images\`. Pictures are looked up in the user folder first, then in the app folder.
- **BREAKING (source users only):** a `settings.ini` or `custom_*.png` next to the script is no longer read, and nothing is migrated. No release has shipped yet, so there are no zip users to migrate.
- `tests\meowtab.test.ahk` and `tools\readme-shots.ahk` use an empty temporary data folder, so they never read or change the user's real data.
- README: sentences that say "next to the script" or "in `images/`" now name the new location.

## Capabilities

### New Capabilities
- `user-data`: where MeowTab keeps the user's settings and pictures, and that they survive replacing the app folder.

### Modified Capabilities
None.

## Impact

`settings-store.ahk` (paths), `settings-panel.ahk` and `desktop-icon.ahk` if they build paths themselves, the picture loading lines in `meowtab.ahk` and `meowtab-classic.ahk`, `tests\meowtab.test.ahk`, `tools\readme-shots.ahk` and `README.md`. No change to the UI or to `build.ps1`.
