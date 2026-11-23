---
assignees:
- claude-code
position_column: todo
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
- [ ] ResponseView does not read `\.liveRowRange`.
- [ ] A live-range move evaluates ResponseView.body only for rows whose liveness flips.
- [ ] A response outside a thread row stays live.
- [ ] Existing placeholder behavior (`placeholderHeight`) does not change.

## Tests
Write the tests first.
- Add a DEBUG `BodyEvaluationCounter` key in ResponseView.body (pattern: Sources/AgentViewKit/Items/ToolCallView.swift:124-127, 267-275).
- New hosted test in IntegrationTests/Tests/IntegrationTests/Thread/ (pattern: SessionModelRedrawScopeTests.swift:94-134): host many answers, report visible positions that cross the slack, assert that only flipped rows evaluate.
- Run `swift test` in the root (headless). Run the hosted test alone: `cd IntegrationTests && swift test --filter <TestName>`. One hosted test at a time.
- No sleep, poll, retry or time limit. Wait only on certain events.

## Workflow
Use /tdd.

## Subtasks
- [ ] Add the `transcriptRowIsLive` environment key with default `true`.
- [ ] Set it per row in `ConversationView.rows(shownCount:)`.
- [ ] Change ResponseView `isLive` to read the Bool.
- [ ] Add the DEBUG counter key in ResponseView.body.
- [ ] Add the hosted test and make it pass.

Files: ResponseView.swift, ConversationView.swift, the environment key file (new or near LiveRowRange.swift), one new test file. #scroll-perf