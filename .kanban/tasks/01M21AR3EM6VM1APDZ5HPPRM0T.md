---
comments:
- actor: claude-code
  id: 01m2nw5c29795kve2gav284mta
  text: |-
    ### implement — changed
    Decisions (made without a question, to match plan.md §9 E and Docs/decisions/checkpoints.md):
    - The library default of `checkpointActions` is `LoggingCheckpointActions` (it logs and does nothing), as `threadActions` does. The recorder is `RecordingCheckpointActions` in AgentViewKitTestSupport.
    - The three restore actions are a row of glass buttons, not a pull-down `Menu`. A menu item is not in the accessibility tree until the menu opens, so each action must be visible to be reachable and testable.
    - Each slider stop is also a button that selects its checkpoint. The last checkpoint is selected at first. The slider shows only for two or more checkpoints.
    - A restore "drops later turns" when it restores the conversation and a checkpoint with a larger `turnIndex` is in the list (`CheckpointView.dropsLaterTurns`). Only then the confirmation (`checkpoint-confirm`, `checkpoint-cancel`) shows. A code restore needs no confirmation.
    - A failed restore shows its error text (`checkpoint-error`).
    - `Checkpoint.init(id:turnIndex:createdAt:label:capabilities:)` sets the flags from `CheckpointCapabilities`. An init with explicit flags is for a host source that keeps its own file snapshots.
    - `ThreadChange.clear` also removes the checkpoints.
    - No task on the board adds a Router checkpoint source (a `CheckpointActions` that forks after each turn and calls `restoreSession`). A new task is necessary for it.
    - evidence: swift test, 646 + 71 + 85 + 20 + 1 tests pass; 10 new CheckpointView hosted tests and 5 Checkpoint model tests.
    - next: commit, then review.
  timestamp: 2026-09-16T19:47:38.185963+00:00
- actor: claude-code
  id: 01m2nw9rm41prsxyt7fm3rj8e4
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — Checkpoint.swift, CheckpointActions.swift, CheckpointView.swift, RecordingCheckpointActions.swift, AgentThread.swift, ThreadChange.swift, 2 test files
    - test: green — swift test, 646 + 85 + 71 + 20 + 1 tests pass, no new warnings
    - commit: 7e18f95
    - review: clean — review sha HEAD~1..HEAD, 0 findings (7 files reviewed)
  timestamp: 2026-09-16T19:50:02.116455+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21BZT72PPWS2479YRC8DJEE
- 01M21ABCXCQMMYMRK3QBM7CCJV
position_column: done
position_ordinal: a080
title: 'CheckpointView: history slider with restore code, conversation, or both, over a Checkpoint model (plan §9 E)'
---
## What
Create `Sources/AgentViewKit/Checkpoints/Checkpoint.swift` and `CheckpointView.swift`, per plan.md §9 E. The source capabilities come from the R13 research task and live in `Docs/decisions/checkpoints.md`.

- `Checkpoint { id, turnIndex, createdAt, label, canRestoreCode, canRestoreConversation }`. `AgentThread.checkpoints: [Checkpoint]` and `ThreadChange.setCheckpoints`.
- `CheckpointActions` protocol on the source: `restore(checkpoint, code: Bool, conversation: Bool) async throws`. The environment key `checkpointActions` defaults to a no-op recorder in test support.
- `CheckpointView(checkpoints:)`: a slider across turns with a label per stop (`checkpoint-stop-<index>`), and a menu with Restore code, Restore conversation, Restore both (`checkpoint-restore-code`, `checkpoint-restore-conversation`, `checkpoint-restore-both`), each enabled by the checkpoint flags. A confirmation (`checkpoint-confirm`) appears before a restore that drops later turns.
- The flags of each `Checkpoint` a source produces come from `CheckpointCapabilities` for that source.

## Acceptance Criteria
- [x] Five checkpoints mount five `checkpoint-stop-*` elements in order.
- [x] A checkpoint with `canRestoreCode == false` mounts `checkpoint-restore-code` as disabled.
- [x] A press on `checkpoint-restore-both` then `checkpoint-confirm` calls `restore` with both flags true.

## Tests
- [x] `Tests/AgentViewKitTests/Checkpoints/CheckpointViewHostedTests.swift`: the three cases through a recording `CheckpointActions`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.