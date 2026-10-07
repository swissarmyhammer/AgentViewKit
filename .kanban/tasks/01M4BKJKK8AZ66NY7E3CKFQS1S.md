---
assignees:
- claude-code
depends_on:
- 01M4BHMJNEVT7DQ6KHVZTXQXVH
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
- Use `/tdd` — write failing tests first, then implement to make them pass. #blocked-upstream