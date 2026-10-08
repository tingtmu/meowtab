# Proposal

## Why

ROADMAP item 5. Users currently run the source or build the exe themselves. There is no published release, no public evidence to check a download against, and no WinGet or Scoop package. Depends on `user-data-in-appdata`, so that upgrades keep settings.

## What Changes

- **CI** on a `v*` tag:
  - fails unless the tag matches the version stamped in both exes;
  - writes `SHA256SUMS.txt` for the zip and both exes;
  - creates a **draft** GitHub release with `meowtab.zip` and `SHA256SUMS.txt`. Nothing is public until the author publishes it.
- **`tools/release-checks.ps1 <folder>`:** checks the downloaded release files against `SHA256SUMS.txt`, then uploads the zip and both exes to VirusTotal (key from `VT_API_KEY`). It waits for the results and prints a Markdown block (file, SHA-256, detections, report link) for the release notes.
- **Scoop:** `bucket/meowtab.json` in this repo, with a versioned release URL and hash, Start menu shortcuts for both exes, and checkver/autoupdate from GitHub releases. Users run `scoop bucket add meowtab https://github.com/tingtmu/meowtab`.
- **WinGet:** package `tingtmu.MeowTab`, a zip with both exes as portable commands. It is made with `wingetcreate` and submitted to `microsoft/winget-pkgs`, where its manifests live.
- **README:**
  - the quick start becomes "download and run";
  - a "Check the download" section covers hashes, the scan links on the release page and their limits (heuristic scans, AutoHotkey-compiled exes are sometimes flagged, no code signing so SmartScreen may warn);
  - a WinGet/Scoop section covers install, update and removal, and where data stays;
  - a short "Releasing" checklist.
- **First release, v0.1.0:** every public step (push and tag, VirusTotal upload, publishing, the WinGet pull request) waits for the author's OK.

Out of scope: code signing, an installer (`.msi` or setup exe), the Scoop Extras bucket (it needs about 100 stars), and running VirusTotal in CI.

## Capabilities

### New Capabilities
- `releases`: what a tagged release contains and the public checks published with it.
- `package-install`: installing, updating and removing MeowTab with WinGet and Scoop.

### Modified Capabilities
None.

## Impact

`.github/workflows/build.yml`, the new `tools/release-checks.ps1` and `bucket/meowtab.json`, `README.md`, `ROADMAP.md`. External: GitHub releases of `tingtmu/meowtab`, VirusTotal, and a pull request to `microsoft/winget-pkgs`. No app code changes.
