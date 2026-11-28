---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8fwgft0megy8dffps1czgb8
  text: |-
    Cause of the jump drift found (worktree virtual4, probe logs of the scrolled gallery screen). The stack recorded `scrollOffset.y` as `ScrollGeometry.contentOffset.y`, but it wrote `ScrollPosition.scrollTo(y:)`. The point of `scrollTo(y:)` starts below the top content inset: a write of y lands at contentOffset y - top inset. Log: write y=179 -> offset 132, y=120 -> 73, y=78 -> 31 (top inset 47). Each anchor write moved the list up by the header height, the move brought new rows under the header, their heights made a new anchor write, and so on to the top of the transcript. With no bars (all MovingThread tests before) the inset is zero, so no unit test saw it. The defect also exists on the virtual stack without the band change, but writes were rare there.
    Fix: record `contentOffset.y + contentInsets.top` (`TranscriptScrollOffset.positionY`). Band: `ConversationView` records `contentInsets` top/bottom (`TranscriptScrollInsets`, state, changes only with a bar), the window mounts `TranscriptViewport.shown` (rows in bounds plus the bands under the bars); the anchor stays the first row between the bars (`visible`).
    The unit host reproduces the drift with `MovingThread(barHeight: 150)` and a jump to answer 30 of 120 (text at 272 instead of under the bar at 450), and the anchor test with bars (row moved by -4705).
    Inspector image: the content is at the same place on main and virtual4; only the overlay scroller differs. An overlay scroller shows only after a scroll or a content size change. On main, the lazy stack corrects its estimated height after the first display; the virtual stack has the exact height at once, so no flash. Not a layout defect.
  timestamp: 2026-11-28T01:32:26.816417+00:00
- actor: claude-code
  id: 01m8fyexww2mwrzbvnsmmyvnvt
  text: |-
    Gallery check of 046c1f5c found a new defect: inspector-dark stopped away from the bottom (pill in view) and inspector-light showed one row in raw Markdown. Probes of the inspector screen: the bottom bar gets a transient inset of 1135.5 pt, the list unpins, and the first scroll to the last row (`scrollTo(id:anchor:.bottom)`) comes late. In the base commit, a row that leaves the kept margin makes one more layout pass, and SwiftUI applies the kept row id again, so the list ends at the bottom. Two changes of 046c1f5c removed that pass: (1) the `scrollInsets` state evaluated the whole list in the first passes (band off + state: fail; band off + model read only by the window: pass); (2) the rows under the bars widened the kept margin, so row 0 stayed mounted (model + band: fail; model + band without a wider margin: pass).
    Fix 8f4df622: `TranscriptScrollInsetsModel` (only the window body reads it), and `mountedRows(visible:shown:...)` mounts the rows under the bars without a wider margin (`aKeptRowNextToTheRowsUnderTheBarsLeaves`, RED with the margin from `shown`).
    Open, not in scope: the first scroll to the bottom depends on a later layout pass to end at the bottom. This was already so in the base commit. New card recommended.
  timestamp: 2026-11-28T02:06:32.860470+00:00
- actor: claude-code
  id: 01m8fyfdxem9t4xtnv3add32pm
  text: |-
    ### implement — changed
    - evidence: commits 046c1f5c and 8f4df622 in worktree virtual4 (on main merge ea041e5b). Files: Sources/AgentViewKit/Thread/ConversationView.swift, TranscriptRowStack.swift, TranscriptRowGeometry.swift; Tests/AgentViewKitTests/Helpers/MovingThread.swift (barHeight), Thread/TranscriptBarBandTests.swift, Thread/TranscriptBarAnchorTests.swift, Thread/TranscriptRowGeometryTests.swift. RED seen for each new test. Root `swift test`: 2078 + 59 passed, 0 issues. IntegrationTests (on 046c1f5c): 1100 passed, 5 known issues. Gallery: two runs of 8f4df622 give the same images. Against main, only the overlay scroller column differs (12 px wide) in screens/scrolled-*, thread-*, inspector-dark and generated/GlassSnapshotTests/floating-notes-*, floating-sign-in-*: the knob size and place follow the exact content height of the virtual stack (main uses estimated heights), and main flashes the scroller in inspector-dark after its estimate correction. The rows under the header now show as on main.
    - next: /review. Follow-up card ^6cqgyfz (first scroll to the bottom needs a later layout pass).
  timestamp: 2026-11-28T02:06:49.262878+00:00
- actor: claude-code
  id: 01m8fyr87bezvd3z0qb899hka4
  text: 'IntegrationTests on the final commit 8f4df622: 1100 passed, 5 known issues (15-minute kill guard, not used).'
  timestamp: 2026-11-28T02:11:38.347973+00:00
depends_on:
- 01M8C4ZJVYEF1X702PCKR7CX7B
position_column: doing
position_ordinal: '8280'
title: 'Scroll 2b: the virtual stack mounts the rows under the glass bars of a thread'
---
Found on 2026-11-27 in the gallery check of ^kr7cx7b (worktree virtual4, commit 2461b9cf).

## Problem
The virtual stack (`TranscriptRowWindow` in `Sources/AgentViewKit/Thread/TranscriptRowStack.swift`) reads the rows in view from `proxy.bounds(of: .scrollView)`. In an `AgentThreadView`, the list goes on under the bars (`.safeAreaBar`), and the scroll view gives the bar heights as content insets. The bounds of `.scrollView` leave out the parts under the bars (probe: bounds 450 pt high, `ScrollGeometry.visibleRect` 600 pt, `contentInsets.top` 150). Thus no row mounts under the top bar, and the glass of the header shows no row. The LazyVStack of main shows the row there. Gallery evidence: `screens/scrolled-light.png` and `scrolled-dark.png`: on main an "Assistant" row is under the header, on virtual4 the band is empty.

## What did not work
A record of the content insets (`onScrollGeometryChange` of `contentInsets`, not observable) that the window adds to the band in view. The unit test passed, but the gallery jump of the scrolled screen then drifted: the jump lands at offset 233 (as on main), the rows under the bar mount and get their real heights, the stack moves the offset to keep the first row in place (233 to 221), and after each move the offset goes up the list (174, 132, 73, 31). The list ended at the top of the transcript, and the result changed from run to run. A split of the band (anchor on the rows between the bars, mount of the rows under the bars too) did not stop the drift. The change was reverted.

## What
- [ ] Mount the rows under the top and the bottom bars of a thread.
- [ ] A jump to an item ends with the item under the top bar, as on main, and stays there when the rows under the bar get their heights.

## Tests
- [ ] RED first: a `MovingThread` with a clear top bar (`.safeAreaBar(edge: .top)` of 150 pt) of 60 answers, scrolled at rest to the middle: a text view of a row meets the band of the bar (this test passed on main and failed on virtual4).
- [ ] A test that reproduces the jump drift (the unit host did not reproduce it with `PreviewFixtures.scrolledSession` and the height cache; the gallery did).
- [ ] The ScreenshotTests gallery: `screens/scrolled-*` match main, and two runs give the same images.

## Workflow
- Use `/tdd`. #perf