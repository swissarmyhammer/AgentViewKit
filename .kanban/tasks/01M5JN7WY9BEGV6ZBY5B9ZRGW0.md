---
assignees:
- claude-code
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