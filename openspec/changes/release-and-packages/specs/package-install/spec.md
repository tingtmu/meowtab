# Spec Delta

## Purpose

Installing, updating and removing MeowTab through WinGet and Scoop on a Windows machine that has no AutoHotkey, delivering the same files as the direct download.

## ADDED Requirements

### Requirement: Install with Scoop
MeowTab SHALL install from its own Scoop bucket in this repository, with both exes, the shipped pictures, and Start menu shortcuts for both switchers.

#### Scenario: Clean machine
- **WHEN** on Windows without AutoHotkey the user runs `scoop bucket add meowtab https://github.com/tingtmu/meowtab` and then `scoop install meowtab/meowtab`
- **THEN** the Start menu has MeowTab entries, and `meowtab.exe` starts, shows its tray icon and opens the switcher with the shipped pictures

### Requirement: Install with WinGet
MeowTab SHALL install with `winget install tingtmu.MeowTab`, exposing both exes as the commands `meowtab` and `meowtab-classic`.

#### Scenario: Clean machine
- **WHEN** on Windows without AutoHotkey the user runs `winget install tingtmu.MeowTab` and then `meowtab`
- **THEN** MeowTab starts, shows its tray icon and opens the switcher with the shipped pictures

### Requirement: Updates keep user data
Updating, or uninstalling and reinstalling, through either package manager SHALL keep the user's settings and pictures.

#### Scenario: Reinstall
- **WHEN** the user saves a setting and their own pictures, then updates (or uninstalls and installs again) with Scoop or WinGet
- **THEN** the setting and pictures still apply when MeowTab starts

### Requirement: Removal works as documented
Uninstalling SHALL remove the app files and the shortcuts the package created. The README SHALL say that settings and pictures stay in `%APPDATA%\MeowTab` and how to delete them.

#### Scenario: Uninstall
- **WHEN** the user runs the README's uninstall command for their package manager and then deletes `%APPDATA%\MeowTab` as described
- **THEN** no MeowTab files, shortcuts or commands remain

### Requirement: Packages match the release
Both package manifests SHALL point to the versioned GitHub release URL of the latest published release, with the hash of that exact file.

#### Scenario: After a release
- **WHEN** a release is published and its packages are updated
- **THEN** the Scoop manifest and the WinGet manifest name that version, and their hash equals the zip's line in `SHA256SUMS.txt`
