---
comments:
- actor: claude-code
  id: 01m2ns5en1vk2w5p27cjw6056v
  text: |-
    ### implement — changed
    Decisions (no user question, per plan.md and Docs/decisions/subagent-source.md):
    - The v1 adapter is `SubagentMapping` in `AgentViewKitRouter`, because it reads `TranscriptEvent`. Its tests are in `Tests/AgentViewKitRouterTests/Subagents/SubagentAdapterTests.swift`. The `AgentViewKitTests` target cannot import the Router (ImportBoundaryTests). The Router test target now links `PackageFileSupport`.
    - `RouterThreadSource` gets `apply(_: TranscriptEvent)` and an injectable `clock`. A parent session event patches a run only when the thread has that run.
    - The row identifier and the level value (`Level N`) are on a leaf element (state symbol + title). A SwiftUI container element does not give its accessibility value. The row label is `<title>, <state>`.
    - The Stop button shows only when the host gives `onStop` and the run is active (`working`, `needsInput`). The Open button shows only when the host gives `onOpen`; it is disabled until the run has a `threadID`.
    - `ThreadChange.clear` also removes the subagent runs. A cancelled `runSettled` outcome gives `unknown("cancelled")`.
    - evidence: swift test, 761 tests pass, 0 fail.
  timestamp: 2026-09-16T18:55:15.105037+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21C00SPMFVC8JE3YXHTJTAG
- 01M21ABCXCQMMYMRK3QBM7CCJV
position_column: doing
position_ordinal: '8180'
title: SubagentTreeView over a SubagentRun model (plan §9 C, §11#15)
---
## What
Create `Sources/AgentViewKit/Subagents/SubagentRun.swift` and `SubagentTreeView.swift`, per plan.md decision 15. The data-source decision comes from the R14 research task and lives in `Docs/decisions/subagent-source.md`.

- `SubagentRun` (`@Observable`): `id`, `parentID`, `title`, `state` (`working`, `needsInput`, `readyForReview`, `done`, `failed`, `unknown(String)`), `startedAt`, `endedAt`, `threadID`. `AgentThread.subagents: [SubagentRun]` and `ThreadChange.upsertSubagent`.
- `SubagentTreeView(runs:)`: an outline of runs by parent, a state symbol per row, a Stop button that calls a host closure, and a drill-in that opens the child thread through a host closure. Identifiers `subagent-row-<id>`, `subagent-stop-<id>`, `subagent-open-<id>`.
- The adapter for `SubagentSource.v1` emits `upsertSubagent` from the fixture recorded by the R14 task. The other candidates stay unimplemented.

## Acceptance Criteria
- [x] A three-level run tree mounts rows with the nesting level in the accessibility value.
- [x] A state patch adds one evaluation to that row and zero to the others.
- [x] Decoding `Tests/Fixtures/subagent/` through the v1 adapter produces at least one `upsertSubagent`.

## Tests
- [x] `Tests/AgentViewKitTests/Subagents/SubagentTreeViewHostedTests.swift`.
- [x] `Tests/AgentViewKitRouterTests/Subagents/SubagentAdapterTests.swift`: the fixture mapping. (The `AgentViewKitTests` target cannot import the Router, so this file is in the Router test target.)
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.