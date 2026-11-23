---
assignees:
- claude-code
position_column: todo
position_ordinal: '8480'
title: Keep the conversation pill mounted so an unpin from the bottom does not hitch
---
## Rule
Stay with SwiftUI and use it smarter. Do not replace views with AppKit.

## What
Bug: "scrolling is not very smooth in the agent view". One hitch occurs when the list unpins from the bottom.
- Sources/AgentViewKit/Thread/AgentThreadView.swift:558-559 inserts `ConversationPill` in the `FloatingGlassContainer` (:535) only when `showsPill` is true. The insert changes the glass container layout.
- Sources/AgentViewKit/Thread/ConversationView.swift:709-716 `ConversationFollowAnchor` changes `defaultScrollAnchor` at the same time.
- Fix: keep `ConversationPill` always mounted. Hide it with `.opacity(0)`, `.allowsHitTesting(false)` and `.accessibilityHidden(true)` when it does not show.

## Acceptance Criteria
- [ ] The pill view is in the tree in both states.
- [ ] A hidden pill is not visible, not clickable, and not in accessibility.
- [ ] One unpin evaluates the floating controls a small, fixed number of times.

## Tests
Write the tests first.
- Add a DEBUG `BodyEvaluationCounter` key in the floating control body.
- New hosted test in IntegrationTests/Tests/IntegrationTests/Thread/: pin at bottom, unpin one time, assert the count of floating-control evaluations.
- Run `swift test` in the root (headless). Run the hosted test alone: `cd IntegrationTests && swift test --filter <TestName>`. One hosted test at a time.
- No sleep, poll, retry or time limit.

## Workflow
Use /tdd.

## Subtasks
- [ ] Add the DEBUG counter key.
- [ ] Add the hosted test (it fails first).
- [ ] Keep the pill mounted and hide it with opacity and hit testing.
- [ ] Update snapshot images if the look changes and give the paths.

Files: AgentThreadView.swift, ConversationPill source file, one new test file. #scroll-perf