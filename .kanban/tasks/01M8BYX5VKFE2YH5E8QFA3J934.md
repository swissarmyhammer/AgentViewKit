---
assignees:
- claude-code
position_column: todo
position_ordinal: '8180'
title: 'Spike: a SwiftUI virtual transcript list with exact row heights, measured with a flick'
---
User request (2026-11-26): the transcript scroll is "way way too slow". The user wants a continuous, smooth flick scroll, and the fix must stay in SwiftUI.

Research (2026-11-26) shows that the fast chat lists follow 4 rules. AVK breaks all 4:
1. Row sizes come from data, off the main thread, cached by content and width (Texture `calculateSizeThatFits:`, the web chat lists). The list never measures a row view during a scroll.
2. The total height is exact. A SwiftUI lazy stack estimates the rows it has not measured from the average of placed rows (WWDC26 session 321), and it corrects as rows load. AVK traces show `LazySubviewPlacements` with about 1.9 s in 15 s.
3. A fixed pool of row views is recycled (Nil Coalescing, "Designing a custom lazy list in SwiftUI").
4. Rows are cheap while they move. A heavy view (an EK editor) mounts only when the list is at rest, or for the row that has the focus or the mouse.

This spike measures the ceiling before AVK changes.

## What
- [ ] In the profile harness (scratchpad `ScrollProfile`, not in AVK `Sources/`), build a virtual list: one SwiftUI `ScrollView` with a custom `Layout` that has the exact total height from prefix sums of known row heights, and places only the visible rows plus an overscan.
- [ ] Row heights: compute them off the main thread from the entry text at the list width (Core Text `CTFramesetterSuggestFrameSizeWithConstraints`, or the measure that the AVK row uses). Cache them by entry id, entry version and width.
- [ ] Rows in motion show static text (SwiftUI `Text` from the same attributed text). They are recycled through a fixed pool of slot ids. A row at rest mounts the real AVK row.
- [ ] A flick driver: a real momentum scroll (a scroll wheel event with momentum phases, or a decelerating velocity curve from about 6000 pt/s), for the 200-row transcript.
- [ ] Measure 3 variants with the flick driver: AVK main as it is, the virtual list with real AVK rows, and the virtual list with static rows in motion. Record the main-thread time, the frames delivered, the hitch count and the largest hitch.

## Acceptance Criteria
- [ ] The card has the numbers of the 3 variants for the flick.
- [ ] The card states which of the 4 rules gives most of the gain, and the next cards for AVK.

## Tests
- [ ] The trace runs are windowed: send start and end lines to testudoapp-9a, editorkit-7a, kanbanviewkit-1c and snapshotviewkit-bc, and run one at a time on a quiet machine.
- [ ] No change in AVK `Sources/` in this spike.

## Workflow
- A spike. The AVK change cards that follow use `/tdd`. #perf