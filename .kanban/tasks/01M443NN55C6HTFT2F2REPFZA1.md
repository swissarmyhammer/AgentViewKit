---
assignees:
- claude-code
depends_on:
- 01M443NCQ6B4040Y9X0SBNCN28
position_column: todo
position_ordinal: '9380'
title: 'Bind the transcript rows to SessionModel: ForEach on TranscriptEntry.id, message and thought rows'
---
## What
The thread view reads the transcript of `SessionModel`, not `AgentThread`. Source: update.md §4.2, §4.6, §4.7 ("Row identity").

- [ ] Add a new initializer `AgentThreadView(session:actions:)` that takes a `SessionModel`. `ConversationView` and `ItemRow` (`Sources/AgentViewKit/Thread/`) iterate the transcript of the model with `ForEach` keyed on `TranscriptEntry.id`, and `ItemRow` switches on the `TranscriptEntry` case.
- [ ] **Keep the old `AgentThreadView(thread:actions:)` initializer for now**, and mark it deprecated. Its callers stay unchanged in this task: `Examples/ReadmeSnippets/Snippets/HostApp.swift`, `ACPQuickStart.swift`, `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift` and the `README.md` blocks. The adapter removal task deletes the old initializer after the demo and quick-start tasks move these callers.
- [ ] Bind `UserMessageView`, `AssistantMessageView` and `ReasoningView` (`Sources/AgentViewKit/Items/`) to `UserMessageEntry`, `AgentMessageEntry` and `ThoughtEntry`. A thought and an agent message with the same `messageId` are two rows. The streaming tail (`StreamingMessage`, `ParagraphSplitter`, `StreamingMarkdownBalancer`) works on the text of one entry and keeps no session state.
- [ ] Add a test helper in `Sources/AgentViewKitTestSupport/` that makes a `ConnectionModel` and `SessionModel` over `InMemoryTransport.pair()` with `ScriptedWireAgent`, with `coalescingCadence: .zero`. Later view tasks use it.
- [ ] Other entry kinds show `UnknownItemView` until their own task binds them.

## Acceptance Criteria
- [ ] A scripted session with a user message, a thought and an agent message shows three rows in order.
- [ ] A streamed chunk redraws only its own row.
- [ ] `swift test` and `Scripts/check-readme.sh` pass (the old initializer still compiles for the snippets).

## Tests
- [ ] `Tests/AgentViewKitTests/Thread/SessionTranscriptViewHostedTests.swift`: the three-row order; the row identity does not change when a pending user message gets its `messageId`; a body evaluation count with `BodyEvaluationCounter` shows that a chunk redraws one row only.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.