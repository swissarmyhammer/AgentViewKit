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