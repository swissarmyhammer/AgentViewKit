---
assignees:
- claude-code
position_column: todo
position_ordinal: 8b80
title: 'First layouts: a report at the top of the list, and anchored offsets past the bottom'
---
Found in ^dwybk4c (2026-11-28). In the first layouts of a ConversationView at the bottom (120 answers, no height cache, TranscriptRowAnchorTests), the stack applies a geometry while the scroll offset is 0 (report rows 0..<9), between two passes at the bottom. That report can unpin the list or not, with the order of the SwiftUI reports. Also the stack writes anchored offsets past the bottom offset (scrollOffset.y 9156 and 9560 with a max of 8752).

TranscriptBarAnchorTests.aRowInViewMovesOnlyByTheScrollWhenTheRowsUnderTheBarGetTheirHeights moves the clip view to the middle and measures the last row in view, the pattern that made TranscriptRowAnchorTests depend on the order of the tests.

## What
- [ ] Find why the list has offset 0 in a layout of the first scroll to the bottom, and remove that pass.
- [ ] Clamp the anchored offset to the bottom offset, or tell why not.
- [ ] Make TranscriptBarAnchorTests jump to the middle and measure the first row in view, as TranscriptRowAnchorTests does.

## Tests
- [ ] A test that fails when a layout of the first scroll to the bottom reports the rows at the top.

#perf