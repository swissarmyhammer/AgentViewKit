---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8drpzw37wxc5mttwg3w99pq
  text: |-
    ### review — findings
    - evidence: `review sha 483f527b^1..483f527b` gives 0 findings (0 confirmed, 0 refuted, 7 validators run, 0 failed). The diff has no findings. The card stays in review because no item on the card is checked, and the review skill does not let the reviewer set the checks.
    - evidence that I checked: c857a766, 45123917, 90dcacfd and d94b771d all contain 483f527b. CI run 45940010012 is on d94b771d, and its 3 jobs ("Build & test", "Examples (AgentViewKitDemo)", "Integration (opt-in, real dependencies)") are success. IntegrationTests/Package.resolved pins EK main at 1892af46.
    - evidence that I did not check: the full IntegrationTests counts (1099 pass, 5 known issues in FontRoleExpectationsTests), and the start and end lines to the 4 peers for the hosted run. These come only from the relay.
    - what the evidence proves: items "What" 1 and 2, "Acceptance" 1, and "Tests" 1 and 2 have support, if the implementer confirms the counts. "What" 3 has support from the note "no place had targets too close". The card names EK ^frjgqyz, but the evidence names EK ^5851ngm and ^g0kk4m2. Someone must record that these cards replace ^frjgqyz, or give the sha of ^frjgqyz.
    - open: "Acceptance" 2 (the test fails on an EK version without the layout) was not run. The EK JumpChipLayoutTests are proof of the EK layout only, not proof that this AVK test can fail. The card does not permit the EK tests as proof. The item stays open until a person runs the test on an older EK pin or writes on the card that the EK tests are sufficient.
    - next: the implementer or the user sets the checks on the items that the evidence proves, records the RED result or the permission, and runs /review again.
  timestamp: 2026-11-27T05:47:36.707244+00:00
- actor: claude-code
  id: 01m8drx0q7ev5z07k9bqspj5mz
  text: |-
    ### RED setup for Acceptance item 2 (not run yet)
    - EK base: f2ed9109, the first parent of EK fd4419a9 (the first ^5851ngm commit, "jump chips never overlap"). The older EK has every EK API that the test uses: `JumpModeController.activate(layer:)`, `overlayState?.chips`, `HostedViewHarness`, `accessibilityElements(identifiedAs:under:)`, `accessibilityFrame(of:)`.
    - AVK base: ec9b9b8e (2026-11-26 07:07), the last AVK main commit before EK fd4419a9 (08:06). AVK follows EK `main` and does not track Package.resolved, so this AVK commit was made against an EK before the layout. Each AVK symbol that the test uses is in ec9b9b8e (git grep).
    - EK worktree: scratchpad/ek-wt/jumpred (detached at f2ed9109).
    - AVK worktree: scratchpad/avk-wt/jumpred (detached at ec9b9b8e). Changes: the test file from 483f527b only; IntegrationTests/Package.swift pins EK with `.package(path: "deps/EditorKit")`; IntegrationTests/deps/EditorKit is a symlink to the EK worktree (a path package takes its identity from its folder name, as in the spike-* harnesses); IntegrationTests/Package.resolved is the main copy with no editorkit pin (the FMACP pins date from 2026-11-24, before ec9b9b8e).
    - The build `swift build --package-path IntegrationTests --build-tests` did not run yet: a coordinator HOLD stops all builds.
    - What did not work: nothing tried yet. Watch for: the root package `..` names EK by URL; the root path pin of IntegrationTests must override it, as in spike-before.
  timestamp: 2026-11-27T05:50:54.183853+00:00
