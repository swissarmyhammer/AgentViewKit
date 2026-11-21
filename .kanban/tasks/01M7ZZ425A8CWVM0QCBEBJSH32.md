---
assignees:
- claude-code
position_column: todo
position_ordinal: '8680'
title: MarkdownFence uses the fence run of CodeFenceLine, so the two fence scanners have one run rule
---
## What
`MarkdownFence` (`Sources/AgentViewKit/Content/MarkdownFence.swift`, the fence rules of `MarkdownParagraphs` for the paragraph index of a `CitationMarker`) and `CodeFenceLine` (`Sources/AgentViewKit/Content/MarkdownCodeFences.swift`, task ^4g2xbx1) both read the indent and the fence run at the start of a line. `MarkdownFence.backtickRun(_:)` is a near copy of `CodeFenceLine.run(in:)`: the same indent limit (3), the same minimum run (3), and the same "nothing but whitespace after a closing run" rule. Only the fence characters are different (`MarkdownFence` knows only backticks). If one copy changes, the other can drift.

Task ^4g2xbx1 did not change `MarkdownFence`, because the user decision of 2026-11-21 tells: "Do not change MarkdownFence or the citation paragraph numbers."

- [ ] Make `MarkdownFence.opening(_:)` and `MarkdownFence.closes(_:_:)` use `CodeFenceLine` and accept only a backtick run. Delete `MarkdownFence.backtickRun(_:)` and its two constants.
- [ ] Do not change the behavior: a tilde line is still not a fence line for `MarkdownFence`, and the paragraph numbers of citations do not change.

## Acceptance Criteria
- [ ] The current tests of `MarkdownParagraphs`, `MarkdownFence` and the citations pass with no change.
- [ ] A new test: a tilde fence is not a fence of `MarkdownParagraphs` (it stays prose for the paragraph index).

## Tests
- [ ] Run `swift test` in the repo root. Expected: all tests pass, 0 failures.

## Workflow
- Use `/tdd`. Ask the user first, because the user decision of 2026-11-21 kept `MarkdownFence` as it is.