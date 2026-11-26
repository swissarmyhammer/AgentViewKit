---
assignees:
- claude-code
position_column: todo
position_ordinal: 8c80
title: aStreamedTurnKeepsTheThreadPinnedToTheBottom is not certain under load
---
`IntegrationTests/Tests/IntegrationTests/Thread/ThreadFloatingControlsHostedTests.swift:313` (`aStreamedTurnKeepsTheThreadPinnedToTheBottom`) fails with `Expectation failed: !unpinned.isRaised` in some full IntegrationTests runs, and passes alone. It failed on branch e428ddc6 and on the ^8sdsx64 branch 90138f37. The ^c4sg6gz sub agent also saw its headless copy fail in 2 of 4 group runs on main ecb3a865. The test rules require certain tests: no test may depend on the load or on the order.

## What
- [ ] Find the event that the test assumes but does not wait for. Candidates: the visibility report after an append, the geometry action, and the manager unpin through `noteVisible` in `Sources/AgentViewKit/Thread/ConversationView.swift`.
- [ ] Either make the product deterministic (the manager must not unpin during a streamed append while the list follows the bottom), or make the test wait for the certain event (`ObservationWait.until` on the manager state).
- [ ] Add a headless test in `Tests/AgentViewKitTests/Thread/` that shows the cause, if a headless test can show it.

## Acceptance Criteria
- [ ] The test passes in 5 of 5 full IntegrationTests runs with `--no-parallel`.
- [ ] No sleep, poll, retry or time limit is added.

## Tests
- [ ] `swift test --no-parallel --package-path IntegrationTests` passes 5 times. This is a hosted run, so send start and end lines to testudoapp-9a, editorkit-7a, kanbanviewkit-1c and snapshotviewkit-bc.
- [ ] `swift test` (root) passes with 0 failures and 0 warnings.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #bug #test