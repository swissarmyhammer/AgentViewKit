---
assignees:
- claude-code
depends_on:
- 01M443QAWWDY730CX0EDPG4T4Z
- 01M48MR5W3YAB8VFA4KTJZVCYN
position_column: todo
position_ordinal: b080
title: 'Remove the kit turn grouping: delete TurnSummary, and bind ActivityTimeline and ThreadMinimapView to the transcript order of SessionModel'
---
## What
Owner rule (2026-10-06): the kit does no turn tracking and keeps no logic that the model owns ("i don't really want you to worry about turns"). At present the kit groups the thread into turns and measures them:

- `Sources/AgentViewKit/Activity/TurnSummary.swift`: `turnRanges(in:)`, `anchors(in:)`, `turn(startingAt:in:)` and `summarize(_:)` split the items at each user message, and the "Worked N s, K tools, +A −R" line uses `startedAt` and `endedAt`, which the host measured on the kit records. `SessionModel` has no turn and no time.
- `Sources/AgentViewKit/Activity/ActivityTimeline.swift` makes one section for each turn, with the turn summary as its header and bars from the host times.
- `Sources/AgentViewKit/Thread/ThreadMinimapView.swift` reads `AgentThread.items`.
- `Sources/AgentViewKit/Thread/ConversationView.swift` (`threadRows`) puts a `ThreadTurnSummary` above the first agent item of each turn.

- [ ] Delete `TurnSummary`, `TurnSummaryRow` and `ThreadTurnSummary`. Keep `DiffStat` only if a tool call view shows the stat of its own diff.
- [ ] `ActivityTimeline` takes a `SessionModel` and shows one row for each `ThoughtEntry`, `ToolCallEntry`, `TerminalEntry` and `ErrorEntry` of `SessionModel.transcript`, in transcript order. It shows no turn section, no duration and no time bar. The open state of a row stays view state.
- [ ] `ThreadMinimapView` takes a `SessionModel` and shows one tick for each entry of `SessionModel.transcript`, with the tint of the entry case and of `ToolCallEntry.status`.
- [ ] `ConversationView` shows no turn summary row. Remove `TurnSummaryTests` and the turn tests of `ActivityTimelineHostedTests`.

## Acceptance Criteria
- [ ] No source in `Sources/AgentViewKit/` splits the transcript into turns or computes a duration from kit times.
- [ ] A tool call entry that the model adds shows a new row in the timeline and a new tick in the minimap with no other step; a status change of the entry changes the tint of its tick.
- [ ] A tap on a minimap tick scrolls the conversation to the row of the entry.

## Tests
- [ ] `Tests/AgentViewKitTests/Activity/ActivityTimelineHostedTests.swift`: rows in transcript order from a `SessionModel` with a thought, two tool calls and an error; a new tool call from the scripted agent adds a row.
- [ ] `Tests/AgentViewKitTests/Thread/ThreadMinimapViewHostedTests.swift`: one tick for each entry; a status update changes the tint; a tick tap scrolls to the row.
- [ ] `Tests/PackageStructureTests/RemovedVocabularyTests.swift`: add `TurnSummary` and `ThreadTurnSummary`.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.