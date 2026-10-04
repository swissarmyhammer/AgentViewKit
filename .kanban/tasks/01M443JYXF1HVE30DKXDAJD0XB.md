---
assignees:
- claude-code
depends_on:
- 01M443JSSJ6J6T21ASTAQBCY5S
position_column: todo
position_ordinal: 8b80
title: 'Remove subagents: upsertSubagent, SubagentRun, SubagentSource and SubagentTreeView'
---
## What
Only the Router made subagents. The owner decided to remove them now (update.md §3 D5, §6).

- [ ] Delete `Sources/AgentViewKit/Subagents/` (`SubagentRun.swift`, `SubagentSource.swift`, `SubagentTreeView.swift`).
- [ ] Remove `upsertSubagent` from `ThreadChange` and the subagent state from `AgentThread`.
- [ ] Delete `Tests/AgentViewKitTests/Subagents/` (`SubagentRunTests`, `SubagentSourceTests`, `SubagentTreeViewHostedTests`) and `Tests/Fixtures/subagent/`. Remove the fixture path from `PackageFileSupport` if it is there.
- [ ] Add `upsertSubagent`, `SubagentSource` and `SubagentTreeView` to the symbol list in `Tests/PackageStructureTests/RemovedVocabularyTests.swift`.

## Acceptance Criteria
- [ ] No source, test or fixture refers to subagents.
- [ ] `swift test` passes.

## Tests
- [ ] `RemovedVocabularyTests` fails before the removal and passes after it.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.