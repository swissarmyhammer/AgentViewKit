---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m44dbpneqpqjnqd0a3jsgcpe
  text: |-
    Research done.
    - Router references are in: `Package.swift`, `Sources/AgentViewKitRouter/`, `Tests/AgentViewKitRouterTests/`, `ManifestTests.swift`, `README.md`, `Examples/ReadmeSnippets/Snippets/RouterQuickStart.swift`.
    - `ManifestTests.linksTheTestSupportTargetFromEachKitTestTarget` and `pinsTheSiblingPackagesToMain` also name the Router. They must change.
    - `ImportBoundaryTests` and its fixture `Fixtures/ImportBoundary/Violating/Nested/ImportsRuntimes.swift` name the Router as forbidden modules. The fixture is scanner test data that the build excludes. It is not a real import. update.md section 7 item 4 gives the import boundary change to the FoundationModels removal, so this task keeps it.
    - Comments in `Sources/AgentViewKit` (SubagentSource, CheckpointCapabilities, catalog.md) name the Router. They do not import it. Other removal tasks remove these files.
    - `Benchmarks/Package.resolved` has Router pins. The pin move tasks change that file.
    - FoundationModelsExtras stays in the root `Package.resolved` as a transitive dependency of FoundationModelsACPClient (update.md section 1).
  timestamp: 2026-10-04T21:33:15.310164+00:00
- actor: claude-code
  id: 01m44dqtre6mc3r7gvk2nj9n4t
  text: |-
    Implementation done (TDD).
    - RED: `ManifestTests` changed first. The product list has three products. New tests `declaresNoRouterOrExtrasPackage`, `linksNoRouterOrExtrasProduct` and `declaresNoRouterTarget`. Four tests failed for the expected reason. Then `Package.swift` changed, and all 12 tests passed.
    - `Package.swift`: the Router product, target, test target, the two packages and the `ReadmeSnippetsTests` dependencies are removed. The header comment says that the kit does not depend on FoundationModelsRouter or FoundationModelsExtras. The DemoSupport comment says "three library products".
    - `README.md`: the Router quick start, the `AgentViewKitRouter` product line and the Router and Extras dependency names are removed. The heading is now "Two quick starts". The intro says that a Router agent reaches the kit as an ACP agent. `Scripts/extract-readme-snippets.sh` wrote 3 snippets.
    - The import scanner fixture `Fixtures/ImportBoundary/Violating/Nested/ImportsRuntimes.swift` had `import FoundationModelsRouter` and `import ... FoundationModelsExtras...` lines. The acceptance criterion says no file in `Tests/` imports these modules. The fixture now uses `public import FoundationModelsACPClient` and `@_exported import struct FoundationModels.Transcript`, so it keeps the same declaration forms. `ImportBoundaryTests.scannerReportsEachForbiddenImportInTheFixture` changed first (RED), then the fixture (GREEN). The forbidden sets in `ImportBoundaryTests` still name the Router and Extras modules. The parser test arguments still hold these names as strings. They are not imports.
    - `Package.resolved` resolved again: the Router, mlx-swift, mlx-swift-lm, EventSource, swift-asn1 and swift-crypto pins are removed. FoundationModelsExtras stays as a transitive dependency of FoundationModelsACPClient. The FoundationModelsACP, FoundationModelsACPClient and EditorKit revisions did not change. Rainbow shows 4.2.1 to 4.2.2 in the diff. This can be from the earlier planning change to the file.
    - Not changed here, because other tasks own them: comments that name the Router in `Sources/AgentViewKit` (SubagentSource, CheckpointCapabilities, catalog.md), `Docs/decisions/*.md`, `plan.md`, and `Benchmarks/Package.resolved`.
    - Removing the Router also removes the mlx-swift build and its C++ warnings from the build.
  timestamp: 2026-10-04T21:39:52.718642+00:00
- actor: claude-code
  id: 01m44dqyze180jnw0w4qcpqwz1
  text: |-
    ### implement — changed
    - evidence: Package.swift, README.md, Tests/PackageStructureTests/ManifestTests.swift, Tests/PackageStructureTests/ImportBoundaryTests.swift, Tests/PackageStructureTests/Fixtures/ImportBoundary/Violating/Nested/ImportsRuntimes.swift, Package.resolved (resolved again); deleted Sources/AgentViewKitRouter/ (7 files), Tests/AgentViewKitRouterTests/ (7 files), Examples/ReadmeSnippets/Snippets/RouterQuickStart.swift. Commands: `swift test --filter ManifestTests` (RED 4 failed, then GREEN 12 passed), `swift test --filter ImportBoundaryTests` (RED, then GREEN 7 passed), `swift build --build-tests` (complete, 0 warnings), `swift test` (1511 tests passed, 0 failed), `swift test --filter PackageStructureTests` (47 passed), `Scripts/check-readme.sh` (passed).
    - next: review
  timestamp: 2026-10-04T21:39:57.038320+00:00
position_column: doing
position_ordinal: '80'
title: Remove the AgentViewKitRouter target
---
## What
The Router is not a direct dependency of an ACP client kit. A Router agent reaches the kit through FoundationModelsACPAgent and ACP. Source: update.md §1, §7 items 1, 2, 4.

- [x] Delete `Sources/AgentViewKitRouter/` and `Tests/AgentViewKitRouterTests/`.
- [x] In `Package.swift`: remove the `AgentViewKitRouter` product, target and test target. Remove `AgentViewKitRouter` and the `FoundationModelsRouter` product from `ReadmeSnippetsTests`. Remove the FoundationModelsRouter and FoundationModelsExtras packages from `dependencies`. Change the header comment.
- [x] Delete `Examples/ReadmeSnippets/Snippets/RouterQuickStart.swift` and the Router quick start in `README.md`. Run `Scripts/extract-readme-snippets.sh`.
- [x] Keep `Tests/Fixtures/subagent` for the subagent removal task. (The demo app does not link the Router product: `PACKAGE_PRODUCTS` in `generate_xcodeproj.rb` has no Router entry, so no demo change is necessary.)

## Acceptance Criteria
- [x] No file in `Sources/`, `Tests/`, `Examples/` or `Benchmarks/` imports `FoundationModelsRouter` or `FoundationModelsExtras`.
- [x] `Package.swift` has no Router product, target or package.
- [x] `swift build --build-tests`, `swift test` and `Scripts/check-readme.sh` pass.

## Tests
- [x] `Tests/PackageStructureTests/ManifestTests.swift`: change the expected product list. Add a test that the manifest has no `FoundationModelsRouter` and no `FoundationModelsExtras` package.
- [x] `swift test --filter PackageStructureTests` passes, then the full `swift test`.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.