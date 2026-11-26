---
assignees:
- claude-code
position_column: todo
position_ordinal: '8480'
title: 'Scroll 1: a row height cache from data, off the main thread'
---
From spike ^fa3j934 (2026-11-26). The virtual transcript needs the exact height of each row with no view, off the main thread. Measuring the views costs 1.7 s on main for 200 rows, and Core Text is too inexact (mean error 246 pt). EK makes an exact measure: `EditorLayoutMeasure.height(of:width:style:)` (EK ^ep9f55d, 0 pt error for text; images from their natural size, ^chy02jm; code with a gutter, ^v8t0pka).

## What
- [ ] A new type `TranscriptRowHeights` (Sources/AgentViewKit/Thread/): a cache of the height of each entry by entry id, entry version (row key and content digest) and width. It computes on a background task, and it publishes the heights to the main actor.
- [ ] A chrome rule for each row kind (user message, agent message, collapsed thought, tool call card, diff, command output, plan, notice): the row padding, the header heights and the block frames that AVK adds around the EK text. Each rule is a pure function of the entry and the theme metrics.
- [ ] The EK measure for the text parts, when EK ^ep9f55d is on EK main. Until then, the type takes an injected measure, so the next cards can start.
- [ ] Only the last row, while it streams, gets a new height per update. A width change computes again in the background, and the rows in view first.

## Acceptance Criteria
- [ ] For each row kind, the cached height equals the height of the mounted row within 0.5 pt at 320, 480 and 720 pt widths.
- [ ] The cache does no work on the main thread for a row that does not change.

## Tests
- [ ] Unit tests in Tests/AgentViewKitTests/Thread/ that mount each row kind in a window that is never ordered in, and compare its height with the cache. No sleep, poll, retry or clock; wait on the observable publish.
- [ ] `swift test` passes with 0 failures and 0 warnings.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #perf