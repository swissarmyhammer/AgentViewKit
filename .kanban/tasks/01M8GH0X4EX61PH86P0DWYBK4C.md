---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8gn9ftz90p36d6eap6thdxr
  text: |-
    Causes found (2026-11-28):
    1. aSteadyFlickMountsNoRowInTheStepThatShowsIt: TranscriptViewport.movesDown(from:) gave a direction only when the first or last row in view changed. The last answer (149) is taller than the view, so steps 0-21 kept visible 149..<150, and the record kept the direction "down" from the first layouts at rest. The lead row (shown.upperBound) was then past the end, so no lead row mounted until step 22. In the first layouts at rest the window got a transient report at the top (offset 0, rows 0..<9); that pass dropped the kept row 148, and the return to the bottom set movesDown = true. Whether that transient report reaches the window depends on the main-actor work of other tests. In the passing orders, row 148 stayed mounted from rest, so the test passed by chance, not by the lead row.
    2. TranscriptRowAnchorTests: since 524d5102 the viewport record is written in the layout, so the stack anchored a height change on the new first row in view, a row with no layout yet (rows 56/57 at the top of a scroll up). Rows in view jumped by 72 pt (moved 222 pt for a 150 pt scroll). Also the test measured the last row in view, which leaves the stack when the rows move down 150 pt (moved -5104 = text view off the window). And it moved the clip view to the middle: when the first layouts did not unpin the list (order of the SwiftUI reports), .defaultScrollAnchor(.bottom, for: .sizeChanges) moved it back to the bottom.
    Fixes: firstRowDepth in TranscriptViewport gives the direction inside one row; TranscriptStackGeometry.isLaidOut + anchorRowKey(visible:) anchors on the first laid-out row in view; the anchor test jumps (jumpAtRest) to the middle answer and measures the first row in view.
    Not done here, noted for a new card: the transient top report in the first layouts, and anchored offsets past the bottom (scrollOffset.y 9156 with a max of 8752). TranscriptBarAnchorTests has the same last-row / clip-move pattern; it passes now.
  timestamp: 2026-11-28T08:45:31.871013+00:00
- actor: claude-code
  id: 01m8gna92gytk47ac6kxsacx8v
  text: |-
    ### implement — changed
    - evidence: commit c117b40e — Sources/AgentViewKit/Thread/TranscriptRowStack.swift, Sources/AgentViewKit/Thread/TranscriptElementHeights.swift, Tests/AgentViewKitTests/Thread/TranscriptRowAnchorTests.swift, Tests/AgentViewKitTests/Thread/TranscriptViewportTests.swift (new, 3 tests). RED at base 358706cc: both filters failed 3 of 3 alone. 10 runs alone after the fix: `--filter aSteadyFlickMountsNoRowInTheStepThatShowsIt` 10/10 pass; `--filter TranscriptRowAnchorTests` 10/10 pass. `--filter "aSteadyFlickMountsNoRowInTheStepThatShowsIt|TranscriptFlatRowTests"` 6/6 pass; `--filter TranscriptFlickWorkTests` 6/6 pass. Root `swift test`: 2096 tests in 261 suites passed, plus 59 tests in 12 suites passed, 0 issues. With the old anchor rule, the new anchor test fails (moved 222 pt), so the check is not weaker.
    - next: /review. Follow-up card ^mbzdaw3 (transient top report in the first layouts, anchored offsets past the bottom, TranscriptBarAnchorTests pattern). Tool friction: each kanban write (add comment, add task, update task, move task) returns the whole board (about 188 KB), not the changed item.
  timestamp: 2026-11-28T08:45:57.712943+00:00
- actor: claude-code
  id: 01m8gnreajb481pra0ahq0j30z
  text: 'Root runs at c117b40e: 6 of 6 full `swift test` runs passed (2096 tests in 261 suites, plus 59 tests in 12 suites, 0 issues each). The card''s "6 runs in the root run" item is now proven.'
  timestamp: 2026-11-28T08:53:41.842673+00:00
position_column: doing
position_ordinal: '8480'
title: 'Lead row: a row made at rest above the view is made again in the step that shows it'
---
Found in ^9ync5h3 (2026-11-28). `TranscriptFlickWorkTests.aSteadyFlickMountsNoRowInTheStepThatShowsIt` depends on the order of the tests. With `--filter "aSteadyFlickMountsNoRowInTheStepThatShowsIt|TranscriptFlatRowTests"` it fails 6 of 6 runs, also with the flat form turned off (the behavior of main 204a33b8); with `--filter TranscriptFlickWorkTests` alone it passes.

Trace (instrumented element, 50 turns of `FlickTranscript`, the list at the bottom, only the last answer in view): the thought row of the last turn (just above the view) is made at rest, real, and it appears. It disappears before step 0 of the flick (during `makeCached` or `startMoving`). The stack makes it again in step 20, the step in which it comes into view, so the lead-row mount (`TranscriptMountPlan`, one row ahead of a live motion) did not mount it one step ahead.

The cause of the first disappear and why it depends on the other tests (their main-actor jobs run inside `PendingRunLoopBlocks.run()` of `settle()`) is not known yet.

Also in scope (2026-11-28): `TranscriptRowAnchorTests` fails when run alone.

## What
- [x] Find why the row above the view leaves the window at the start of the motion, and why the lead row does not come back one step ahead.
- [x] Make the test certain: no dependency on the jobs of other tests.
- [x] Find and fix the cause of the `TranscriptRowAnchorTests` failure alone.

## Tests
- [x] `aSteadyFlickMountsNoRowInTheStepThatShowsIt` passes in each order (alone, with `TranscriptFlatRowTests`, in the root run), 6 runs each.
- [x] `TranscriptRowAnchorTests` passes 10 runs alone and in the root run.

#perf