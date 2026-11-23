---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m84r0nejqgcv1t8pk21er4s5
  text: 'Research: `AgentRowListEntry.header` is matched in two places only (the `id` switch in AgentRowSection.swift and the `ForEach` switch in AgentRowList.swift). `AgentRowSection(id:title:items:)` is called in AgentRowList.swift previews and in two hosted test files; a default `detail: String? = nil` keeps them. The unit test reads the header element with `accessibilityElements(identifiedAs:under:includingScrollAreas:)` from EditorTestSupport, as `AgentRowListRowLabelTests` does. The hosted test `voiceOverHearsTheHeaderAsAHeading` reads role "AXHeading"; the unit test also reads the role with `accessibilityRole(of:)`, so no hosted run is necessary. The gallery fixture will follow `ChipRowsGalleryFixtures` and use `SnapshotFixtures.narrowWidth`.'
  timestamp: 2026-11-23T17:42:15.250438+00:00
- actor: claude-code
  id: 01m84rmgjqvpr5vde6v4kzfgy9
  text: |-
    ### implement — changed
    - evidence: TDD. RED 1: the new tests did not compile (no `detail`). RED 2: after the model change, `theHeaderReadsItsTitleAndItsDetail` failed (label "Other Agents" only). GREEN: 5/5 in AgentRowSectionHeaderTests. Headless `swift test`: 1645 tests in 186 suites and 54 tests in 11 suites passed, no code warning (only the build-system note "missing creator for mutated node" of mlx-swift, which existed before). Gallery `swift test --package-path ScreenshotTests` with a temp HOME: 42 tests in 4 suites passed. No hosted IntegrationTests run: no hosted test changed.
    - layout: `ViewThatFits(in: .horizontal)` with the title and the detail on one line, else the title above the detail. The title has `.lineLimit(1)` and `.layoutPriority(1)`; the detail has `.lineLimit(1)`, `.truncationMode(.tail)` and `.monospacedDigit()`. A section with no detail shows the title alone. The header is one element (`.accessibilityElement(children: .combine)`) with `.isHeader` and its identifier; a unit test reads the role "AXHeading".
    - files: Sources/AgentViewKit/Lists/AgentRowSection.swift, Sources/AgentViewKit/Lists/AgentRowList.swift, Tests/AgentViewKitTests/Lists/AgentRowSectionHeaderTests.swift (new), ScreenshotTests/Tests/ScreenshotTests/RowSectionGalleryFixtures.swift (new), ScreenshotTests/Tests/ScreenshotTests/HostedSnapshotTests.swift.
    - PNGs: ~/Library/Caches/AgentViewKit/screenshot-check/generated/HostedSnapshotTests/row-sections-{light,dark}.png and row-sections-narrow-{light,dark}.png. At 420 pt the detail stands after the title; at 180 pt it moves below the title.
    - next: /review.
  timestamp: 2026-11-23T17:53:05.623137+00:00
- actor: claude-code
  id: 01m84rs2bvdy3jm1b7tm8hvbpd
  text: |-
    ### review — findings
    - evidence: `review sha HEAD~1..HEAD` on commit 48d6b82f. Counts: 1 finding, 1 confirmed, 0 refuted (7 attempted, 0 failed). Finding: ScreenshotTests/Tests/ScreenshotTests/HostedSnapshotTests.swift:223 `duplication/duplication`. The 8 card boxes are ticked. The evidence is the implement comment (headless `swift test`: 1645 tests in 186 suites and 54 tests in 11 suites pass; gallery: 42 tests in 4 suites pass), the four row-sections PNGs in ~/Library/Caches/AgentViewKit/screenshot-check/generated/HostedSnapshotTests/, and the diff (AgentRowList.swift changes only the header case and the preview, so no row, focus segment or jump label is added).
    - next: /implement removes the copied generate call in HostedSnapshotTests.swift (one helper for the two row-sections tests), then /review again.
  timestamp: 2026-11-23T17:55:34.907662+00:00
- actor: claude-code
  id: 01m84rzjmv4p1gf15qrp8vrfgc
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 5 files
    - test: green — swift test 1645 + 54; gallery 42
    - commit: 48d6b82f
    - review: findings — ScreenshotTests/Tests/ScreenshotTests/HostedSnapshotTests.swift:223

    ### implement — changed
    - evidence: the two gallery tests are now one test with two arguments (name, size). The size constants of RowSectionGalleryFixtures and SnapshotFixtures.narrowWidth are nonisolated, so the test arguments can read them. Gallery: 41 tests in 4 suites passed (the two cases count as one test); row-sections and row-sections-narrow PNGs are new (11:58).
    - next: commit, then review.
  timestamp: 2026-11-23T17:59:08.187696+00:00
