---
comments:
- actor: claude-code
  id: 01m2newdbkz3e4ry2nm3y2evke
  text: |-
    ### implement — changed
    - evidence: Docs/decisions/checkpoints.md, Sources/AgentViewKit/Checkpoints/CheckpointCapabilities.swift, Tests/AgentViewKitTests/Checkpoints/CheckpointCapabilitiesTests.swift. `swift test --filter AgentViewKitTests`: 374 tests in 32 suites passed.
    - decisions: router = no code, conversation yes, granularity `turn` (fork between turns through `RoutedSession.fork(workingDirectory:)`). acp = no code, no conversation, granularity `unavailable`, because `session/fork` is unstable only and plan.md of FoundationModelsACP forbids building on it. The Granularity enum has no `entry` case, because no v1 source gives an entry restore point. No v1 source restores code; `canRestoreCode` is false for each v1 checkpoint.
    - note for ^hpprm0t: the Checkpoint fields and rules are in the Decision section of checkpoints.md. The Router source must prove `restoreSession(id:)` on a nested fork id with a test.
    - next: test, commit, review
  timestamp: 2026-09-16T15:55:33.107574+00:00
- actor: claude-code
  id: 01m2nf574mdnqh5d5ehtrjbhdg
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 3 files (decision, CheckpointCapabilities, test)
    - test: green — swift test --filter AgentViewKitTests, 374 passed
    - commit: 3897f56
    - review: findings — Tests/AgentViewKitTests/Checkpoints/CheckpointCapabilitiesTests.swift:69 (reuse/reuse)
  timestamp: 2026-09-16T16:00:21.652791+00:00
- actor: claude-code
  id: 01m2nf9rbn2gw0afydpxekqrea
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — MarkdownTable helper; CheckpointCapabilitiesTests and ContextUsageTests use it
    - test: green — swift test --filter AgentViewKitTests, 374 passed
    - commit: b3f1518
    - review: clean — review sha HEAD~1..HEAD, 0 findings
  timestamp: 2026-09-16T16:02:50.357251+00:00
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
position_column: done
position_ordinal: '9080'
title: 'Research R13: checkpoint sources in the Router and ACP, recorded as the Checkpoint decision (plan §14)'
---
## What
Settle research R13 from plan.md §14 and record it where the code can check it.

- Read `makeFork()` in `../FoundationModelsRouter/Sources/FoundationModelsRouter/Session/LanguageModelSessionBackend.swift` and the transcript rewrite on compaction. Read `session/fork` in the ACP unstable method table in `../FoundationModelsACP`. Record what each can restore: code, conversation, or both, and at which granularity (turn, entry).
- Write `Docs/decisions/checkpoints.md` with a table `source | restores code | restores conversation | granularity | wire call` and the v1 decision for the `Checkpoint` model fields.
- Encode the decision: `Sources/AgentViewKit/Checkpoints/CheckpointCapabilities.swift` with one static `CheckpointCapabilities` value per source (`router`, `acp`) that a test compares with the table rows.

## Acceptance Criteria
- [x] `Docs/decisions/checkpoints.md` exists with the table and the decision.
- [x] `CheckpointCapabilities.router` and `.acp` match the table rows (a test parses the rows).

## Tests
- [x] `Tests/AgentViewKitTests/Checkpoints/CheckpointCapabilitiesTests.swift`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 10:55)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 2 file(s) reviewed, 3 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `Docs/decisions/checkpoints.md` — no validator matches this file

- [x] `Tests/AgentViewKitTests/Checkpoints/CheckpointCapabilitiesTests.swift:69` `reuse/reuse` — The tableRows() function reinvents markdown table parsing. Its algorithm (split lines, find header, filter table rows, extract cells) is 0.93 identical to UsageDecisionTable.rows() in ContextUsageTests.swift. The rule mandates that a near-match should be extended rather than copied. Extract a shared markdown table parser helper that accepts text and header, and accepts a cell-to-Row mapper function. Both tests can pass their respective mappers to avoid duplicating the core parse algorithm.