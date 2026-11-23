---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m855d9s1yqf8y43pv4pb56fk
  text: |-
    Research (implement):
    - SessionModel.transcript (FoundationModelsACPClient) changes only by append, removeAll and replace (rollback). A streamed chunk changes the entry object, not the array. Thus an observation of `session.transcript` tells each change of the array.
    - Plan: a `@MainActor final class TranscriptRowIndex` (in TranscriptEntryLookup.swift) keeps a `[String: Int]` of row keys to positions. It builds the dictionary on the first lookup, and it registers `withObservationTracking { session.transcript }`. The change callback (synchronous, in willSet, on the main actor) marks the dictionary stale. The next lookup builds it again. Thus a report does no linear search, and the index is built again only after a change of the transcript. The index keeps a weak reference to its session, so a new session also builds it again.
    - ConversationView keeps the index in @State (as ParseMemo). noteVisible, the scroll to an item and noteLastItem use it.
    - In DEBUG, each build adds one count to a BodyEvaluationCounter key from BodyEvaluationKey.make(prefix:id:), so a test counts the builds.
    - ScrollAnchorManager.noteVisible assigns visibleIDs only when the value is different. jumpItemID and the pin logic do not change.
  timestamp: 2026-11-23T21:36:20.769511+00:00
- actor: claude-code
  id: 01m855y3ge5ew0va7vs58j7jr5
  text: |-
    Implementation landed (not committed).
    - Discovery: the observation tests passed before the guard. The `@Observable` macro of this toolchain (Swift 6.4.2) generates `shouldNotifyObservers`: a write of an equal value to an Equatable property sends no notification. Thus the card premise "observers then run again" is not true on this toolchain. The two tests stay as regression locks (they fail if `visibleIDs` loses the Equatable skip, for example a manual `withMutation`). The guard (`if isNewReport, acceptsReport(of:) || isAtBottom`) is in place as the card orders. It also removes the second array comparison in the macro setter for each equal report.
    - TranscriptRowIndex (TranscriptEntryLookup.swift): `[String: Int]` of row keys, built on the first lookup; `withObservationTracking { session.transcript }` marks it stale in willSet (MainActor.assumeIsolated, the model is @MainActor); a weak session reference makes a new session build it again; a callback from an earlier session does not mark it. Duplicate keys keep the first position, as `position(ofRowKey:)`. DEBUG build count key: `BodyEvaluationKey.make(prefix: "transcript-row-index-", id: ObjectIdentifier of the session)`.
    - ConversationView keeps the index in @State; noteVisible, scroll(to: .item) and noteLastItem use it. AgentCommandTarget and AgentItemScope still use the linear lookup (one call for each command, not for each scroll step); not changed.
    - RED for the index: compile error (type missing). GREEN: 7 of 7.
  timestamp: 2026-11-23T21:45:31.406293+00:00
- actor: claude-code
  id: 01m855y75xfgae672pndzkd5c8
  text: |-
    ### implement — changed
    - evidence: `swift test` (root) 1685 tests in 189 suites passed + 59 tests in 12 suites passed, 0 code warnings (only the build-system "missing creator" note for the mlx bundle); `swift build --build-tests` passed in IntegrationTests and ScreenshotTests, 0 warnings. 5 files: Sources/AgentViewKit/Infrastructure/ScrollAnchorManager.swift, Sources/AgentViewKit/Thread/ConversationView.swift, Sources/AgentViewKit/Thread/TranscriptEntryLookup.swift, Tests/AgentViewKitTests/Infrastructure/ScrollAnchorManagerTests.swift, Tests/AgentViewKitTests/Thread/TranscriptRowIndexTests.swift (new).
    - hosted tests: none written; the card makes none necessary. No hosted suite was run.
    - next: /review. Task stays in doing.
  timestamp: 2026-11-23T21:45:35.165423+00:00
- actor: claude-code
  id: 01m85631xt8nte2m89vtce6ycs
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` (commit 42965097). 5 files reviewed. 0 findings, 0 confirmed, 1 refuted, 7 attempted, 0 failed. The 2 .kanban files are not reviewed (ignore rule). No prior review findings sections. All acceptance criteria and subtasks are checked.
    - next: the task moves to done.
  timestamp: 2026-11-23T21:48:13.626593+00:00
position_column: done
position_ordinal: ffffffff9c80
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
- [x] A report does no linear search of the transcript.
- [x] The index is rebuilt only when the transcript changes.
- [x] Repeated equal reports cause 0 observation notifications of `visibleIDs`.
- [x] Existing ScrollAnchorManager behavior (pin, jump wait) does not change.

## Tests
Write the tests first.
- Headless unit test in Tests/AgentViewKitTests: use `withObservationTracking` on `visibleIDs`, send equal reports, assert 0 notifications.
- Unit test for the index: equal positions to `position(ofRowKey:)`; rebuild after a transcript change.
- Run `swift test` in the root. If a hosted test is necessary, run it alone: `cd IntegrationTests && swift test --filter <TestName>`.
- No sleep, poll, retry or time limit.

## Workflow
Use /tdd.

## Subtasks
- [x] Write the observation test (it fails first).
- [x] Guard the `visibleIDs` write in ScrollAnchorManager.
- [x] Write the index test.
- [x] Add the rowKey index and use it in ConversationView.noteVisible.

Files: ScrollAnchorManager.swift, ConversationView.swift, TranscriptEntryLookup.swift, two test files. #scroll-perf