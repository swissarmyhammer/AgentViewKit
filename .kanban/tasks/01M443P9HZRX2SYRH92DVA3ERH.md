---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m473exwmcj9yxhts79b3nknx
  text: |-
    Research done.
    - `CompactionEntry` (client `be7e615`) is an `@Observable` class: `compactionId`, `status: Unstable.CompactionStatus`, `summary: [ContentBlock]`, `error: String?`, `meta`, `hasReportedStatus`. A `compaction_summary_chunk` before any `compaction_update` makes the entry with the status `SessionEntry.Compaction.unreportedStatus` (`.unknown("_unreported")`).
    - `SessionNotice` has an internal init, so tests make notices only through the wire: `{"sessionUpdate": "notice", "severity": ..., "title": ..., "description": ...}` with `ScriptedSession.sendUpdate(_:)`. `SessionModel.notices` is in arrival order; `dismissNotice(_:)` takes `SessionNotice.ID` (a UUID).
    - Wire tags: `compaction_update`, `compaction_summary_chunk`, `notice`. The stable decoder reads them as unknown updates, and the client model reads them with `Unstable.SessionUpdate`.
    - Plan: `CompactionEntryView(entry:)` follows the entry-view pattern (input `internal`); the summary shows through `ContentBlockView` with `TranscriptMessageView.messageBlocks(of:)`. Add `StatusColors.color(for: Unstable.CompactionStatus)` next to the tool call and plan status colors. `SessionNoticeBanner(session:)` shows one glass banner for each notice above the conversation in `AgentThreadView(session:actions:)`.
  timestamp: 2026-10-05T22:37:58.548010+00:00
- actor: claude-code
  id: 01m473x0v48s9r1qdnkbnvxe77
  text: |-
    Implementation landed with TDD.
    - RED: the new hosted tests failed to compile because `CompactionEntryView` and `SessionNoticeBanner` did not exist; the two new `StatusColorsTests` cases failed with "no exact matches in call to instance method 'color'".
    - GREEN: `CompactionAndNoticeHostedTests` (6 tests) and `StatusColorsTests` pass.
    - Added `CompactionEntryView(entry:)`: title "Context compaction", the status (In progress, Completed, Failed, Cancelled, "No status yet" for `unreportedStatus`, or the unknown wire value), the failure reason, and the summary through `ContentBlockView`.
    - Added `SessionNoticeBanner(session:)`: one glass banner for each notice, label "<severity>, <title>, <description>", and a Dismiss button that calls `dismissNotice(_:)`. `AgentThreadView(session:actions:)` shows it above the conversation.
    - Added `StatusColors.color(for: Unstable.CompactionStatus)` and `color(for: Unstable.NoticeSeverity)` (error = failed, warning = running, info = pending, as the priority tint does). No fixed colors, because `AgentTheme` says that views use only tokens.
    - Removed `TranscriptEntry.kindName`: its only caller was the compaction placeholder in `ItemRow`.
    - Full `swift test`: 1324 tests in 117 suites passed; the only warning is the expected mlx-swift `missing creator for mutated node`.
  timestamp: 2026-10-05T22:45:40.324292+00:00
- actor: claude-code
  id: 01m473x31g9sk1hj7dzvwa9m45
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Items/CompactionEntryView.swift (new), Sources/AgentViewKit/Status/SessionNoticeBanner.swift (new), Sources/AgentViewKit/Thread/ItemRow.swift, Sources/AgentViewKit/Thread/AgentThreadView.swift, Sources/AgentViewKit/Thread/TranscriptEntryKind.swift, Sources/AgentViewKit/Theme/AgentTheme.swift, Tests/AgentViewKitTests/Items/CompactionAndNoticeHostedTests.swift (new), Tests/AgentViewKitTests/Theme/StatusColorsTests.swift; `swift test` 1324 tests passed.
    - next: /review
  timestamp: 2026-10-05T22:45:42.576537+00:00
- actor: claude-code
  id: 01m4749zkkvmc2r6hnj8ztnd4b
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — CompactionEntryView (new), SessionNoticeBanner (new), ItemRow, AgentThreadView, StatusColors for compaction status and notice severity
    - test: green — swift test, 1324 passed
    - commit: 800d5d3
    - review: findings — Sources/AgentViewKit/Items/CompactionEntryView.swift:52, Sources/AgentViewKit/Items/CompactionEntryView.swift:62, Sources/AgentViewKit/Status/SessionNoticeBanner.swift:64, Sources/AgentViewKit/Status/SessionNoticeBanner.swift:77, Sources/AgentViewKit/Status/SessionNoticeBanner.swift:90
  timestamp: 2026-10-05T22:52:45.043571+00:00
