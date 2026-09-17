# Text selection

Status: decided. Source: plan.md §9 A, §11 decision 8, §14 research R10.
Task ^h41qtbk. Date: 2026-09-17.

This file records how far a text selection goes in a thread on macOS 27.
`Tests/AgentViewKitTests/Items/MessageActionsHostedTests.swift` reads the
`mode:` line and compares it with `MessageActions.selectionMode`. Keep the form
of this line.

mode: `perMessage`

## Probe

The probe was a hosted test in `AgentViewKitTests`. The test was removed after
the run, because the probe is research output and not a criterion.

- A `ScrollView` held a `LazyVStack` with two rows. Each row had a height of
  40 points.
- Variant 1: each row was a Textual `StructuredText`, with
  `.textual.textSelection(.enabled)` on the stack. This is the text path of
  `ResponseView`.
- Variant 2: each row was a SwiftUI `Text`, with `.textSelection(.enabled)` on
  the stack.
- The test sent a mouse down in the first row, ten mouse drags to a point in
  the second row, and a mouse up, to the view at the start point. Then it sent
  `copy(_:)` to the first responder and read the general pasteboard. The test
  kept the pasteboard contents and put them back after the read.

## Result

| variant | view under each row | text of a drag in one row | text of a drag across two rows |
|---|---|---|---|
| Textual `StructuredText` | one `NSTextInteractionView` for each row | `Alpha first` | `Alpha first` (no text from the second row) |
| SwiftUI `Text` | one `AppKitTextInteractionView` for each row | none | none |

- Each row has its own interaction view and its own selection model. A drag
  that starts in one row does not go into the next row.
- The SwiftUI `Text` copy did not write to the pasteboard in the hosted window.
  The views are also one for each row, so the result for that variant is the
  same: no selection across rows.

## Decision

- The kit selects text in one message at a time (`perMessage`). This agrees
  with plan.md §11 decision 8.
- `MessageActions` gives Copy for one message and Copy thread for all
  messages, so that the user can copy text from more than one message.
- Examine this decision again when Textual or SwiftUI gives one selection model
  for more than one view.
