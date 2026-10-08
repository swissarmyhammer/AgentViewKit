# Attachment types (R15)

Status: decided. Source: plan.md §3.6, §9 F, and §14 R15.

This file records which files each data source accepts as an attachment, and
the default view that `AttachmentView` uses for each uniform type.
`Tests/AgentViewKitTests/Attachments/AttachmentResolutionTests.swift` parses
the table below. It compares each row with
`AttachmentView.defaultRenderer(for:)`. A change to the table must come with
the same change to the code. Keep the header and the form of the rows. Put the
type identifier and the renderer name in backticks. Do not use a `|` character
in a cell.

The Router is not a data source of the kit (`Docs/decisions/acp-client-kit.md`),
so the table does not name it.

## Default renderers

| UTType | source support | default renderer |
|---|---|---|
| `public.png` | FoundationModels: image segment; ACP: image block | `image` |
| `public.jpeg` | FoundationModels: image segment; ACP: image block | `image` |
| `public.heic` | FoundationModels: image segment; ACP: image block | `image` |
| `com.adobe.pdf` | FoundationModels: no; ACP: blob resource or resource link | `pdf` |
| `public.plain-text` | FoundationModels: no; ACP: text resource or resource link | `text` |
| `net.daringfireball.markdown` | FoundationModels: no; ACP: text resource or resource link | `text` |
| `public.swift-source` | FoundationModels: no; ACP: text resource or resource link | `code` |
| `public.python-script` | FoundationModels: no; ACP: text resource or resource link | `code` |
| `public.mp3` | FoundationModels: no; ACP: audio block | `audio` |
| `com.microsoft.waveform-audio` | FoundationModels: no; ACP: audio block | `audio` |
| `public.mpeg-4` | FoundationModels: no; ACP: blob resource or resource link | `movie` |
| `com.apple.quicktime-movie` | FoundationModels: no; ACP: blob resource or resource link | `movie` |
| `public.json` | FoundationModels: no; ACP: text resource or resource link | `chip` |
| `public.zip-archive` | FoundationModels: no; ACP: resource link | `chip` |
| `public.data` | FoundationModels: no; ACP: resource link | `chip` |

Renderer names:

- `image`: a preview of the image.
- `pdf`: a thumbnail from `QLThumbnailGenerator`.
- `text`: the text through Textual. A markdown file shows as Markdown.
- `code`: the text in a `CodeBlockView`.
- `audio`: an AVKit player with the controls only.
- `movie`: an AVKit player.
- `chip`: the file icon from `NSWorkspace`, the name, and the size.

`AttachmentView` walks the types in this order: `public.image`,
`com.adobe.pdf`, `public.source-code`, `public.plain-text`, `public.audio`,
`public.movie`. The first type that the file type conforms to gives the
renderer. A source file conforms to `public.plain-text` too, so
`public.source-code` comes first. A type that conforms to none of them shows
as a chip. A registration with `.attachmentView(for:)` replaces the default
for its type and each subtype.

## Survey

### FoundationModels

- A prompt holds `Transcript.Segment` values. The attachment segment
  (`Transcript.AttachmentSegment`) holds image content only. The
  FoundationModels source of the earlier kit mapped it to an image block. The
  ACP client kit has no FoundationModels source (`acp-client-kit.md`).

### ACP v2

- `PromptCapabilities` in `FoundationModelsACP` has three flags:
  - `image`: the agent accepts an image block.
  - `audio`: the agent accepts an audio block.
  - `embeddedContext`: the agent accepts a resource block. The resource holds
    text or a base64 blob.
- A resource link block is always permitted. The agent reads the file itself.
- Thus a client sends a text file as a text resource, a binary file as a blob
  resource or as a resource link, and other files as a resource link.
