---
assignees:
- claude-code
position_column: doing
position_ordinal: '8180'
title: 'EditorKitPromptEditor: use the EditorKit Return hook with modifier keys'
---
EditorKit main (commit 6f40b85, origin f521c2d) now gives the `EditorView` Return hook the modifier keys, and it sends Command-Return to that hook.

The new API:
- `ReturnKeyModifiers` (an OptionSet in EditorText) has `.shift`, `.control`, `.option` and `.command`.
- `EditorView.init(model:lineHeight:onEscapeKey:onReturnKey: ((ReturnKeyModifiers) -> Bool)?)`. The old `() -> Bool` form is deprecated.
- An open completion session still gets Return before the host hook.

Today `EditorKitPromptEditor` reads `NSApp.currentEvent` to get the modifier keys, and it sends Command-Return on the next pass of the main loop. The tests cannot exercise this workaround, because `NSApp.currentEvent` is empty in tests.

## Work
- Update the EditorKit package pin (`swift package update EditorKit`) so that the new API is available.
- Change `EditorKitPromptEditor` to use `onReturnKey: { modifiers in ... }`. Remove the `NSApp.currentEvent` read and the delayed Command-Return send.
- Keep the behavior the same: Return submits, Shift-Return adds a newline (return `false`), and Command-Return sends at once.

## Acceptance
- [ ] No code reads `NSApp.currentEvent` in `Sources/AgentViewKit/Input/`.
- [ ] No deprecated `onReturnKey` form is used.
- [ ] The hosted tests send the Return, Shift-Return and Command-Return key events through the text view `keyDown(with:)`, as EditorKit `Tests/EditorSwiftUIHostedTests/ReturnKeyHostedTests.swift` does. All three tests pass.