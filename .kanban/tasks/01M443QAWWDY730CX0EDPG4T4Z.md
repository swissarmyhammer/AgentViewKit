---
assignees:
- claude-code
depends_on:
- 01M443NN55C6HTFT2F2REPFZA1
- 01M443GNSTVHXNPFNPG33W402N
position_column: todo
position_ordinal: 9b80
title: 'Bind the state banners to SessionModel: agentState, replay marker, missed updates with Reload, closed thread'
---
## What
Source: update.md §4.2 (`agentState`), §4.7 ("Agent state", "Resume", "Missed updates", "Closed thread"), §5 (`replayFrom`), §9.2.

- [ ] `StateBanner` (`Sources/AgentViewKit/Status/StateBanner.swift`) reads `SessionModel.agentState` (`StateUpdate?`): `.running`, `.idle` with its `stopReason` (use the stop reason table of the stop reason task with `StopReason.unknown(String)`), `.requiresAction`, and a general state for `.unknown(String, JSONValue)`.
- [ ] Show a replay marker while `isReplaying` is true. After a resume, show a "history can be partial" note from `history` (`SessionHistory`). Never say that the history is complete.
- [ ] When `hasMissedUpdates` is true, show a banner with a "Reload" action. The action calls `ConnectionModel.resumeSession(_:)` with `replayFrom: .start`.
- [ ] When `isClosed` is true, show a closed state and disable the composer.

## Acceptance Criteria
- [ ] Each `agentState` case shows its banner; `.idle(_truncated)` shows the truncated text.
- [ ] A buffer overflow in a test (small `bufferLimits`) shows the missed-updates banner; Reload sends `session/resume` with `replayFrom` start.
- [ ] A closed session shows the closed state.

## Tests
- [ ] `Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift`: one test for each criterion. Use `connect(over:logger:bufferLimits:client:)` with small limits for the overflow test.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.