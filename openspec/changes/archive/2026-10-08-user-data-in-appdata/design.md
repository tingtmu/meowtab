# Design

## Context

Every user-data path comes from `settings-store.ahk` (`SettingsFile`, `MoodImage`, `PendingImage`, `PendingClear`), except the picture loading in `meowtab.ahk` and `meowtab-classic.ahk`, which builds `A_ScriptDir\IMG_DIR\...` itself. `SettingsLoad()` runs early in auto-execute (`meowtab.ahk` line 25), before the globals defined in the included files are set. `tests\meowtab.test.ahk` includes `meowtab.ahk`, so it loads settings exactly as the app does.

## Decisions

- **One data folder, `%APPDATA%\MeowTab`** (the user chose it). It works the same for the zip, WinGet and Scoop with no package-specific "persist" rules. Rejected: keeping data next to the exe, because WinGet's upgrade deletes the extracted folder; a portable mode (settings.ini beside the exe wins), because it doubles the paths to test and nobody has asked for it.
- **Picture lookup: user folder first, then app folder.** Writing always goes to the user folder. This keeps the shipped set updatable and still finds sets added to the repo's `images\` by pull request. Rejected: choosing the folder by prefix (`chill` means app, anything else means user), because it breaks hand-made sets placed in the app folder.
- **Test override:** a global data-folder path that a script can set *before* including `meowtab.ahk`; when it isn't set, `%APPDATA%\MeowTab` is used. This follows the existing `DESKTOP_DIR` pattern, but is read early enough for `SettingsLoad`. The test and `readme-shots` point it at an empty folder under `%TEMP%` and delete that folder afterwards.
- **No migration.** No release has shipped. Source users move their files by hand, and the README says where.

## Risks / Trade-offs

- [Uninstall leaves `%APPDATA%\MeowTab` behind.] → The README's removal steps (added by release-and-packages) say to delete it, which is the usual behaviour for Windows apps.
- [Pending imports would be orphaned if the panel crashes.] → `PendingClear` already sweeps them; it now sweeps the user folder.
