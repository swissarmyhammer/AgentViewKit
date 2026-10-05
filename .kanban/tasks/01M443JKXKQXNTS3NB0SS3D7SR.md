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
- actor: claude-code
  id: 01m461yc96ceys4c0xfrkbeee4
  text: |-
    ### review — findings
    - evidence: `review sha HEAD~1..HEAD` (commit c7e5dd8). 1 finding, 1 confirmed, 0 refuted. Tests/PackageStructureTests/RemovedVocabularyTests.swift:43 `reuse/reuse` — the `uses` function reinvents the line-scanning pattern from ImportScanner.violations(inSource:file:forbidden:).
    - next: /implement the finding in the dated `## Review Findings (2026-10-05 07:48)` section. The task stays in review.
  timestamp: 2026-10-05T12:52:13.222366+00:00
- actor: claude-code
  id: 01m461ye3c4ch84fjvys0zbg77
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — deleted Branches, BranchNavigator and their tests; ThreadChange, AgentThread, README, HostApp; RemovedVocabularyTests (new)
    - test: green — swift test, 1455 passed; README and demo UI gates passed; benchmark timing gate failed under load (p90 4.15 ms, limit 4.0 ms)
    - commit: c7e5dd8
    - review: findings — Tests/PackageStructureTests/RemovedVocabularyTests.swift:43
  timestamp: 2026-10-05T12:52:15.084118+00:00
- actor: claude-code
  id: 01m46265nx5fxnbqp91hztvffr
  text: |-
    Review finding `reuse/reuse` corrected (TDD).
    - RED: new `Tests/PackageStructureTests/SourceLineScannerTests.swift` (4 tests). The build failed because `SourceLineScanner` and `SourceLine` did not exist.
    - GREEN: new `Tests/PackageStructureTests/SourceLineScanner.swift`. `SourceLine` holds file, line number and text. `SourceLineScanner.matches(inSource:file:match:)` is the one line traversal (split, enumerate, number from 1). `SourceLineScanner.matches(inSwiftFilesBelow:relativeTo:match:)` is the one directory traversal (find Swift files, relative name, read text).
    - REFACTOR: `ImportScanner.violations(in:forbidden:)` now calls the shared scanner. `violations(inSource:file:forbidden:)` is replaced by the per-line matcher `violations(on:forbidden:)`. `ImportScanner.swift` does not import `PackageFileSupport` now. `RemovedVocabularyTests.uses(of:inSource:file:)` is replaced by the per-line matcher `uses(of:on:)`. `sourcesUseNoRemovedSymbol` uses the shared directory scan with `relativeTo: PackageFiles.root`, so the file names stay `Sources/...`. The two existing `uses` tests keep their assertions.
    - Not changed, on purpose: `ImportBoundaryTests.scannerReportsEachForbiddenImportInTheFixture` splits a fixture file into lines to check each violation. That is an existing test, and it reads lines by number, not by a scan.
  timestamp: 2026-10-05T12:56:28.605552+00:00
- actor: claude-code
  id: 01m46267zk36pxfvbz1hged368
  text: |-
    ### implement — changed
    - evidence: 4 files. Added: Tests/PackageStructureTests/SourceLineScanner.swift, Tests/PackageStructureTests/SourceLineScannerTests.swift. Changed: Tests/PackageStructureTests/ImportScanner.swift, Tests/PackageStructureTests/RemovedVocabularyTests.swift. Commands: `swift test --filter PackageStructureTests` passed (65 tests, 0 warnings). `swift test` passed (1 + 65 + 1265 + 128 = 1459 tests, 0 warnings).
    - next: /review. The finding `Tests/PackageStructureTests/RemovedVocabularyTests.swift:43` `reuse/reuse` is `- [x]`. The task stays in doing.
  timestamp: 2026-10-05T12:56:30.963324+00:00
