---
assignees:
- claude-code
position_column: todo
position_ordinal: '8680'
title: 'EditorKit: nav.up and nav.down are inverted on macOS'
---
Found in AVK-7d (^56y8q6a). This is a defect in EditorKit. AgentViewKit cannot fix it.

`GeometryProbeView.windowRect` gives `convert(bounds, to: nil)`. On macOS these are AppKit window coordinates, where y increases upward. `FocusNavigator` treats a larger `minY` as "down" (NavSnapshot: "Toward smaller y (visually up, in the flipped UI sense the host resolves)"). No code flips the rects.

Measured in a hosted AgentThreadView: the first message (top of the window) has minY 77 and the second message (below it) has minY 8. Thus `nav.down` from the first message stays put, and `nav.up` moves visually down to the second message. `nav.firstSibling` and `nav.lastSibling` and the drill-in default ("topmost-leftmost") are inverted for the same cause. The EditorKit test `NavBoardHarness` has the inversion built in ("row 0 at the bottom").

Fix in EditorKit: flip the rects of the snapshot to a top-left origin (for example, `window.contentView` coordinates with `isFlipped`, or `windowHeight - maxY`), and correct `NavBoardHarness`.

Then in AgentViewKit: `AgentNavigationHostedTests.theNavChordsMoveTheFocusBetweenTwoMessageItems` orders the messages by the minY of EditorKit. After the fix, change the test to use the transcript order (the first message is at the top) for the `nav.down` move. #avk-7