- actor: claude-code
  id: 01m474a24jq6djew785aryegpv
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (800d5d3); 5 findings, 5 confirmed, 1 refuted; all swift/access-control — CompactionEntryView.swift:52, CompactionEntryView.swift:62, SessionNoticeBanner.swift:64, SessionNoticeBanner.swift:77, SessionNoticeBanner.swift:90.
    - note: SessionNoticeBanner.severityLabel, symbolName and label have callers in the separate struct NoticeBanner in the same file. Plain `private` on SessionNoticeBanner does not let NoticeBanner call them. The fix must give the narrowest scope that compiles (for example `fileprivate`, or move the helpers into NoticeBanner).
    - next: /implement the findings on ^dva3erh
  timestamp: 2026-10-05T22:52:47.634568+00:00
- actor: claude-code
  id: 01m474he7pp05628wdz2kvr089
  text: |-
    Review findings fixed (5 of 5, all swift/access-control).
    - CompactionEntryView: `title` and `statusLabel(for:)` are now `private static`. The same cause was also on `symbolName`, which only the view uses, so it is also `private static` now.
    - SessionNoticeBanner: `severityLabel(_:)`, `symbolName(for:)` and `label(for:)` had their only callers in the private struct `NoticeBanner`. They moved into `NoticeBanner` as `private static`, and the calls use `Self.`. This is a smaller scope than `fileprivate`.
    - No test called these helpers. `CompactionAndNoticeHostedTests` already checks the results through the accessibility labels of the views ("Context compaction, Completed", "Warning, <title>, <description>"), so no test change was necessary.
    - `swift build --build-tests`: build complete. Full `swift test`: 1324 tests in 117 suites passed. The only warning is the known mlx-swift SwiftPM warning "missing creator for mutated node".
  timestamp: 2026-10-05T22:56:49.398802+00:00
- actor: claude-code
  id: 01m474hfetzb2crz15nxzvkm4h
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Items/CompactionEntryView.swift, Sources/AgentViewKit/Status/SessionNoticeBanner.swift; `swift build --build-tests` complete; `swift test` 1324 tests in 117 suites passed.
    - next: /review
  timestamp: 2026-10-05T22:56:50.650837+00:00
depends_on:
- 01M443NN55C6HTFT2F2REPFZA1
position_column: doing
position_ordinal: '80'
title: Show CompactionEntry rows and SessionNotice banners from the client model
---
## What
The built client model has two parts that update.md does not list: `CompactionEntry` (an unstable ACP compaction update, with `compactionId` and `hasReportedStatus`) and `SessionNotice` (an unstable notice with `severity`, `title`, `description`, `meta`, and `SessionModel.dismissNotice(_:)`). The owner decided on 2026-10-04 to show both now. The old kit compaction view stays removed; this task adds new views on the client model.

- [x] Add `Sources/AgentViewKit/Items/CompactionEntryView.swift`: a row that shows that the agent compacted the context, and its status.
- [x] Add `Sources/AgentViewKit/Status/SessionNoticeBanner.swift`: one banner for each notice of the session, with its severity, title and description, and a dismiss button that calls `dismissNotice(_:)`.
- [x] Add the compaction case to `ItemRow`, and the notice banner to `AgentThreadView`.

## Acceptance Criteria
- [x] A compaction update shows one row at its position.
- [x] A notice shows a banner; the dismiss button removes it from the model.

## Tests
- [x] `Tests/AgentViewKitTests/Items/CompactionAndNoticeHostedTests.swift`: the compaction row; the notice banner; the dismiss action.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-10-05 17:48)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 8 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Sources/AgentViewKit/Items/CompactionEntryView.swift:52` `swift/access-control` — Static helper `title` is only used internally within the view body (lines 104, 113) and should be marked `private` to make its scope explicit. Change `static var title` to `private static var title`.
- [x] `Sources/AgentViewKit/Items/CompactionEntryView.swift:62` `swift/access-control` — Static helper function `statusLabel` is only used internally within the view body (line 96) and should be marked `private` to make its scope explicit. Change `static func statusLabel` to `private static func statusLabel`.
- [x] `Sources/AgentViewKit/Status/SessionNoticeBanner.swift:64` `swift/access-control` — Static helper function `severityLabel` is only used internally within the view body (line 91 in banner's accessibility label) and should be marked `private` to make its scope explicit. Change `static func severityLabel` to `private static func severityLabel`.
- [x] `Sources/AgentViewKit/Status/SessionNoticeBanner.swift:77` `swift/access-control` — Static helper function `symbolName` is only used internally within the view body (line 121) and should be marked `private` to make its scope explicit. Change `static func symbolName` to `private static func symbolName`.
- [x] `Sources/AgentViewKit/Status/SessionNoticeBanner.swift:90` `swift/access-control` — Static helper function `label` is only used internally within the view body (line 139) and should be marked `private` to make its scope explicit. Change `static func label` to `private static func label`.
