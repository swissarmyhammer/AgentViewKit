---
assignees:
- claude-code
depends_on:
- 01M8C4ZJVYEF1X702PCKR7CX7B
position_column: todo
position_ordinal: '8780'
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