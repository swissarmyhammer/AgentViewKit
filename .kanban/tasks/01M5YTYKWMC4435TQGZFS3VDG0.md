---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5ywe6ng4nn2qqq0z7y28qj2
  text: |-
    Research + implementation notes:
    - Reused the existing flow layout: `ChipFlowLayout` was private in `Items/ToolCallView.swift` (location chips). Moved it, unchanged, to `Sources/AgentViewKit/Content/ChipFlowLayout.swift` (internal) so DiffView and LocationChips share one layout.
    - DiffView body is now always `VStack(spacing: editorStyle.spacing.m) { fileChips; detail }`. Chips: `ChipFlowLayout(spacing: editorStyle.spacing.xs)`; the chip drops the row's `Spacer`, keeps the symbol, name (middle truncation), `.help(path)`, counts, `.buttonStyle(.plain)`, `selectableSurface` (radius renamed `fileRowRadius` -> `fileChipRadius`), labels, `.isSelected` trait and `diff-file-<path>` identifiers. No fill on unselected chips (transparent by default). ^ey6v778 (tile tokens) is still in todo, so the gaps use EditorStyle spacing tokens.
    - Removed `fileListWidth` and `rendererMinWidth` (no other users).
    - "Jump scopes of the rows": the file rows had no jump/command scope (only accessibility identifiers), so there was nothing to carry over.
    - One file: the chip row always shows. The EditorKit renderer draws a file header row with the path only (no counts) and it lives inside the swappable renderer, so no duplicate was dropped; the chip stays as the one place with name + counts.
    - New public `DiffView.detailIdentifier` ("diff-detail") on the detail container, so hosted tests can measure it.
    - Gotcha for tests: `HostedViewHarness.frame(identifier:)` returns accessibility (screen) frames, y axis UP. "Chip above detail" is `chip.minY >= detail.maxY`; "wrapped below" is `second.maxY <= first.minY`. My first RED run used the flipped form and read the coordinates wrong.
    - RED observed: detail width at 720, chips-above at 720, share-a-line, wrap-at-160 all failed on the old ViewThatFits/HStack layout; GREEN: `swift test --filter DiffViewHostedTests` 18/18 pass.
  timestamp: 2026-10-27T14:32:42.928387+00:00
- actor: claude-code
  id: 01m5ywres3c919d325rj11r7f4
  text: |-
    ### implement — changed
    - evidence: files — Sources/AgentViewKit/Diff/DiffView.swift, Sources/AgentViewKit/Content/ChipFlowLayout.swift (new; moved from ToolCallView.swift), Sources/AgentViewKit/Items/ToolCallView.swift, Tests/AgentViewKitTests/Diff/DiffViewHostedTests.swift, Tests/AgentViewKitTests/Diff/DiffRendererDefaultHostedTests.swift (doc comment), Tests/AgentViewKitTests/Snapshots/ReviewGalleryNotes.swift. Tests: `swift test --filter DiffViewHostedTests` 18/18 pass (new: theDetailIsAsWideAsTheView x2 widths, theChipsAreAboveTheDetail x2, theChipsShareALineWhenTheyFit, theChipsWrapToASecondLineWhenTheyDoNotFit, withOneFileTheChipShows; renamed aPressOnAChipGivesThatFileToTheRenderer, eachFileHasAChipWithItsLanguageAndCounts). `swift test --filter "SnapshotTests|SnapshotTextTests"` 47/47 pass, so no `__Snapshots__` image changed (no snapshot fixture holds a diff) and none was re-recorded. `swift test --filter ReviewGallery` 13/13 pass, gallery regenerated (index.html carries the new thread note). Full `swift test`: 1859 tests in 230 suites passed (7 known issues are pre-existing withKnownIssue in FontRoleExpectationsTests); the only warning is the SwiftPM build-system "missing creator for mutated node ... mlx-swift_Cmlx.bundle", not from this code.
    - Card notes: "chip maxY ≤ detail minY" is written in screen coordinates (y up) as `chip.minY >= detail.maxY - tolerance`. Tapping a chip is covered by aPressOnAChipGivesThatFileToTheRenderer. No header duplicate dropped (EditorKit file header row shows the path only, no counts, inside the swappable renderer).
    - Open: the regenerated thread PNGs were not looked at by eye — this session has no image viewer (files tool rejects PNG; a helper agent had the same limit). ReviewGalleryNotes states the new layout from the hosted geometry tests and marks the image as to be judged again. ^q89x329 and ^a2dy2gt both still apply (comments on each card).
    - next: /review
  timestamp: 2026-10-27T14:38:18.915656+00:00
