---
depends_on:
- 01M21AGTHBZSXFCZHZE5A7FQWQ
- 01M21AHYBMNR7CNDZRPMWRTRTY
- 01M21AHNHX7YF6D4268FQ3K3YA
- 01M21AJ767SWK19SZA82PZWGZ2
position_column: todo
position_ordinal: a980
title: 'ActivityTimeline: interleaved tool calls, reasoning, and terminals with host timestamps (plan §9 C)'
---
## What
Create `Sources/AgentViewKit/Activity/ActivityTimeline.swift` and `TurnSummary.swift`, per plan.md §9 C.

- `TurnSummary.compute(items:)`: groups items into turns (a user message starts a turn) and computes per turn: duration from the first `startedAt` to the last `endedAt`, tool call count by status, and a diff stat sum when tool content carries diffs.
- `ActivityTimeline(thread:)`: a vertical timeline per turn: reasoning spans, tool calls with their durations as bars, terminals, and errors, in time order. Rows expand to the matching `ToolCallView` or `ReasoningView`.
- `TurnSummaryRow(turn)`: the one-line summary "Worked N s, K tools, +A −R" shown above each assistant turn in the thread and as the collapsed timeline header.
- Missing timestamps degrade to order-only rows without durations.

## Acceptance Criteria
- [ ] A turn with two tool calls of 1 s and 2 s reports 3 s and "2 tools".
- [ ] Items without timestamps render in order with no duration.
- [ ] A click on a bar expands the matching view.

## Tests
- [ ] `Tests/AgentViewKitTests/Activity/TurnSummaryTests.swift`: grouping and sums.
- [ ] `Tests/AgentViewKitTests/Activity/ActivityTimelineHostedTests.swift`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.