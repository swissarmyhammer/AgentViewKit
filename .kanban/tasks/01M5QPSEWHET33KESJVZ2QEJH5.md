---
assignees:
- claude-code
position_column: todo
position_ordinal: a680
title: 'ImageView: build its block-file attachment with ContentBlockFile.attachment(of:named:type:)'
---
Found while working ^fqr901r. That card added `ContentBlockFile.attachment(of:named:type:)` (Sources/AgentViewKit/Content/Blocks/ContentBlockFile.swift), which `ResourceBlockView` now uses for the block file of a blob resource. `ImageView.file(of:)` (Sources/AgentViewKit/Content/Blocks/ImageView.swift) still builds the same attachment by hand: `ContentBlockFile.url(of:named:)`, then `Attachment(id: AttachmentID(url.absoluteString), url:, type:, name:, size: data.count)`. The duplication rule forbade editing that counterpart inside ^fqr901r.

- [ ] `ImageView.file(of:)` calls `ContentBlockFile.attachment(of:named:type:)` and the hand-built copy is gone.
- [ ] `AttachmentCommandsHostedTests.anImageRegistersTheFiveCommandsAtTheScopeOfItsFile` and `WireContentBlockViewHostedTests.aPressOnAWireImageSelectsItsBytesInTheInspector` stay green. #avk-8