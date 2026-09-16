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
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
position_column: doing
position_ordinal: '8180'
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