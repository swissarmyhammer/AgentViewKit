---
assignees:
- claude-code
position_column: todo
position_ordinal: 9f80
title: 'Tests: take the image scope id in SelectionSurfaceSitesHostedTests from ContentBlockFile.attachment(of:named:type:)'
---
Found while working ^7rxq60t. `SelectionSurfaceSitesHostedTests.imageBlock()` (Tests/AgentViewKitTests/Theme/SelectionSurfaceSitesHostedTests.swift) returns `ContentBlockFile.url(of:named:)`, and the image site test then builds the scope id by hand with `AttachmentID(url.absoluteString)`.

- [ ] The image site takes its id from `ContentBlockFile.attachment(of:named:type:).id`, as `AttachmentCommandsHostedTests` and `AttachmentFocusRingHostedTests` now do.
- [ ] `swift test` stays green. #avk-8