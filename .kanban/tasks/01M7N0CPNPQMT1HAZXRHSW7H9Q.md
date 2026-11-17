---
assignees:
- claude-code
position_column: done
position_ordinal: ffffffde80
title: 'D196 (b): Finder look for file items — Quick Look thumbnail, workspace icon placeholder'
---
Peer request from testudoapp-75 (TestudoApp decision D196, 25c4cf6).

Each AVK place that shows a file as an item shows what Finder shows:
- AttachmentChip (the chat, the composer chips, the fallback of AttachmentView).
- The header of ArtifactView: replace the SF Symbol `AgentSymbol.artifact` with the file image.

Behavior:
- Request the Quick Look thumbnail with `QLThumbnailGenerator`, representation types `.thumbnail` and `.icon`, at the screen scale, in icon mode.
- Until the thumbnail is ready, and when there is none, show `NSWorkspace.shared.icon(forFile:)`.
- AVK draws no type icons of its own.
- Keep `.openAttachment` and the title "Open". Do not deprecate `AttachmentInspector` (D196 (a): no change).

Acceptance:
- Unit tests for the thumbnail request and the fallback.
- A gallery image with real thumbnails (compile only; no hosted runs).
- No XCUITests.

#peer #attachments