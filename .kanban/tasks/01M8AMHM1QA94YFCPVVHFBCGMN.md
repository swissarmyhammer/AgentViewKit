---
assignees:
- claude-code
position_column: todo
position_ordinal: 8c80
title: Adopt .editorRefreshGeneration for EditorView slot closures whose output changes
---
Request from editorkit-7a (2026-11-25), from EK ^m0ntdb1. After ^m0ntdb1, a no-op `updateNSView` of an `EditorView` does no refresh (1.34 ms → 0.03 ms for each pass). A slot closure whose output changes with no other input change no longer refreshes the view. A text version, selection, presentation, wrap, fold, theme or font change still refreshes on its own. Blocked until the EK sha of ^m0ntdb1 is on EK main.

## What
- [ ] Find each `EditorView` slot closure in `Sources/AgentViewKit` whose output can change with no other input change, for example the `codeBlockHeader` closure of `Sources/AgentViewKit/Code/CodeBlockView.swift` and the header of `Sources/AgentViewKit/Code/BlockHeader.swift`.
- [ ] Give each one `.editorRefreshGeneration(_:)` with a value that increases when the closure output changes, for example a copied-state flag or a run state.
- [ ] Update the EK pin to the sha of ^m0ntdb1.

## Acceptance Criteria
- [ ] A change of the closure output (for example, the Copy button state of a code block header) shows in the editor with no other change.
- [ ] A body pass with no change does no refresh.

## Tests
- [ ] A unit test in `Tests/AgentViewKitTests/Code/` that changes only the slot output (in a window that is never ordered in) and reads the new header content from the accessibility tree.
- [ ] `swift test` passes with 0 failures and 0 warnings. A temp HOME is not possible, because the harness refuses the HOME override.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #perf