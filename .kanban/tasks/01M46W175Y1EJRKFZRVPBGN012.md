---
assignees:
- claude-code
position_column: todo
position_ordinal: a880
title: Find the main-actor stall at the start of the full swift test run
---
## What
In the full `swift test` run after ^repfza1, ACP tests that use `bounded(_:)` passed the 5-second limit, because the main actor was busy for about 9 seconds at the start of the run. Run alone, these tests pass. The test step raised `operationLimitSeconds` in `Tests/AgentViewKitTests/ACP/ScriptedWireAgent+Bounded.swift` from 5 to 60. That hides the stall. Find what blocks the main actor (for example a hosted view test, a SessionModel test or a test helper from ^repfza1), remove the cause, and put the limit back to a small value.

- [ ] Measure the main-actor stall in the full run and find its source.
- [ ] Remove the cause.
- [ ] Put `operationLimitSeconds` back to 5 seconds or less.

## Acceptance Criteria
- [ ] The full `swift test` passes two times with the small limit.

## Tests
- [ ] `swift test` passes two times.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.