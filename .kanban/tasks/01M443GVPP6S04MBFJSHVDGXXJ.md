---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m44mmg3d923pwsjhgg1620q8
  text: |-
    Research:
    - ScriptedWireAgent answers each request with the scripted result or `{}`. It has no special path for `session/prompt`.
    - InMemoryDemoAgent sends a whole `user_message` with the ID `demo-user-<turn>` as a follow-up after the result. This echo goes away. The new echo comes from ScriptedWireAgent: one `user_message_chunk` with the UUID `messageId` of the result.
    - In alpha.3, `ContentChunk` and `UserMessage` both have `messageId`, so the chunk decodes now.
    - ACPThreadSource opens a user stream for the text chunk. The next agent chunk closes it, so the thread items of the demo turn are [<UUID>, demo-reply-1]. ACPDemoSessionTests.aSendOfHelloGivesTheReplyOfTheAgent must change: it used `userMessageID(turn:)`.
    - ACPThreadActionsTests uses a plain AgentThread that no source feeds, so the echo does not change its items.
    - The screen is locked (ioreg CGSSessionScreenIsLocked = true). No demo UI test refers to the user message ID, and the card requires only `swift test`.
  timestamp: 2026-10-04T23:40:23.533820+00:00
- actor: claude-code
  id: 01m44mxdbk0jn6m69pkbbf2dhj
  text: |-
    Implementation landed (TDD: the 5 new tests failed first on the missing `messageId` and the missing echo, then passed).
    - ScriptedWireAgent: a `session/prompt` that does not fail gets a result with a new UUID `messageId`. The scripted result object is kept, and `messageId` is added to it. The agent echoes the joined prompt text in one `user_message_chunk` with the same `messageId` and the `sessionId` of the request. The new option `promptEchoOrder` (`.beforeResult` is the default, `.afterResult` is the other value) sets the order. `promptText(of:)` and `textBlock(_:)` moved to ScriptedWireAgent as internal static helpers, so that the two agents share them.
    - InMemoryDemoAgent: the `user_message` follow-up with the ID `demo-user-<turn>` is removed, together with `userMessageID(turn:)` and its prefix. The echo now comes from ScriptedWireAgent before the result.
    - ACPDemoSessionTests: the hello test now reads the UUID of the user item and checks its text. thePromptTextJoinsTheTextBlocks calls `ScriptedWireAgent.promptText`.
    - Examples/AgentViewKitDemo/Tests/ACPTabEndToEndTests.swift: the user row ID was `item-row-demo-user-1`. The test now finds the row with an identifier that starts with `item-row-` and is not the reply row. `xcodebuild build-for-testing` passes. The UI test did not run, because the screen is locked (CGSSessionScreenIsLocked = true). Run `Scripts/test-examples.sh` when the screen is unlocked.
  timestamp: 2026-10-04T23:45:15.635216+00:00
- actor: claude-code
  id: 01m44mxgw7zxypdexsfjrw7w2d
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/DemoSupport/ScriptedWireAgent.swift, Sources/DemoSupport/InMemoryDemoAgent.swift, Tests/AgentViewKitACPTests/DemoAgentMessageIdTests.swift (new), Tests/AgentViewKitACPTests/ACPDemoSessionTests.swift, Examples/AgentViewKitDemo/Tests/ACPTabEndToEndTests.swift. `swift test --filter AgentViewKitACPTests`: 128 tests pass. `swift test`: all runs pass (1, 57, 1291, 59, 128 tests), no warnings. `xcodebuild build-for-testing` of AgentViewKitDemo: TEST BUILD SUCCEEDED. The demo UI test did not run (the screen is locked).
    - next: /review. Run Scripts/test-examples.sh when the screen is unlocked.
  timestamp: 2026-10-04T23:45:19.239239+00:00
position_column: doing
position_ordinal: '8180'
title: Send messageId in the prompt result of the scripted demo agents, and echo the user message
---
## What
In ACP alpha.7, `PromptResponse.messageId` is required. `ScriptedWireAgent` (`Sources/DemoSupport/ScriptedWireAgent.swift`) and `InMemoryDemoAgent` (`Sources/DemoSupport/InMemoryDemoAgent.swift`) answer `session/prompt` with `{}`. After the alpha.7 pin move, each prompt in the tests and in the in-memory demo fails at runtime. Source: update.md §7 item 3.

Do this before the pin move. The alpha.3 decoder ignores the extra field, so the change is safe now.

- [x] Give each prompt result a new `messageId` (a UUID string).
- [x] Before the result, send a `user_message` update (`user_message_chunk` with the same `messageId`) that echoes the prompt text.
- [x] Add an option to `ScriptedWireAgent` to send the echo after the result. The later composer task tests the two orders with it.

## Acceptance Criteria
- [x] The JSON of each prompt result of the two agents has a `messageId`.
- [x] Each prompt gives one echoed user message with the same ID, before the result by default, or after the result when the option is set.

## Tests
- [x] Add tests in `Tests/AgentViewKitACPTests/` (a new file `DemoAgentMessageIdTests.swift`): read the raw frames of each agent, and assert the `messageId` in the result and in the echo, for the two orders.
- [x] `swift test --filter AgentViewKitACPTests` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #acp-client