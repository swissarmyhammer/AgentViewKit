---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5d9zx39pxjpdf2a4rfbnkvn
  text: |-
    Research: `forbiddenInSources` in ImportBoundaryTests.swift sets the forbidden modules of the "Sources" boundary. No file in Sources, Tests or Package.swift refers to KanbanViewKit or SnapshotViewKit. Package.swift excludes `Fixtures` from the PackageStructureTests build, so a fixture can import a module that the package does not have. The design text D105 is not in this repository.

    Work: added the new fixture directory `Fixtures/ImportBoundary/OtherKits/ImportsOtherKits.swift`. It imports KanbanViewKit, SnapshotViewKit and SwiftUI. Added the test `sourcesForbidTheImportsOfTheOtherViewKits`. It scans that fixture with `forbiddenInSources` and expects exactly ["KanbanViewKit", "SnapshotViewKit"]. RED: the test failed with `violations.map(\.module) → []`. GREEN: added "KanbanViewKit" and "SnapshotViewKit" to `forbiddenInSources` and updated the doc comments. The "Sources" boundary case passes on the real sources.
  timestamp: 2026-10-20T18:43:14.665697+00:00
- actor: claude-code
  id: 01m5d9zyz497m2znkfh2m2kdy4
  text: |-
    ### implement — changed
    - evidence: 2 files — Tests/PackageStructureTests/ImportBoundaryTests.swift, Tests/PackageStructureTests/Fixtures/ImportBoundary/OtherKits/ImportsOtherKits.swift (new). `swift test --filter PackageStructureTests`: 130 tests in 17 suites passed, 0 failed.
    - next: /review
  timestamp: 2026-10-20T18:43:16.580736+00:00
- actor: claude-code
  id: 01m5da3m1tfjw0p9hrqz5s2mw7
  text: |-
    ### test — green
    - evidence: swift test — 1348 tests in 158 suites passed, 0 failed, 0 skipped, 2 known issues (existed before). The only warning is the mlx bundle build warning (existed before). No new warning.
    - next: review
  timestamp: 2026-10-20T18:45:16.474521+00:00
- actor: claude-code
  id: 01m5da5fgmfaz9w1mfp9vzb00x
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 678dd17). 0 findings, 0 confirmed, 0 refuted. 2 files reviewed. 4 .kanban files not reviewed (ignore rule).
    - next: none. The task is in done.
  timestamp: 2026-10-20T18:46:17.364806+00:00
- actor: claude-code
  id: 01m5da5s6653whgy8bywv97gqg
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 2 files
    - test: green — swift test, 1348 passed, 2 known issues that were there before
    - commit: 678dd17
    - review: clean — 0 findings
  timestamp: 2026-10-20T18:46:27.270815+00:00
position_column: done
position_ordinal: fff280
title: 'AVK-7g Import boundary: AgentViewKit does not import the other view kits'
---
Design: D105 (g). Step 5 work, small.

Tests/PackageStructureTests/ImportBoundaryTests.swift has `forbiddenInSources` (line 14). Add `KanbanViewKit` and `SnapshotViewKit` to the forbidden modules of Sources, so that no kit links another kit. The scope kind text is the contract between the kits.

Acceptance: the test fails on a fixture that imports KanbanViewKit and passes on the sources. #avk-7