- actor: claude-code
  id: 01m462dz387e67w1k4g8pgjh14
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` (commit 1224c36). 0 findings, 0 confirmed, 0 refuted. 4 files reviewed. All prior review items are checked.
    - next: none. The task moved to done.
  timestamp: 2026-10-05T13:00:44.008013+00:00
- actor: claude-code
  id: 01m462e09ccnvpwqapggdjvj0f
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — SourceLineScanner (new), SourceLineScannerTests (new), ImportScanner, RemovedVocabularyTests
    - test: green — swift test, 1459 passed
    - commit: 1224c36
    - review: clean — 0 findings
  timestamp: 2026-10-05T13:00:45.228233+00:00
depends_on:
- 01M443HB3E33J2VKEYYF9NN7AX
position_column: done
position_ordinal: d880
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

## Review Findings (2026-10-05 07:48)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 8 file(s) reviewed, 9 not reviewed.

> 8 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 8 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `README.md` — no validator matches this file

> ⚠️ tool rule 'code-hygiene/disallowed-constructs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> disallowed-constructs-swift found no file at Sources/AgentViewKit/Items/BranchNavigator.swift, so its constructs are unread

> ⚠️ tool rule 'code-hygiene/disallowed-constructs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> disallowed-constructs-swift found no file at Sources/AgentViewKit/Model/Branches.swift, so its constructs are unread

> ⚠️ tool rule 'code-hygiene/disallowed-constructs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> disallowed-constructs-swift found no file at Tests/AgentViewKitTests/Items/BranchNavigatorHostedTests.swift, so its constructs are unread

> ⚠️ tool rule 'code-hygiene/disallowed-constructs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> disallowed-constructs-swift found no file at Tests/AgentViewKitTests/Model/BranchesTests.swift, so its constructs are unread

> ⚠️ tool rule 'code-hygiene/function-length-swift' declined an item — it judged the rest of the code, and this it could not judge:
> function-length-swift found no file at Sources/AgentViewKit/Items/BranchNavigator.swift, so its bodies are unread

> ⚠️ tool rule 'code-hygiene/function-length-swift' declined an item — it judged the rest of the code, and this it could not judge:
> function-length-swift found no file at Sources/AgentViewKit/Model/Branches.swift, so its bodies are unread

> ⚠️ tool rule 'code-hygiene/function-length-swift' declined an item — it judged the rest of the code, and this it could not judge:
> function-length-swift found no file at Tests/AgentViewKitTests/Items/BranchNavigatorHostedTests.swift, so its bodies are unread

> ⚠️ tool rule 'code-hygiene/function-length-swift' declined an item — it judged the rest of the code, and this it could not judge:
> function-length-swift found no file at Tests/AgentViewKitTests/Model/BranchesTests.swift, so its bodies are unread

> ⚠️ tool rule 'code-hygiene/idioms-swift' declined an item — it judged the rest of the code, and this it could not judge:
> idioms-swift found no file at Sources/AgentViewKit/Items/BranchNavigator.swift, so its declarations are unread

> ⚠️ tool rule 'code-hygiene/idioms-swift' declined an item — it judged the rest of the code, and this it could not judge:
> idioms-swift found no file at Sources/AgentViewKit/Model/Branches.swift, so its declarations are unread

> ⚠️ tool rule 'code-hygiene/idioms-swift' declined an item — it judged the rest of the code, and this it could not judge:
> idioms-swift found no file at Tests/AgentViewKitTests/Items/BranchNavigatorHostedTests.swift, so its declarations are unread

> ⚠️ tool rule 'code-hygiene/idioms-swift' declined an item — it judged the rest of the code, and this it could not judge:
> idioms-swift found no file at Tests/AgentViewKitTests/Model/BranchesTests.swift, so its declarations are unread

> ⚠️ tool rule 'code-hygiene/magic-numbers-swift' declined an item — it judged the rest of the code, and this it could not judge:
> magic-numbers-swift found no file at Sources/AgentViewKit/Items/BranchNavigator.swift, so its literals are unread

> ⚠️ tool rule 'code-hygiene/magic-numbers-swift' declined an item — it judged the rest of the code, and this it could not judge:
> magic-numbers-swift found no file at Sources/AgentViewKit/Model/Branches.swift, so its literals are unread

> ⚠️ tool rule 'code-hygiene/magic-numbers-swift' declined an item — it judged the rest of the code, and this it could not judge:
> magic-numbers-swift found no file at Tests/AgentViewKitTests/Items/BranchNavigatorHostedTests.swift, so its literals are unread

> ⚠️ tool rule 'code-hygiene/magic-numbers-swift' declined an item — it judged the rest of the code, and this it could not judge:
> magic-numbers-swift found no file at Tests/AgentViewKitTests/Model/BranchesTests.swift, so its literals are unread

> ⚠️ tool rule 'code-hygiene/missing-docs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> missing-docs-swift found no file at Sources/AgentViewKit/Items/BranchNavigator.swift, so its declarations are unread

> ⚠️ tool rule 'code-hygiene/missing-docs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> missing-docs-swift found no file at Sources/AgentViewKit/Model/Branches.swift, so its declarations are unread

> ⚠️ tool rule 'code-hygiene/missing-docs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> missing-docs-swift found no file at Tests/AgentViewKitTests/Items/BranchNavigatorHostedTests.swift, so its declarations are unread

> ⚠️ tool rule 'code-hygiene/missing-docs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> missing-docs-swift found no file at Tests/AgentViewKitTests/Model/BranchesTests.swift, so its declarations are unread

- [x] `Tests/PackageStructureTests/RemovedVocabularyTests.swift:43` `reuse/reuse` — The `uses` function reinvents the line-scanning pattern from ImportScanner.violations(inSource:file:forbidden:). Both split source by newline, enumerate lines with offset, filter/map based on a predicate per line, and return results with file/line metadata. The matching logic differs (imports vs symbols), but the traversal pattern is identical and should be parameterized rather than duplicated. Extract a generic line-scanner utility that accepts a predicate function, or extend ImportScanner to support multiple match types beyond imports. Both can then call the shared scanning function with their respective matching logic.
