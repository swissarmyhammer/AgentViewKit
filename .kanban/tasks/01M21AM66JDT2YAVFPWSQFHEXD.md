---
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21ACHJYSF8G8R7HY3M70Z7F
position_column: todo
position_ordinal: '9e80'
title: AttachmentView family, UTType resolution, and AttachmentInspector with QuickLook (plan §3.6, §9 F)
---
## What
Create `Sources/AgentViewKit/Attachments/Attachment.swift`, `AttachmentView.swift`, `AttachmentChip.swift`, `AttachmentInspector.swift`, and `ArtifactView.swift`, per plan.md §3.6 and §9 F. This task also settles research R15.

- Research R15 (plan.md §14): record what each source accepts as an attachment. FoundationModels accepts images only (`Segment.attachment`). ACP accepts image, audio, resource, and resource link blocks. Read what the Router does with other files in `../FoundationModelsRouter`. Write `Docs/decisions/attachment-types.md` with a table `UTType | source support | default renderer`.
- `Attachment { id, url, type: UTType, name, size }` with `init(url:)` that resolves the type from the extension and the resource values.
- `AttachmentView(attachment)`: reads `AttachmentRegistry`; defaults by conformance: `.image` preview, `.pdf` thumbnail through `QLThumbnailGenerator`, `.plainText` and markdown through Textual, `.sourceCode` through `CodeBlockView`, `.audio` and `.movie` through AVKit players, else `AttachmentChip` (type icon from `NSWorkspace`, name, size). A tap sets the inspector selection. Accessibility identifier `attachment-<renderer>` where renderer is one of `image`, `pdf`, `text`, `code`, `audio`, `movie`, `chip`.
- `AttachmentView.defaultRenderer(for: UTType) -> String` exposes the table for tests.
- `AttachmentInspector`: a trailing `.inspector` on `AgentThreadView` bound to `InspectorSelection` (`@MainActor @Observable`). Hosts `QLPreviewView` and the actions Open (`NSWorkspace.open`), Reveal in Finder, Share (`ShareLink`), Save (`fileExporter`), and pop-out Quick Look (`.quickLookPreview`). Identifiers `inspector-open`, `inspector-reveal`, `inspector-share`, `inspector-save`, `inspector-quicklook`.
- `ArtifactView(artifact:)`: a titled panel with `AttachmentView` for the body and the same actions.

## Acceptance Criteria
- [ ] A `.swift` file mounts `attachment-code`; a `.bin` file mounts `attachment-chip`.
- [ ] A registered `.attachmentView(for: .pdf)` wins over the default.
- [ ] A press on a chip sets `InspectorSelection` and the inspector shows the file name and the five action identifiers.
- [ ] Every row in `Docs/decisions/attachment-types.md` matches `AttachmentView.defaultRenderer(for:)` (a test parses the table).

## Tests
- [ ] `Tests/AgentViewKitTests/Attachments/AttachmentResolutionTests.swift`: the conformance walk with temp files, the decision-table match.
- [ ] `Tests/AgentViewKitTests/Attachments/AttachmentInspectorHostedTests.swift`: selection and action identifiers.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.