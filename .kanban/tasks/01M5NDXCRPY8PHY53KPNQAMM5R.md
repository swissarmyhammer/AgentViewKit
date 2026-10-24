---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5ntr2nts6x7k0d987cmwv7z
  text: |-
    Picked up. Research:
    - EditorKit is resolved at 3bc9d3e (Package.resolved), which already holds ^99zb1dt (d4d057c): `SingleLineField(model:id:value:format:lineHeight:pasteboard:)` is in EditorKit Sources/EditorSwiftUI/SingleLineFieldValue.swift. The value form wraps the host's `.onEditorCommit`, so the host hears each commit after the binding is written; `.onAppear` shows the value with addToHistory `.disabled`; an outside binding change re-formats through `.onChange(of: formattedValue)`.
    - All slot modifiers (`editorSizingMode`, `editorPlaceholder`, `editorTextAccessibilityIdentifier/Label`, `onEditorCommit`) return `Self` on EditorSlotComposing, so AgentOneLineField can hold a prebuilt `SingleLineField` (text form or value form) and apply its one slot chain to either: no copy of the slot code.
    - The only SwiftUI `TextField(` in Sources/AgentViewKit is ElicitationNumberField's stepper label.
    - The number field already distinguishes `integer` (rounded writes, slider step 1), so an integer field gets `IntegerFormatStyle<Int>` over an Int binding, a number field `FloatingPointFormatStyle<Double>`.
    - Hosted helpers to reuse: SingleLineFieldChecks (type, Return, undo via `edit.undo`), ElicitationViewHostedTests.mount/makeFormParams. The harness cannot increment a stepper (blocking AppKit animation), so the "Stepper re-formats the field" test drives the same binding from outside (AnswerBox), which is the path the Stepper writes.
    - The existing test `theStepperShowsTheAnswer` asserts the control identifier on the incrementor; the card moves the identifier to the text view, so that test changes with it.
  timestamp: 2026-10-24T02:09:59.482485+00:00
- actor: claude-code
  id: 01m5nv9kwjnb1jhfef4mss30hb
  text: |-
    Implementation landed (not committed). What the next agent should know:
    - AgentOneLineField now stores a prebuilt `SingleLineField` and has two inits: text `init(model:identifier:placeholder:onSubmit:)` (unchanged call sites in SessionListView, PermissionView, FontRoleHostedTests) and value `init(model:identifier:placeholder:value:format:onSubmit:)`. Both run the one slot chain (sizing, placeholder, label, identifier, `onEditorCommit` gated by `submitsField`, the shared `agentTextInputEdge`). The `.display` font role stays EditorKit's default; FontRoleHostedTests now pins it for the number input.
    - ElicitationNumberField's stepper path is HStack { number input (max width 160) ; Stepper(title, ...).labelsHidden() }. The control identifier moved from the incrementor to the text view; the Stepper has no identifier. Model kept in `@State OwnModelSlot(editable: true)`.
    - What did not work: my first test asserted that "2.5" in an integer field is rejected. Foundation's `IntegerFormatStyle<Int>` regex component whole-matches "2.5" as 2 (checked with a scratch script: "2.5" -> 2, "4x" -> nil, "1,234" -> 1234), so EditorKit's whole-match rule accepts it. The test now pins the real contract: a fraction commits its whole part (a floating-point format plus the rounding binding would end at 3).
    - Typing into a value field needs a select-all first, because the field already shows a number ("0" with no answer and no minimum). New helper `SingleLineFieldChecks.replaceText(with:inFieldWith:in:)`.
    - `ElicitationTextFieldEditingHostedTests.mount(_:)` now takes the params (default: the old required-name form), so the number tests reuse its command-scope window.
    - The build prints `warning: missing creator for mutated node: ... mlx-swift_Cmlx.bundle` from SwiftPM's build graph on every build, before and after this change; it is the dependency bundle, not compiler output.
  timestamp: 2026-10-24T02:19:34.162235+00:00
