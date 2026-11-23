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
position_column: doing
position_ordinal: '80'
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
- [ ] `AgentRowSection(id:title:items:detail:)` exists, and the old init call compiles with no change.
- [ ] A section with a detail shows the title and the detail in its header; a section with no detail shows the same header as before.
- [ ] At a narrow width, the title stays whole and the detail truncates or moves; the header never pushes the list wider.
- [ ] The VoiceOver label of the header is "<title>, <detail>" when a detail exists, else "<title>"; the trait `.isHeader` stays.
- [ ] The arrow keys, the jump labels and the mouse pass the header by, as before.

## Tests
- [ ] Unit tests first (headless `swift test`), in a new file /Users/wballard/github/swissarmyhammer/AgentViewKit/Tests/AgentViewKitTests/Lists/AgentRowSectionHeaderTests.swift: `entries(of:id:)` carries the detail into the header entry; a section with no detail gives `detail == nil`; the accessibility label of the header (find it as `AgentRowListRowLabelTests` finds a row label) is "Other Agents, Reading 1,240 of 4,427", and is "Recent" with no detail.
- [ ] Screenshot gallery screen in /Users/wballard/github/swissarmyhammer/AgentViewKit/ScreenshotTests/Tests/ScreenshotTests: a list with a section "Other Agents" and the detail "Reading 1,240 of 4,427", at the normal width and at a narrow width (add the snapshots in HostedSnapshotTests.swift, as `chip-rows-narrow` does). Run: `HOME=$(mktemp -d) swift test --package-path ScreenshotTests`. Give the PNG paths for review.
- [ ] `swift test` passes with no new warning.

## Workflow
- Use /tdd -- write failing tests first, then implement to make them pass. #d212