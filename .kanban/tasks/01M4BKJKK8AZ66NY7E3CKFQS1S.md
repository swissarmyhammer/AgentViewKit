---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4cwf8dc4za92r7dtat3cxkg
  text: Unblocked (2026-10-08). Client task 8mx2fve is done (2026-10-07 17:57), and FoundationModelsACPClient origin/main is e1cac1d. Task ^vewxkf3 moves the client pin to e1cac1d and the ACP pin to the revision that the client resolves, so this task now depends on ^vewxkf3 and does not move the pins again. Check that the pinned FoundationModelsACP has the a25yvy1 InMemoryTransport fix before you remove InProcessClientTransport.
  timestamp: 2026-10-08T04:31:15.884194+00:00
depends_on:
- 01M4BTQV4WZHK4CE5F6VEWXKF3
position_column: todo
position_ordinal: b880
title: Remove the in-process wrapper transport when the InMemoryTransport fix is pinned
---
## What
Task ^ztxqxvh added `InProcessClientTransport` in `Sources/AgentViewKit/ACP/InProcessAgent.swift`, because `ConnectionModel.disconnect()` did not end the stream of an `InMemoryTransport.pair()`, so an in-process agent stayed alive. FoundationModelsACPClient tasks a25yvy1 (the fix in FoundationModelsACP `InMemoryTransport`) and 8mx2fve (adopt it in the client) fix the cause. This task starts when the kit can pin a pushed client commit that has 8mx2fve.

- [ ] Move the FoundationModelsACPClient and FoundationModelsACP pins to the pushed commits (targeted updates in the three `Package.resolved` files) and update `ResolvedPinsTests`.
- [ ] Delete `InProcessClientTransport` and serve the pair directly in `InProcessAgent.makeConnection(serving:)`.
- [ ] Delete `AgentConnectionBox.waitUntilClosed()` if no other caller uses it.

## Acceptance Criteria
- [ ] No `InProcessClientTransport` in `Sources/`.
- [ ] `aDisconnectOfTheModelClosesTheAgentSide` still passes.

## Tests
- [ ] `Tests/AgentViewKitTests/ACP/InProcessAgentTests.swift`: `aDisconnectOfTheModelClosesTheAgentSide`.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.