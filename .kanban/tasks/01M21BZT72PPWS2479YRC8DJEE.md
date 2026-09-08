---
depends_on:
- 01M21A8RWGWE533JR6GQ4DNN06
position_column: todo
position_ordinal: c680
title: 'Research R13: checkpoint sources in the Router and ACP, recorded as the Checkpoint decision (plan §14)'
---
## What
Settle research R13 from plan.md §14 and record it where the code can check it.

- Read `makeFork()` in `../FoundationModelsRouter/Sources/FoundationModelsRouter/Session/LanguageModelSessionBackend.swift` and the transcript rewrite on compaction. Read `session/fork` in the ACP unstable method table in `../FoundationModelsACP`. Record what each can restore: code, conversation, or both, and at which granularity (turn, entry).
- Write `Docs/decisions/checkpoints.md` with a table `source | restores code | restores conversation | granularity | wire call` and the v1 decision for the `Checkpoint` model fields.
- Encode the decision: `Sources/AgentViewKit/Checkpoints/CheckpointCapabilities.swift` with one static `CheckpointCapabilities` value per source (`router`, `acp`) that a test compares with the table rows.

## Acceptance Criteria
- [ ] `Docs/decisions/checkpoints.md` exists with the table and the decision.
- [ ] `CheckpointCapabilities.router` and `.acp` match the table rows (a test parses the rows).

## Tests
- [ ] `Tests/AgentViewKitTests/Checkpoints/CheckpointCapabilitiesTests.swift`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.