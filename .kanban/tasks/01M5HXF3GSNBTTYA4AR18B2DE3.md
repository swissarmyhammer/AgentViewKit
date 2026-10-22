---
assignees:
- claude-code
position_column: todo
position_ordinal: a180
title: 'AVK-14c Add #Preview blocks for AttachmentPreview, its parts, and AttachmentActions'
---
## Goal

The user examines the look of each component in the Xcode canvas. These attachment views have no `#Preview`:

- `Sources/AgentViewKit/Attachments/AttachmentPreview.swift` — `AttachmentPreview`, `LoadStateView`, `ImagePreview`, `ThumbnailPreview`, `TextFilePreview`, `AttachmentTextContent`, `MediaPlayerPreview`
- `Sources/AgentViewKit/Attachments/AttachmentActions.swift` — `AttachmentActions` (the 5 buttons of AVK-11)

## Change

Add `#Preview` blocks in the same file as each view. Use `Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift`. Make each file that a preview needs in a temporary directory, or put it in the fixtures as data. Give each preview a name that tells its state.

- [ ] `AttachmentPreview`: an image, a text file, a long text file, an audio file, a video file, a file kind with no preview, a file that is missing, and the load state.
- [ ] `ThumbnailPreview`: a wide image, a tall image, and a very small image.
- [ ] `AttachmentActions`: a local file (all 5 buttons available), a web URL (only Open and Share available), and a missing file (all buttons not available). Use a recording `AttachmentFileService`, so that a press in the canvas does not open Finder or a panel.

## Rules

- No new public API. No backward compatibility code (ARCHITECTURE.md).
- The package builds with 0 warnings. The full suite passes with the window monitor. #avk-14