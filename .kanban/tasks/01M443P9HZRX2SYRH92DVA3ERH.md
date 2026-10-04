---
assignees:
- claude-code
depends_on:
- 01M443NN55C6HTFT2F2REPFZA1
position_column: todo
position_ordinal: '9680'
title: Show CompactionEntry rows and SessionNotice banners from the client model
---
## What
The built client model has two parts that update.md does not list: `CompactionEntry` (an unstable ACP compaction update, with `compactionId` and `hasReportedStatus`) and `SessionNotice` (an unstable notice with `severity`, `title`, `description`, `meta`, and `SessionModel.dismissNotice(_:)`). The owner decided on 2026-10-04 to show both now. The old kit compaction view stays removed; this task adds new views on the client model.

- [ ] Add `Sources/AgentViewKit/Items/CompactionEntryView.swift`: a row that shows that the agent compacted the context, and its status.
- [ ] Add `Sources/AgentViewKit/Status/SessionNoticeBanner.swift`: one banner for each notice of the session, with its severity, title and description, and a dismiss button that calls `dismissNotice(_:)`.
- [ ] Add the compaction case to `ItemRow`, and the notice banner to `AgentThreadView`.

## Acceptance Criteria
- [ ] A compaction update shows one row at its position.
- [ ] A notice shows a banner; the dismiss button removes it from the model.

## Tests
- [ ] `Tests/AgentViewKitTests/Items/CompactionAndNoticeHostedTests.swift`: the compaction row; the notice banner; the dismiss action.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.