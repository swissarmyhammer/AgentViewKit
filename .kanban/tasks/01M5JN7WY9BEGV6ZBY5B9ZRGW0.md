---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5jpg0mzmyqn7yhhc7ym5079
  text: 'Resolved by the review-findings pass of ^18b2de3 (finding `reuse/reuse` at PreviewFixtures.swift:723, not yet committed): the one implementation is now the internal `RecordingAttachmentFileService` in `Sources/AgentViewKit/Infrastructure/RecordingAttachmentFileService.swift`. `PreviewFixtures.attachmentFileService` makes one, the tests reach it through `@testable import`, and the test copy `Tests/AgentViewKitTests/Helpers/RecordingAttachmentFileService.swift` and `PreviewFixtures.RecordingFileService` are deleted. This card''s own loop decides its column.'
  timestamp: 2026-10-22T20:57:57.663255+00:00
position_column: todo
position_ordinal: a780
title: Use PreviewFixtures.RecordingFileService in the tests in place of RecordingAttachmentFileService
---
## Goal

AVK-14c (^18b2de3) added `PreviewFixtures.RecordingFileService` in `Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift`, so that a press on a file action in the canvas opens nothing. It records each run, as `Tests/AgentViewKitTests/Helpers/RecordingAttachmentFileService.swift` does for the tests. The two types hold the same logic.

## Change

- [ ] Make the tests that use `RecordingAttachmentFileService` (`AttachmentCommandsHostedTests`, `AgentAttachmentCommandsTests`, `AgentCommandDispatchTests`) use `PreviewFixtures.RecordingFileService`.
- [ ] Delete `Tests/AgentViewKitTests/Helpers/RecordingAttachmentFileService.swift`.
- [ ] The full suite passes with 0 warnings.