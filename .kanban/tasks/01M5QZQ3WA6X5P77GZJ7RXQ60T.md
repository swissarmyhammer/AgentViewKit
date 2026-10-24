---
assignees:
- claude-code
position_column: todo
position_ordinal: 9f80
title: 'Tests: build block-file attachments with ContentBlockFile.attachment(of:named:type:)'
---
Found while working ^z2qejh5. No view in Sources builds the block-file attachment by hand any more, but tests still do:

- `ContentFileSelectionHostedTests.blobAttachment` (Tests/AgentViewKitTests/Content/ContentFileSelectionHostedTests.swift) builds the whole attachment by hand: `ContentBlockFile.url(of:named:)`, then `Attachment(id: AttachmentID(url.absoluteString), url:, type: .zip, name:, size:)`.
- `AttachmentCommandsHostedTests.anImageRegistersTheFiveCommandsAtTheScopeOfItsFile` and `AttachmentFocusRingHostedTests` (the `.image` surface) build the id by hand: `AttachmentID(ContentBlockFile.url(of:named:).absoluteString)`.

- [ ] `ContentFileSelectionHostedTests.blobAttachment` calls `ContentBlockFile.attachment(of:named:type:)`.
- [ ] The two image tests take the id from `ContentBlockFile.attachment(of:named:type:).id`, or record why the hand-built id is the stronger oracle.
- [ ] `swift test` stays green. #avk-8