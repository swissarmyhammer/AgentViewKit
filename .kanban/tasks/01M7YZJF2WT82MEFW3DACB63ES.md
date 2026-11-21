---
assignees:
- claude-code
position_column: todo
position_ordinal: '8480'
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