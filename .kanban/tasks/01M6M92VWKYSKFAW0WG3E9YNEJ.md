---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6md722cx3r3yxs9jnq5jgsz
  text: 'Consumer check, 2026-11-04: KVK 9784a5d (BoardTagRow on EK TagDisplay), SVK b25a20c and TestudoApp 37845ac use no ChipFlowLayout. Deleting it no longer waits on any kit, only on this card''s own move to EditorChipRows. That move still waits for the path chip ^hpxbqhx and preview ^qw7ws1y merges, which touch ToolCallLocationChips and DiffView.'
  timestamp: 2026-11-04T23:09:57.708415+00:00
- actor: claude-code
  id: 01m6nsnyqa7z6b5w9k2fjkf48d
  text: |-
    Implementation landed in commit 197dac24 (branch worktree-agent-a9021a0a21b612f9c, after ^6jwprd3's 4e7de07e on base 5f52457d; not pushed or merged). EK checkout 01b49c34 has `EditorChipRows`.
    - Consumers re-grepped (origin main shallow clones, no truncation, .md included): KVK d73069b, SVK b03783e, TestudoApp 5c3a4bd have no ChipFlowLayout. Nobody else needs it.
    - ToolCallLocationChips.swift and DiffView.swift use `EditorChipRows(spacing:)`. Deleted ChipFlowLayout.swift (and its #Preview), the now-dead `StylePreviewFixtures.chipTitles`, the DocC `ChipFlowLayout` entry, and the ARCHITECTURE.md/plan.md mentions.
    - Zero-width check: every chip in both rows is EK's PathChip (the plain and the AgentLocationChipStyle location styles both return `configuration.chip`, which is a PathChip; the diff file chips are PathChip). A PathChip always draws its file symbol plus `.padding(.horizontal, spacing.s)`, so it is never zero width. EK's "row is non-empty" break therefore matches AVK's old `origin.x > 0` for every AVK chip. Only a host's own ToolCallLocationChipStyle that returns a zero-width view could tell the two apart.
    - Tests: EK's EditorChipRowsTests covers "chips that fit stay on one row" and "a chip that does not fit starts the next row", so those two AVK checks were dropped. EK does not check these, so they moved onto `EditorChipRows` (`@testable import EditorStyle`) in Tests/AgentViewKitStyleTests/EditorChipRowsTests.swift: a chip that fits keeps its ideal size; a too-wide chip is re-measured at the row width (height included); a chip that stays too wide is clamped to the row width; no re-measure at infinite width; a full-width chip has a row of its own (mixed row heights). EK has no hosted check, so the IntegrationTests check `aFlowLayoutStartsANewRowWhenAViewDoesNotFit` (SurfaceAndTileTests) now builds `EditorChipRows`. These checks could later move into EK itself.
    - Gallery: new HostedSnapshotTests `chip-rows-narrow` (ChipRowsGalleryFixtures: 6 location chips over a 6-file DiffView, 420 pt wide), light and dark. Captured once from a real window together with ^6jwprd3's banners, file chips and action buttons. The sample folders are long, so each chip takes a row of its own (wrapping and middle truncation show, but no two chips share a row). Shorter fixture paths would show both, and need another capture.

    ### implement — changed
    - evidence: commit 197dac24, 12 files; `swift test` 969 + 60 passed; `swift test --package-path IntegrationTests` 945 passed (5 known issues are FontRoleExpectationsTests' deliberate negative checks); `swift test --package-path ScreenshotTests` 25 passed, gallery at ~/Library/Caches/AgentViewKit/screenshot-check/index.html; zero warnings in AVK targets (only mlx-swift dependency warnings)
    - next: review
  timestamp: 2026-11-05T12:07:03.146277+00:00
position_column: done
position_ordinal: ffffffa280
title: Move AVK's chip rows onto EditorKit's EditorChipRows and delete ChipFlowLayout
---
EK ^qrn90t1 (on EK origin, after b1488e1d) adds public `EditorChipRows` to EditorStyle: `init(spacing: CGFloat, edge: HorizontalEdge = .leading)`. Harvested from AVK's `ChipFlowLayout`.

**Waits for:** the path chip card ^hpxbqhx (it touches ToolCallLocationChips.swift) and the preview card ^qw7ws1y (DiffView.swift) to merge into main first, so this doesn't fight their changes. Deleting ChipFlowLayout also waits for KVK's BoardTagRow.swift to move onto EditorChipRows; kanbanviewkit-6d has been told.

## What
- `ChipFlowLayout(spacing:)` becomes `EditorChipRows(spacing:)` in ToolCallLocationChips.swift, DiffView.swift, and the #Preview and docs entry.
- Move ChipFlowLayoutTests onto EK's type, or drop the checks EK's own tests cover, and say which on the card.
- Behavior difference: AVK starts a new row when `origin.x > 0`, EK when the row isn't empty. They differ only after a zero-width chip. Check that no AVK chip can be zero width.
- Before deleting ChipFlowLayout, grep the KVK, SVK and Testudo origin mains with no truncation, and wait for each user's SHA. No shims.

## Acceptance Criteria
- [ ] AVK has no ChipFlowLayout, or the card says who still needs it.
- [ ] The review gallery shows the location chips and diff file rows wrapping, light and dark, at narrow width.

## Tests
- [ ] The full AVK test suite is green, with zero warnings in AVK targets.