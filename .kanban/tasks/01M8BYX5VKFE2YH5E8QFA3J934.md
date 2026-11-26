---
assignees:
- claude-code
position_column: done
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
- [x] In the profile harness (scratchpad `ScrollProfile`, not in AVK `Sources/`), build a virtual list: one SwiftUI `ScrollView` with a custom `Layout` that has the exact total height from prefix sums of known row heights, and places only the visible rows plus an overscan.
- [x] Row heights: compute them off the main thread from the entry text at the list width (Core Text `CTFramesetterSuggestFrameSizeWithConstraints`, or the measure that the AVK row uses). Cache them by entry id, entry version and width.
- [x] Rows in motion show static text (SwiftUI `Text` from the same attributed text). They are recycled through a fixed pool of slot ids. A row at rest mounts the real AVK row.
- [x] A flick driver: a real momentum scroll (a scroll wheel event with momentum phases, or a decelerating velocity curve from about 6000 pt/s), for the 200-row transcript.
- [x] Measure 3 variants with the flick driver: AVK main as it is, the virtual list with real AVK rows, and the virtual list with static rows in motion. Record the main-thread time, the frames delivered, the hitch count and the largest hitch.

## Acceptance Criteria
- [x] The card has the numbers of the 3 variants for the flick.
- [x] The card states which of the 4 rules gives most of the gain, and the next cards for AVK.

## Tests
- [x] The trace runs are windowed: send start and end lines to testudoapp-9a, editorkit-7a, kanbanviewkit-1c and snapshotviewkit-bc, and run one at a time on a quiet machine.
- [x] No change in AVK `Sources/` in this spike.

## Workflow
- A spike. The AVK change cards that follow use `/tdd`. #perf

## Results (2026-11-26)

200 rows of a recorded session, 900 x 1000 window. One driver for all variants: it moves the clip view each frame; a flick starts at 6000 pt/s and slows by 0.998 per ms; 7 flicks in 15 s. 3 rounds, Time Profiler + Hitches, rotated order. Means of 3 rounds. Files: scratchpad/spike-virtual, spike-traces-run2.txt, traces/spike-V*-r*.trace.

| Variant | Main thread ms | Frames delivered | Hitches | Hitch sum ms | Largest hitch ms | Up-front cost |
|---|---|---|---|---|---|---|
| V0 ConversationView (main) | 6731 | 93.8 % | 63 | 967 | 50.0 | none |
| V1 virtual Layout + real rows | 6157 | 96.9 % | 46 | 667 | 33.3 | 1.7 s on main to measure 200 rows |
| V2 = V1 + static rows in motion | 1927 | 97.6 % | 16 | 425 | 75.0 (mount at rest) | 1.7 s measure + 30 ms |
| V3 = V2 + Core Text heights | 1221 | 98.0 % | 15 | 364 | 66.7 | 155 ms off main; heights wrong (mean error 246 pt) |
| V4 SwiftUI List | 12662 | 85.4 % | 307 | 2575 | 16.7 | none |

Decision by the trace rule: V2 wins (-71 % main-thread time, 4x fewer hitches). Rule 4 (cheap rows in motion) gives most of the gain. Rule 2 (exact height) gives -9 %, and it is necessary so that a static row and its real row have the same height. The lazy stack estimate is +72 % (88,271 pt against 51,365 pt). Rule 1 needs an exact off-main measure (EK ^ep9f55d): measuring views costs 1.7 s on main, and Core Text is too inexact. SwiftUI List is rejected: it is 2x slower, it opens at the top, and its total height is an estimate. The hang in the first slot was in the event driver (a gesture-phase event started the AppKit tracking loop); the new driver sends no events.
