---
assignees:
- claude-code
depends_on:
- 01M443JKXKQXNTS3NB0SS3D7SR
position_column: todo
position_ordinal: 8a80
title: 'Remove checkpoints: setCheckpoints, Checkpoint, CheckpointCapabilities and CheckpointView'
---
## What
No source makes checkpoints. The owner decided to remove them now (update.md §3 D5, §6).

- [ ] Delete `Sources/AgentViewKit/Checkpoints/` (`Checkpoint.swift`, `CheckpointActions.swift`, `CheckpointCapabilities.swift`, `CheckpointView.swift`) and `Sources/AgentViewKitTestSupport/RecordingCheckpointActions.swift`.
- [ ] Remove `setCheckpoints` from `ThreadChange` and the checkpoint state from `AgentThread`.
- [ ] Delete `Tests/AgentViewKitTests/Checkpoints/` (`CheckpointTests`, `CheckpointCapabilitiesTests`, `CheckpointViewHostedTests`). Remove the checkpoint parts of `Tests/AgentViewKitTests/Model/BranchesTests.swift` if that file still exists.
- [ ] Add `setCheckpoints`, `CheckpointView` and `CheckpointCapabilities` to the symbol list in `Tests/PackageStructureTests/RemovedVocabularyTests.swift`.

## Acceptance Criteria
- [ ] No source or test uses a checkpoint type.
- [ ] `swift test` passes.

## Tests
- [ ] `RemovedVocabularyTests` fails before the removal and passes after it.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.