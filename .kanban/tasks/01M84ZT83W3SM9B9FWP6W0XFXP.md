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
- actor: claude-code
  id: 01m851s50vqfxhj3vnjgz0e71w
  text: |-
    ### review — findings
    - evidence: `review sha HEAD~1..HEAD` gave 1 finding (1 confirmed, 1 refuted). IntegrationTests/Tests/IntegrationTests/Thread/LiveRowRangeRedrawScopeTests.swift:48 `reuse/reuse`.
    - next: Move the row-stack builder into one shared test helper with a width parameter. Make LiveRowModelsTests and LiveRowRangeRedrawScopeTests call it. Then do the review again. The task stays in review.
  timestamp: 2026-11-23T20:32:54.811256+00:00
- actor: claude-code
  id: 01m851syd5355dcy2rnq3xc7zq
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 6 files
    - test: green — swift test 1654 + 59; hosted 4 suites
    - commit: 3a5b9e0b
    - review: findings — IntegrationTests/Tests/IntegrationTests/Thread/LiveRowRangeRedrawScopeTests.swift:48
  timestamp: 2026-11-23T20:33:20.805075+00:00
- actor: claude-code
  id: 01m85230tarpseg9vamsjx94v5
  text: |-
    Finding reuse/reuse at LiveRowRangeRedrawScopeTests.swift:48 is done. The new helper TranscriptRowsStack.view(of:rows:width:) in Sources/AgentViewKitTestSupport/TranscriptRowsStack.swift makes the VStack and ForEach of rows with the environment of ConversationView. LiveRowModelsTests and LiveRowRangeRedrawScopeTests both call it. Their copies are removed.

    Discovery: the test support target does not see the internal symbols of AgentViewKit. A public helper cannot use the internal type LiveRowRange in its signature. Thus these symbols now have `package` access, as PixelGrid does: LiveRowRange (the type only), EnvironmentValues.liveRowRange, EnvironmentValues.transcriptRowPosition, TranscriptRowLiveness (with a package init and body), and View.threadTextSelection(). A host of the kit does not see them. The helper also has `package` access. The IntegrationTests package is a different SwiftPM package, so it reaches the helper with `@testable import AgentViewKitTestSupport`. This works in the debug test build.
  timestamp: 2026-11-23T20:38:18.186411+00:00
- actor: claude-code
  id: 01m85233s76whynxr7k9959415
  text: |-
    ### implement — changed
    - evidence: 6 files — Sources/AgentViewKitTestSupport/TranscriptRowsStack.swift (new), Sources/AgentViewKit/Thread/LiveRowRange.swift, Sources/AgentViewKit/Attachments/TranscriptFileOrder.swift, Sources/AgentViewKit/Selection/ThreadTextSelection.swift, Tests/AgentViewKitTests/Thread/LiveRowModelsTests.swift, IntegrationTests/Tests/IntegrationTests/Thread/LiveRowRangeRedrawScopeTests.swift. swift test: 1654 + 59 passed, no code warnings. IntegrationTests swift build --build-tests: clean. swift test --filter LiveRowRangeRedrawScopeTests: 1 test passed.
    - next: test, then commit, then review
  timestamp: 2026-11-23T20:38:21.223408+00:00
- actor: claude-code
  id: 01m8526wdc68r5kk701y93sgct
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` (commit 749d87b2) gave 0 findings (0 confirmed, 1 refuted, 7 attempted, 0 failed). 6 files were reviewed. All items in the prior Review Findings section are checked.
    - next: none. The task moved to done.
  timestamp: 2026-11-23T20:40:24.748637+00:00
position_column: done
position_ordinal: ffffffff9a80
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

## Review Findings (2026-11-23 14:30)

> Scope: `review sha HEAD~1..HEAD`. The review examined only the lines that this change added or changed. 5 files were reviewed. 3 files were not reviewed.

> 2 files were not reviewed. An ignore rule excludes them:
> - `.kanban/ (from .reviewignore)`: 2 files

> 1 file was not reviewed. No validator applies to it:
> - `ARCHITECTURE.md`: no validator applies to this file

- [x] `IntegrationTests/Tests/IntegrationTests/Thread/LiveRowRangeRedrawScopeTests.swift:48` `reuse/reuse` — The new static function `rowsView(of:rows:)` makes the same VStack and ForEach of rows as `LiveRowModelsTests.rowsView`. The only differences are the frame width and the return type. When the row environment changes (for example, the `TranscriptRowLiveness` modifier), you must change the two copies together. Move the builder of the row stack into one helper that the two test targets can call, for example in AgentViewKitTestSupport or in a shared IntegrationTests helper. Make the width a parameter. Then make LiveRowModelsTests and LiveRowRangeRedrawScopeTests call this helper. Do not keep two copies of the same environment setup.
