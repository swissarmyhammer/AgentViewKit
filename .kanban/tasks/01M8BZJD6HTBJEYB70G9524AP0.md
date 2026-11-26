---
assignees:
- claude-code
position_column: todo
position_ordinal: '8380'
title: No two jump mode labels overlap in a dense transcript, the jump list and the thread bars
---
Request from TestudoApp (relayed by testudoapp-9a, 2026-11-26). In jump mode, EK shows a label (`jump.chip`) on each jump target. On the Testudo Skills list the labels overlap (EK ^frjgqyz, an overlap-free chip layout, in work at editorkit-7a). AVK has dense places where the same can happen.

## What
- [ ] Add a hosted test in `IntegrationTests/Tests/IntegrationTests/Commands/` (next to the existing jump tests; grep `jump.chip` and the jump mode tests) that starts jump mode on each of these:
  - a dense transcript: many short messages and tool call rows in `AgentThreadView`,
  - the `SessionJumpList` (EditorSelectionList) with about 8 sessions,
  - the thread bars (the top bar with the status line and the header, and the bottom bar with the composer and the request deck).
- [ ] Read the frame of each `jump.chip` element (accessibility tree), and check that no two frames intersect, and that each frame is inside the window.
- [ ] If AVK places jump targets so close that the EK layout cannot separate them, record the place and fix it in AVK.

## Acceptance Criteria
- [ ] The hosted test passes on EK main with the EK overlap-free chip layout (^frjgqyz).
- [ ] The test fails on an EK version without that layout, if a place in AVK has overlapping labels now (record the result on this card).

## Tests
- [ ] `swift test --no-parallel --package-path IntegrationTests --filter <new suite>` passes. This is a hosted run: send start and end lines to testudoapp-9a, editorkit-7a, kanbanviewkit-1c and snapshotviewkit-bc.
- [ ] The full IntegrationTests run passes one time.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
- Start when EK sends the sha of ^frjgqyz. The test can be written before that. #test #bug