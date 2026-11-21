---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m802ghyxp31cqz675mqky4qb
  text: |-
    Research done.
    - `EditorBlockHeader` (EditorBlockChrome.swift) puts the line in the middle of the tile gap under the row, and the line takes no layout space. `CommandOutputView` and `TerminalView` also use it, so it stays. `BlockHeader` uses its `separatorPlacement`.
    - Plan for `BlockHeaderLayout`: three subviews (title, line, buttons). Wide: one row; the line is in the middle of the tile gap under the row, outside the bounds, as now (so `CodeBlockView` keeps its look). Narrow: title, then the line in the middle of a tile gap, then the buttons at the leading edge. The geometry is in pure functions (`fitsOnOneLine`, `frames`, `size`), as `SideCardLayout` does, so a unit test reads it with no view.
    - When the buttons have zero width (the attachment group is off), the layout stays wide.
    - `AttachmentInspector`: each block gets `.inspectorBlockHeader(.hidden)`. Each block is its own one-object `InspectorView` (naming `.byHost`), so the hidden setting holds also in the stacked form. The title keeps `nameIdentifier(of:)`, so the hosted tests that read the name row by its identifier keep working.
  timestamp: 2026-11-21T22:09:29.565517+00:00
- actor: claude-code
  id: 01m803b5effrwgktanx5jas7we
  text: |-
    Implementation landed (TDD: BlockHeaderTests failed first because `BlockHeaderLayout` did not exist, then they passed).
    - New `Sources/AgentViewKit/Code/BlockHeader.swift`: `BlockHeader` and `BlockHeaderLayout`. The geometry is in pure functions (`fitsOnOneLine`, `size(title:actions:width:)` and `frames(title:lineHeight:actions:in:)`). `sizeThatFits` and `placeSubviews` call them. The tests read them on fixed sizes.
    - Wide: the line is in the middle of the tile gap under the row and takes no layout space (as `EditorBlockHeader`), so the look of `CodeBlockView` does not change. Narrow: title, the line in the middle of a tile gap, then the buttons at the leading edge. When the buttons have zero width, the header stays on one line.
    - The `Divider` is in a `VStack`, so it is horizontal also in a horizontal host such as a form row.
    - `EditorBlockHeader.separatorPlacement` is now `nonisolated`, because the `Layout` methods are nonisolated and read it.
    - `AttachmentInspector`: each block has `.inspectorBlockHeader(.hidden)` and a `BlockHeader` in `.actions`. The title keeps `nameIdentifier(of:)`. The `.inspectorBlockHeader(.automatic)` of the stack was removed. The `.named(...)` call now gives `fields:` as a labeled argument (swift format OnlyOneTrailingClosureArgument).
    - `CodeBlockView`: the header is a `BlockHeader`. The imports EditorStyle and EditorTheme are not used now, so I removed them.
    - ScreenshotTests: new image `inspector-attachment-builtin-narrow-one` (window of `narrowWidth`, 240 pt). The wide image `inspector-attachment-builtin-one` stays. RISK: the old PNG shows a 270 pt inspector column. "answer.swift" and the 4 buttons are about 155 pt wide, so the header goes narrow only when the column content is narrower than that. I did not run the gallery (it takes the screen focus), so I cannot say if the 240 pt window gives a column that narrow.
    - Formatter: the repo has no .swift-format, and the code uses 120 columns. I ran `swift format lint --strict` with the default configuration plus lineLength 120 and 2-space indentation on the 7 touched files: 0 findings. The default 100-column configuration also reports the lines of files that I did not change.
  timestamp: 2026-11-21T22:24:01.487607+00:00
- actor: claude-code
  id: 01m803b91sbt4tsb46xnt4kjf7
  text: |-
    ### implement — changed
    - evidence: 7 files — Sources/AgentViewKit/Code/BlockHeader.swift (new), Tests/AgentViewKitTests/Code/BlockHeaderTests.swift (new, 18 tests), Sources/AgentViewKit/Code/CodeBlockView.swift, Sources/AgentViewKit/Code/EditorBlockChrome.swift, Sources/AgentViewKit/Attachments/AttachmentInspector.swift, Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift, ScreenshotTests/Tests/ScreenshotTests/InspectorGallery.swift. `swift test`: 1604 tests in 181 suites passed and 54 tests in 11 suites passed, 0 failures, 0 compiler warnings. `swift build --build-tests` in IntegrationTests and ScreenshotTests: Build complete. swift format lint --strict (lineLength 120): 0 findings.
    - next: /review. The hosted suites and the gallery did not run (screen focus). The user must look at the PNG inspector-attachment-builtin-narrow-one to see if the header is narrow at that width.
  timestamp: 2026-11-21T22:24:05.177829+00:00
