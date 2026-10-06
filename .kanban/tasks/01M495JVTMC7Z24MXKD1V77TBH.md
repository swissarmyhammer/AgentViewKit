---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m499ck60prv1a7jr1jkdwamd
  text: |-
    Implementation done. The test `bumpNotifiesAnObserverOfTheRevision` now uses `ChangeFlag.observing { _ = reasoning.revision }`. The hand-written `withObservationTracking` code is removed. The test has no sleep.

    Proof of the second criterion: I removed `revision += 1` from `ThreadRecord.bump()` for a short time. `swift test --filter ThreadItemTests` then failed at `#expect(changed.value)` (`changed.value → false`). I put the line back. `git diff Sources` is empty.

    Note: the rules dump for `.swift` is 754k characters. It was too large to read in full.
  timestamp: 2026-10-06T19:00:02.368282+00:00
- actor: claude-code
  id: 01m499cmwtn89q12gxf1zc2k1r
  text: |-
    ### implement — changed
    - evidence: 1 file — Tests/AgentViewKitTests/Model/ThreadItemTests.swift. `swift test --filter ThreadItemTests`: 11 tests passed (it failed as expected with `bump()` broken). Full `swift test`: 1319 tests in 122 suites passed, 0 failures. The only warning is the expected mlx-swift `missing creator for mutated node`.
    - next: /review
  timestamp: 2026-10-06T19:00:04.122083+00:00
position_column: doing
position_ordinal: '80'
title: Use ChangeFlag.observing in ThreadItemTests.bumpNotifiesAnObserverOfTheRevision
---
## What
`Tests/AgentViewKitTests/Model/ThreadItemTests.swift` `bumpNotifiesAnObserverOfTheRevision` makes a `ChangeFlag` and calls `withObservationTracking` with an `onChange` that calls `set()`. This is the pattern that `ChangeFlag.observing(_:when:)` (`Sources/AgentViewKitTestSupport/ChangeFlag.swift`) gives. Found during ^et6e0ps (review finding `reuse/reuse` on `flagAnswerBeforePrompt`). That card did not change this file, because it is not in its scope.

## Acceptance Criteria
- [x] `bumpNotifiesAnObserverOfTheRevision` uses `ChangeFlag.observing { _ = reasoning.revision }`.
- [x] The test still fails when `Reasoning.bump()` does not change `revision`.
- [x] Full `swift test` passes.