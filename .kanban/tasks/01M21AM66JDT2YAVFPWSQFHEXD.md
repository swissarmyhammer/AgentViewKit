---
comments:
- actor: claude-code
  id: 01m2nshxcnpgz355jq2ym5c912
  text: |-
    Research R15 (before implementation):
    - FoundationModels: a prompt takes `Transcript.AttachmentSegment` with image content only.
    - ACP v2 `PromptCapabilities`: `image` (image block), `audio` (audio block), `embeddedContext` (resource block, text or blob). A resource link is always permitted.
    - Router: `RoutedSession.enqueue(prompt:)` takes a `Transcript.Prompt`. `TranscriptEntryMapper` persists an attachment segment only as an image URL; an attachment with no URL rebuilds as a text segment. `ToolCallAttachment` records are structured records keyed by schema name that the Router never renders to the model. Thus the Router accepts images only; for other files the host must put the text in the prompt or give a path that a tool reads.
    Design decisions:
    - `AttachmentView` shows a registered view first (nearest supertype, `AttachmentRegistry.resolve(type:)`), else the default renderer from an ordered conformance table (image, pdf, code before text, text, audio, movie, else chip).
    - `AgentThreadView` gets the inspector through a public `.attachmentInspector(selection:)` modifier. It uses the `InspectorSelection` of the environment when the host gives one, else its own. The hosted test mounts the modifier directly, because the thread rows still show placeholders for message content.
    - `ArtifactView` shows the action row only when the artifact has a URL. An inline-only artifact has no file to open, reveal, share, save, or preview.
  timestamp: 2026-09-16T19:02:03.413690+00:00
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21ACHJYSF8G8R7HY3M70Z7F
position_column: doing
position_ordinal: '8180'
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
- [x] A `.swift` file mounts `attachment-code`; a `.bin` file mounts `attachment-chip`.
- [x] A registered `.attachmentView(for: .pdf)` wins over the default.
- [x] A press on a chip sets `InspectorSelection` and the inspector shows the file name and the five action identifiers.
- [x] Every row in `Docs/decisions/attachment-types.md` matches `AttachmentView.defaultRenderer(for:)` (a test parses the table).

## Tests
- [x] `Tests/AgentViewKitTests/Attachments/AttachmentResolutionTests.swift`: the conformance walk with temp files, the decision-table match.
- [x] `Tests/AgentViewKitTests/Attachments/AttachmentInspectorHostedTests.swift`: selection and action identifiers.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.