- actor: claude-code
  id: 01m803q8g3w3bddt5f1kwctbmv
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD; 5 findings (confirmed 6, refuted 0) — Sources/AgentViewKit/Code/BlockHeader.swift:232, :236, :274, :298; Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift:816 (code-hygiene/magic-numbers-swift). No finding is in a test, so the rule that drops findings on old tests does not apply.
    - next: Replace the magic numbers in BlockHeader.swift and PreviewFixtures.swift with named constants. Remove this cause from all of each file. Then do the review again.
  timestamp: 2026-11-21T22:30:37.827284+00:00
- actor: claude-code
  id: 01m803qw6anhjpsr6apchbp4v8
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 7 files (BlockHeader, CodeBlockView, AttachmentInspector, gallery)
    - test: green — swift test, 1604 tests in 181 suites and 54 tests in 11 suites passed; IntegrationTests and ScreenshotTests build passed (not run)
    - commit: 599dfd86
    - review: findings — Sources/AgentViewKit/Code/BlockHeader.swift:232, :236, :274, :298; Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift:816 (code-hygiene/magic-numbers-swift)
  timestamp: 2026-11-21T22:30:57.994469+00:00
- actor: claude-code
  id: 01m80401dmgqfsmepjwneb0b94
  text: |-
    Iteration 2: the 5 magic-number findings are fixed.
    - The rule `code-hygiene/magic-numbers-swift` is swiftlint `no_magic_numbers` with `allowed_numbers: [0, 1, -1, 100]`. I ran swiftlint with that configuration on the two files. Before: 6 hits (the 5 findings; PreviewFixtures:816 has two literals). After: 0 hits in the whole of each file.
    - BlockHeader.swift: the three `/ 2` are now `* Self.middle` (`nonisolated static let middle: CGFloat = 0.5`, documented). The two row offsets use a new private helper `centeringOffset(of:in:)`. `Parts` reads its subviews by a new `Position` enum (title, line, actions; the raw value is the index), so `dropFirst(2)` is gone. `* 0.5` gives the same value as `/ 2` in binary floating point, so the frames do not change.
    - PreviewFixtures.swift: `[320, 60]` is now `blockHeaderWideWidth` and `blockHeaderNarrowWidth`, each documented; `blockHeaderWidths` lists them.
    - Formatter: the earlier comment is not correct. The repo code agrees with the default swift-format configuration (100 columns). With lineLength 120, the unchanged PreviewFixtures.swift gives 3 RemoveLine findings; with the default configuration it gives 0. So I used the default configuration: `swift format lint --strict` on the two files gives 0 findings.
    - One acceptance item stays open: "The current tests of CodeBlockView and of the attachment inspector pass with no change". Those tests are hosted tests (IntegrationTests: CodeBlockViewHostedTests, AttachmentInspector*HostedTests). The hosted suites take the screen focus, so they did not run. Only a hosted run can tick it.
  timestamp: 2026-11-21T22:35:25.492004+00:00
- actor: claude-code
  id: 01m804059jnkvhjw3f3dpdt0yw
  text: |-
    ### implement — changed
    - evidence: 2 files — Sources/AgentViewKit/Code/BlockHeader.swift, Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift. swiftlint no_magic_numbers (rule configuration): 0 hits in the two files. `swift test`: 1604 tests in 181 suites and 54 tests in 11 suites passed, 0 failures, 0 compiler warnings (BlockHeaderTests passed). `swift build --build-tests` in IntegrationTests and ScreenshotTests: Build complete (suites not run). `swift format lint --strict` (default configuration) on the two files: 0 findings. The build shows the known SwiftPM line "missing creator for mutated node ... mlx-swift_Cmlx.bundle"; it is not from this change. 5 of 5 findings ticked; 10 of 11 subtasks ticked.
    - next: /review. Open: the acceptance item on the current hosted tests of CodeBlockView and the attachment inspector needs a hosted run.
  timestamp: 2026-11-21T22:35:29.458326+00:00
