---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8ar84wa9nmss3a1td4tq2ga
  text: |-
    ### implement — changed
    - evidence: f268cb9d (the RED test) and d4ebd97e (the fix), merged into main as 37c830ea. RED: `swift test --filter ElicitationNumberFieldBoundsTests` stopped with "Fatal error: Range requires lowerBound <= upperBound" (signal 5). GREEN: root swift test 1779 + 59 passed, 0 failures. The one warning is a SwiftPM build-system warning about the mlx-swift_Cmlx.bundle dependency, not about AVK code.
    - fix: ElicitationNumberField.stepperRange(minimum:maximum:) makes the range from the bounds in order. A missing bound or a NaN bound leaves that end open. The stepper stays, and the validator still reports the schema bounds. The slider was already safe (minimum < maximum).
    - next: the review, and the hosted elicitation suites at the next screen slot.
  timestamp: 2026-11-26T01:41:47.018916+00:00
- actor: claude-code
  id: 01m8are9hqs7gwbahgzerfse0n
  text: |-
    ### review — clean
    - evidence: `review sha e456d438..37c830ea` — 0 findings, 0 confirmed, 0 refuted (7 attempted, 0 failed, 2 files reviewed). RED run trapped with "Range requires lowerBound <= upperBound". After the fix, the mount test and the 4 pure tests pass. Root `swift test`: 1779 + 59 passed, 0 failures. The 11 elicitation unit tests on main pass.
    - next: none. The card moves to done.
  timestamp: 2026-11-26T01:45:08.407597+00:00
position_column: done
position_ordinal: ffffffffaf80
title: An elicitation number field with a minimum above its maximum stops the app
---
Found during ^8sdsx64 (2026-11-25). `ElicitationNumberField` in `Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift` gives the schema `minimum...maximum` to the system `Stepper` as a `ClosedRange<Double>`. When an agent sends a schema whose `minimum` is above its `maximum`, the range construction traps and the app stops. The schema comes from the agent, so the kit must not trust it.

## What
- [x] In `ElicitationNumberField`, make the stepper range from the two bounds in order (`min(a, b)...max(a, b)`), or show no stepper when the bounds are not in order. The validator still reports the schema bounds.
- [x] Add a unit test in `Tests/AgentViewKitTests/Elicitation/` that mounts the field with `minimum: 9, maximum: 1` in a window that is never ordered in, and checks that it mounts and shows its input.

## Acceptance Criteria
- [x] A number field with `minimum` above `maximum` mounts with no trap.
- [x] A number field with bounds in order keeps its stepper range as before.

## Tests
- [x] The new unit test fails (it traps) before the fix, and passes after the fix.
- [x] `swift test` passes with 0 failures and 0 warnings. A temp HOME is not possible, because the harness refuses the HOME override.

## Evidence (2026-11-25)
- RED: the run of `ElicitationNumberFieldBoundsTests` before the fix trapped with "Range requires lowerBound <= upperBound".
- GREEN: after the fix, the mount test and the 4 pure tests pass.
- Root `swift test`: 1779 + 59 passed, 0 failures.
- The 11 elicitation unit tests on main pass.
- Review `review sha e456d438..37c830ea`: 0 findings (2 files reviewed).

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #bug