---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4a41vj427sqyfn471s2vnbt
  text: |-
    Research done.
    - Users of TurnSummary: ActivityTimeline (turn sections, header, bar span) and ConversationView.threadRows (ThreadTurnSummary above the first agent item of a turn, on the old thread path). The session path of ConversationView uses none of it. No demo, Example or other source uses TurnSummary, TurnSummaryRow, ThreadTurnSummary or DiffStat. No tool call view shows a DiffStat. Thus all of TurnSummary.swift goes, DiffStat too.
    - ActivityTimeline and ThreadMinimapView have no user outside their tests (only README and plan.md text). Their init(thread:) is replaced by init(session:). The threadMinimap(thread:...) modifier becomes threadMinimap(session:...).
    - ActivityEntry (host times, terminal entries derived from tool content, time sort, barRange) is kit logic over the kit records. It goes. The row identifiers move to ActivityTimeline (rowIdentifier(for:), detailIdentifier(for:)) and use the row key of the entry.
    - ThreadItem.kindName has one user: the minimap. It goes; TranscriptEntry gets an internal kindName for the tick identifiers.
    - Tick tint: case of the entry, and ToolCallEntry.status (ToolCallSource default status when nil) through statusColors. In a DEBUG build each tick element gives the wire status of a tool call as its value, so a test can see the status that sets the tint.
    - Jump: rail calls ScrollAnchorManager.noteJump(to:) with the row key, then the proxy or onScroll(.item(key)); ConversationView(session:) resolves row keys with ConversationSource.position(of:).
    - README Components lines for ActivityTimeline and ThreadMinimapView stay (ReadmeCoverageTests; ^g95wwbs removes them).
  timestamp: 2026-10-07T02:46:02.052638+00:00
- actor: claude-code
  id: 01m4a5xeekmzz69amy2w0vzj35
  text: |-
    Implementation landed (TDD: RED by compile failure on the missing init(session:) APIs and by RemovedVocabularyTests; then GREEN).

    Changes:
    - Deleted Sources/AgentViewKit/Activity/TurnSummary.swift (TurnSummary, TurnSummaryRow, ThreadTurnSummary, DiffStat; no tool call view used DiffStat) and Tests/AgentViewKitTests/Activity/TurnSummaryTests.swift. RemovedVocabularyTests now holds TurnSummary, TurnSummaryRow, ThreadTurnSummary and DiffStat.
    - ActivityTimeline: init(session:). One row for each thought, tool call, terminal and error entry, in transcript order (private TimelineEntry holds the model objects, no copy). No turn section, no duration, no bar. Expanded rows are @State keyed by row key. ActivityEntry (host times, terminal entries derived from tool content, time sort, barRange) is gone; the identifiers are ActivityTimeline.rowIdentifier(for:) and detailIdentifier(for:) on the row key. The timeline puts the session in \.sessionModel for the linked elicitations of ToolCallView.
    - ThreadMinimapView and threadMinimap(...): session: in place of thread:. Ticks from SessionModel.transcript; tint from the entry case and ToolCallEntry.status. In a DEBUG build the tick element value is the wire status of a tool call. TranscriptEntry got an internal kindName; ThreadItem.kindName (only user was the minimap) is deleted.
    - ConversationView: no turn summary row on the old thread path.

    Discovery (important): the rail made a tick click unable to scroll the conversation to a row outside the lazy stack. Cause: ConversationView had .defaultScrollAnchor(.bottom) for all roles; the AppKit ScrubSurface view in the overlay makes size changes that the .sizeChanges role answers by moving the list back to the bottom. Fix: .defaultScrollAnchor(.bottom) for .initialOffset and .alignment, and a private ConversationFollowAnchor modifier that sets the .sizeChanges anchor to .bottom only while the manager is pinned and keeps no jump anchor (it reads the manager in its own body, so the list does not evaluate on a pin change). ScrollAnchorManager now clears anchorID when the list becomes pinned again (new unit test aReturnToTheBottomClearsTheJumpAnchor), so streaming follow comes back after the user returns to the bottom.
    What did not work: a SwiftUI DragGesture or onTapGesture in place of ScrubSurface gets no synthesized NSEvent in the hosted harness (the old comment on ScrubSurface was right); a ForEach keyed on rowKey did not change the result.

    Left on purpose: duration code that remains is on the deprecated record path only (ToolCallView.durationText over ToolCallRecord times, Reasoning.duration); ^gzj5cye removes the records. AgentCommandTarget.turnRows (^19kd9gm) lists user message rows for jump navigation and does not group the transcript.
  timestamp: 2026-10-07T03:18:34.707992+00:00
