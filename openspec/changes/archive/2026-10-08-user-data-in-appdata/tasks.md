# Tasks

## 1. Data folder

- [x] 1.1 In `settings-store.ahk`, add the data folder: a global that a script may set before including `meowtab.ahk`, defaulting to `%APPDATA%\MeowTab`. Point `SettingsFile()` at it, and have `SettingsCreate` create the folder when needed. Verify with the checks in 1.3.
- [x] 1.2 Move pictures:
  - Pending imports and `custom_*.png` are written to `<data>\images` (created when needed).
  - `MoodImage` looks in the user folder first, then the app's `images\`.
  - `meowtab.ahk` and `meowtab-classic.ahk` load pictures through that lookup.
  - `PendingClear` sweeps the user folder.

  Verify: grep finds no user-data path still built from `A_ScriptDir`, and `AppDir()` and the shipped `images\` are only read.
- [x] 1.3 In `tests\meowtab.test.ahk`:
  - Before the include, point the data folder at a new empty folder under `%TEMP%`, and delete that folder at the end.
  - Add checks: saving settings creates `<data>\settings.ini` and nothing next to the script; saving pictures puts `custom_*.png` in `<data>\images`; the lookup prefers the user folder and falls back to the app folder.

  Verify: `ALL PASSED`, and `%APPDATA%\MeowTab` (absent on the dev machine) still doesn't exist afterwards.
- [x] 1.4 Give `tools\readme-shots.ahk` the same empty temporary data folder, which replaces its "settings.ini exists" guard. Verify: with a temporary non-default `%APPDATA%\MeowTab\settings.ini` present (e.g. `FONT_SIZE=20`), `settings out.png` still shows default settings. Remove the temporary file and folder afterwards.

## 2. Compiled app

- [x] 2.1 Build with `build.ps1`. Extract `dist\meowtab.zip` to a temporary folder and run `meowtab.exe /settings`. Save a changed setting and a user picture set (through the panel, or by hand as `<prefix>_*.png` in `%APPDATA%\MeowTab\images` with `IMG_PREFIX` set). Close it, delete that folder, extract the zip to a new one and run `meowtab.exe /settings` again. Verify:
  - a file listing shows the data only under `%APPDATA%\MeowTab`;
  - a capture of the settings panel alone shows the saved value and pictures;
  - the first-run question isn't asked again;
  - `meowtab-classic.exe /settings` shows the same value.

  Afterwards, delete `%APPDATA%\MeowTab` and any desktop shortcut the check created.

## 3. Docs

- [x] 3.1 In `README.md`, replace every "next to the script" / "in `images/`" for user data with `%APPDATA%\MeowTab` (`settings.ini`, `images\`). Add one short note that settings from an older checkout can be moved there by hand. Verify: grep `README.md` for "next to the script" finds nothing about settings or pictures.

## Workflow follow-up

- Independent Opus review of the diff before the commit.
- One commit with the code and `openspec/changes/user-data-in-appdata/`, then archive (this creates `openspec/specs/user-data/spec.md`). No push.
