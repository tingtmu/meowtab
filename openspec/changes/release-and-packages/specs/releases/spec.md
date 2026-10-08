# Spec Delta

## Purpose

What a MeowTab release contains and the public evidence published with it, so users can check that a download is the file that was built and scanned.

## ADDED Requirements

### Requirement: A version tag builds a draft release
Pushing a `vX.Y.Z` tag SHALL build the zip in CI and create a draft GitHub release with `meowtab.zip` and `SHA256SUMS.txt`. The checksum file SHALL list the SHA-256 of the zip and of both exes inside it. The build SHALL fail, without a release, when the tag differs from the version stamped in either exe.

#### Scenario: Matching tag
- **WHEN** `v0.1.0` is pushed and both exes are stamped `0.1.0`
- **THEN** a draft release `v0.1.0` holds `meowtab.zip` and `SHA256SUMS.txt`, and the hashes in that file match the attached zip and the exes extracted from it

#### Scenario: Mismatched tag
- **WHEN** a tag is pushed whose version differs from the exes' version
- **THEN** the workflow fails and no release is created

### Requirement: Published releases carry their checks
Each published release's notes SHALL give, for the zip and both exes, the SHA-256 and a VirusTotal report link for exactly that file, together with a short note on what the scans do and don't show. When a release file changes, its hashes and reports SHALL be redone before it is published again.

#### Scenario: Checking a download
- **WHEN** a user downloads `meowtab.zip` from the release and hashes it with `Get-FileHash`
- **THEN** the hash equals the one in the notes and in `SHA256SUMS.txt`, and the linked VirusTotal report is for that hash

### Requirement: The README leads to the release and its checks
The README's quick start SHALL send users to the latest release to download and run MeowTab, and SHALL show where the hashes and scan reports are before they download.

#### Scenario: New visitor
- **WHEN** someone follows the README's quick start
- **THEN** they reach the latest release's `meowtab.zip` and the instructions for checking it, without building anything
