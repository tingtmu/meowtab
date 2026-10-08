# Spec Delta

## Purpose

Where MeowTab keeps what the user changes (settings and their own pictures), so that it survives replacing, upgrading or reinstalling the app.

## ADDED Requirements

### Requirement: Settings live in the user's AppData
MeowTab SHALL read and write its settings in `%APPDATA%\MeowTab\settings.ini`, shared by `meowtab` and `meowtab-classic`, and SHALL NOT write a settings file next to the exe or script. The folder SHALL be created when something is first saved.

#### Scenario: Saving from the settings panel
- **WHEN** `%APPDATA%\MeowTab` does not exist and the user changes a setting and saves
- **THEN** `%APPDATA%\MeowTab\settings.ini` holds the new value, the switcher uses it after the reload, and no `settings.ini` appears next to the exe

### Requirement: The user's pictures live in the user's AppData
Pictures the user adds (through the settings panel or by hand as a `<prefix>_*.png` set) SHALL be stored in and read from `%APPDATA%\MeowTab\images\`. The shipped pictures SHALL stay in the app's `images\` folder and are never written to. A picture set SHALL be looked up in the user folder first, then in the app folder.

#### Scenario: Choosing own pictures
- **WHEN** the user picks pictures in the settings panel and saves
- **THEN** `custom_few.png`, `custom_some.png` and `custom_many.png` are in `%APPDATA%\MeowTab\images\`, the switcher shows them, and the app's `images\` folder is unchanged

#### Scenario: Shipped set
- **WHEN** there is no user data at all
- **THEN** the switcher shows the shipped `chill_*` pictures from the app's `images\` folder

### Requirement: User data survives replacing the app
Settings and the user's pictures SHALL still apply after the app folder is deleted and replaced by a fresh copy of the app, as a package upgrade or reinstall does.

#### Scenario: Fresh copy of the app
- **WHEN** the user saves a setting and their own pictures, closes MeowTab, deletes the app folder and starts the exe from a freshly extracted `meowtab.zip`
- **THEN** the saved setting and pictures are in use, and no first-run question is asked again

### Requirement: Tests and captures leave user data alone
The integration test and the screenshot tool SHALL run against an empty temporary data folder, never reading or changing `%APPDATA%\MeowTab`.

#### Scenario: Developer has their own settings
- **WHEN** `%APPDATA%\MeowTab\settings.ini` holds non-default values and `tests\meowtab.test.ahk` or `tools\readme-shots.ahk` runs
- **THEN** they run with default settings, and the file and its folder are unchanged afterwards
