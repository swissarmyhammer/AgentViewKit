---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: The transcript rows line up with the bars
---
Design decision of editorkit-9f (2026-11-09; the user asked for bars that are aligned and look good): in each view, the leading and trailing edges of the list content line up with the edges of the bars.

## What to do
- AgentThreadView and ConversationView: the horizontal content margin of the transcript list is the leading and the trailing value of `@Environment(\.barInsets)`. The left edge of each row surface (a tool call card, a message row) stands exactly under the left edge of the glass header and of the composer glass (12 pt with the default theme).
- Keep the vertical margins of the list.
- With no host inset (`\.barInsets` is zero), the horizontal margin is zero.
- The list today pads its rows with `.padding(editorStyle.rowPadding)` inside the ScrollView (ConversationView.swift, `list`). Change only its horizontal part.
- Add a hosted test: with `.barInsets()`, the minX of the header glass, the minX of the composer glass and the minX of the first row surface are equal. It must fail before the change.
- Report the measured x of the three edges.

## Acceptance
- [ ] The new test passes, and it fails before the change.
- [ ] Unit, integration and screenshot suites pass.