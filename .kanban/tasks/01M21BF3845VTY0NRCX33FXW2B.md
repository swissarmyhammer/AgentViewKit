---
comments:
- actor: claude-code
  id: 01m2pm529bj2j7rvwpcrbpy9yw
  text: |-
    ### finish iteration 1 — clean
    - implement: SessionThreadActions, SessionProfileHooks (with SessionActivityTimes), the hooks parameter of SessionThreadSource, and no error item for a cancelled stream. The gated stream tests now open the first gate before they read text.
    - test: timeout 1500 swift test, green: AgentViewKitTests 995, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 22, AgentViewKitFoundationModelsTests 43.
    - commit: 1a3a0dc
    - review: review sha HEAD~1..HEAD, 0 findings.

    SDK facts found with probes: each profile hook runs after its entry is complete, and the session waits for the hook. The session reads transcriptErrorHandlingPolicy when a turn starts. A cancelled stream throws CancellationError. A profile must be built outside the main actor, because the session takes it as a sending value.
  timestamp: 2026-09-17T02:46:53.995842+00:00
depends_on:
- 01M21AGTHBZSXFCZHZE5A7FQWQ
- 01M21CAWYA16NQ5MKZKBBH4DS6
position_column: done
position_ordinal: b780
title: SessionThreadActions and DynamicProfile timestamp hooks for FoundationModels (plan §3.3, §3.4)
---
## What
Create `Sources/AgentViewKitFoundationModels/SessionThreadActions.swift` and `SessionProfileHooks.swift`, per plan.md §3.3 and §3.4.

- `SessionThreadActions: AgentThreadActions` over a `SessionThreadSource`. `send` starts `source.stream(prompt)` in a `Task` the actions object keeps. `cancel` cancels that `Task`, then applies the host's `transcriptErrorHandlingPolicy` (`.revertTranscript` by default). The other verbs (permission, elicitation, config, connect, login, terminal auth, logout) log at `debug` and return, because the bare SDK has none of these.
- `SessionProfileHooks.install(on builder: inout DynamicProfileBuilder, source:)`: adds `.onPrompt`, `.onResponse`, `.onReasoning`, `.onToolCall`, and `.onToolOutput` that stamp `startedAt` on the matching record when it appears and `endedAt` when its output lands. The host calls this when it builds its profile. Without it, `SessionThreadSource` stamps observation times.
- The hooks also feed `ActivityTimeline` through the same timestamps.

Decision (SDK facts): `DynamicProfileBuilder` is a result builder, not a value. The shipped API is `SessionProfileHooks(clock:)`, `hooks.install(on: profile) -> some DynamicProfile`, and `SessionThreadSource(session:..., hooks:)`. The session reads the policy when a turn starts, so `send` writes the policy to the session before the turn.

## Acceptance Criteria
- [x] `send` then `cancel` leaves `thread.state == .idle` and the task cancelled.
- [x] With the hooks installed on a fake model that runs one tool, the tool record has `startedAt < endedAt`.
- [x] `respond(to: PermissionRequest,_:)` on this source does not throw and logs once.

## Tests
- [x] `Tests/AgentViewKitFoundationModelsTests/SessionThreadActionsTests.swift`: the three cases on the fake `LanguageModel`.
- [x] `swift test --filter AgentViewKitFoundationModelsTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 21:43)

Scope: `review sha HEAD~1..HEAD` (1a3a0dc). Zero findings.