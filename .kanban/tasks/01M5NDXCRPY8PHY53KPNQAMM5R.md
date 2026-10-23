---
assignees:
- claude-code
position_column: todo
position_ordinal: b380
title: 'Elicitation number field: SingleLineField(value:format:) instead of TextField(value:format:)'
---
Follow-up to ^8zmkh1a, which kept `ElicitationNumberField` (Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift) on SwiftUI `TextField(value:format: .number)` inside a Stepper, because SingleLineField had no number form. The user's rule: "if we need a one line editor, we need a one line mode of our editor kit editor". EditorKit ^99zb1dt landed on main at d4d057c (code 954b559, 138a38e).

## EditorKit API (from editorkit-28)
- `SingleLineField(model:id:value:format:lineHeight:pasteboard:)`, where Format is a `ParseableFormatStyle` with `FormatOutput == String`. Example: `SingleLineField(model: m, id: "count", value: $n, format: .number)`.
- Typing changes only the text. The binding is written on commit (Return, focus loss, Esc), and only when the whole trimmed text parses. For number, currency, percent and date styles the WHOLE text must match, so "4x" is rejected. Invalid input keeps the last valid value and redisplays it. A valid commit re-formats the text ("1234" → "1,234"). `.onEditorCommit` runs after the binding is written. An outside binding change, such as the Stepper, re-formats the field.
- Undo: typing is one window-stack entry; a re-formatting commit is another.

## What to do
- [ ] `swift package update EditorKit` to d4d057c or later (also the demo's gitignored Package.resolved).
- [ ] ElicitationNumberField uses the number form through AgentOneLineField, or a sibling of it with the same sizing, placeholder, label and identifier slots. Keep the Stepper, and keep the field's control identifier on the text view.
- [ ] Integer vs number schema: use an integer format for `integer` schema fields if the field has that distinction today.
- [ ] Return in the number field presses Submit when the form is complete, like the text field (`elicitationReturnAction`), and runs after the binding is written.
- [ ] Remove the doc note in ElicitationNumberField that explains the TextField.
- [ ] Hosted tests (red first): typing plus Return writes the value; invalid text keeps the last value and redisplays it; the Stepper re-formats the field; ⌘Z undoes the typing; the identifier and label are on the text view; schema min/max errors still show (ElicitationFieldErrorsHostedTests).
- [ ] Re-record only the elicitation snapshots that change, and list them.

Acceptance: no SwiftUI `TextField(` is left in Sources/AgentViewKit; the full `swift test` is green; the demo builds. #avk-7