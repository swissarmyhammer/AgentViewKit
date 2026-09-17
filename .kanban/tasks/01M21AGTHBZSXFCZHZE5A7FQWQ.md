---
comments:
- actor: claude-code
  id: 01m2pk29yr6r3kaerv5n963yew
  text: |-
    ### finish iteration 1 — findings
    - implement: SessionThreadSource, ContextWindow, SessionErrorMapping; FakeLanguageModel, FakeTools, source, observation, and error mapping tests; ChangeFlag and waitUntil moved to AgentViewKitTestSupport.
    - test: timeout 1500 swift test, green: AgentViewKitTests 995, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 22, AgentViewKitFoundationModelsTests 34.
    - commit: c99de54
    - review: 1 finding (magic-numbers-swift, SessionThreadSourceTests.swift:48).

    SDK facts found with probes: session.transcript changes during a stream; a stream snapshot comes one event late; session.usage is cumulative and Snapshot.usage is per response; the default error policy removes the prompt from the transcript.
  timestamp: 2026-09-17T02:27:54.968741+00:00
depends_on:
- 01M21ADYPYG3D8P53AAJQZZ61D
- 01M21ACSE9JBXMRD2FQQD4CYR6
position_column: doing
position_ordinal: '8180'
title: 'SessionThreadSource: live LanguageModelSession observation, streaming tail, usage, errors (plan §3.3)'
---
## What
Create `Sources/AgentViewKitFoundationModels/SessionThreadSource.swift`, per plan.md §3.3. The actions object and the profile hooks come in their own task.

- `SessionThreadSource` (`@MainActor`): takes a `LanguageModelSession` and an `AgentThread`. Seeds from `TranscriptMapping.items(for: session.transcript)`. Tracks `session.transcript` and `session.isResponding` with `withObservationTracking` in a loop and diffs the entry ids to emit inserts, replaces, and removes. Sets `thread.state` from `isResponding`.
- Streaming: `source.stream(_ prompt:)` runs `session.streamResponse(to:)`, feeds each `Snapshot.rawContent` text delta to `thread.streaming[id]`, and on completion closes the streaming message and applies the final entries from `Response.transcriptEntries`.
- `Snapshot.usage` and `session.usage` fill `ContextUsage` per `Docs/decisions/usage-model.md`. `LanguageModelError` cases become `.error` items with the case and its payload (`contextSizeExceeded` carries `contextSize` and `tokenCount`).
- Without profile hooks, the source stamps `startedAt` with the time it first observes an entry and `endedAt` when the matching output appears.

## Acceptance Criteria
- [x] After `respond` completes on a session with a fake `LanguageModel`, the thread has the new user and assistant items with the transcript ids.
- [x] During a stream, `thread.streaming[id]` grows and the record content is set on close.
- [x] A thrown `LanguageModelError.contextSizeExceeded` becomes an `.error` item with both counts.
- [x] A tool call record has `startedAt <= endedAt` after the tool output lands.

## Tests
- [x] `Tests/AgentViewKitFoundationModelsTests/FakeLanguageModel.swift`: a fake built on the macOS 27 `LanguageModelExecutor` protocol that scripts text, reasoning, and a tool call.
- [x] `Tests/AgentViewKitFoundationModelsTests/SessionThreadSourceTests.swift`: assert the thread after each step.
- [x] `Tests/AgentViewKitFoundationModelsTests/SessionThreadSourceObservationTests.swift`: a chunk invalidates only the streaming observer, not the items observer.
- [x] `swift test --filter AgentViewKitFoundationModelsTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 21:23)
- [ ] `Tests/AgentViewKitFoundationModelsTests/SessionThreadSourceTests.swift:48` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.