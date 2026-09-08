---
depends_on:
- 01M21BESSF4MJ0TS2JSHH9WTFM
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: todo
position_ordinal: 9c80
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
- [ ] A one-field request mounts no tab elements; a three-field request mounts three `elicitation-tab-*` elements.
- [ ] `elicitation-submit` is disabled until every required field validates, then enabled.
- [ ] A custom `.elicitationFooter` replaces the default footer.
- [ ] Esc sends `.cancel`; the `RecordingFocusReporter` records `elicitation-form` on appear.

## Tests
- [ ] `Tests/AgentViewKitTests/Elicitation/ElicitationViewHostedTests.swift`: layouts, the gate, the slot override, the three actions, focus, through `NoopThreadActions` and `RecordingFocusReporter`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.