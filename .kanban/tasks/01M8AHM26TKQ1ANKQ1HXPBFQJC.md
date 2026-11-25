---
assignees:
- claude-code
position_column: todo
position_ordinal: 8a80
title: An elicitation number field with a minimum above its maximum stops the app
---
Found during ^8sdsx64 (2026-11-25). `ElicitationNumberField` in `Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift` gives the schema `minimum...maximum` to the system `Stepper` as a `ClosedRange<Double>`. When an agent sends a schema whose `minimum` is above its `maximum`, the range construction traps and the app stops. The schema comes from the agent, so the kit must not trust it.

## What
- [ ] In `ElicitationNumberField`, make the stepper range from the two bounds in order (`min(a, b)...max(a, b)`), or show no stepper when the bounds are not in order. The validator still reports the schema bounds.
- [ ] Add a unit test in `Tests/AgentViewKitTests/Elicitation/` that mounts the field with `minimum: 9, maximum: 1` in a window that is never ordered in, and checks that it mounts and shows its input.

## Acceptance Criteria
- [ ] A number field with `minimum` above `maximum` mounts with no trap.
- [ ] A number field with bounds in order keeps its stepper range as before.

## Tests
- [ ] The new unit test fails (it traps) before the fix, and passes after the fix.
- [ ] `swift test` passes with 0 failures and 0 warnings. A temp HOME is not possible, because the harness refuses the HOME override.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #bug