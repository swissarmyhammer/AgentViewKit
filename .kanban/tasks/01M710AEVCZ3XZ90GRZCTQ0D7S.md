---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: The leading symbol of each row uses the symbol column of the style
---
## Problem
EditorKit main has `EditorStyle.symbolColumnWidth` (22 pt default) and `.symbolColumn()` (module EditorStyle) for the leading SF Symbol of a row (peer editorkit-9f, 2026-11-09). Some AVK rows put a symbol before their text with a private width (for example `TaskListView.statusSymbolWidth = 16`) or with no fixed width. Then the text of different rows does not line up.

## Work
- Update the EditorKit pin (gitignored Package.resolved files) to EK main.
- Find each AVK row that puts an SF Symbol before its text: TaskListView, the tool call row, the terminal row, the banners, the attachment chips, the plan rows and the others.
- Replace the private width or the missing width with `.symbolColumn()`. Remove the private width constants.
- Update the tests that read the old widths.

## Acceptance
- [ ] No AVK row gives its leading symbol a private width.
- [ ] A headless unit test or a layout test proves that the rows use the width of the style.
- [ ] The root `swift test` passes. `swift build --package-path IntegrationTests --build-tests` and `swift build --package-path ScreenshotTests --build-tests` pass.
- [ ] Do NOT run windowed tests or the gallery.