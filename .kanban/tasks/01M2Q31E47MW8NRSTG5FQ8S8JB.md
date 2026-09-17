---
assignees:
- claude-code
position_column: doing
position_ordinal: '8180'
title: 'DiffView: use the EditorKit DiffView accessibility identifiers'
---
EditorKit main (commit 11ad7d1, origin 38d05a4) now gives the EditorSwiftUI `DiffView` public accessibility identifiers:
- `DiffView.accessibilityIdentifier` = "editor.diff" (the root, in both layouts)
- `DiffView.oldColumnAccessibilityIdentifier` = "editor.diff.old"
- `DiffView.newColumnAccessibilityIdentifier` = "editor.diff.new"

EditorKit sets these identifiers on the AppKit host views (`NSView.accessibilityIdentifier()`), not through the SwiftUI modifier. EditorTestSupport has `HostedWindow.views(withAccessibilityIdentifier:in:)` to find them.

Today `EditorKitDiffRenderer` puts its own identifier `diff-editor-renderer` on the EditorKit view, because EditorKit had none.

## Work
- Update the EditorKit pin (`swift package update EditorKit`) so that the new identifiers are available.
- In the diff tests, find the EditorKit view by its EditorKit identifiers (the root, and the two columns in the side-by-side layout).
- Decide if `DiffView.editorRendererIdentifier` (`diff-editor-renderer`) is still necessary. Remove it if no code needs it.

## Acceptance
- [ ] The hosted diff tests find the EditorKit view by `editor.diff`.
- [ ] A test of the side-by-side layout finds `editor.diff.old` and `editor.diff.new`.
- [ ] `swift test` passes with no new warnings.