---
assignees:
- claude-code
depends_on:
- 01M443NN55C6HTFT2F2REPFZA1
position_column: todo
position_ordinal: a980
title: 'Show the entry text with no kit stream copy: remove EntryTextStream, isLastWhileRunning and the second coalescer'
---
## What
Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient. The kit keeps no copy of model data and no logic that the model owns. At present, for each streaming entry, `EntryTextStream` makes a `StreamingMessage` that keeps a second copy of the entry text (`StreamingMessage.text`) and its own `StreamingCoalescer`. The model already keeps the text in the entry object and applies the chunks at display rate (`SessionModel.defaultCoalescingCadence`). The kit also decides which entry "streams" with `SessionModel.isLastWhileRunning(_:)` (last entry and `agentState` `.running`). That is kit turn logic: it is wrong during background runs, when the agent stays `running` after the message ends.

- [ ] `Sources/AgentViewKit/Streaming/EntryTextStream.swift`: delete the file. `TranscriptMessageView` and the thought view read the text of the entry object (`AgentMessageEntry.content`, `UserMessageEntry.content`, `ThoughtEntry.content`) in their body. The paragraph split (`ParagraphSplitter`) and the Markdown balance (`StreamingMarkdownBalancer`) are pure functions of that text. No `@State` and no kit `@Observable` object keeps a copy of the text.
- [ ] `Sources/AgentViewKit/Thread/SessionTranscriptEnvironment.swift`: delete `isLastWhileRunning(_:)`. No view decides from `agentState` and the transcript order that an entry streams. Keep `isRunning` only if a view shows `agentState` with it.
- [ ] `Sources/AgentViewKit/Items/TranscriptMessageView.swift` and `Sources/AgentViewKit/Items/ReasoningView.swift` (`ThoughtEntryBlock`): remove the `EntryTextStream` wrapper and the per-entry "live" and "in progress" state. A thought shows its text as the model holds it.
- [ ] The session path does not use `StreamingMessage` or `StreamingCoalescer`. (The kit model removal task deletes the two types when the thread path goes.)

## Acceptance Criteria
- [ ] After each chunk that the model applies (`flushPendingChunks()` in a test), the row shows the full text of the entry object, split into the same paragraphs as a pure call of `ParagraphSplitter` on that text.
- [ ] An agent message that is last while the model reports `agentState` `.running` shows the same view as the same message after `.idle`, except the views that read `agentState` directly.
- [ ] No source in `Sources/AgentViewKit/` calls `isLastWhileRunning` on a `SessionModel`, and no session-path view makes a `StreamingMessage`.
- [ ] A chunk to one entry evaluates the body of that row only.

## Tests
- [ ] `Tests/AgentViewKitTests/Thread/SessionTranscriptViewHostedTests.swift`: stream three chunks into one `AgentMessageEntry` through the scripted agent; after each flush, assert that the row text equals the entry text; send `idle` and assert that the row does not change.
- [ ] `Tests/AgentViewKitTests/Items/SessionEntryRowsHostedTests.swift`: a thought entry shows its text while running and after idle, with no in-progress state of the kit; with `BodyEvaluationCounter`, a chunk to one entry does not evaluate the other rows.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.