- actor: claude-code
  id: 01m84s1pg18m9fxk5jd212msgq
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` on commit 3f848759. Counts: 0 findings, 0 confirmed, 1 refuted (7 attempted, 0 failed). 3 files reviewed; 2 .kanban files excluded by .reviewignore. All items of the earlier Review Findings section are checked.
    - next: none. The task moved to done.
  timestamp: 2026-11-23T18:00:17.665783+00:00
position_column: done
position_ordinal: ffffffff9480
title: AgentRowSection header shows a secondary text for progress
---
## What
TestudoApp decision D212 (design /Users/wballard/github/swissarmyhammer/TestudoApp/features/session-import-redesign.md, 5.1 and 6, row "AgentViewKit"): while the index reads the files of a folder, the header of the section "Other Agents" shows the text "Reading 1,240 of 4,427". The kit must let a section header of `AgentRowList` show a secondary text.

Change these files:
- /Users/wballard/github/swissarmyhammer/AgentViewKit/Sources/AgentViewKit/Lists/AgentRowSection.swift
  - `AgentRowSection<Item>`: add `public let detail: String?` (the secondary text, already localized, `nil` for no text). Add a parameter `detail: String? = nil` to `init(id:title:items:)`, so each current caller stays the same.
  - `AgentRowListEntry.header(sectionID:title:)`: add `detail: String?`. Update `entries(of:id:)` and the `id` switch.
  - `AgentRowSectionHeader`: add `let detail: String?`. Show the title and, after it, the detail in the same font role (`.ui`, `.subheadline`), regular weight, `.secondary` style, with `.monospacedDigit()` so the numbers do not move while they change.
  - Narrow width: the title keeps one line and has the higher layout priority. The detail has one line and truncates at its tail. Use `ViewThatFits` (title and detail on one line; else the title only, or the title above the detail). Pick the simplest of these that keeps the title whole, and state it in the doc comment.
  - VoiceOver: the header is one element (`.accessibilityElement(children: .combine)` or an explicit label) and reads "<title>, <detail>". It keeps the trait `.isHeader` and its identifier.
- /Users/wballard/github/swissarmyhammer/AgentViewKit/Sources/AgentViewKit/Lists/AgentRowList.swift: pass the detail from the entry to `AgentRowSectionHeader` (near line 334). Update the `#Preview("Sections")` with one section that has a detail.

A header is no row: the change must not add a row, a focus segment or a jump label. Do not change Sources/AgentViewKit/StatusLine/*.

## Acceptance Criteria
- [x] `AgentRowSection(id:title:items:detail:)` exists, and the old init call compiles with no change.
- [x] A section with a detail shows the title and the detail in its header; a section with no detail shows the same header as before.
- [x] At a narrow width, the title stays whole and the detail truncates or moves; the header never pushes the list wider.
- [x] The VoiceOver label of the header is "<title>, <detail>" when a detail exists, else "<title>"; the trait `.isHeader` stays.
- [x] The arrow keys, the jump labels and the mouse pass the header by, as before.

## Tests
- [x] Unit tests first (headless `swift test`), in a new file /Users/wballard/github/swissarmyhammer/AgentViewKit/Tests/AgentViewKitTests/Lists/AgentRowSectionHeaderTests.swift: `entries(of:id:)` carries the detail into the header entry; a section with no detail gives `detail == nil`; the accessibility label of the header (find it as `AgentRowListRowLabelTests` finds a row label) is "Other Agents, Reading 1,240 of 4,427", and is "Recent" with no detail.
- [x] Screenshot gallery screen in /Users/wballard/github/swissarmyhammer/AgentViewKit/ScreenshotTests/Tests/ScreenshotTests: a list with a section "Other Agents" and the detail "Reading 1,240 of 4,427", at the normal width and at a narrow width (add the snapshots in HostedSnapshotTests.swift, as `chip-rows-narrow` does). Run: `HOME=$(mktemp -d) swift test --package-path ScreenshotTests`. Give the PNG paths for review.
- [x] `swift test` passes with no new warning.

## Workflow
- Use /tdd -- write failing tests first, then implement to make them pass. #d212

## Review Findings (2026-11-23 11:53)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 5 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `ScreenshotTests/Tests/ScreenshotTests/HostedSnapshotTests.swift:223` `duplication/duplication` — The test theSectionHeadersOfARowListInANarrowColumn repeats the body of theSectionHeadersOfARowList (line 214) line for line. The two tests differ only by a literal name ("row-sections" or "row-sections-narrow") and by a size constant (RowSectionGalleryFixtures.size or narrowSize). Two copies of one generate call can drift apart, and each new width needs another copy. Extract one helper, for example `generateRowSections(named:size:)`, that calls `Self.generate(RowSectionGalleryFixtures.gallery, named: named, size: size)`. Call it from both tests with their own name and size. Alternatively, keep both tests and accept the copy as a test-only convention, since the rest of this file uses the same one-call pattern per fixture.
