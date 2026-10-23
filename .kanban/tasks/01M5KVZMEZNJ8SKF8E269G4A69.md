---
assignees:
- claude-code
position_column: todo
position_ordinal: a880
title: 'Drop StockPromptEditor: EditorKitPromptEditor is the only composer (no TextEditor<AttributedString>)'
---
User decision (2026-10-23, relayed by editorkit-28): "we should never be using TextEditor<AttributedString> at all, if we need a one line editor, we need a one line mode of our editor kit editor."

Why: a plain SwiftUI `TextEditor<AttributedString>` can't redo undone typing on macOS 27.0.1, even without EditorKit, because SwiftUI's write-back after an undo clears redo. EditorKit card ^2x162ch closed with no workaround. `EditorKitPromptEditor` (an EditorView) has full window-stack undo and redo.

Work:
- Remove `StockPromptEditor` (`Sources/AgentViewKit/Input/StockPromptEditor.swift`) and every way to select it: composer slots, options, previews, demo settings and docs. `EditorKitPromptEditor` becomes the only composer. No backward-compatibility shim (ARCHITECTURE.md).
- Remove or adapt the tests that cover StockPromptEditor. That includes the StockPromptEditor cases and the `withKnownIssue` redo limit in `ComposerWindowUndoHostedTests` (^m1wgq3k). Keep the EditorKitPromptEditor cases, and add a real redo assertion for it (⇧⌘Z / `edit.redo` re-applies undone typing).
- If the public API names the stock editor (a public type or an enum case), remove it, and note the break for hosts. testudoapp-2c must know before the push.
- Search Sources, Tests, Examples and the docs for `TextEditor` and remove every other `TextEditor<AttributedString>` use too.
- Full `swift test` green; the demo builds. #avk-7