---
assignees:
- claude-code
depends_on:
- 01M443QAWWDY730CX0EDPG4T4Z
- 01M443NW9A12NWXYHJFYTTTA85
position_column: todo
position_ordinal: 9f80
title: 'Show background runs: the order running, text, tool updates, a new message, idle; and a waiting state'
---
## What
After the streamed answer ends, the agent keeps the prompt `running` until all background runs end. In this time the client can get more `tool_call_update` messages and a full `agent_message_chunk` with a new `messageId`. Then `idle` comes. Source: update.md §9.3.

- [ ] Add a scripted sequence to `ScriptedWireAgent` (or the test helper) for this order: `running`, streamed text, tool updates, a full chunk with a new `messageId`, `idle`.
- [ ] Show "Waiting for background work" in `StateBanner` (or `WorkStatusLabel`) when the state is `running` and no text streamed for the current turn after the last agent message.

## Acceptance Criteria
- [ ] The thread shows two assistant messages, in order, and the tool rows between them update.
- [ ] The waiting state shows between the first message and the second message, and goes away at `idle`.

## Tests
- [ ] `Tests/AgentViewKitTests/Thread/BackgroundRunsHostedTests.swift`: the order above; assert the two assistant rows and the waiting state.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.