---
depends_on:
- 01M21ADYPYG3D8P53AAJQZZ61D
- 01M21ACSE9JBXMRD2FQQD4CYR6
position_column: todo
position_ordinal: '9280'
title: 'SessionThreadSource: live LanguageModelSession observation, streaming tail, usage, errors (plan §3.3)'
---
## What
Create `Sources/AgentViewKitFoundationModels/SessionThreadSource.swift`, per plan.md §3.3. The actions object and the profile hooks come in their own task.

- `SessionThreadSource` (`@MainActor`): takes a `LanguageModelSession` and an `AgentThread`. Seeds from `TranscriptMapping.items(for: session.transcript)`. Tracks `session.transcript` and `session.isResponding` with `withObservationTracking` in a loop and diffs the entry ids to emit inserts, replaces, and removes. Sets `thread.state` from `isResponding`.
- Streaming: `source.stream(_ prompt:)` runs `session.streamResponse(to:)`, feeds each `Snapshot.rawContent` text delta to `thread.streaming[id]`, and on completion closes the streaming message and applies the final entries from `Response.transcriptEntries`.
- `Snapshot.usage` and `session.usage` fill `ContextUsage` per `Docs/decisions/usage-model.md`. `LanguageModelError` cases become `.error` items with the case and its payload (`contextSizeExceeded` carries `contextSize` and `tokenCount`).
- Without profile hooks, the source stamps `startedAt` with the time it first observes an entry and `endedAt` when the matching output appears.

## Acceptance Criteria
- [ ] After `respond` completes on a session with a fake `LanguageModel`, the thread has the new user and assistant items with the transcript ids.
- [ ] During a stream, `thread.streaming[id]` grows and the record content is set on close.
- [ ] A thrown `LanguageModelError.contextSizeExceeded` becomes an `.error` item with both counts.
- [ ] A tool call record has `startedAt <= endedAt` after the tool output lands.

## Tests
- [ ] `Tests/AgentViewKitFoundationModelsTests/FakeLanguageModel.swift`: a fake built on the macOS 27 `LanguageModelExecutor` protocol that scripts text, reasoning, and a tool call.
- [ ] `Tests/AgentViewKitFoundationModelsTests/SessionThreadSourceTests.swift`: assert the thread after each step.
- [ ] `Tests/AgentViewKitFoundationModelsTests/SessionThreadSourceObservationTests.swift`: a chunk invalidates only the streaming observer, not the items observer.
- [ ] `swift test --filter AgentViewKitFoundationModelsTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.