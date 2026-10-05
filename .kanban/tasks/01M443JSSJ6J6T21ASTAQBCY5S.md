---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m462nave2jn30jtwz0fbk3ma
  text: |-
    Research: the checkpoint code was in `Sources/AgentViewKit/Checkpoints/` (4 files), `Sources/AgentViewKitTestSupport/RecordingCheckpointActions.swift`, `ThreadChange.setCheckpoints`, and `AgentThread.checkpoints` (property, apply case, clear). The tests were in `Tests/AgentViewKitTests/Checkpoints/` (3 files). `BranchesTests.swift` does not exist. The demo app and the ACP target do not use checkpoints.

    RED: added "CheckpointCapabilities", "CheckpointView", "setCheckpoints" to `RemovedVocabularyTests.removedSymbols`. `swift test --filter RemovedVocabularyTests` failed with 14 uses in `Sources/`.

    GREEN: deleted the files with `git rm`, removed the case, the property, the apply case and the clear line, and removed "checkpoints" from the doc comment of `ThreadChange.clear`. The filter test passed.

    Not changed, on purpose: the README "Components" line for `CheckpointView` stays, because ReadmeCoverageTests holds the README list equal to plan.md §9, and task ^g95wwbs removes those lines from both files. `plan.md`, `plan-review.md`, `update.md` and `Docs/decisions/checkpoints.md` keep their checkpoint text for the same plan rewrite.

    The rules dump for `.swift` was 754K characters, which is too large to read in one pass. This task only deletes code and adds names to a list.
  timestamp: 2026-10-05T13:04:45.422210+00:00
- actor: claude-code
  id: 01m462ndr1z3scev63t9nxwx3c
  text: |-
    ### implement — changed
    - evidence: deleted Sources/AgentViewKit/Checkpoints/{Checkpoint,CheckpointActions,CheckpointCapabilities,CheckpointView}.swift, Sources/AgentViewKitTestSupport/RecordingCheckpointActions.swift, Tests/AgentViewKitTests/Checkpoints/{CheckpointTests,CheckpointCapabilitiesTests,CheckpointViewHostedTests}.swift; edited Sources/AgentViewKit/Model/ThreadChange.swift, Sources/AgentViewKit/Model/AgentThread.swift, Tests/PackageStructureTests/RemovedVocabularyTests.swift. `swift test` exit 0 (1245 + 128 + 65 + 1 tests pass, 0 warnings). `Scripts/test-examples.sh AgentViewKitDemo` passed (2 UI tests), with load averages 7.53 before and 10.33 after.
    - next: /review
  timestamp: 2026-10-05T13:04:48.385186+00:00
- actor: claude-code
  id: 01m462w1axz0g5xyx5ew0sz00e
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (cb62aa5) — 0 findings (findings 0, confirmed 0, refuted 0; 7 validators attempted, 0 failed). 11 files reviewed. 4 .kanban files not reviewed because of .reviewignore. The Swift tool rules did not read the 8 deleted files, because those files do not exist after the commit.
    - next: none — the task moved to done.
  timestamp: 2026-10-05T13:08:25.053205+00:00
- actor: claude-code
  id: 01m462w2x2v9nxgrabe49cnkfr
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — deleted the Checkpoints sources, RecordingCheckpointActions and the checkpoint tests; ThreadChange, AgentThread, RemovedVocabularyTests
    - test: green — swift test passed (1, 65, 1245, 128); demo UI gate passed
    - commit: cb62aa5
    - review: clean — 0 findings
  timestamp: 2026-10-05T13:08:26.658650+00:00
depends_on:
- 01M443JKXKQXNTS3NB0SS3D7SR
position_column: done
position_ordinal: d980
title: 'Remove checkpoints: setCheckpoints, Checkpoint, CheckpointCapabilities and CheckpointView'
---
## What
No source makes checkpoints. The owner decided to remove them now (update.md §3 D5, §6).

- [x] Delete `Sources/AgentViewKit/Checkpoints/` (`Checkpoint.swift`, `CheckpointActions.swift`, `CheckpointCapabilities.swift`, `CheckpointView.swift`) and `Sources/AgentViewKitTestSupport/RecordingCheckpointActions.swift`.
- [x] Remove `setCheckpoints` from `ThreadChange` and the checkpoint state from `AgentThread`.
- [x] Delete `Tests/AgentViewKitTests/Checkpoints/` (`CheckpointTests`, `CheckpointCapabilitiesTests`, `CheckpointViewHostedTests`). Remove the checkpoint parts of `Tests/AgentViewKitTests/Model/BranchesTests.swift` if that file still exists.
- [x] Add `setCheckpoints`, `CheckpointView` and `CheckpointCapabilities` to the symbol list in `Tests/PackageStructureTests/RemovedVocabularyTests.swift`.

## Acceptance Criteria
- [x] No source or test uses a checkpoint type.
- [x] `swift test` passes.

## Tests
- [x] `RemovedVocabularyTests` fails before the removal and passes after it.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.