---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5m60y7xpx93y2zr7jgjz3ae
  text: |-
    From editorkit-28 (2026-10-23), for SingleLineField:
    - `.editorTextAccessibilityIdentifier(_:)` (d4c767f) puts the id on the NSTextView; keep each replaced field's accessibility identifier that way.
    - SingleLineField has its OWN nested `editor:` command scope. Landing focus on an OUTER scope around it (a request card's item scope, for example) focuses the outer scope, not the field: that's the user's nested-scope rule. Landing on the field's own scope focuses the field. So a jump onto a permission card or elicitation card no longer puts the caret in its text field; check any AVK tests or behaviour that expect it, and keep the user's rule.
    - EditorKit f913e78 or later is needed.
  timestamp: 2026-10-23T10:48:35.325462+00:00
- actor: claude-code
  id: 01m5n7r8eygprrez36713r0bmg
  text: |-
    Picked up. Research results before any code change:
    - EditorKit pin 0222582 has f913e78 and d4c767f. No pin change is necessary.
    - One-line `TextField(` in Sources/AgentViewKit: PermissionView comment field (Return calls sendReject), SessionListView search field (no onSubmit, the text filters the rows), ElicitationNumberField stepper input (`TextField(value:format: .number)`). `ElicitationTextField` already uses `SingleLineField` (with no Return action today). No other one-line TextField.
    - CONFLICT with the card: EditorKit 781f2fe (^a54d840, after this card was written) changed SingleLineField. Esc now commits the edit and drills out (`nav.drillOut`); "No key discards the draft". Revert Field is the command `editor.revertField` on Control-Command-Z (`StandardChords.revertField`). `.onSubmit` was removed; the host hears each end of an edit with `.onEditorCommit(_:)` and a reason (`.submit`, `.submitNow`, `.leave`, `.focusLoss`). So the card requirement "reverts on Esc" cannot be done with the current EditorKit contract.
    - SingleLineField has no API for a formatted value (no parse, no format, no revert of an input that is not valid). Per the card, the number field stays on its TextField with a note, and the gap goes to editorkit-28.
    - PermissionView has `.onExitCommand { startCancelPermission }`. With a SingleLineField in the card, Esc in the field commits and drills out; it does not cancel the request. Esc on the card (focus outside the field) still cancels.
    - No snapshot shows the comment row or the session list, so no snapshot change is expected.
  timestamp: 2026-10-23T20:38:02.462092+00:00
- actor: claude-code
  id: 01m5n8aex4s51mv267qnrvarj8
  text: |-
    Implementation landed (not committed).
    - New `OneLineTextField` (Sources/AgentViewKit/Input/OneLineTextField.swift): a `SingleLineField` that edits a `String` binding, with `.editorPlaceholder`, `.editorTextAccessibilityIdentifier`, `.editorTextAccessibilityLabel`, and `.onEditorCommit`. Return and Command-Return call `onSubmit` with the commit text. Also `TextInputOutline` / `.textInputOutline()`, now shared with `ElicitationTextField`.
    - `OwnModelSlot` takes a model factory; `OwnModelSlot.makeEditable()` replaces the private `TextFieldModelSlot` of ElicitationFieldViews.swift.
    - PermissionView comment field and SessionListView search field use `OneLineTextField`. Same `@State` binding, same identifiers (`permission-comment`, `session-list-search`), now on the NSTextView. Return in the comment field still sends the reject with the comment.
    - ElicitationNumberField keeps its `TextField(value:format:)` with a code note. GAP for editorkit-28: SingleLineField has no formatted value (no parse, no format, no revert of a text that is not a number).
    - ElicitationTextField was already a SingleLineField; no change other than the shared outline and slot.
    - Behaviour change: Esc in the comment field now commits and drills out (EditorKit rule). It no longer cancels the request. Esc on the card still cancels.
    - In the demo, SessionListView is not under a root `.commandScope`, so its search field undoes on its own stack there, not on a window stack. Not changed here.
    - Tests: new PermissionCommentFieldHostedTests (5), SessionSearchFieldHostedTests (5 cases), 2 new focus tests in AgentNavigationHostedTests (3 cases: nav and jump onto the card focus the card and not the field; a landing on the field scope focuses the field). Existing comment and search tests now find the NSTextView by identifier. RED: 14 issues, each "views.count == 1" (no EditorKit text view). GREEN: 18 tests in 3 suites passed.
  timestamp: 2026-10-23T20:47:58.884489+00:00
- actor: claude-code
  id: 01m5n8apzc1d6e07ewa3c8x93z
  text: |-
    BLOCKER (a person must decide): the card requires "Esc reverts" and a hosted test "reverts on Esc". The current EditorKit contract (781f2fe, ^a54d840, KanbanViewKit plan §6.6) says Esc commits the edit and drills out, and "No key discards the draft". Revert is Revert Field (`editor.revertField`, Control-Command-Z). AVK cannot make Esc revert without a fight with EditorKit.
    What this pass did instead: each replaced field has a hosted test that Revert Field (by its chord, through the window registry) puts back the focus-in text, and a test that Esc keeps the text (comment field: the request stays pending; search field: the filter stays).
    Decision needed: accept "revert = Revert Field (Control-Command-Z); Esc commits" as the meaning of the card, or ask EditorKit for an Esc that reverts.
  timestamp: 2026-10-23T20:48:07.148467+00:00
- actor: claude-code
  id: 01m5n8aw4x1ypk8ztmzs0ggrsn
  text: |-
    ### implement — stuck
    - evidence: 12 files. New: Sources/AgentViewKit/Input/OneLineTextField.swift, Tests/AgentViewKitTests/Helpers/OneLineFieldHarness.swift, Tests/AgentViewKitTests/HumanInTheLoop/PermissionCommentFieldHostedTests.swift, Tests/AgentViewKitTests/Sessions/SessionSearchFieldHostedTests.swift. Changed: Sources/AgentViewKit/Code/OwnModelSlot.swift, Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift, Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift, Sources/AgentViewKit/Sessions/SessionListView.swift, Tests/AgentViewKitTests/Commands/AgentNavigationHostedTests.swift, Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift, Tests/AgentViewKitTests/HumanInTheLoop/PermissionViewHostedTests.swift, Tests/AgentViewKitTests/Sessions/SessionPickerConnectionModelHostedTests.swift. `swift test`: 1714 tests in 211 suites passed (3 known issues, all existing), and 227 tests in 30 suites passed. `xcodebuild ... -scheme AgentViewKitDemo build`: BUILD SUCCEEDED. No snapshot changed. No EditorKit pin change.
    - gap: the card requirement "reverts on Esc" conflicts with the EditorKit contract (Esc commits; Revert Field is Control-Command-Z). See the BLOCKER comment.
    - next: a person decides the Esc rule; then /review.
  timestamp: 2026-10-23T20:48:12.445961+00:00
position_column: doing
position_ordinal: '8380'
title: Replace one-line SwiftUI TextFields with EditorKit SingleLineField
---
User decision (2026-10-23, relayed by editorkit-28): a one-line editor uses EditorKit's one-line mode, not a SwiftUI text field. `SingleLineField` (EditorSwiftUI): lineLimit 1, Return submits via onSubmit, Esc reverts, paste flattens newlines; it has full window-stack undo and redo (EK-6).

Candidates named by editorkit-28 (confirm each and search for more `TextField(` in Sources/AgentViewKit):
- `Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift:342` (the permission comment field)
- `Sources/AgentViewKit/Sessions/SessionListView.swift:166`
- `ElicitationTextField` (elicitation string fields)
- `Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift:340`, a number field. If SingleLineField can't host a formatted number (parse, format, invalid input), don't fake it: report the gap to editorkit-28 and keep that one field on its current control, with a note, until EditorKit supports it.

Keep behaviour:
- the same binding and validation;
- Return submits where it submits today;
- the elicitation error display from ^r8bnszx (errors after an edit or a submit attempt);
- accessibility labels and identifiers;
- the ^cwdb5zg focus behaviour, under the item scopes.

Tests:
- hosted tests that each replaced field edits, submits on Return, reverts on Esc and undoes on the window stack;
- the existing elicitation and permission tests stay green, and the snapshots are re-recorded only where the look changes, listed by name.
Full `swift test` green; the demo builds. #avk-7