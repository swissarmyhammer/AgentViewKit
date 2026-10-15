---
assignees:
- claude-code
position_column: todo
position_ordinal: '8680'
title: 'Test: aChangeOfTheAgentStateSendsNoFrame waits for a Send button that now shows at all times'
---
`Tests/AgentViewKitTests/Input/ComposerSessionModelHostedTests.swift` `aChangeOfTheAgentStateSendsNoFrame` sends `running`, then `idle`, and waits with `harness.pump(until:)` until the Send button shows. After G4 of ^pvje3w3, the Send button shows at all times, also while the agent runs. Thus the wait ends at once, before the client reads the `idle` update, and the test can count the frames before the idle is folded.

Change: wait for the event that the model has the idle state (`ObservationWait.until { CancelAvailabilityTests.isIdle(model.agentState) }`), then count the frames. Remove the `pump(until:)` wait. Fixed-order test, no clock wait. #mail-step-7