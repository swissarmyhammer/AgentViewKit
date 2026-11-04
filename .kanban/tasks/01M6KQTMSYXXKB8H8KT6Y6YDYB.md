---
assignees:
- claude-code
position_column: doing
position_ordinal: '8180'
title: ThreadFloatingControlsHostedTests.aStreamedTurnKeepsTheThreadPinnedToTheBottom fails on main with EditorKit 50414d62
---
Found while implementing ^e4857xj. It reproduces on a clean worktree of main 69856eae, with deps resolved to EditorKit 50414d62 (the run only needs IntegrationTests/Style/InspectorPreviewFrameTests.swift removed to compile, see below).

`swift test --package-path IntegrationTests --filter ThreadFloatingControlsHostedTests` fails 2 expectations, every run:
- ThreadFloatingControlsHostedTests.swift:300 `!unpinned.isRaised` ("the thread unpinned during the turn")
- ThreadFloatingControlsHostedTests.swift:301 `harness.element(identifier: ScrollToBottomPill.identifier) == nil`

It is not caused by the inspector work, because it fails without those changes too. Likely cause: a change in EditorKit between the previous resolved SHA and 50414d62 (e.g. ^268hf35 `.commandClick` shape parameter, or a scroll/anchor change). Find the cause and fix it.

Also on main 69856eae with EK 50414d62: IntegrationTests does not compile. `InspectorPreviewFrameTests.swift:11` reports `ambiguous use of 'inspectorPreviewFrame()'`, because EditorTestSupport brings EditorInspector's `inspectorPreviewFrame()` into scope next to AVK's copy. ^e4857xj removes AVK's copy, which fixes it once it lands.

## Acceptance Criteria
- [ ] aStreamedTurnKeepsTheThreadPinnedToTheBottom passes against the current EditorKit main.

## Tests
- [ ] `swift test --package-path IntegrationTests --filter ThreadFloatingControlsHostedTests` passes.