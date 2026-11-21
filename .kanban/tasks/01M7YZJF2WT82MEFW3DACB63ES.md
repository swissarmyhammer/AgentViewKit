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

- [ ] Add `Sources/AgentViewKit/Code/BlockHeader.swift`: `struct BlockHeader<Title: View, Actions: View>: View` with `init(@ViewBuilder title:, @ViewBuilder actions:)`. Lay it out with a custom `Layout` (`BlockHeaderLayout`) that puts the line in the place that the user decided. Put the decision in a pure static function, `BlockHeaderLayout.fitsOnOneLine(titleWidth:actionsWidth:spacing:available:) -> Bool`, so a unit test can check it. Take the spacing from `\.editorStyle` (`spacing.s` between the title and the buttons, `tile.gap` around the line, as `EditorBlockHeader` does now) and the title font and color from ``CodeBlockView`` (`editorTheme.font(for: .ui, style: .caption)`, `themeSecondary`, one line, middle truncation).
- [ ] Use ``BlockHeader`` in ``CodeBlockView``. The Copy button keeps its accessibility identifier `CodeBlockView.copyIdentifier`.
- [ ] Use ``BlockHeader`` in each block of ``AttachmentInspector``: hide the EditorKit name row (`.inspectorBlockHeader(.hidden)`) and give `.actions { BlockHeader { file name } actions: { AttachmentActions(...) } }`. The file name keeps an accessibility identifier, and each block still names its file (also in the stacked form of several files).

## Acceptance Criteria
- [ ] `BlockHeaderLayout.fitsOnOneLine` returns `true` when title width + spacing + actions width is not more than the available width, and `false` when it is more.
- [ ] In a wide layout, the title and the buttons have the same vertical center, and the line is below both.
- [ ] In a narrow layout, the title is above the line, and the buttons are below the line.
- [ ] ``CodeBlockView`` and ``AttachmentInspector`` both show their header through ``BlockHeader`` (no other title-plus-buttons row in the two files).
- [ ] The current tests of ``CodeBlockView`` and of the attachment inspector pass with no change, except the expected identifiers of the name row if they move.

## Tests
- [ ] New `Tests/AgentViewKitTests/Code/BlockHeaderTests.swift`: `fitsOnOneLine` at the limit, below it and above it; and the frames that `BlockHeaderLayout.placeSubviews` gives in each case (title, line, buttons), with a test `LayoutSubview` proxy or with `sizeThatFits` and `placeSubviews` on fixed sizes.
- [ ] `ScreenshotTests/Tests/ScreenshotTests/InspectorGallery.swift`: add a narrow width of `inspector-attachment-builtin-one`, and keep the wide one, so the user can review both PNGs. Only compile it (`cd ScreenshotTests && swift build --build-tests`).
- [ ] Run `swift test` in the repo root. Expected: all tests pass, 0 failures.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
- Run only the headless `swift test`. Do not run the IntegrationTests or ScreenshotTests suites (they take the screen focus); a build of them is allowed.