- actor: claude-code
  id: 01m5nv9tn8j5hrc0nvt2d1sz18
  text: |-
    ### implement — changed
    - evidence: 9 files — Sources/AgentViewKit/Input/AgentOneLineField.swift, Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift, Sources/AgentViewKit/Elicitation/ElicitationView.swift (docs), Tests/AgentViewKitTests/Elicitation/ElicitationNumberFieldEditingHostedTests.swift (new), Tests/AgentViewKitTests/Elicitation/ElicitationFieldViewsHostedTests.swift, Tests/AgentViewKitTests/Elicitation/ElicitationFieldErrorsHostedTests.swift, Tests/AgentViewKitTests/Elicitation/ElicitationTextFieldEditingHostedTests.swift, Tests/AgentViewKitTests/Helpers/SingleLineFieldChecks.swift, Tests/AgentViewKitTests/Theme/FontRoleHostedTests.swift. RED seen for every new test; `swift test` 1796 tests / 220 suites passed (7 known issues, all intentional withKnownIssue meta-tests); demo `xcodebuild -onlyUsePackageVersionsFromResolvedFile build` BUILD SUCCEEDED; `rg "\bTextField\(" Sources/AgentViewKit` finds nothing; no snapshot re-recorded (none changed).
    - next: /review
  timestamp: 2026-10-24T02:19:41.096294+00:00
position_column: doing
position_ordinal: '8380'
title: 'Elicitation number field: SingleLineField(value:format:) instead of TextField(value:format:)'
---
Follow-up to ^8zmkh1a, which kept `ElicitationNumberField` (Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift) on SwiftUI `TextField(value:format: .number)` inside a Stepper, because SingleLineField had no number form. The user's rule: "if we need a one line editor, we need a one line mode of our editor kit editor". EditorKit ^99zb1dt landed on main at d4d057c (code 954b559, 138a38e).

## EditorKit API (from editorkit-28)
- `SingleLineField(model:id:value:format:lineHeight:pasteboard:)`, where Format is a `ParseableFormatStyle` with `FormatOutput == String`. Example: `SingleLineField(model: m, id: "count", value: $n, format: .number)`.
- Typing changes only the text. The binding is written on commit (Return, focus loss, Esc), and only when the whole trimmed text parses. For number, currency, percent and date styles the WHOLE text must match, so "4x" is rejected. Invalid input keeps the last valid value and redisplays it. A valid commit re-formats the text ("1234" → "1,234"). `.onEditorCommit` runs after the binding is written. An outside binding change, such as the Stepper, re-formats the field.
- Undo: typing is one window-stack entry; a re-formatting commit is another.

## What to do
- [x] `swift package update EditorKit` to d4d057c or later (also the demo's gitignored Package.resolved). Already satisfied: Package.resolved and the demo's Package.resolved both pin EditorKit 3bc9d3e, and d4d057c is an ancestor of 3bc9d3e (`git merge-base --is-ancestor`). No update run, per the dispatch.
- [x] ElicitationNumberField uses the number form through AgentOneLineField, or a sibling of it with the same sizing, placeholder, label and identifier slots. Keep the Stepper, and keep the field's control identifier on the text view. AgentOneLineField gained a value-form init (`value:format:`) that builds `SingleLineField(model:id:value:format:)` and runs the one shared slot chain; the stepper path is now the number input beside a label-hidden Stepper.
- [x] Integer vs number schema: use an integer format for `integer` schema fields if the field has that distinction today. `integer` → `IntegerFormatStyle<Int>` over an Int binding (`wholeNumber(nearest:)` clamps to Int's range); otherwise `FloatingPointFormatStyle<Double>`. Note: Foundation's integer format reads "2.5" whole as 2, so a fraction commits its whole part.
- [x] Return in the number field presses Submit when the form is complete, like the text field (`elicitationReturnAction`), and runs after the binding is written. `onSubmit` of AgentOneLineField (gated by `EditorCommitReason.submitsField`) runs `returnAction`; EditorKit's value form calls it after the write.
- [x] Remove the doc note in ElicitationNumberField that explains the TextField.
- [x] Hosted tests (red first): typing plus Return writes the value; invalid text keeps the last value and redisplays it; the Stepper re-formats the field; ⌘Z undoes the typing; the identifier and label are on the text view; schema min/max errors still show (ElicitationFieldErrorsHostedTests).
- [x] Re-record only the elicitation snapshots that change, and list them. None change: the snapshot fixture's only number field (`Retries`, minimum 0 and a maximum) takes the slider path; all four `theElicitationForm` variants compare equal.

Acceptance: no SwiftUI `TextField(` is left in Sources/AgentViewKit; the full `swift test` is green; the demo builds. #avk-7