- actor: claude-code
  id: 01m5ywyknhfcnzgxd268kerdcy
  text: |-
    ### test — green
    - evidence: `swift test` (exit 0) — 1859 tests in 230 suites passed, 0 failed, 7 known issues (expected count), 0 skipped. Only compiler/build output warning is the build-system notice "missing creator for mutated node: .../mlx-swift_Cmlx.bundle/Contents/MacOS" from the mlx-swift dependency bundle, not repo code. No source or test edits were needed; snapshots not re-recorded; Sources/AgentViewKitTestSupport untouched.
    - next: review
  timestamp: 2026-10-27T14:41:40.529047+00:00
- actor: claude-code
  id: 01m5yx1sekp33y3dayjp44gr92
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (0676da6): 0 findings, 0 confirmed, 0 refuted; 6 files reviewed, 0 not reviewed; 7 attempted, 0 failed, 0 skipped
    - next: none — moved to done
  timestamp: 2026-10-27T14:43:24.755820+00:00
- actor: claude-code
  id: 01m5yx24tqhk4k6f63pajc69yw
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 6 files (DiffView stacked layout, shared ChipFlowLayout)
    - test: green — swift test 1859 passed, 7 known issues
    - commit: 3916f94 (kanban), 0676da6 (code)
    - review: clean — 0 findings; card moved to done
  timestamp: 2026-10-27T14:43:36.407541+00:00
position_column: done
position_ordinal: ffffe780
title: 'AVK-8 diff: file chips in a row above, the file content full width below; drop the side-by-side layout (user review of the gallery)'
---
## Why

The user's review of the review gallery (2026-10-27), verbatim: "the file diff display should have the file chips above and the file content below -- the current version with half width diff wastes space needlessly".

Today, `Sources/AgentViewKit/Diff/DiffView.swift:206-217` uses `ViewThatFits(in: .horizontal)`. It prefers an `HStack` with the file list in a fixed column (`fileListWidth`) beside the detail (`rendererMinWidth`), and falls back to a VStack with the full-width list rows on top. In the transcript the HStack wins, so the patch gets only part of the width.

Screens: `~/Library/Caches/AgentViewKit/screenshot-check/thread--light.png` and `thread--dark.png`. Regenerate them with `swift test --filter ReviewGallery`.

## What to do

- [x] Remove the `ViewThatFits` and the side-by-side layout. The view is always a VStack: the file chips first, then the detail (header plus patch) at full width.
- [x] Draw the files as chips in a wrapping flow (a SwiftUI `Layout` that wraps to the next line, or an existing kit flow layout if there is one). Each chip shows the operation symbol, the file name (middle truncation, full path in `.help`) and the +/− counts when there is a patch. Keep each chip a plain button that selects its file, with `selectableSurface` for the selected chip. Keep the accessibility identifiers and the jump scopes of the rows.
- [x] Remove `fileListWidth`, and `rendererMinWidth` if nothing else uses it.
- [x] Spacing comes from theme tokens: the chip gap and the gap between the chips and the detail. Once ^ey6v778 lands with the EditorStyle tile tokens, use those. Until then, use EditorStyle spacing tokens, no literal numbers.
- [x] With one file, show the chip row anyway, so the file name and counts stay visible. If an existing header already shows them, drop the duplicate and record which one you dropped.
- [x] Hosted tests:
  - the detail's width equals the DiffView's width, within layout rounding, at both a narrow and a wide width;
  - the chips are above the detail (chip maxY ≤ detail minY);
  - chips wrap to a second line when they don't fit on one;
  - tapping a chip selects that file.
- [x] Re-record the `__Snapshots__` images that change, and list them.
- [x] Regenerate the review gallery and update `ReviewGalleryNotes.swift` for the thread screen.

## Related

^q89x329 (diff lines wrap out of alignment with the gutter) and ^a2dy2gt (the +/− counts are unreadable in light) touch the same view. Check they still apply after this change.

## Acceptance

- The diff always shows the file chips above and the file content at full width below.
- The hosted layout tests pass, and the full `swift test` is green.
- The gallery shows the new layout. #avk-8