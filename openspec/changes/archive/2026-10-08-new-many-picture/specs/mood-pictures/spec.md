# Spec Delta

## Purpose

The shipped mood pictures (`chill_few`, `chill_some`, `chill_many`) that peek over the switcher's top edge: how they are framed so the set looks consistent, and how fully they show.

## ADDED Requirements

### Requirement: Shipped pictures share one framing
Each shipped mood picture SHALL be a 512×512 PNG with a transparent background and at most 300 KB. Its art (pixels with alpha > 24) SHALL be centred, with its longer side 482-484 px.

#### Scenario: Measuring the set
- **WHEN** the art bounding box of each shipped picture is measured
- **THEN** each is centred within 1 px on both axes, its longer side is 482-484 px, and the file is 512×512 and ≤ 300 KB

### Requirement: Clean edges
Shipped pictures SHALL have no visible coloured fringe or halo along the outline of the art.

#### Scenario: Light and dark backgrounds
- **WHEN** a picture is shown at 200 % over white and over near-black
- **THEN** no coloured fringe is visible along its outline

### Requirement: The "too many…" cat shows in full
At maximum peek the "many" picture SHALL show the cat's face and both ears in full, with nothing cut at the top of the canvas.

#### Scenario: Switcher with many windows
- **WHEN** the switcher opens with 12 or more windows (`PEEK_MAX` reached) on a 1080p screen at 150 %
- **THEN** the cat's face and both ears show in full above the pane

#### Scenario: Settings panel
- **WHEN** the settings panel opens
- **THEN** the "too many…" card and the "12+ windows" peek scene show the cat with its face and both ears visible
