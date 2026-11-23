---
assignees:
- claude-code
position_column: todo
position_ordinal: '8380'
title: 'Make the visible-rows report cheap: a rowKey position index and no equal visibleIDs writes'
---
## Rule
Stay with SwiftUI and use it smarter. Do not replace views with AppKit.

## What
Bug: "scrolling is not very smooth in the agent view". Each scroll report does too much work.
- Sources/AgentViewKit/Thread/ConversationView.swift:589-602 `noteVisible(ids:isNearBottom:)` calls `transcript.position(ofRowKey:)` (Sources/AgentViewKit/Thread/TranscriptEntryLookup.swift:19) for each id. This is a linear search, and it builds key strings (Sources/AgentViewKit/Thread/TranscriptRowKey.swift:15-45).
- Sources/AgentViewKit/Infrastructure/ScrollAnchorManager.swift:146-151 assigns `visibleIDs = ids` also when `ids == visibleIDs`. Observers then run again: Sources/AgentViewKit/Thread/ThreadMinimapView.swift:376 and Sources/AgentViewKit/Commands/AgentCommandTarget.swift:778.
- Fix: keep a `[String: Int]` rowKey-to-position dictionary that is rebuilt only when the transcript changes. Assign `visibleIDs` only when the value is different.

## Acceptance Criteria
- [ ] A report does no linear search of the transcript.
- [ ] The index is rebuilt only when the transcript changes.
- [ ] Repeated equal reports cause 0 observation notifications of `visibleIDs`.
- [ ] Existing ScrollAnchorManager behavior (pin, jump wait) does not change.

## Tests
Write the tests first.
- Headless unit test in Tests/AgentViewKitTests: use `withObservationTracking` on `visibleIDs`, send equal reports, assert 0 notifications.
- Unit test for the index: equal positions to `position(ofRowKey:)`; rebuild after a transcript change.
- Run `swift test` in the root. If a hosted test is necessary, run it alone: `cd IntegrationTests && swift test --filter <TestName>`.
- No sleep, poll, retry or time limit.

## Workflow
Use /tdd.

## Subtasks
- [ ] Write the observation test (it fails first).
- [ ] Guard the `visibleIDs` write in ScrollAnchorManager.
- [ ] Write the index test.
- [ ] Add the rowKey index and use it in ConversationView.noteVisible.

Files: ScrollAnchorManager.swift, ConversationView.swift, TranscriptEntryLookup.swift, two test files. #scroll-perf