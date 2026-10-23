---
assignees:
- claude-code
position_column: todo
position_ordinal: a980
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