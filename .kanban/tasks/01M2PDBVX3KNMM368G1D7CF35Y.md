---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m2pdy19tjqyhg85w5ta6hnva
  text: |-
    ### finish iteration 1 — done
    - implement: EditorKit pin is f521c2d. EditorKitPromptEditor uses `onReturnKey: { modifiers in ... }`. The `NSApp.currentEvent` read, the SwiftUI Return key handler and the delayed Command-Return send are removed. The editor ignores a prompt change that is its own newest push (a late echo removed the Shift-Return newline). New `HostedViewHarness.sendKeyDown(_:modifiers:to:)`.
    - test: `swift test` passed. AgentViewKitTests 953, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 22, AgentViewKitFoundationModelsTests 1. No new warnings.
    - commit: c016ba0
    - review: `review sha HEAD~1..HEAD`, 0 findings. Clean.
  timestamp: 2026-09-17T00:58:12.154621+00:00
position_column: done
position_ordinal: b280
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
- [x] No code reads `NSApp.currentEvent` in `Sources/AgentViewKit/Input/`.
- [x] No deprecated `onReturnKey` form is used.
- [x] The hosted tests send the Return, Shift-Return and Command-Return key events through the text view `keyDown(with:)`, as EditorKit `Tests/EditorSwiftUIHostedTests/ReturnKeyHostedTests.swift` does. All three tests pass.

## Review Findings (2026-09-16 19:55)

Scope: `review sha HEAD~1..HEAD` (commit c016ba0). 3 files reviewed. 7 validator runs. 0 findings. The review is clean.