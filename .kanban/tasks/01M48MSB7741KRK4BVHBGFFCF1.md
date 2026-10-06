---
assignees:
- claude-code
depends_on:
- 01M48MS20B5GS4711S119KD9GM
- 01M48MQS1Q5HBNDFMBD2CT0C6C
position_column: todo
position_ordinal: ae80
title: 'Bind the message actions and the Markdown export to SessionModel: copy, export and retry from the transcript entries'
---
## What
Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient, and calls the model methods. At present `MessageActions` (`Sources/AgentViewKit/Items/MessageActions.swift`) reads the `agentThread` and `threadActions` environment values: `role(of:in:)` and `lastUserMessage(before:in:)` read `thread.items`, and Retry calls `AgentThreadActions.startSend`. `ThreadExporter.markdown(for:)` (`Sources/AgentViewKit/Items/ThreadExporter.swift`) reads an `AgentThread`. A message row over a `SessionModel` thus shows only Copy.

- [ ] `MessageActions` reads the `sessionModel` environment value. The role comes from the entry case (`.userMessage` or `.agentMessage`) of `SessionModel.transcript`.
- [ ] Retry finds the last `UserMessageEntry` before the message in `SessionModel.transcript` and calls `SessionModel.prompt(_:meta:)` with its `content`. It keeps no copy of the message.
- [ ] `ThreadExporter` gets the Markdown from the message entries of `SessionModel.transcript` (a pure function over the entries). Copy thread uses the same function as the agent commands.
- [ ] No file of this task reads `agentThread`, `threadActions` or a kit `Message` record on the session path.

## Acceptance Criteria
- [ ] On an agent message row, Retry sends a `session/prompt` frame with the content of the earlier user message entry, and the new pending user message shows from the model.
- [ ] Export gives the Markdown of the message entries of the model, in transcript order.
- [ ] A new message entry that the model adds is in the next export with no other step.

## Tests
- [ ] `Tests/AgentViewKitTests/Items/MessageActionsHostedTests.swift`: Retry sends the frame (assert on the frames of the scripted agent); the actions of a user row and of an agent row.
- [ ] `Tests/AgentViewKitTests/Items/ThreadExporterTests.swift`: the Markdown of a transcript with a user message, an agent message, a thought and a tool call (only the messages show).
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.