---
assignees:
- claude-code
depends_on:
- 01M8C4ZJVYEF1X702PCKR7CX7B
position_column: todo
position_ordinal: '8680'
title: 'Scroll 3: static rows while the transcript moves, real rows at rest'
---
From spike ^fa3j934 (2026-11-26). This card gives most of the gain: in the spike, static rows in motion (V2) used 1927 ms of main-thread time in a 15 s flick, against 6731 ms for the current list (-71 %), with 16 hitches against 63. The cost is the EK editor that mounts in each row while the list moves.

## What
- [ ] While the transcript moves (the SwiftUI scroll phase is not idle), each row in the virtual layout (^kr7cx7b) shows a static form with its cached height (^9h7bm9j): the text as SwiftUI `Text` from the same attributed text, or the EK static rendering of a measured document (EK ^8zv7set) when it is on EK main.
- [ ] At rest, the rows in view mount the real row. The row that has the keyboard focus, the mouse, a selection or a running stream stays real at all times.
- [ ] The static form and the real row have the same height (the cache height), so no row jumps when it changes.
- [ ] The static form looks the same as the real row: the same fonts, colors, padding and chrome. A look difference while the list moves is acceptable only for syntax colors of code, if EK ^8zv7set is not ready.

## Acceptance Criteria
- [ ] The flick trace of the spike harness on the real ConversationView shows main-thread time at or below 2000 ms for the 15 s flick (V2 of the spike: 1927 ms).
- [ ] No row changes its height when it changes from static to real.
- [ ] VoiceOver, text selection, the search marks and the jump targets work on a list at rest as before.

## Tests
- [ ] Unit tests: a row gets the static form while the phase is not idle, the real row at rest, and the real row while it has the focus; the two forms have the same height.
- [ ] The full IntegrationTests run passes (hosted, with start and end lines). The gallery images (light and dark) of a thread at rest do not change.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #perf