position_column: doing
position_ordinal: '80'
title: One shared block header (title, buttons, line) for the code block and the attachment inspector
---
## What
Two views show a block header with a title, buttons and a line, but each one does it in its own way:
- ``CodeBlockView`` (`Sources/AgentViewKit/Code/CodeBlockView.swift`, the `header` property): an `HStack` with the title, a `Spacer` and the Copy button, then `.editorBlockHeader()` (`Sources/AgentViewKit/Code/EditorBlockChrome.swift`) draws the line under the row.
- ``AttachmentInspector`` (`Sources/AgentViewKit/Attachments/AttachmentInspector.swift`, `block(of:)`): the EditorKit `InspectorView` draws the file name as one row of its grouped form (`../EditorKit/Sources/EditorInspector/InspectorForm.swift`), the form draws a row line, and ``AttachmentActions`` (`Sources/AgentViewKit/Attachments/AttachmentActions.swift`) is the next row. The snapshot `inspector-attachment-builtin-one` (`ScreenshotTests/Tests/ScreenshotTests/InspectorGallery.swift`, `recordBuiltInAttachmentInspector`) shows it.

The user decided (2026-11-21): one shared component in AgentViewKit, with the same spacing and padding in each place.
- Wide: one line with the title on the leading side and the buttons on the trailing side, then the line under it (the code block style).
- Narrow (the title and the buttons do not fit on one line): the title, then the line, then the buttons.

- [x] Add `Sources/AgentViewKit/Code/BlockHeader.swift`: `struct BlockHeader<Title: View, Actions: View>: View` with `init(@ViewBuilder title:, @ViewBuilder actions:)`. Lay it out with a custom `Layout` (`BlockHeaderLayout`) that puts the line in the place that the user decided. Put the decision in a pure static function, `BlockHeaderLayout.fitsOnOneLine(titleWidth:actionsWidth:spacing:available:) -> Bool`, so a unit test can check it. Take the spacing from `\.editorStyle` (`spacing.s` between the title and the buttons, `tile.gap` around the line, as `EditorBlockHeader` does now) and the title font and color from ``CodeBlockView`` (`editorTheme.font(for: .ui, style: .caption)`, `themeSecondary`, one line, middle truncation).
- [x] Use ``BlockHeader`` in ``CodeBlockView``. The Copy button keeps its accessibility identifier `CodeBlockView.copyIdentifier`.
- [x] Use ``BlockHeader`` in each block of ``AttachmentInspector``: hide the EditorKit name row (`.inspectorBlockHeader(.hidden)`) and give `.actions { BlockHeader { file name } actions: { AttachmentActions(...) } }`. The file name keeps an accessibility identifier, and each block still names its file (also in the stacked form of several files).

## Acceptance Criteria
- [x] `BlockHeaderLayout.fitsOnOneLine` returns `true` when title width + spacing + actions width is not more than the available width, and `false` when it is more.
- [x] In a wide layout, the title and the buttons have the same vertical center, and the line is below both.
- [x] In a narrow layout, the title is above the line, and the buttons are below the line.
- [x] ``CodeBlockView`` and ``AttachmentInspector`` both show their header through ``BlockHeader`` (no other title-plus-buttons row in the two files).
- [ ] The current tests of ``CodeBlockView`` and of the attachment inspector pass with no change, except the expected identifiers of the name row if they move.

## Tests
- [x] New `Tests/AgentViewKitTests/Code/BlockHeaderTests.swift`: `fitsOnOneLine` at the limit, below it and above it; and the frames that `BlockHeaderLayout.placeSubviews` gives in each case (title, line, buttons), with a test `LayoutSubview` proxy or with `sizeThatFits` and `placeSubviews` on fixed sizes.
- [x] `ScreenshotTests/Tests/ScreenshotTests/InspectorGallery.swift`: add a narrow width of `inspector-attachment-builtin-one`, and keep the wide one, so the user can review both PNGs. Only compile it (`cd ScreenshotTests && swift build --build-tests`).
- [x] Run `swift test` in the repo root. Expected: all tests pass, 0 failures.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
- Run only the headless `swift test`. Do not run the IntegrationTests or ScreenshotTests suites (they take the screen focus); a build of them is allowed.

## Review Findings (2026-11-21 16:28)

> Scope: `review sha HEAD~1..HEAD`. The review examined only the lines that this change added or changed. It examined 7 files. It did not examine 4 files.

> 4 files are not examined because an ignore rule excludes them:
> - `.kanban/ (from .reviewignore)` — 4 files

- [x] `Sources/AgentViewKit/Code/BlockHeader.swift:232` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants. Replace the magic numbers with named constants.
- [x] `Sources/AgentViewKit/Code/BlockHeader.swift:236` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants. Replace the magic numbers with named constants.
- [x] `Sources/AgentViewKit/Code/BlockHeader.swift:274` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants. Replace the magic numbers with named constants.
- [x] `Sources/AgentViewKit/Code/BlockHeader.swift:298` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants. Replace the magic numbers with named constants.
- [x] `Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift:816` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants. Replace the magic numbers with named constants.
