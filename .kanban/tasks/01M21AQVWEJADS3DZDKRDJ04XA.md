---
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21C00SPMFVC8JE3YXHTJTAG
- 01M21ABCXCQMMYMRK3QBM7CCJV
position_column: todo
position_ordinal: aa80
title: SubagentTreeView over a SubagentRun model (plan §9 C, §11#15)
---
## What
Create `Sources/AgentViewKit/Subagents/SubagentRun.swift` and `SubagentTreeView.swift`, per plan.md decision 15. The data-source decision comes from the R14 research task and lives in `Docs/decisions/subagent-source.md`.

- `SubagentRun` (`@Observable`): `id`, `parentID`, `title`, `state` (`working`, `needsInput`, `readyForReview`, `done`, `failed`, `unknown(String)`), `startedAt`, `endedAt`, `threadID`. `AgentThread.subagents: [SubagentRun]` and `ThreadChange.upsertSubagent`.
- `SubagentTreeView(runs:)`: an outline of runs by parent, a state symbol per row, a Stop button that calls a host closure, and a drill-in that opens the child thread through a host closure. Identifiers `subagent-row-<id>`, `subagent-stop-<id>`, `subagent-open-<id>`.
- The adapter for `SubagentSource.v1` emits `upsertSubagent` from the fixture recorded by the R14 task. The other candidates stay unimplemented.

## Acceptance Criteria
- [ ] A three-level run tree mounts rows with the nesting level in the accessibility value.
- [ ] A state patch adds one evaluation to that row and zero to the others.
- [ ] Decoding `Tests/Fixtures/subagent/` through the v1 adapter produces at least one `upsertSubagent`.

## Tests
- [ ] `Tests/AgentViewKitTests/Subagents/SubagentTreeViewHostedTests.swift`.
- [ ] `Tests/AgentViewKitTests/Subagents/SubagentAdapterTests.swift`: the fixture mapping.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.