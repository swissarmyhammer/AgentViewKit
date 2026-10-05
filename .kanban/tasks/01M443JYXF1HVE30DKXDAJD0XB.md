---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m46343w5ab81asn6fnsnkf5q
  text: |-
    Research and work done:
    - Only these files referred to subagents in code: the three files in `Sources/AgentViewKit/Subagents/`, `Model/ThreadChange.swift`, `Model/AgentThread.swift`, and the three test files in `Tests/AgentViewKitTests/Subagents/`. No file in the demo, `AgentViewKitACP` or `DemoSupport` used them.
    - `PackageFileSupport` did not hold the fixture path. Only `SubagentSourceTests` held it. `Tests/Fixtures/` held only `subagent/`, so the `Tests/Fixtures/` directory is gone now. `Package.swift` did not refer to it.
    - `AgentThread` lost `subagents`, `subagentIndex`, `subagent(id:)`, the `upsertSubagent` case in `apply(_:)`, the private `upsertSubagent(_:)`, and the two resets in `clear()`. The doc of `ThreadChange.clear` does not name subagent runs now.
    - `RemovedVocabularyTests.removedSymbols` has a "Subagents" group: `SubagentRun`, `SubagentSource`, `SubagentTreeView`, `upsertSubagent`. `SubagentRun` is added too, because the title of the task names it. The whole-word match does not find `SubagentRun` in `SubagentRunID`, but `SubagentRunID` was declared in the deleted `SubagentRun.swift`.
    - RED: `swift test --filter RemovedVocabularyTests` failed with 32 uses in Sources. GREEN: the same command passed after the removal.
    - Not changed, on purpose: `README.md` (the Components line for `SubagentTreeView`; ReadmeCoverageTests ties it to plan.md §9, and ^g95wwbs removes those lines), `plan.md`, `plan-review.md`, `update.md`, and `Docs/decisions/subagent-source.md`. The decision record still names the deleted fixture path `Tests/Fixtures/subagent/router-agent-spawn.jsonl`. update.md tells the decision-record work to remove or mark that record.
  timestamp: 2026-10-05T13:12:49.797518+00:00
- actor: claude-code
  id: 01m46347bfra5anjfdz1wzs4ft
  text: |-
    ### implement — changed
    - evidence: deleted Sources/AgentViewKit/Subagents/ (3 files), Tests/AgentViewKitTests/Subagents/ (3 files), Tests/Fixtures/subagent/router-agent-spawn.jsonl; edited Sources/AgentViewKit/Model/AgentThread.swift, Sources/AgentViewKit/Model/ThreadChange.swift, Tests/PackageStructureTests/RemovedVocabularyTests.swift. `swift test --filter RemovedVocabularyTests` red, then green. `swift test`: 1222 tests in 105 suites passed, plus the other test bundles, 0 failures, 0 compiler warnings. `Scripts/test-examples.sh AgentViewKitDemo`: PASS.
    - next: /review
  timestamp: 2026-10-05T13:12:53.359058+00:00
depends_on:
- 01M443JSSJ6J6T21ASTAQBCY5S
position_column: doing
position_ordinal: '8280'
title: 'Remove subagents: upsertSubagent, SubagentRun, SubagentSource and SubagentTreeView'
---
## What
Only the Router made subagents. The owner decided to remove them now (update.md §3 D5, §6).

- [x] Delete `Sources/AgentViewKit/Subagents/` (`SubagentRun.swift`, `SubagentSource.swift`, `SubagentTreeView.swift`).
- [x] Remove `upsertSubagent` from `ThreadChange` and the subagent state from `AgentThread`.
- [x] Delete `Tests/AgentViewKitTests/Subagents/` (`SubagentRunTests`, `SubagentSourceTests`, `SubagentTreeViewHostedTests`) and `Tests/Fixtures/subagent/`. Remove the fixture path from `PackageFileSupport` if it is there.
- [x] Add `upsertSubagent`, `SubagentSource` and `SubagentTreeView` to the symbol list in `Tests/PackageStructureTests/RemovedVocabularyTests.swift`.

## Acceptance Criteria
- [x] No source, test or fixture refers to subagents.
- [x] `swift test` passes.

## Tests
- [x] `RemovedVocabularyTests` fails before the removal and passes after it.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.