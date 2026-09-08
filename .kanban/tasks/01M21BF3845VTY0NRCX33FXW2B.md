---
depends_on:
- 01M21AGTHBZSXFCZHZE5A7FQWQ
- 01M21CAWYA16NQ5MKZKBBH4DS6
position_column: todo
position_ordinal: b880
title: SessionThreadActions and DynamicProfile timestamp hooks for FoundationModels (plan §3.3, §3.4)
---
## What
Create `Sources/AgentViewKitFoundationModels/SessionThreadActions.swift` and `SessionProfileHooks.swift`, per plan.md §3.3 and §3.4.

- `SessionThreadActions: AgentThreadActions` over a `SessionThreadSource`. `send` starts `source.stream(prompt)` in a `Task` the actions object keeps. `cancel` cancels that `Task`, then applies the host's `transcriptErrorHandlingPolicy` (`.revertTranscript` by default). The other verbs (permission, elicitation, config, connect, login, terminal auth, logout) log at `debug` and return, because the bare SDK has none of these.
- `SessionProfileHooks.install(on builder: inout DynamicProfileBuilder, source:)`: adds `.onPrompt`, `.onResponse`, `.onReasoning`, `.onToolCall`, and `.onToolOutput` that stamp `startedAt` on the matching record when it appears and `endedAt` when its output lands. The host calls this when it builds its profile. Without it, `SessionThreadSource` stamps observation times.
- The hooks also feed `ActivityTimeline` through the same timestamps.

## Acceptance Criteria
- [ ] `send` then `cancel` leaves `thread.state == .idle` and the task cancelled.
- [ ] With the hooks installed on a fake model that runs one tool, the tool record has `startedAt < endedAt`.
- [ ] `respond(to: PermissionRequest,_:)` on this source does not throw and logs once.

## Tests
- [ ] `Tests/AgentViewKitFoundationModelsTests/SessionThreadActionsTests.swift`: the three cases on the fake `LanguageModel`.
- [ ] `swift test --filter AgentViewKitFoundationModelsTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.