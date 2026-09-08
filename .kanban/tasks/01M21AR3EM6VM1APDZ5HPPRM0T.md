---
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21BZT72PPWS2479YRC8DJEE
- 01M21ABCXCQMMYMRK3QBM7CCJV
position_column: todo
position_ordinal: ab80
title: 'CheckpointView: history slider with restore code, conversation, or both, over a Checkpoint model (plan §9 E)'
---
## What
Create `Sources/AgentViewKit/Checkpoints/Checkpoint.swift` and `CheckpointView.swift`, per plan.md §9 E. The source capabilities come from the R13 research task and live in `Docs/decisions/checkpoints.md`.

- `Checkpoint { id, turnIndex, createdAt, label, canRestoreCode, canRestoreConversation }`. `AgentThread.checkpoints: [Checkpoint]` and `ThreadChange.setCheckpoints`.
- `CheckpointActions` protocol on the source: `restore(checkpoint, code: Bool, conversation: Bool) async throws`. The environment key `checkpointActions` defaults to a no-op recorder in test support.
- `CheckpointView(checkpoints:)`: a slider across turns with a label per stop (`checkpoint-stop-<index>`), and a menu with Restore code, Restore conversation, Restore both (`checkpoint-restore-code`, `checkpoint-restore-conversation`, `checkpoint-restore-both`), each enabled by the checkpoint flags. A confirmation (`checkpoint-confirm`) appears before a restore that drops later turns.
- The flags of each `Checkpoint` a source produces come from `CheckpointCapabilities` for that source.

## Acceptance Criteria
- [ ] Five checkpoints mount five `checkpoint-stop-*` elements in order.
- [ ] A checkpoint with `canRestoreCode == false` mounts `checkpoint-restore-code` as disabled.
- [ ] A press on `checkpoint-restore-both` then `checkpoint-confirm` calls `restore` with both flags true.

## Tests
- [ ] `Tests/AgentViewKitTests/Checkpoints/CheckpointViewHostedTests.swift`: the three cases through a recording `CheckpointActions`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.