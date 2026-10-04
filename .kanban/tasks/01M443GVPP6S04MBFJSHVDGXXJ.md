---
assignees:
- claude-code
position_column: todo
position_ordinal: '8280'
title: Send messageId in the prompt result of the scripted demo agents, and echo the user message
---
## What
In ACP alpha.7, `PromptResponse.messageId` is required. `ScriptedWireAgent` (`Sources/DemoSupport/ScriptedWireAgent.swift`) and `InMemoryDemoAgent` (`Sources/DemoSupport/InMemoryDemoAgent.swift`) answer `session/prompt` with `{}`. After the alpha.7 pin move, each prompt in the tests and in the in-memory demo fails at runtime. Source: update.md §7 item 3.

Do this before the pin move. The alpha.3 decoder ignores the extra field, so the change is safe now.

- [ ] Give each prompt result a new `messageId` (a UUID string).
- [ ] Before the result, send a `user_message` update (`user_message_chunk` with the same `messageId`) that echoes the prompt text.
- [ ] Add an option to `ScriptedWireAgent` to send the echo after the result. The later composer task tests the two orders with it.

## Acceptance Criteria
- [ ] The JSON of each prompt result of the two agents has a `messageId`.
- [ ] Each prompt gives one echoed user message with the same ID, before the result by default, or after the result when the option is set.

## Tests
- [ ] Add tests in `Tests/AgentViewKitACPTests/` (a new file `DemoAgentMessageIdTests.swift`): read the raw frames of each agent, and assert the `messageId` in the result and in the echo, for the two orders.
- [ ] `swift test --filter AgentViewKitACPTests` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #acp-client