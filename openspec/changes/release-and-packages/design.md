# Design

## Context

`build.yml` already builds `meowtab.zip` on `v*` tags, with pinned, hash-checked AutoHotkey and Ahk2Exe, and uploads it only as a workflow artifact (`contents: read`). Both exes are stamped by `;@Ahk2Exe-SetVersion` (`0.1.0` today). The repo also carries peek-alttab's old `v1.0.0` and `v1.1.0` tags locally; they must never be pushed to `tingtmu/meowtab`.

## Decisions

- **CI makes a draft, a person publishes.** A separate release job, the only one with `contents: write`, runs `gh release create --draft` (preinstalled on the runner, so no third-party action). A draft lets the scans and notes be finished before anything is public. Rejected: publishing straight from CI, which would ship before the files are checked.
- **The version guard reads both scripts' `SetVersion`** and compares it with the tag. It is cheap, and it stops a WinGet or Scoop version that disagrees with the exe.
- **VirusTotal runs from a local script, not CI.** The API key stays with the author, detections need a human's judgement, and the free API is limited to 4 requests per minute. The script takes a folder (`gh release download <tag> -D <folder>`), so it can be tried on a local build.
- **Scoop: own bucket at `bucket/` in this repo.** Extras requires popularity MeowTab doesn't have yet. Data lives in `%APPDATA%`, so the manifest needs no `persist`. Updates go through Scoop's `checkver.ps1 -Update` against GitHub releases.
- **WinGet: manifests live only in `winget-pkgs`.** `wingetcreate new` makes the first version and `wingetcreate update` makes later ones. Keeping a copy here would just drift. Portable packages get no Start menu entry; the first run's existing "desktop icon?" question covers that.
- **Zip name stays `meowtab.zip`.** The README can then link `releases/latest/download/meowtab.zip`, and package URLs are versioned by the tag path.

## Risks / Trade-offs

- [AutoHotkey-compiled exes often trip antivirus heuristics, and WinGet's checks run Defender.] → Investigate each detection, submit false positives to Microsoft (WDSI) and the vendors concerned, and say so in the notes.
- [The exes aren't code-signed, so SmartScreen warns on first run.] → The README says so and points to the hashes and reports. Signing is out of scope.
- [The workflow can only be fully tested with a real tag.] → It only makes a draft. If a run fails, delete the draft and the tag, fix, and tag again; nothing public is affected.
