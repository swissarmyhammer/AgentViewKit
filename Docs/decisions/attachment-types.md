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

## Default renderers

| UTType | source support | default renderer |
|---|---|---|
| `public.png` | FoundationModels: image segment; ACP: image block; Router: image segment | `image` |
| `public.jpeg` | FoundationModels: image segment; ACP: image block; Router: image segment | `image` |
| `public.heic` | FoundationModels: image segment; ACP: image block; Router: image segment | `image` |
| `com.adobe.pdf` | FoundationModels: no; ACP: blob resource or resource link; Router: no | `pdf` |
| `public.plain-text` | FoundationModels: no; ACP: text resource or resource link; Router: no | `text` |
| `net.daringfireball.markdown` | FoundationModels: no; ACP: text resource or resource link; Router: no | `text` |
| `public.swift-source` | FoundationModels: no; ACP: text resource or resource link; Router: no | `code` |
| `public.python-script` | FoundationModels: no; ACP: text resource or resource link; Router: no | `code` |
| `public.mp3` | FoundationModels: no; ACP: audio block; Router: no | `audio` |
| `com.microsoft.waveform-audio` | FoundationModels: no; ACP: audio block; Router: no | `audio` |
| `public.mpeg-4` | FoundationModels: no; ACP: blob resource or resource link; Router: no | `movie` |
| `com.apple.quicktime-movie` | FoundationModels: no; ACP: blob resource or resource link; Router: no | `movie` |
| `public.json` | FoundationModels: no; ACP: text resource or resource link; Router: no | `chip` |
| `public.zip-archive` | FoundationModels: no; ACP: resource link; Router: no | `chip` |
| `public.data` | FoundationModels: no; ACP: resource link; Router: no | `chip` |

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
  (`Transcript.AttachmentSegment`) holds image content only. The kit maps it
  to an image block (plan.md §3.3).

### ACP v2

- `PromptCapabilities` in `FoundationModelsACP` has three flags:
  - `image`: the agent accepts an image block.
  - `audio`: the agent accepts an audio block.
  - `embeddedContext`: the agent accepts a resource block. The resource holds
    text or a base64 blob.
- A resource link block is always permitted. The agent reads the file itself.
- Thus a client sends a text file as a text resource, a binary file as a blob
  resource or as a resource link, and other files as a resource link.

### FoundationModelsRouter

- `RoutedSession.enqueue(prompt:)` takes a `Transcript.Prompt`. Thus the
  Router accepts what FoundationModels accepts: image segments.
- `TranscriptEntryMapper` persists an attachment segment only as an image URL.
  An attachment segment with no URL rebuilds as a text segment with its label.
- `ToolCallAttachment` records are structured records, keyed by schema name,
  that a tool attaches to its call. The Router never renders them to the
  model. They are not prompt attachments.
- For a file that is not an image, the host must put the text in the prompt,
  or give the path to a tool that reads the file.
