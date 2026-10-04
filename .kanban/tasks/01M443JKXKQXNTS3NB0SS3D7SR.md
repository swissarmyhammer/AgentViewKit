---
assignees:
- claude-code
depends_on:
- 01M443HB3E33J2VKEYYF9NN7AX
position_column: todo
position_ordinal: '8980'
title: 'Remove branches: addBranch, selectBranch, Branches and BranchNavigator'
---
## What
Only the FoundationModels source used branches. The owner decided to remove them now and add them again when ACP gives a producer (update.md §3 D5, §6).

- [ ] Delete `Sources/AgentViewKit/Model/Branches.swift` and `Sources/AgentViewKit/Items/BranchNavigator.swift`.
- [ ] Remove `addBranch` and `selectBranch` from `ThreadChange` (`Sources/AgentViewKit/Model/ThreadChange.swift`) and their apply code and branch state from `AgentThread` (`Sources/AgentViewKit/Model/AgentThread.swift`).
- [ ] Remove the branch use from `Examples/ReadmeSnippets/Snippets/HostApp.swift` and from `README.md`. Run `Scripts/extract-readme-snippets.sh`.
- [ ] Delete `Tests/AgentViewKitTests/Model/BranchesTests.swift` and `Tests/AgentViewKitTests/Items/BranchNavigatorHostedTests.swift`.

## Acceptance Criteria
- [ ] No source, test or snippet uses `addBranch`, `selectBranch`, `Branches` or `BranchNavigator`.
- [ ] `swift test` and `Scripts/check-readme.sh` pass.

## Tests
- [ ] Add a check to `Tests/PackageStructureTests/` (a new `RemovedVocabularyTests.swift`) that scans `Sources/` and fails if it finds the symbols `BranchNavigator`, `addBranch` or `selectBranch`. The later removal tasks add their symbols to the same list.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.