- actor: claude-code
  id: 01m4a5xjqyy7a1pzq3qd09tank
  text: |-
    ### implement — changed
    - evidence: 14 files. Sources: Activity/ActivityTimeline.swift (rewritten), Activity/TurnSummary.swift (deleted), Thread/ThreadMinimapView.swift, Thread/ConversationView.swift, Thread/TranscriptEntryKind.swift, Model/ThreadItem.swift, Infrastructure/ScrollAnchorManager.swift. Tests: Activity/ActivityTimelineHostedTests.swift (rewritten), Activity/TurnSummaryTests.swift (deleted), Thread/ThreadMinimapViewHostedTests.swift (rewritten), Infrastructure/ScrollAnchorManagerTests.swift, PackageStructureTests/RemovedVocabularyTests.swift. `swift test`: 1380 tests in 126 suites passed, 78 tests in 12 suites passed, 1 test passed; warnings only the expected deprecation and mlx-swift "missing creator" ones. No README, snippet or demo change, so check-readme.sh and test-examples.sh did not run.
    - next: /review
  timestamp: 2026-10-07T03:18:39.102372+00:00
depends_on:
- 01M443QAWWDY730CX0EDPG4T4Z
- 01M48MR5W3YAB8VFA4KTJZVCYN
position_column: doing
position_ordinal: '80'
title: 'Remove the kit turn grouping: delete TurnSummary, and bind ActivityTimeline and ThreadMinimapView to the transcript order of SessionModel'
---
## What
Owner rule (2026-10-06): the kit does no turn tracking and keeps no logic that the model owns ("i don't really want you to worry about turns"). At present the kit groups the thread into turns and measures them:

- `Sources/AgentViewKit/Activity/TurnSummary.swift`: `turnRanges(in:)`, `anchors(in:)`, `turn(startingAt:in:)` and `summarize(_:)` split the items at each user message, and the "Worked N s, K tools, +A −R" line uses `startedAt` and `endedAt`, which the host measured on the kit records. `SessionModel` has no turn and no time.
- `Sources/AgentViewKit/Activity/ActivityTimeline.swift` makes one section for each turn, with the turn summary as its header and bars from the host times.
- `Sources/AgentViewKit/Thread/ThreadMinimapView.swift` reads `AgentThread.items`.
- `Sources/AgentViewKit/Thread/ConversationView.swift` (`threadRows`) puts a `ThreadTurnSummary` above the first agent item of each turn.

- [x] Delete `TurnSummary`, `TurnSummaryRow` and `ThreadTurnSummary`. Keep `DiffStat` only if a tool call view shows the stat of its own diff.
- [x] `ActivityTimeline` takes a `SessionModel` and shows one row for each `ThoughtEntry`, `ToolCallEntry`, `TerminalEntry` and `ErrorEntry` of `SessionModel.transcript`, in transcript order. It shows no turn section, no duration and no time bar. The open state of a row stays view state.
- [x] `ThreadMinimapView` takes a `SessionModel` and shows one tick for each entry of `SessionModel.transcript`, with the tint of the entry case and of `ToolCallEntry.status`.
- [x] `ConversationView` shows no turn summary row. Remove `TurnSummaryTests` and the turn tests of `ActivityTimelineHostedTests`.

## Acceptance Criteria
- [x] No source in `Sources/AgentViewKit/` splits the transcript into turns or computes a duration from kit times.
- [x] A tool call entry that the model adds shows a new row in the timeline and a new tick in the minimap with no other step; a status change of the entry changes the tint of its tick.
- [x] A tap on a minimap tick scrolls the conversation to the row of the entry.

## Tests
- [x] `Tests/AgentViewKitTests/Activity/ActivityTimelineHostedTests.swift`: rows in transcript order from a `SessionModel` with a thought, two tool calls and an error; a new tool call from the scripted agent adds a row.
- [x] `Tests/AgentViewKitTests/Thread/ThreadMinimapViewHostedTests.swift`: one tick for each entry; a status update changes the tint; a tick tap scrolls to the row.
- [x] `Tests/PackageStructureTests/RemovedVocabularyTests.swift`: add `TurnSummary` and `ThreadTurnSummary`.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.