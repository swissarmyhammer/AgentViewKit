---
comments:
- actor: claude-code
  id: 01m2nx9v46xpn0pj4badxd4j4k
  text: |-
    ### Design decisions (implement)
    - The kit had no environment value for the focus reporter. I added `EnvironmentValues.focusReporter: (any FocusReporter)?` (default `nil`) in Platform/FocusReporter.swift.
    - Slots: `.elicitationHeader { request in }`, `.elicitationFooter { ElicitationFooterContext in }` (canSubmit, submit, decline, cancel), `.elicitationLayout { ElicitationLayoutContext in }` (fields, tabThreshold, usesTabs), and `.elicitationLayout(tabThreshold:)`. Each slot has its own environment key. The defaults are the public views `ElicitationHeader`, `ElicitationFooter`, and `ElicitationLayout`.
    - Tab threshold: `ElicitationLayout.defaultTabThreshold = 1`. The layout shows tabs when the field count is more than the threshold.
    - The answered mark uses the new `ElicitationValidator.isAnswered(_:against:)`: the answer is not empty and passes the kind constraints. The tab accessibility value is `ElicitationTabMarks.text(required:answered:)`, for example "Required, No answer".
    - Esc uses `.onExitCommand` on the focusable form. The form takes the focus on appear. The test fails when the handler is removed.
    - Defaults pre-populate the answers. A URL mode request shows no fields; the URL consent view (^AKVY93G task) shows that mode.
    - The view keeps the answers in `@State`. A host must give each request its own identity, for example `.id(request.id)`.
  timestamp: 2026-09-16T20:07:33.254287+00:00
depends_on:
- 01M21BESSF4MJ0TS2JSHH9WTFM
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: doing
position_ordinal: '8180'
title: 'ElicitationView form mode: layout, header, footer, validation gate, slots (plan §13.2)'
---
## What
Create `Sources/AgentViewKit/Elicitation/ElicitationView.swift` and `ElicitationLayout.swift`, per plan.md §13.2. The field views and their overrides are in their own task.

- `ElicitationView(request:)`: normalizes the schema with `ElicitationFieldSchema.normalize`, keeps a `[String: JSONValue]` value store, validates on every change, and renders each field through `ElicitationFieldView`.
- Layout: one field inline; more than one tabbed, with a chip per field that shows required and answered marks. The threshold is a parameter of the `.elicitationLayout` slot.
- Header slot `.elicitationHeader` names the requesting server and shows the message. Footer slot `.elicitationFooter` has Submit (`.glassProminent`, disabled until `ElicitationValidator.isComplete`), Decline, Cancel. Esc maps to `cancel`. On appear the view calls the `FocusReporter` with its own identifier.
- Submit calls `respond(to:_:)` with `.accept(.object(values))`; Decline with `.decline`; Cancel with `.cancel`.
- Accessibility identifiers: `elicitation-form`, `elicitation-tab-<name>`, `elicitation-submit`, `elicitation-decline`, `elicitation-cancel`.

## Acceptance Criteria
- [x] A one-field request mounts no tab elements; a three-field request mounts three `elicitation-tab-*` elements.
- [x] `elicitation-submit` is disabled until every required field validates, then enabled.
- [x] A custom `.elicitationFooter` replaces the default footer.
- [x] Esc sends `.cancel`; the `RecordingFocusReporter` records `elicitation-form` on appear.

## Tests
- [x] `Tests/AgentViewKitTests/Elicitation/ElicitationViewHostedTests.swift`: layouts, the gate, the slot override, the three actions, focus, through `NoopThreadActions` and `RecordingFocusReporter`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.