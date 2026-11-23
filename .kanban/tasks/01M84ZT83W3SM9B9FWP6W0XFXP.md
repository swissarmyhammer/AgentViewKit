---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m851m4jes1nz443jmr6tj15c
  text: |-
    Implementation notes.
    - The per-row liveness is a ViewModifier, `TranscriptRowLiveness(position:)`, in LiveRowRange.swift. ConversationView applies it in the ForEach of `rows(shownCount:)`. The modifier reads `\.liveRowRange` and sets `\.transcriptRowIsLive` (default `true`). Thus only the small modifier body of each row observes `LiveRowRange.positions`, not the body of ConversationView, and the content gets only a Bool.
    - ResponseView reads `\.transcriptRowIsLive` only. It does not read `\.liveRowRange` or `\.transcriptRowPosition` now. `\.transcriptRowPosition` stays for AttachmentView and TranscriptFileOrder.
    - `\.liveRowRange` stays: ConversationView sets it, and the modifier reads it.
    - The unit hosts of LiveRowModelsTests mirror ConversationView, so they apply the modifier now.
    - New unit test `aResponseOutsideAThreadRowKeepsItsEditorWhenTheLiveRowsMove` covers the criterion "a response outside a thread row stays live".
    - ARCHITECTURE.md: one sentence added to the live-row paragraph.
    - RED result of the hosted test: all 60 responses evaluated on one move; the 36 rows that kept their liveness gave 36 issues. GREEN: only the 24 flipped rows evaluate; the 36 others count 0.
  timestamp: 2026-11-23T20:30:10.510530+00:00
- actor: claude-code
  id: 01m851m7pae56x7jgtdn75geht
  text: |-
    ### implement — changed
    - evidence: root `swift test` 1654 tests in 186 suites + 59 tests in 12 suites passed, no code warnings; IntegrationTests `swift build --build-tests` complete; hosted, one at a time: LiveRowRangeRedrawScopeTests 1/1, SessionModelRedrawScopeTests 1/1, ConversationViewHostedTests 12/12, ResponseViewHostedTests 5/5 passed. Files: Sources/AgentViewKit/Thread/LiveRowRange.swift, Sources/AgentViewKit/Content/ResponseView.swift, Sources/AgentViewKit/Thread/ConversationView.swift, Tests/AgentViewKitTests/Thread/LiveRowModelsTests.swift, IntegrationTests/Tests/IntegrationTests/Thread/LiveRowRangeRedrawScopeTests.swift (new), ARCHITECTURE.md
    - next: /review
  timestamp: 2026-11-23T20:30:13.706390+00:00
position_column: doing
position_ordinal: '80'
title: Give each thread row its liveness as a Bool so a live-range move updates only the rows that flip
---
## Rule
Stay with SwiftUI and use it smarter. Do not replace views with AppKit.

## What
Bug: "scrolling is not very smooth in the agent view" (seen in TestudoApp). Each move of the live range evaluates the body of each ResponseView.
- Sources/AgentViewKit/Content/ResponseView.swift:75 reads `@Environment(\.liveRowRange)`, and :183-186 `isLive` calls `liveRows.isLive(rowPosition)`. This observes `LiveRowRange.positions` (Sources/AgentViewKit/Thread/LiveRowRange.swift:35). Thus each change of `positions` evaluates each ResponseView.
- Fix: in `ConversationView.rows(shownCount:)` (Sources/AgentViewKit/Thread/ConversationView.swift:435-442), compute `liveRows.isLive(position)` in the ForEach and set a new environment value `\.transcriptRowIsLive: Bool` (default `true`) on each row. ResponseView reads this Bool, not `LiveRowRange`. SwiftUI then updates only the rows whose value changes.
- Keep `\.transcriptRowPosition` for other users.

## Acceptance Criteria
- [x] ResponseView does not read `\.liveRowRange`.
- [x] A live-range move evaluates ResponseView.body only for rows whose liveness flips.
- [x] A response outside a thread row stays live.
- [x] Existing placeholder behavior (`placeholderHeight`) does not change.

## Tests
Write the tests first.
- Add a DEBUG `BodyEvaluationCounter` key in ResponseView.body (pattern: Sources/AgentViewKit/Items/ToolCallView.swift:124-127, 267-275).
- New hosted test in IntegrationTests/Tests/IntegrationTests/Thread/ (pattern: SessionModelRedrawScopeTests.swift:94-134): host many answers, report visible positions that cross the slack, assert that only flipped rows evaluate.
- Run `swift test` in the root (headless). Run the hosted test alone: `cd IntegrationTests && swift test --filter <TestName>`. One hosted test at a time.
- No sleep, poll, retry or time limit. Wait only on certain events.

## Workflow
Use /tdd.

## Subtasks
- [x] Add the `transcriptRowIsLive` environment key with default `true`.
- [x] Set it per row in `ConversationView.rows(shownCount:)`.
- [x] Change ResponseView `isLive` to read the Bool.
- [x] Add the DEBUG counter key in ResponseView.body.
- [x] Add the hosted test and make it pass.

Files: ResponseView.swift, ConversationView.swift, the environment key file (new or near LiveRowRange.swift), one new test file. #scroll-perf