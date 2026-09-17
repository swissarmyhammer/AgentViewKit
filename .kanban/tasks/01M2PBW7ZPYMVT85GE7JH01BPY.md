---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m2pcx8yeq91hzj4q1av5mdje
  text: |-
    ### finish iteration 1 — findings
    - implement: added the `hostedSerially` trait (Tests/AgentViewKitTests/Helpers/HostedSerialTrait.swift). It holds one process lock for each hosted test. Added the trait to each hosted suite.
    - test: five parallel `swift test` runs passed (950/93/71/20/1 each). `swift test --no-parallel` passed. No new warnings.
    - commit: 524b3d5
    - review: 1 finding (completeness/invariant-propagation at ResponseViewHostedTests.swift:9). Fix: a new test checks that each hosted test file has the trait.
  timestamp: 2026-09-17T00:40:18.638009+00:00
- actor: claude-code
  id: 01m2pdb7110y4sdfv6023x2vt6
  text: |-
    ### finish iteration 2 — findings
    - implement: added HostedSerialTraitTests (lock tests and a scan that fails when a hosted test file has no `.hostedSerially`).
    - test: `swift test --no-parallel` and one parallel run passed (953/93/71/20/1). No new warnings.
    - commit: 2be3386
    - review: 2 findings (swift/immutability at HostedSerialTraitTests.swift:79; reuse/reuse at HostedSerialTraitTests.swift:97).
  timestamp: 2026-09-17T00:47:55.425302+00:00
- actor: claude-code
  id: 01m2pdb8djvmmac1hajq139eje
  text: |-
    ### finish iteration 3 — clean
    - implement: moved `swiftFiles(in:)` to `PackageFiles` (PackageFileSupport) with two tests. ImportScanner and HostedSerialTraitTests use it. The scan builds its list with `compactMap`.
    - test: `swift test --no-parallel` and one parallel run passed (953/93/71/22/1). No new warnings.
    - commit: ca9bbdf
    - review: 0 findings. All prior items checked.
  timestamp: 2026-09-17T00:47:56.850353+00:00
position_column: done
position_ordinal: b180
title: Make the hosted tests stable when swift test runs suites in parallel
---
## What
In a parallel `swift test` run (the default), some hosted tests fail on some runs. The same tests pass with `swift test --no-parallel` and when their suite runs alone. The failures also occur on 3b9ce9d, before ^y5ra063.

Seen failures:
- `EditorKitPromptEditorHostedTests.aSlashListsTheCommandsAndReturnAcceptsOne`: the completion list does not open after "/" (the editor text is "/" and the editor is the first responder).
- `SessionListViewHostedTests.loadMoreAddsTheSecondPageAndGoesAway`
- `AuthorizationViewHostedTests.aThrownErrorShowsTheMessageAndARetryButton`
- `CheckpointViewHostedTests.aFailedRestoreShowsTheError`

Notes:
- Each `HostedViewHarness` makes its window key at init, so windows of parallel suites take the key status from each other.
- A SwiftUI focus set in `onAppear` (`isFocused = true`) made the EditorKit completion test fail more often. `PermissionView` uses `.defaultFocus` for this reason. `ElicitationView` still sets the focus in `onAppear`.
- The machine was under load (sourcekit-lsp at 100% CPU) during the runs.

## Acceptance Criteria
- [x] Five parallel `swift test` runs in a row pass with the same test counts.

## Tests
- [x] Run `swift test` five times and record the result of each run. Result (524b3d5): runs 1 to 5 all passed with AgentViewKitTests 950, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 20, AgentViewKitFoundationModelsTests 1. After ca9bbdf, one parallel run and one `--no-parallel` run passed with 953, 93, 71, 22, 1.

## Review Findings (2026-09-16 19:29)
- [x] `Tests/AgentViewKitTests/Content/ResponseViewHostedTests.swift:9` `completeness/invariant-propagation` — The `.hostedSerially` trait is added to serialize hosted test execution and prevent key window conflicts. However, many other hosted test suites in the codebase are near-copies of the changed files (per the `duplicates` probe at 0.85–0.96 similarity) but were not updated with the same trait. If the problem affects all hosted tests taking the key window from each other, all hosted test suites should receive the same treatment to apply the fix uniformly. Apply @Suite(.serialized, .hostedSerially) to all remaining hosted test suites in the codebase. The commit message states 'Hosted tests take the key window from each other' and 'run hosted tests one at a time', implying all hosted tests need this trait, not just the 9 modified here.

## Review Findings (2026-09-16 19:40)
- [x] `Tests/AgentViewKitTests/TestSupport/HostedSerialTraitTests.swift:79` `swift/immutability` — Build a collection with `compactMap`, not a `var` accumulator. The mutable variable requires walking every line of the loop body to understand the final result. Replace with `let missing = try files.compactMap { file -> String? in let text = try String(contentsOf: file, encoding: .utf8); let isHosted = Self.hostingMarkers.contains { text.contains($0) }; guard text.contains(Self.testMarker), isHosted, !text.contains(Self.traitMarker) else { return nil }; return file.lastPathComponent }`.
- [x] `Tests/AgentViewKitTests/TestSupport/HostedSerialTraitTests.swift:97` `reuse/reuse` — The `swiftFiles` function reimplements the same capability that already exists in `ImportScanner.swift:90`. The function enumerates Swift files in a folder with identical logic and contract, duplicating behavior that should be shared. Extract `swiftFiles` to a shared test utility module that both `HostedSerialTraitTests` and `ImportScanner` can reuse, rather than maintaining duplicate implementations.

## Review Findings (2026-09-16 19:45)
No findings.