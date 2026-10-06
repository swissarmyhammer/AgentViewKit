---
assignees:
- claude-code
depends_on:
- 01M443NN55C6HTFT2F2REPFZA1
- 01M443GNSTVHXNPFNPG33W402N
- 01M48MQ0BVDHNY798PTF3VYEQH
position_column: todo
position_ordinal: 9b80
title: 'Bind the state banners to SessionModel: agentState, replay marker, missed updates with Reload, closed thread'
---
## What
Source: update.md §4.2 (`agentState`), §4.7 ("Agent state", "Resume", "Missed updates", "Closed thread"), §5 (`replayFrom`), §9.2. Owner rule (2026-10-06): the banners bind directly to the observable model of FoundationModelsACPClient. They show what `SessionModel` holds and call the model methods. The kit keeps no copy of the state, does no turn tracking (no "turn started" or "turn ended" state of its own), and keeps no "reload in progress" flag that the model already holds.

- [ ] `StateBanner` (`Sources/AgentViewKit/Status/StateBanner.swift`) takes the `SessionModel` and reads `SessionModel.agentState` (`StateUpdate?`) directly in its body: `.running`, `.idle` with its `stopReason` (use the stop reason table of the stop reason task with `StopReason.unknown(String)`), `.requiresAction`, and a general state for `.unknown(String, JSONValue)`. Remove the kit `ThreadState` use from the session path. The "Show Error" action finds the last `ErrorEntry` in `SessionModel.transcript`; the kit keeps no error list.
- [ ] Show a replay marker while `isReplaying` is true. After a resume, show a "history can be partial" note from `history` (`SessionHistory`). Never say that the history is complete.
- [ ] When `hasMissedUpdates` is true, show a banner with a "Reload" action. The action calls `ConnectionModel.resumeSession(_:)` with `replayFrom: .start`. The banner goes away only when the model clears `hasMissedUpdates`.
- [ ] When `isClosed` is true, show a closed state. The composer reads `isClosed` directly to disable itself.

## Acceptance Criteria
- [ ] Each `agentState` value that the model reports shows its banner with no other step; `.idle(_truncated)` shows the truncated text. A new value replaces the banner.
- [ ] A buffer overflow in a test (small `bufferLimits`) shows the missed-updates banner. Reload sends `session/resume` with `replayFrom` start, and the banner goes away after the model clears `hasMissedUpdates`.
- [ ] A closed session shows the closed state, and the composer is disabled.
- [ ] No source in `Sources/AgentViewKit/Status/` keeps a copy of `agentState`, `hasMissedUpdates`, `isReplaying`, `history` or `isClosed`.

## Tests
- [ ] `Tests/AgentViewKitTests/Status/SessionStateBannersHostedTests.swift`: one test for each criterion. The scripted agent sends each state; the test asserts the banner text after each change. Use `connect(over:logger:bufferLimits:client:)` with small limits for the overflow test, and assert the `session/resume` frame for Reload.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.