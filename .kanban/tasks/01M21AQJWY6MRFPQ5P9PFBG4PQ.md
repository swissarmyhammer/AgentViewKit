---
comments:
- actor: claude-code
  id: 01m2p1d7jtw3gqn47fwd0bhs8g
  text: 'Note from ^fq3k3ya: `Reasoning` now has `startedAt` and `endedAt` (host measured, the same as `ToolCallRecord`). No source sets them yet. This task must use these fields for the reasoning rows. If this task adds the host timestamps, it must set `Reasoning.startedAt` when a reasoning item arrives and `Reasoning.endedAt` when the next item follows or the turn stops; `ReasoningView` then shows "Thought for N s". `ActivityState(thread:)` and `AgentThread.isLastWhileRunning(_:)` give the live state.'
  timestamp: 2026-09-16T21:19:18.618974+00:00
- actor: claude-code
  id: 01m2pm547827p8130af8q6v05r
  text: 'Note from ^33fxw2b: for FoundationModels, SessionProfileHooks (AgentViewKitFoundationModels) stamps host times. SessionThreadSource copies them to ToolCallRecord and Reasoning startedAt and endedAt. The times of prompt and response entries are available from `hooks.times(for: entryID)` as SessionActivityTimes.'
  timestamp: 2026-09-17T02:46:55.976290+00:00
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