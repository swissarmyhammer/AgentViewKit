---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4616577w8p7ssy0y38avaab
  text: |-
    Research done.
    - Branch code lives in `Model/Branches.swift` (BranchSet, branchUserMessageID, addBranch, selectBranch, isInHiddenBranch, hiddenBranchItem, regeneratedUserMessage) and `Items/BranchNavigator.swift`.
    - `AgentThread` has the `branches` property, the two apply cases, `branches = [:]` in clear, and a hidden-branch path in `closeStreaming`. `AgentThread.replaceItems(after:with:)` has one caller only: `selectBranch`. It becomes dead code, so it goes too.
    - No source outside these files calls `isInHiddenBranch` or `regeneratedUserMessage` now (the FoundationModels and Router sources are gone).
    - The demo app does not use branches. README and `Examples/ReadmeSnippets/Snippets/HostApp.swift` use `BranchNavigator` in `.messageFooter`.
    - `Docs/decisions/branches.md` stays. The card does not name it; the documents task rewrites the decision records.
    - New test file: `Tests/PackageStructureTests/RemovedVocabularyTests.swift`, which uses `PackageFiles.swiftFiles(in:)` on `Sources`.
  timestamp: 2026-10-05T12:38:59.559813+00:00
- actor: claude-code
  id: 01m461jhck9a21418ajp7rfv8j
  text: |-
    Implementation done (TDD).
    - RED: new `Tests/PackageStructureTests/RemovedVocabularyTests.swift`. `sourcesUseNoRemovedSymbol` failed with 18 uses of `BranchNavigator`, `addBranch` and `selectBranch` in `Sources/`. The two helper tests (whole-word match, no match in a longer word) passed.
    - GREEN: deleted `Model/Branches.swift`, `Items/BranchNavigator.swift`, `Model/BranchesTests.swift`, `Items/BranchNavigatorHostedTests.swift`. Removed `addBranch` and `selectBranch` from `ThreadChange`. Removed from `AgentThread`: the `branches` property, the two apply cases, `branches = [:]` in clear, the hidden-branch path in `closeStreaming`, and `replaceItems(after:with:)` (its only caller was `selectBranch`). `AgentThread.logger` is now `private`, because no extension in another file uses it now.
    - README and `HostApp.swift` snippet: the footer slot example now uses `MessageActions(message:)` in place of `BranchNavigator`. Ran `Scripts/extract-readme-snippets.sh`.
    - Not changed, on purpose: the `BranchNavigator` bullet in the README "Components" list. `ReadmeCoverageTests` holds that list equal to the plan.md §9 inventory, which still names `BranchNavigator`. The task "Rewrite plan.md, the remaining decision records and the README for an ACP client kit" must remove both lines, and `Docs/decisions/branches.md`. The FoundationModels removal task kept the `AgentTranscriptView` bullet in the same way.
  timestamp: 2026-10-05T12:45:45.235681+00:00
- actor: claude-code
  id: 01m461jvxv0f42t0h6g6rz90e2
  text: |-
    ### implement — changed
    - evidence: 9 files. Deleted: Sources/AgentViewKit/Model/Branches.swift, Sources/AgentViewKit/Items/BranchNavigator.swift, Tests/AgentViewKitTests/Model/BranchesTests.swift, Tests/AgentViewKitTests/Items/BranchNavigatorHostedTests.swift. Changed: Sources/AgentViewKit/Model/ThreadChange.swift, Sources/AgentViewKit/Model/AgentThread.swift, README.md, Examples/ReadmeSnippets/Snippets/HostApp.swift. Added: Tests/PackageStructureTests/RemovedVocabularyTests.swift.
    - commands: `swift test` passed (1 + 61 + 1265 + 128 tests, 0 warnings). `Scripts/check-readme.sh` passed. `Scripts/test-examples.sh AgentViewKitDemo` passed (2 UI tests). `Scripts/check-benchmarks.sh` failed on timing only: "The p90 chunk cost is 4.15 ms. The limit is 4.0 ms." Load averages during the run: 8.09 at start, 9.46 at end (uptime). This change does not touch the streaming chunk path.
    - next: /review. Open item for the documents task: the README "Components" bullet and the plan.md §9 line for `BranchNavigator`, and Docs/decisions/branches.md.
  timestamp: 2026-10-05T12:45:56.027867+00:00
depends_on:
- 01M443HB3E33J2VKEYYF9NN7AX
position_column: doing
position_ordinal: '8280'
title: 'Remove branches: addBranch, selectBranch, Branches and BranchNavigator'
---
## What
Only the FoundationModels source used branches. The owner decided to remove them now and add them again when ACP gives a producer (update.md §3 D5, §6).

- [x] Delete `Sources/AgentViewKit/Model/Branches.swift` and `Sources/AgentViewKit/Items/BranchNavigator.swift`.
- [x] Remove `addBranch` and `selectBranch` from `ThreadChange` (`Sources/AgentViewKit/Model/ThreadChange.swift`) and their apply code and branch state from `AgentThread` (`Sources/AgentViewKit/Model/AgentThread.swift`).
- [x] Remove the branch use from `Examples/ReadmeSnippets/Snippets/HostApp.swift` and from `README.md`. Run `Scripts/extract-readme-snippets.sh`.
- [x] Delete `Tests/AgentViewKitTests/Model/BranchesTests.swift` and `Tests/AgentViewKitTests/Items/BranchNavigatorHostedTests.swift`.

## Acceptance Criteria
- [x] No source, test or snippet uses `addBranch`, `selectBranch`, `Branches` or `BranchNavigator`.
- [x] `swift test` and `Scripts/check-readme.sh` pass.

## Tests
- [x] Add a check to `Tests/PackageStructureTests/` (a new `RemovedVocabularyTests.swift`) that scans `Sources/` and fails if it finds the symbols `BranchNavigator`, `addBranch` or `selectBranch`. The later removal tasks add their symbols to the same list.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.