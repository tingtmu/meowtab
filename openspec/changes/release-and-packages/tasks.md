# Tasks

Starts after `user-data-in-appdata` is committed.

## 1. Release build and checks

- [x] 1.1 In `build.yml`, add a version guard: the tag without its `v` must equal `SetVersion` in `meowtab.ahk` and `meowtab-classic.ahk`. Verify: the guard's script passes for `v0.1.0` and fails for `v0.1.1` when run locally.
- [x] 1.2 Have `build.yml` write `SHA256SUMS.txt` (`sha256sum` format: the zip, `meowtab/meowtab.exe`, `meowtab/meowtab-classic.exe`) and upload it with the zip. On tags only, a release job with `contents: write` creates the draft release with both files. Verify: the hashing step run locally on a `build.ps1` output matches `Get-FileHash`, and an Opus review of the workflow. The real run is 3.1.
- [x] 1.3 Write `tools/release-checks.ps1 <folder>`:
  - verify the files against `SHA256SUMS.txt`;
  - upload the zip and both exes to VirusTotal with `VT_API_KEY`, keeping within 4 requests per minute;
  - wait for each analysis and print Markdown with the file, SHA-256, detections and report link;
  - without a key, stop after the hash check with a clear message.

  Verify on a local build: the hashes pass, a changed byte fails, and a missing key gives the message.
- [x] 1.4 Write the README sections, and remove the "no installer yet" status note:
  - a quick start that links to `releases/latest/download/meowtab.zip`;
  - "Check the download": `Get-FileHash`, the release's scan links and their limits, and the SmartScreen warning;
  - where data lives and how to delete it;
  - a short "Releasing" checklist (bump `SetVersion`, tag, run checks, publish, update both packages).

  Verify: the README's own commands run as written on a local build.

## 2. Package manifests

- [x] 2.1 Write `bucket/meowtab.json`:
  - `version` and a versioned release `url`; `hash` stays a placeholder until 3.3;
  - `extract_dir: meowtab`;
  - `shortcuts` for both exes;
  - `checkver: github` and `autoupdate`, with the hash taken from `SHA256SUMS.txt`.

  Verify: it passes Scoop's schema, and Scoop's `checkver.ps1` reads it.
- [x] 2.2 Prepare the `tingtmu.MeowTab` WinGet manifest (zip, nested portable, both exes with aliases `meowtab` and `meowtab-classic`, installed per user (`Scope` omitted: winget validate rejects it for portable), MIT) outside the repo. Verify: `winget validate` passes with a placeholder URL and hash.

- [x] 2.3 From the author's clean-machine test: Scoop's `post_install` starts `$dir\meowtab.exe` (`$dir` is already the `current` folder then), so the first-run desktop-icon question appears without looking for the exe. WinGet portable has no post-install step. Verify: the schema validates, and a local `scoop install` starts `…\current\meowtab.exe` with its first-run question.

## 3. First release, v0.1.0 (each step waits for the author's OK)

- [x] 3.1 Tag `v0.1.0` and push only that tag; `main` waits until 3.3, so the README's download link never points to a missing release. Verify: CI passes, and the draft holds `meowtab.zip` and `SHA256SUMS.txt`.
- [x] 3.2 With the author's `VT_API_KEY`, run `gh release download v0.1.0 -D <tmp>` and then `tools/release-checks.ps1 <tmp>`. Investigate every detection, and submit false positives where needed. Verify: the report links open for the expected hashes. (v0.1.0: zip 0/68; Gridinsoft `Trojan.Heur!` on both exes and APEX `Malicious` on classic, both generic heuristics on a first-seen file; Microsoft Defender clean; the AutoHotkey 2.0.28 base is 0/71. No reports filed, since Defender is what WinGet checks.)
- [x] 3.3 Publish the release with its notes (what MeowTab is, the hash and scan block, and the limits). Fill in the Scoop hash, then commit and push `main`. Verify: an anonymous download of `releases/latest/download/meowtab.zip` matches `SHA256SUMS.txt`, and `scoop install bucket\meowtab.json` followed by `scoop uninstall meowtab` works on the dev machine without launching the app (the author's own Alt+Tab keeps running).
- [ ] 3.4 Submit the WinGet manifest with the real URL and hash to `microsoft/winget-pkgs`. Verify: the PR's checks pass and it merges, or any Defender flag has been reported and handled.
- [ ] 3.5 Add the README's "Install with WinGet or Scoop" section (install, update, uninstall, data note), then commit and push. Verify: its commands match the manifests.
- [ ] 3.6 The author checks on another PC or VM without AutoHotkey, for both package managers: install, launch, change a setting, reinstall (the setting is kept), uninstall, then delete `%APPDATA%\MeowTab` as documented. Verify: the author reports every step passing. (Scoop passed on 2026-10-08: install, launch, setting kept through reinstall, uninstall.)

## Workflow follow-up

- Commits go in stages (1-2 before the tag, then 3.3 and 3.5), each staged by Haiku. Mark ROADMAP item 5 done, then archive after 3.6.