- actor: claude-code
  id: 01m8dtn7gk23tznv71jesjdbd9
  text: |-
    RED build: the build passes. The first build stopped because the disk was full (ENOSPC). After the coordinator made space (675 GB free), I built again.
    - Command: `swift build --package-path IntegrationTests --build-tests` in scratchpad/avk-wt/jumpred. Exit 0. "Build complete! (105.28 sec)". 0 errors.
    - Revisions: AVK ec9b9b8e. EK f2ed9109 through IntegrationTests/deps/EditorKit (link to scratchpad/ek-wt/jumpred). The workspace state uses this local path. No EditorKit checkout from GitHub is in .build/checkouts.
    - Test file: IntegrationTests/Tests/IntegrationTests/Commands/JumpLabelOverlapHostedTests.swift compiles into the IntegrationTests product.
    - Warnings: 133. 130 are C++17-extension warnings in the third-party .build/checkouts/mlx-swift. 1 is a "missing creator for mutated node" build-system warning for the mlx-swift_Cmlx bundle. 2 are a SwiftPM "Conflicting identity for editorkit" warning. The cause of these 2 is the RED setup: the root package gets EK from GitHub and IntegrationTests/deps/EditorKit gives a local path with the same identity. No warning is in AVK or EK source.
    - I did not run the test. The RED run is the next step: `swift test --no-parallel --package-path IntegrationTests --filter JumpLabelOverlapHostedTests`.
    - Full log: scratchpad/jumpred-build.log.
  timestamp: 2026-11-27T06:21:36.147301+00:00
position_column: done
position_ordinal: '8280'
title: No two jump mode labels overlap in a dense transcript, the jump list and the thread bars
---
Request from TestudoApp (relayed by testudoapp-9a, 2026-11-26). In jump mode, EK shows a label (`jump.chip`) on each jump target. On the Testudo Skills list the labels overlap (EK ^frjgqyz, an overlap-free chip layout, in work at editorkit-7a). AVK has dense places where the same can happen.

## What
- [x] Add a hosted test in `IntegrationTests/Tests/IntegrationTests/Commands/` (next to the existing jump tests; grep `jump.chip` and the jump mode tests) that starts jump mode on each of these:
  - a dense transcript: many short messages and tool call rows in `AgentThreadView`,
  - the `SessionJumpList` (EditorSelectionList) with about 8 sessions,
  - the thread bars (the top bar with the status line and the header, and the bottom bar with the composer and the request deck).
- [x] Read the frame of each `jump.chip` element (accessibility tree), and check that no two frames intersect, and that each frame is inside the window.
- [x] If AVK places jump targets so close that the EK layout cannot separate them, record the place and fix it in AVK.
  - Result: no place had targets too close. The three tests pass with no AVK fix, so no AVK fix was necessary.

## Acceptance Criteria
- [x] The hosted test passes on EK main with the EK overlap-free chip layout (^frjgqyz).
  - Note: EK ^5851ngm (the overlap-free chip layout, first commit EK fd4419a9) and EK ^g0kk4m2 (no chip for a clipped target, no chip outside the window) replace the EK card ^frjgqyz that this card names. ^5851ngm is in EK main since 6295826b. ^g0kk4m2 (EK 49acc391 to 27fa4366) is in EK main after 6295826b. Both are in EK 1892af46, the EK pin in IntegrationTests/Package.resolved.
- [x] The test fails on an EK version without that layout, if a place in AVK has overlapping labels now (record the result on this card).
  - RED (2026-11-27): AVK ec9b9b8e + this test, EK f2ed9109 (the commit before ^5851ngm): `swift test --no-parallel --package-path IntegrationTests --filter JumpLabelOverlapHostedTests` ran 3 tests, 2 failed with `labels.overlaps.isEmpty` (noTwoJumpLabelsOverlapInADenseTranscript, noTwoJumpLabelsOverlapInTheThreadBars); the jump list test passed. On EK 1892af46 and later all 3 pass.

## Tests
- [x] `swift test --no-parallel --package-path IntegrationTests --filter <new suite>` passes. This is a hosted run: send start and end lines to testudoapp-9a, editorkit-7a, kanbanviewkit-1c and snapshotviewkit-bc.
- [x] The full IntegrationTests run passes one time.
  - Evidence: the full IntegrationTests runs on c857a766, 45123917 and 90dcacfd (each contains 483f527b): 1099 tests pass, and the 5 known issues are the expected-failure checks in FontRoleExpectationsTests. JumpLabelOverlapHostedTests passes in each run. CI run 45940010012 on d94b771d is green (3 jobs).
  - No headless unit test is possible from AVK: EK `JumpChipLayout` is internal. EK tests the layout in JumpChipLayoutTests.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
- Start when EK sends the sha of ^frjgqyz. The test can be written before that. #test #bug

## Review Findings (2026-11-26 23:39)

> Scope: `review sha 483f527b^1..483f527b` — reviewed the diffs only — lines this change added or modified. 1 file(s) reviewed, 0 not reviewed.
