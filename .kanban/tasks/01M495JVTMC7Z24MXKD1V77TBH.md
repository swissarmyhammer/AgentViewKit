---
assignees:
- claude-code
position_column: todo
position_ordinal: b280
title: Use ChangeFlag.observing in ThreadItemTests.bumpNotifiesAnObserverOfTheRevision
---
## What
`Tests/AgentViewKitTests/Model/ThreadItemTests.swift` `bumpNotifiesAnObserverOfTheRevision` makes a `ChangeFlag` and calls `withObservationTracking` with an `onChange` that calls `set()`. This is the pattern that `ChangeFlag.observing(_:when:)` (`Sources/AgentViewKitTestSupport/ChangeFlag.swift`) gives. Found during ^et6e0ps (review finding `reuse/reuse` on `flagAnswerBeforePrompt`). That card did not change this file, because it is not in its scope.

## Acceptance Criteria
- [ ] `bumpNotifiesAnObserverOfTheRevision` uses `ChangeFlag.observing { _ = reasoning.revision }`.
- [ ] The test still fails when `Reasoning.bump()` does not change `revision`.
- [ ] Full `swift test` passes.