---
assignees:
- claude-code
depends_on:
- 01M443QAWWDY730CX0EDPG4T4Z
- 01M443NW9A12NWXYHJFYTTTA85
- 01M48MQDWDPN98ZSWQ4N7S44FW
position_column: todo
position_ordinal: 9f80
title: 'Show background runs as SessionModel reports them: two agent message rows, tool rows that update, running until idle'
---
## What
After the streamed answer ends, the agent keeps the prompt `running` until all background runs end. In this time the client can get more `tool_call_update` messages and a full `agent_message_chunk` with a new `messageId`. Then `idle` comes. Source: update.md §9.3.

Owner rule (2026-10-06): the views bind directly to the observable model of FoundationModelsACPClient, and the kit does no turn tracking ("i don't really want you to worry about turns"). Thus this task adds no kit logic for the order. The old step "show Waiting for background work when no text streamed for the current turn after the last agent message" is removed: it needs kit turn tracking (the current turn, the time of the last text) that the model does not hold. The kit shows only what `SessionModel` reports: the entries of `transcript` in their order, and `agentState`.

- [ ] Add a scripted sequence to `ScriptedWireAgent` (or the test helper) for this order: `running`, streamed text, tool updates, a full chunk with a new `messageId`, `idle`.
- [ ] Do not add kit code for this order. The transcript view shows the entries of `SessionModel.transcript`; the state banner shows `agentState` (`.running` until `.idle`), as the state banner task binds it.

## Acceptance Criteria
- [ ] The thread shows two agent message rows, in transcript order (two `AgentMessageEntry` objects in the model), and the tool rows between them show each `tool_call_update` of the model.
- [ ] The running state shows while the model reports `agentState` `.running`, also after the first message ends, and goes away when the model reports `.idle`.
- [ ] No source in `Sources/AgentViewKit/` keeps a "current turn", a "last text time" or a "waiting" state of its own.

## Tests
- [ ] `Tests/AgentViewKitTests/Thread/BackgroundRunsHostedTests.swift`: the order above through the scripted agent; assert the two agent message rows and their order against `SessionModel.transcript`, the tool row status after each update, and the running banner until `idle`.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.