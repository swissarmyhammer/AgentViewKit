---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8b0zh0vdg4cf4dxfjjbsds0
  text: |-
    ### implement — no-change (no place needs the modifier)
    - evidence: an audit of Sources/AgentViewKit on EK 44b9f941. The code block, BlockHeader, diff and tool output headers are SwiftUI views beside the editor, not slots, so EK refresh does not apply to them. The real slots need no generation:
      - RenderedMarkdownView `.editorCodeBlockHeader` uses only `block`, which comes from the document.
      - `.citing`, `.transcriptSearchMarks` and `.editorInlineDecorations` are providers that EK asks again.
      - The gutter, the placeholder and the accessibility strings are compared values.
    - result: no RED test is possible, so the source does not change. The root swift test passes on EK 44b9f941: 1779 + 59 tests.
    - other: the IntegrationTests build on EK main needed a fix, because EK e5e3c164 removed ScopeFocusRingWeight. The fix is 8c67fd9a (BarButtonFocusRingHostedTests.swift:103), and it is merged into main.
    - outcome: done, because the card's change is not needed. If EK adds a slot whose output depends on host state, open a new card.
  timestamp: 2026-11-26T04:14:21.723433+00:00
position_column: done
position_ordinal: ffffffffb080
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